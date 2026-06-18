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
- [Tool Details](#tool-details)
- [Comparison](#comparison)
- [Installation](#installation)
- [Usage Tips](#usage-tips)
- [Other AI Tools](#works-with-other-ai-tools)
- [License](#license)

## Why?

Claude Code's built-in `WebSearch` / `WebFetch` are weak at Chinese content and can't render SPA sites. The MCP ecosystem has excellent search tools — this strategy **composes them** so you always get the best result.

## Tools

| Tool | Type | Link | Summary |
|------|------|------|---------|
| **tavily** | MCP Service | [tavily.com](https://www.tavily.com/) | AI search engine — server-side crawling with auto-summarized results |
| **web-search** | MCP Service | [npm: open-websearch](https://www.npmjs.com/package/open-websearch) | Multi-engine aggregator (Baidu / Bing / Google / DuckDuckGo / CSDN / Juejin) |
| **context7** | MCP Service | [GitHub: upstash/context7](https://github.com/upstash/context7) | Precise technical doc lookup with code examples |
| **chrome-devtools** | MCP Service | [npm: chrome-devtools-mcp](https://www.npmjs.com/package/chrome-devtools-mcp) | Browser automation — the ultimate SPA scraper |

## Strategy Overview

```
User query
  ├── "How do I use X / what's the API" → context7
  ├── "Search X" (Chinese)               → web-search + Baidu
  ├── "Search X" (English)               → tavily
  ├── "Fetch this page"                  → check if SPA
  │   ├── Not SPA → tavily_extract / web-search fetchWebContent
  │   └── SPA     → chrome-devtools browser rendering
  ├── "Research X"                       → tavily_research
  └── All above failed                   → built-in WebSearch (fallback)
```

## Tool Details

### 1. Chinese Search → web-search + Baidu

- Baidu is the most reliable for Chinese content
- For tech articles: `engines: ["csdn"]` or `engines: ["juejin"]`
- Multi-source: `engines: ["baidu", "bing"]`
- ⚠️ You must set `engines` explicitly — default is Bing only

### 2. English Search → tavily

- Server-side crawling — no direct international access needed
- AI auto-summarizes results
- `tavily_research` for deep dives / `tavily_crawl` for bulk / `tavily_map` for sitemaps

### 3. Technical Docs → context7

- Best for React / Next.js / Tailwind / Prisma and other mainstream libraries
- Returns official docs + code examples, not search results
- Version-aware; fall back to search engines for niche libraries

### 4. SPA Sites → chrome-devtools

- Pure JS-rendered SPA sites return empty shells to fetch-based tools
- Browser renders the real DOM → `take_snapshot` captures actual content
- Telltale sign: fetch returns near-empty JSON or minimal text

### 5. Fallback → Built-in WebSearch / WebFetch

- Only when all other tools are unavailable
- Never use as first choice

## Comparison

| Capability | Built-in | tavily | web-search | context7 |
|------------|:-------:|:------:|:----------:|:--------:|
| Chinese search | ❌ | ⚠️ | ✅ | ❌ |
| English search | ⚠️ | ✅ | ✅ | ❌ |
| Technical docs | ❌ | ⚠️ | ⚠️ | ✅ |
| AI summarization | ❌ | ✅ | ❌ | ❌ |
| SPA scraping | ❌ | ❌ | ❌ | ❌ |
| API key required | ❌ | ✅ | ❌ | ❌ |

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Node.js](https://nodejs.org/) 18+
- [Chrome](https://www.google.com/chrome/) (for chrome-devtools)

### Quick Install (Recommended)

```powershell
# Double-click setup.bat, or in PowerShell:
powershell -ExecutionPolicy Bypass -File setup.ps1
```

The script: prompts for Tavily key → checks dependencies → installs MCPs → choose strategy language (Chinese/English) → deploys strategy → shows status summary.

### Manual Install

```bash
# tavily (API key required — sign up at https://tavily.com)
claude mcp add --scope user tavily --transport http "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_KEY"

# web-search (free)
claude mcp add --scope user web-search -- cmd /c npx -y open-websearch@latest

# context7 (free)
claude mcp add --scope user context7 --transport http "https://mcp.context7.com/mcp"

# chrome-devtools (requires Chrome)
claude mcp add --scope user chrome-devtools -- cmd /c npx chrome-devtools-mcp@latest
```

### Verify

```bash
claude mcp list
```

### Deploy Strategy File

Copy the strategy file to your Claude Code config directory (use `strategy_en.md` for English):

```bash
# Windows
copy strategy.md %USERPROFILE%\.claude\CLAUDE.md

# Mac / Linux
cp strategy.md ~/.claude/CLAUDE.md
```

## Usage Tips

1. **Daily search**: Chinese → web-search + Baidu, English → tavily
2. **Tech docs**: context7 first — faster and more accurate than search
3. **SPA sites**: straight to chrome-devtools — don't waste time on other tools
4. **Deep research**: tavily_research — multi-source synthesis automatically

## Works with Other AI Tools

This strategy works with any MCP-compatible AI coding tool: [Cursor](https://cursor.sh/) · [Windsurf](https://codeium.com/windsurf) · [Cline](https://github.com/cline/cline) · [Continue](https://continue.dev/)

## License

[MIT](LICENSE)
