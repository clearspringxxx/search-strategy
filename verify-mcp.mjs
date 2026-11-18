#!/usr/bin/env node
// 联网搜索 MCP 真实可用性验证
// 对 ~/.claude.json 中配置的四个 MCP 各执行一次：initialize 握手 + notifications/initialized + tools/call
// 仅统计已安装的服务器；退出码 0 = 全部通过，1 = 存在失败

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

if (typeof fetch !== "function") {
  console.error("需要 Node.js 18 或更高版本（当前版本不支持 fetch）");
  process.exit(1);
}

const CONFIG_PATH = path.join(os.homedir(), ".claude.json");
const PROTOCOL_VERSION = "2024-11-05";
const CLIENT_INFO = { name: "search-strategy-verify", version: "1.0.0" };

const TESTS = [
  {
    name: "baidu-search",
    tool: "AIsearch",
    args: { query: "MCP 连通性测试", resource_type_filter: [{ type: "web", top_k: 1 }] },
    detail: textSummary,
  },
  {
    name: "bright-data",
    tool: "search_engine",
    args: { query: "connectivity test", engine: "bing" },
    detail: textSummary,
  },
  {
    name: "context7",
    tool: "resolve-library-id",
    args: { libraryName: "react", query: "React hooks usage" },
    detail: (r) => libraryId(r) || textSummary(r),
  },
  {
    name: "tavily",
    tool: "tavily_search",
    args: { query: "connectivity test", max_results: 1, search_depth: "ultra-fast" },
    detail: textSummary,
  },
];

function contentText(result) {
  if (!result) return "";
  if (Array.isArray(result.content)) {
    const parts = result.content
      .filter((p) => p && p.type === "text" && typeof p.text === "string")
      .map((p) => p.text);
    if (parts.length) return parts.join("\n");
  }
  if (result.structuredContent) return JSON.stringify(result.structuredContent);
  return JSON.stringify(result);
}

function textSummary(result) {
  const t = contentText(result).replace(/\s+/g, " ").trim();
  if (!t) return "调用成功（无文本返回）";
  return t.length > 90 ? t.slice(0, 90) + "…" : t;
}

function libraryId(result) {
  const m = contentText(result).match(/Context7-compatible library ID:\s*(\S+)/);
  return m ? m[1] : null;
}

function initRequest(id) {
  return {
    jsonrpc: "2.0",
    id,
    method: "initialize",
    params: { protocolVersion: PROTOCOL_VERSION, capabilities: {}, clientInfo: CLIENT_INFO },
  };
}

function callRequest(id, test) {
  return {
    jsonrpc: "2.0",
    id,
    method: "tools/call",
    params: { name: test.tool, arguments: test.args },
  };
}

function parseSseChunk(chunk) {
  const events = [];
  let event = "message";
  let data = [];
  const flush = () => {
    if (data.length) events.push({ event, data: data.join("\n") });
    event = "message";
    data = [];
  };
  for (const line of chunk.split(/\r?\n/)) {
    if (line === "") {
      flush();
      continue;
    }
    if (line.startsWith(":")) continue;
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) data.push(line.slice(5).trimStart());
  }
  flush();
  return events;
}

function parseRpcPayload(raw) {
  const trimmed = raw.trim();
  if (!trimmed) return null;
  if (trimmed.startsWith("event:") || trimmed.startsWith("data:")) {
    let fallback = null;
    for (const ev of parseSseChunk(trimmed)) {
      if (ev.event !== "message") continue;
      try {
        const msg = JSON.parse(ev.data);
        if (msg.id !== undefined || msg.result !== undefined || msg.error !== undefined) return msg;
        fallback = msg;
      } catch {}
    }
    return fallback;
  }
  try {
    return JSON.parse(trimmed);
  } catch {
    return null;
  }
}

async function postOnce(url, headers, body, sessionId, timeoutMs) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const h = {
      "Content-Type": "application/json",
      Accept: "application/json, text/event-stream",
      ...headers,
    };
    if (sessionId) h["Mcp-Session-Id"] = sessionId;
    const res = await fetch(url, { method: "POST", headers: h, body: JSON.stringify(body), signal: ctrl.signal });
    const raw = await res.text();
    return {
      status: res.status,
      sessionId: res.headers.get("mcp-session-id"),
      data: parseRpcPayload(raw),
      raw,
    };
  } finally {
    clearTimeout(timer);
  }
}

function assertResult(result, status) {
  if (!result) throw new Error(`工具调用无结果（HTTP ${status}）`);
  if (result.isError) throw new Error(`工具返回错误：${textSummary(result)}`);
}

async function testHttp(entry, test) {
  const url = entry.url;
  const headers = entry.headers || {};
  const init = await postOnce(url, headers, initRequest(1), null, 20000);
  if (!init.data || init.data.error) throw new Error(`initialize 失败（HTTP ${init.status}）`);
  const sid = init.sessionId || null;
  await postOnce(url, headers, { jsonrpc: "2.0", method: "notifications/initialized" }, sid, 10000);
  const call = await postOnce(url, headers, callRequest(2, test), sid, 30000);
  if (call.data && call.data.error) throw new Error(`工具调用错误：${JSON.stringify(call.data.error).slice(0, 120)}`);
  const result = call.data && call.data.result;
  assertResult(result, call.status);
  return test.detail(result);
}

