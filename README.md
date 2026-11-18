<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/platform-Claude%20Code-orange.svg" alt="Platform">
  <img src="https://img.shields.io/badge/MCP-4%20servers-brightgreen.svg" alt="MCP Servers">
</p>

# 🔍 Web Search MCP Strategy

> A Claude Code MCP search toolchain strategy — routes every query to the right engine automatically.

English | [简体中文](README_ZH.md)

## Table of Contents

- [Why?](#why)
- [Tools](#tools)
- [Strategy Overview](#strategy-overview)
- [Invocation Rules](#invocation-rules)
- [Tool Details](#tool-details)
- [Installation](#installation)
- [Files](#files)
- [License](#license)

## Why?

No single search tool covers everything: Chinese content, English research, library docs, and page fetching are better served by different services. Without a shared routing rule, the common failure modes are picking the wrong tool, wasting quota on redundant fetches, and lacking a defined fallback order.

This project provides an invocation-layer strategy plus install scripts:

- `search.md`: routing only — scenarios, trigger signals, priority (content type over language), and fallback order
- Install scripts: set up four MCP servers in one go (baidu-search, bright-data, context7, tavily)
- Optional fallbacks: the ccproxy command-level proxy (downloads only, last resort), plus browser-fallback guidance for ego-browser / chrome-devtools

## Tools

| Tool | Type | Link | Summary |
|------|------|------|---------|
| **baidu-search** | MCP Service | [百度AI搜索](https://cloud.baidu.com/doc/AppBuilder/s/zm8pn5cju) | Baidu AI Search — best Chinese quality |
| **bright-data** | MCP Service | [brightdata.com](https://brightdata.com/) | Professional web crawling with anti-blocking |
| **tavily** | MCP Service | [tavily.com](https://www.tavily.com/) | AI search engine — server-side crawling with auto-summarized results |
| **context7** | MCP Service | [GitHub: upstash/context7](https://github.com/upstash/context7) | Precise technical doc lookup with code examples |

> **Note**: baidu-search and bright-data work together as a combined Chinese search solution.
>
> **Note**: ccproxy is an optional fallback tool (in `ccproxy/`); after installing the four MCP servers, the import script asks whether to copy it to `~/.claude/skills/ccproxy`, then offers a two-level port-change prompt. ego-lite (which provides the `ego-browser` skill) and chrome-devtools-mcp are not handled by the script; see "Optional Tools (Install Yourself)" below.

## Strategy Overview

```
User query
  ├── "How do I use X / what's the API" → context7
  ├── "Search X" (Chinese)               → baidu-search + bright-data
  ├── "Search X" (English)               → tavily
  ├── "Fetch this page"                  → bright-data (domestic) / tavily_extract (international)
  ├── "Research X"                       → tavily_research
  ├── Network failure on downloads       → alternatives/mirrors first → ccproxy last resort
  └── All above failed                   → built-in WebSearch → browser fallback (ego-browser / chrome-devtools)
```

## Invocation Rules

- Chinese search → baidu-search + bright-data; English search → tavily; technical docs → context7 first
- Content type beats language: Chinese technical docs still go to context7
- Troubleshooting: API usage → context7; ready-made solutions → language-based search
- Split multi-intent queries; route search, fetch, and download separately
- Never use tavily or built-in WebSearch for Chinese content
- Fall back to search engines only for libraries context7 doesn't list
- Snippets first; fetch full text only for the top 1-3 results
- Retry the same tool at most once, then fall back
- MCP search never uses a proxy; the proxy is for download fallback only
- ccproxy default ports: Clash Verge 7897 / FlClash 7890; change via `/ccproxy port` (two-level prompt, saved to `~/.claude/ccproxy.json`)

## Tool Details

### 1. Chinese Search → baidu-search + bright-data

- baidu-search: Baidu AI Search, best Chinese quality, returns summary + URL
- bright-data: Professional web crawling with JS rendering, returns full content
- Workflow: baidu-search finds URLs → bright-data crawls full content

### 2. English Search → tavily

- Server-side crawling — no direct international access needed
- AI auto-summarizes results
- `tavily_research` for deep dives / `tavily_crawl` for bulk / `tavily_map` for sitemaps

### 3. Technical Docs → context7

- Best for React / Next.js / Tailwind / Prisma and other mainstream libraries
- Returns official docs + code examples, not search results
- Version-aware; fall back to search engines for niche libraries

### 4. Fallback → Built-in WebSearch / WebFetch → Browser

- Only when all other tools are unavailable
- On network failures while downloading/cloning/installing: try official alternatives/domestic mirrors first; use ccproxy only as a last resort
- Login walls / anti-bot blocking crawls: ego-browser operates, chrome-devtools diagnoses

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Node.js](https://nodejs.org/) 18+

### Quick Import (Recommended)

#### Windows

Double-click `import.bat`, or run in terminal:

```powershell
.\import.ps1
```

#### Linux / macOS

```bash
chmod +x ./import.sh && ./import.sh
```

The script installs the four MCP servers (bright-data uses the official Remote MCP — no local install; context7 uses the `ctx7 setup` one-command install), then asks whether to install the optional ccproxy fallback skill (with an optional port-change prompt). Finally, `verify-mcp.mjs` performs one real tool call against each installed MCP server (this consumes a small amount of query quota).

### Manual Install

```bash
# baidu-search (SSE connection, no additional dependencies)
claude mcp add --scope user --transport sse baidu-search "http://appbuilder.baidu.com/v2/ai_search/mcp/sse?api_key=Bearer+YOUR_API_KEY"

# bright-data (official Remote MCP; get your token at https://brightdata.com/cp/setting/users)
claude mcp add --scope user --transport http bright-data "https://mcp.brightdata.com/mcp?token=YOUR_TOKEN"

# tavily (API key required — sign up at https://tavily.com)
claude mcp add --scope user --transport http tavily "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_KEY"

# context7 (one-command install: browser OAuth, then MCP config + rule + skill are written automatically)
npx -y ctx7 setup --mcp --claude --yes
```

Deploy strategy file (use `search_en.md` for English):

```bash
# Copy strategy to strategies directory
mkdir -p ~/.claude/strategies
cp search.md ~/.claude/strategies/search.md

# Add reference to CLAUDE.md
echo "@~/.claude/strategies/search.md" >> ~/.claude/CLAUDE.md
```

### Optional Tools (Install Yourself)

These tools are not installed by the import script; install them manually if needed:

#### ego-lite (browser fallback with your logins)

- Project: [citrolabs/ego-lite](https://github.com/citrolabs/ego-lite) (MIT)
- Use case: login walls / anti-bot pages — the agent drives a real browser in its own Space without taking over your tabs, reusing your Chrome logins
- Platforms: macOS (Apple Silicon / Intel), Windows x64; Linux is on the roadmap
- Install (either way):
  - Download the app: https://lite.ego.app
  - Install just the skill; the app install is guided on the first browser task:
    ```bash
    npx skills add citrolabs/ego-lite
    ```
- On first launch you can migrate your Chrome data (logins, cookies, extensions, bookmarks)
- Usage: run `/ego-browser <task>` in your agent

#### chrome-devtools-mcp (browser diagnostics / automation)

- Project: [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) (Apache-2.0)
- Use case: performance traces, network / console diagnostics, browser automation; drives your local Chrome
- Requirements: Node.js LTS (`^20.19.0 || ^22.12.0 || >=23`), current stable Chrome
- Install:
  ```bash
  claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
  ```
- Claude Code can also install it as a plugin:
  ```
  /plugin marketplace add ChromeDevTools/chrome-devtools-mcp
  /plugin install chrome-devtools-mcp@chrome-devtools-plugins
  ```
- Privacy: usage statistics are reported by default; disable with `--no-usage-statistics` (or set `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`)

### Verify

```bash
claude mcp list      # connection status
node verify-mcp.mjs  # real tool-call verification (the four search MCPs only)
```

## Works with Other AI Tools

This strategy works with any MCP-compatible AI coding tool: [Cursor](https://cursor.sh/) · [Windsurf](https://codeium.com/windsurf) · [Cline](https://github.com/cline/cline) · [Continue](https://continue.dev/)

## Files

- `search.md` — Invocation layer (Chinese): routing + decision flow + rules; full explanations in this README
- `search_en.md` — Invocation layer (English)
- `import.bat` / `import.ps1` / `import.sh` — Import scripts (four MCP servers only)
- `verify-mcp.mjs` — Real usability check (MCP handshake + actual tool calls)
- `ccproxy/` — Command-level proxy skill (optional fallback, not installed by the import script)

## License

[MIT](LICENSE)
