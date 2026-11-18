#!/usr/bin/env node
/**
 * ccproxy — command-level proxy wrapper (last-resort download fallback).
 *
 * Runs ONE command through the local proxy when it needs to reach foreign
 * resources (GitHub / npm registry / PyPI / crates.io / download sites).
 *
 * It does NOT touch MCP search traffic (baidu-search / tavily / context7),
 * does not write global config files, and has no init/global/project modes.
 *
 * Ports: defaults are Clash Verge 127.0.0.1:7897 and FlClash 127.0.0.1:7890.
 * Users can override them via `ccproxy port`; overrides are stored in
 * ~/.claude/ccproxy.json (only written when a port is actually changed).
 */

import net from "node:net";
import os from "node:os";
import path from "node:path";
import fs from "node:fs";
import { spawn } from "node:child_process";
import readline from "node:readline/promises";

const DEFAULT_PROXIES = [
  { name: "Clash Verge", host: "127.0.0.1", port: 7897 },
  { name: "FlClash", host: "127.0.0.1", port: 7890 },
];

const CONFIG_PATH = path.join(os.homedir(), ".claude", "ccproxy.json");
const PROBE_TIMEOUT_MS = 800;
const NO_PROXY_VALUE = "localhost,127.0.0.1,::1";

function validPort(n) {
  return Number.isInteger(n) && n >= 1 && n <= 65535;
}

function loadProxies() {
  let saved = {};
  try {
    const raw = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
    for (const p of DEFAULT_PROXIES) {
      const v = raw[p.name];
      if (validPort(v)) saved[p.name] = v;
    }
  } catch {
    // no config or invalid JSON -> defaults
  }
  return DEFAULT_PROXIES.map((p) => ({
    ...p,
    port: saved[p.name] ?? p.port,
  }));
}

function saveProxies(proxies) {
  const data = {};
  for (const p of proxies) data[p.name] = p.port;
  fs.mkdirSync(path.dirname(CONFIG_PATH), { recursive: true });
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(data, null, 2) + "\n", "utf8");
}

function resolveProxy(proxies, input) {
  const norm = (s) => s.toLowerCase().replace(/[\s_.-]/g, "");
  const key = norm(input);
  if (["clash", "clashverge", "verge"].includes(key)) {
    return proxies.find((p) => p.name === "Clash Verge");
  }
  if (["flclash", "fl"].includes(key)) {
    return proxies.find((p) => p.name === "FlClash");
  }
  return proxies.find((p) => norm(p.name) === key);
}

function probe({ host, port }) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port });
    let settled = false;
    const done = (ok) => {
      if (settled) return;
      settled = true;
      socket.destroy();
      resolve(ok);
    };
    socket.setTimeout(PROBE_TIMEOUT_MS);
    socket.once("connect", () => done(true));
    socket.once("timeout", () => done(false));
    socket.once("error", () => done(false));
  });
}

async function detectProxy() {
  const proxies = loadProxies();
  for (const proxy of proxies) {
    if (await probe(proxy)) return proxy;
  }
  return null;
}

function usage() {
  console.log(
    [
      "ccproxy — 命令级代理（只作用于单条命令）",
      "",
      "用法:",
      "  node ccproxy.mjs run -- <命令...>              通过本地代理执行一条命令",
      "  node ccproxy.mjs detect                        输出检测到的代理（JSON）",
      "  node ccproxy.mjs port                          查看端口配置（终端内可两级修改）",
      "  node ccproxy.mjs port --json                   输出当前端口配置（JSON）",
      '  node ccproxy.mjs port --set "<软件名>=<端口>"   保存端口修改，如 "FlClash=7891"',
      "",
      "默认端口: Clash Verge 127.0.0.1:7897 → FlClash 127.0.0.1:7890",
      "配置文件: ~/.claude/ccproxy.json（不存在时使用默认值）",
      "",
      "兜底用法: 确认网络层问题、且官方替代通道/国内镜像不可用时，才包一层执行",
      "不适用: MCP 搜索（baidu-search / tavily / context7）；非网络错误（404/401/权限）",
    ].join("\n"),
  );
}

