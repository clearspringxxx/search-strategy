# 🔍 Web Search MCP Strategy

> A battle-tested Claude Code web search toolchain strategy — picks the right search tool for every scenario.

## Why do you need this?

Claude Code's built-in `WebSearch` and `WebFetch` have limitations (poor Chinese results, can't handle SPA sites). The MCP ecosystem offers several excellent search tools, each with its own strengths. This strategy **composes them together** to cover Chinese/English search, technical docs, SPA scraping, and more.

## Tools

| Tool | Type | Link | Summary |
|------|------|------|---------|
| **tavily** | MCP Service | [tavily.com](https://www.tavily.com/) | AI search engine — server-side crawling with auto-summarized results |
| **web-search** | MCP Service | [npm: open-websearch](https://www.npmjs.com/package/open-websearch) | Multi-engine aggregator (Baidu, Bing, Google, DuckDuckGo, CSDN, Juejin, etc.) |
| **context7** | MCP Service | [GitHub: upstash/context7](https://github.com/upstash/context7) | Precise technical documentation lookup for mainstream libraries |
| **chrome-devtools** | MCP Service | [npm: chrome-devtools-mcp](https://www.npmjs.com/package/chrome-devtools-mcp) | Browser automation — the ultimate solution for SPA websites |

## Strategy Overview

```
User asks a question
  ├── "How do I use X / what's the API / how to configure" → context7
  ├── "Search for X" (Chinese) → web-search + Baidu
  ├── "Search for X" (English) → tavily
  ├── "Fetch this webpage" → check if SPA first
  │     ├── Not SPA → tavily_extract (international) / web-search fetchWebContent (domestic)
  │     └── SPA → chrome-devtools browser rendering
  ├── "Research X topic" → tavily_research
  └── All above failed → built-in WebSearch (fallback)
```

## Tool Details

### 1. Chinese Search → web-search + Baidu

**Best for**: Chinese-language searches, domestic tech articles

- Baidu is the most reliable for Chinese content, no connectivity issues in China
- For tech articles, set `engines: ["csdn"]` or `engines: ["juejin"]`
- For multi-source coverage, use `engines: ["baidu", "bing"]`

**Note**: You must explicitly specify `engines`. The default is Bing only.

### 2. English Search → tavily

**Best for**: English searches, AI-summarized results, batch fetching

- Server-side crawling — no need for direct international access
- AI auto-summarizes results, saving you filtering time
- Use `tavily_research` for deep research topics
- Use `tavily_crawl` / `tavily_map` for bulk fetching or sitemaps

### 3. Technical Docs → context7

**Best for**: Looking up React / Next.js / Tailwind / Prisma and other mainstream libraries

- More precise than search engines — returns official docs + code examples
- Supports version-specific queries (e.g., Next.js v14 vs v15)
- Fall back to search engines only for niche or unlisted libraries

### 4. SPA Sites → chrome-devtools Browser

**Best for**: Pure JS-rendered SPA sites (icourse163, most modern frontend apps)

- Search engines and fetch tools can only get empty shells from SPA sites
- Use browser rendering to capture real DOM content
- Telltale sign: fetch returns empty JSON or minimal content

### 5. Emergency Fallback → Built-in WebSearch / WebFetch

- Only use when the above tools are unavailable
- Do not use as the first choice

## Comparison

| Capability | Built-in Search | tavily | web-search | context7 |
|------------|----------------|--------|------------|----------|
| Chinese search | ❌ Poor | ⚠️ Average | ✅ Baidu support | ❌ |
| English search | ⚠️ Average | ✅ Excellent | ✅ Multi-engine | ❌ |
| Technical docs | ❌ | ⚠️ | ⚠️ | ✅ Precise |
| AI summarization | ❌ | ✅ | ❌ | ❌ |
| SPA scraping | ❌ | ❌ | ❌ | ❌ |
| API key required | ❌ | ✅ | ❌ | ❌ |

## Installation

### Prerequisites

- [Claude Code](https://claude.ai/code) installed
- [Node.js](https://nodejs.org/) 18+
- [Chrome browser](https://www.google.com/chrome/) (required by chrome-devtools)

### Quick Install Script (Windows)

An interactive one-click installer that guides you through setting up all MCP services:

```powershell
# Double-click to run (recommended)
setup.bat

# Or run in PowerShell
powershell -ExecutionPolicy Bypass -File setup.ps1
```

What the script does:
- Interactive input for Tavily API Key (can be skipped)
- Auto-detects Node.js and Claude Code
- Auto-skips already-installed MCP services (safe to re-run)
- Installs the strategy file to `~/.claude/CLAUDE.md`, with skip/append/overwrite options if one already exists
- Final status summary of all four search MCPs

### Manual Install

```bash
# tavily (requires API key — sign up at https://tavily.com)
claude mcp add --scope user tavily --transport http "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_API_KEY"

# web-search (free, no API key needed)
claude mcp add --scope user web-search -- cmd /c npx -y open-websearch@latest

# context7 (free, no API key needed)
claude mcp add --scope user context7 --transport http "https://mcp.context7.com/mcp"

# chrome-devtools (requires Chrome browser)
claude mcp add --scope user chrome-devtools -- cmd /c npx chrome-devtools-mcp@latest
```

> Replace `YOUR_API_KEY` with your Tavily API key. All other tools are free and require no registration.

### Verify Installation

```bash
claude mcp list
```

All tools should show `✔ Connected`.

## Usage Tips

1. **Daily search**: web-search + Baidu for Chinese, tavily for English
2. **Technical docs**: context7 first — it's faster and more accurate than search engines
3. **SPA sites**: go straight to chrome-devtools; don't waste time on other tools
4. **Deep research**: use tavily_research — it synthesizes info from multiple sources automatically

## Strategy File

[strategy.md](strategy.md) is the Claude Code strategy configuration file with the complete search tool selection rules. Copy it to `~/.claude/` and rename to `CLAUDE.md` to enable it globally:

```bash
# Windows
copy strategy.md %USERPROFILE%\.claude\CLAUDE.md

# Mac/Linux
cp strategy.md ~/.claude/CLAUDE.md
```

## Works with Other AI Tools

This strategy is not limited to Claude Code — it works with any MCP-compatible AI coding tool:

- [Cursor](https://cursor.sh/)
- [Windsurf](https://codeium.com/windsurf)
- [Cline](https://github.com/cline/cline)
- [Continue](https://continue.dev/)

## License

MIT