async function testSse(entry, test) {
  const url = entry.url;
  const headers = { Accept: "text/event-stream", ...(entry.headers || {}) };
  const ctrl = new AbortController();
  const hardTimer = setTimeout(() => ctrl.abort(), 60000);
  const pending = new Map();
  let postUrl = null;
  let streamError = null;

  const res = await fetch(url, { method: "GET", headers, signal: ctrl.signal });
  if (!res.ok || !res.body) throw new Error(`SSE 连接失败（HTTP ${res.status}）`);
  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  (async () => {
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        // SSE 允许 CRLF；统一成 LF 后再按空行切分事件
        buffer = buffer.replace(/\r\n/g, "\n");
        let idx;
        while ((idx = buffer.indexOf("\n\n")) !== -1) {
          const chunk = buffer.slice(0, idx);
          buffer = buffer.slice(idx + 2);
          for (const ev of parseSseChunk(chunk)) {
            if (ev.event === "endpoint") {
              postUrl = new URL(ev.data.trim(), url).toString();
            } else if (ev.event === "message") {
              let msg;
              try {
                msg = JSON.parse(ev.data);
              } catch {
                continue;
              }
              if (msg.id !== undefined && pending.has(msg.id)) {
                const cb = pending.get(msg.id);
                pending.delete(msg.id);
                cb.resolve(msg);
              }
            } else if (ev.event === "error") {
              streamError = ev.data;
            }
          }
        }
      }
    } catch (e) {
      if (e.name !== "AbortError") streamError = e.message;
    }
  })();

  const waitUntil = async (predicate, ms, what) => {
    const end = Date.now() + ms;
    while (Date.now() < end) {
      if (predicate()) return;
      if (streamError) throw new Error(`SSE 错误：${streamError}`);
      await new Promise((r) => setTimeout(r, 100));
    }
    throw new Error(`等待${what}超时`);
  };

  await waitUntil(() => postUrl, 10000, " endpoint");

  const sseHeaders = { "Content-Type": "application/json", ...(entry.headers || {}) };
  const rpc = (body, timeoutMs) =>
    new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        pending.delete(body.id);
        reject(new Error("等待 SSE 响应超时"));
      }, timeoutMs);
      pending.set(body.id, {
        resolve: (msg) => {
          clearTimeout(timer);
          resolve(msg);
        },
      });
      fetch(postUrl, { method: "POST", headers: sseHeaders, body: JSON.stringify(body), signal: ctrl.signal })
        .then(async (r) => {
          if (!r.ok) {
            clearTimeout(timer);
            pending.delete(body.id);
            reject(new Error(`POST 失败（HTTP ${r.status}）`));
          }
          try {
            await r.text();
          } catch {}
        })
        .catch((e) => {
          clearTimeout(timer);
          pending.delete(body.id);
          reject(e);
        });
    });

  try {
    const init = await rpc(initRequest(1), 20000);
    if (init.error) throw new Error(`initialize 错误：${JSON.stringify(init.error).slice(0, 120)}`);
    const notifyRes = await fetch(postUrl, {
      method: "POST",
      headers: sseHeaders,
      body: JSON.stringify({ jsonrpc: "2.0", method: "notifications/initialized" }),
      signal: ctrl.signal,
    });
    try {
      await notifyRes.text();
    } catch {}
    const call = await rpc(callRequest(2, test), 30000);
    if (call.error) throw new Error(`工具调用错误：${JSON.stringify(call.error).slice(0, 120)}`);
    assertResult(call.result, 200);
    return test.detail(call.result);
  } finally {
    clearTimeout(hardTimer);
    try {
      await reader.cancel();
    } catch {}
    ctrl.abort();
  }
}

async function main() {
  let config;
  try {
    config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
  } catch (e) {
    console.error(`无法读取 ${CONFIG_PATH}：${e.message}`);
    process.exit(1);
  }

  const servers = config.mcpServers || {};
  const installed = TESTS.filter((t) => servers[t.name] && servers[t.name].url);
  const skipped = TESTS.filter((t) => !installed.includes(t));

  for (const t of skipped) console.log(`  [SKIP] ${t.name}：未安装`);

  let ok = 0;
  let fail = 0;
  for (const test of installed) {
    const entry = servers[test.name];
    const type = String(entry.type || "").toLowerCase();
    const isSse = type === "sse" || (!type && /\/sse(\?|$)/.test(entry.url || ""));
    try {
      const detail = isSse ? await testSse(entry, test) : await testHttp(entry, test);
      ok++;
      console.log(`  [OK]   ${test.name}：${detail}`);
    } catch (e) {
      fail++;
      const hint =
        test.name === "context7" && /Invalid API key/i.test(e.message)
          ? "（修复：npx -y ctx7 logout && npx -y ctx7 login && npx -y ctx7 setup --mcp --claude --yes）"
          : "";
      console.log(`  [FAIL] ${test.name}：${e.message}${hint}`);
    }
  }

  console.log(`  总计: ${ok + fail} | 正常: ${ok} | 异常: ${fail}`);
  process.exit(fail > 0 ? 1 : 0);
}

main();