async function portCommand(args) {
  const proxies = loadProxies();

  if (args[0] === "--json") {
    const data = {};
    for (const p of proxies) data[p.name] = p.port;
    console.log(JSON.stringify(data));
    return;
  }

  if (args[0] === "--set") {
    const spec = args[1] || "";
    const m = spec.match(/^(.+?)=(\d+)$/);
    if (!m) {
      console.error('用法: node ccproxy.mjs port --set "<软件名>=<端口>"');
      process.exit(1);
    }
    const proxy = resolveProxy(proxies, m[1].trim());
    if (!proxy) {
      console.error(`未知代理软件: ${m[1].trim()}（可选: ${proxies.map((p) => p.name).join(" / ")}）`);
      process.exit(1);
    }
    const port = Number(m[2]);
    if (!validPort(port)) {
      console.error("端口无效：必须是 1-65535 的整数");
      process.exit(1);
    }
    proxy.port = port;
    saveProxies(proxies);
    console.log(`已保存：${proxy.name} → ${proxy.host}:${port}`);
    console.log(`配置文件：${CONFIG_PATH}`);
    return;
  }

  console.log("当前代理端口:");
  for (const p of proxies) {
    console.log(`  ${p.name}: ${p.host}:${p.port}`);
  }
  console.log(`配置文件：${CONFIG_PATH}${fs.existsSync(CONFIG_PATH) ? "" : "（不存在，使用默认值）"}`);

  if (!process.stdin.isTTY) {
    console.log("");
    console.log('非交互环境：请用 port --set "<软件名>=<端口>" 保存修改。');
    return;
  }

  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    console.log("");
    console.log("修改哪一个代理软件？");
    proxies.forEach((p, i) => console.log(`  [${i + 1}] ${p.name}（当前 ${p.port}）`));
    console.log(`  [${proxies.length + 1}] 不修改，退出（保持默认）`);

    const choice = (await rl.question("请选择: ")).trim();
    const idx = Number(choice) - 1;
    if (choice === "" || choice === "0" || choice === String(proxies.length + 1)) {
      console.log("已退出，未修改。");
      return;
    }
    if (!Number.isInteger(idx) || idx < 0 || idx >= proxies.length) {
      console.log("无效选择，已退出，未修改。");
      return;
    }

    const proxy = proxies[idx];
    console.log("");
    console.log(`输入 ${proxy.name} 的新端口（1-65535）`);
    console.log(`  [${proxies.length + 1}] 不修改，退出（保持当前 ${proxy.port}）`);

    const portInput = (await rl.question("新端口: ")).trim();
    if (portInput === "" || portInput === "0" || portInput === String(proxies.length + 1)) {
      console.log("已退出，未修改。");
      return;
    }
    const port = Number(portInput);
    if (!validPort(port)) {
      console.log("端口无效，已退出，未修改。");
      return;
    }
    proxy.port = port;
    saveProxies(proxies);
    console.log(`已保存：${proxy.name} → ${proxy.host}:${port}`);
  } finally {
    rl.close();
  }
}

// cmd.exe quoting: wrap args containing spaces/quotes in double quotes.
// Typical args (URLs, package names) contain neither, so this stays simple.
function quoteWinArg(arg) {
  if (arg === "") return '""';
  if (/[\s"]/.test(arg)) return '"' + arg.replace(/"/g, '""') + '"';
  return arg;
}

function buildEnv(proxyUrl) {
  const env = {
    ...process.env,
    HTTP_PROXY: proxyUrl,
    HTTPS_PROXY: proxyUrl,
    ALL_PROXY: proxyUrl,
    npm_config_proxy: proxyUrl,
    npm_config_https_proxy: proxyUrl,
    NO_PROXY: NO_PROXY_VALUE,
  };
  if (process.platform !== "win32") {
    // Lowercase variants for tools that only check them (e.g. python urllib).
    env.http_proxy = proxyUrl;
    env.https_proxy = proxyUrl;
    env.all_proxy = proxyUrl;
    env.no_proxy = NO_PROXY_VALUE;
  }
  return env;
}

async function runCommand(args) {
  if (args.length === 0) {
    usage();
    process.exit(1);
  }

  const proxy = await detectProxy();
  if (!proxy) {
    console.error(
      "未检测到本地代理：请先启动 Clash Verge (127.0.0.1:7897) 或 FlClash (127.0.0.1:7890)，" +
        "或先用 port --set 调整端口",
    );
    process.exit(2);
  }

  const proxyUrl = `http://${proxy.host}:${proxy.port}`;
  const env = buildEnv(proxyUrl);
  console.error(`[ccproxy] ${proxy.name} ${proxyUrl} -> ${args.join(" ")}`);

  const isWin = process.platform === "win32";
  const child = isWin
    ? spawn(args.map(quoteWinArg).join(" "), { stdio: "inherit", env, shell: true })
    : spawn(args[0], args.slice(1), { stdio: "inherit", env });

  child.on("error", (err) => {
    console.error(`[ccproxy] 无法启动命令: ${err.message}`);
    process.exit(127);
  });
  child.on("exit", (code, signal) => {
    process.exit(signal ? 1 : (code ?? 0));
  });
}

async function main() {
  const [command, ...rest] = process.argv.slice(2);

  if (!command || command === "help" || command === "--help" || command === "-h") {
    usage();
    process.exit(command ? 0 : 1);
  }

  if (command === "detect") {
    const proxy = await detectProxy();
    console.log(JSON.stringify(proxy, null, 2));
    process.exit(0);
  }

  if (command === "port") {
    await portCommand(rest);
    return;
  }

  if (command !== "run") {
    console.error(`未知命令: ${command}\n`);
    usage();
    process.exit(1);
  }

  const args = rest[0] === "--" ? rest.slice(1) : rest;
  await runCommand(args);
}

main();
