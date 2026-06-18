# Web Search MCP Strategy

## Tool Priority

Choose the right tool for each scenario. Don't blindly use defaults.

### Chinese Search → web-search (engines: ["baidu"])
- Baidu is most reliable for Chinese content; no connectivity issues in China
- For tech articles: `engines: ["csdn"]` or `engines: ["juejin"]`
- For multi-source coverage: `engines: ["baidu", "bing"]`

### English Search → tavily
- Server-side crawling; no direct international access needed
- AI auto-summarizes results for you
- Deep research: `tavily_research`
- Bulk fetching / sitemaps: `tavily_crawl` / `tavily_map`

### Technical Documentation → context7
- Best for React / Next.js / Tailwind / Prisma and other mainstream libraries
- More precise than search engines — returns official docs + code examples
- Fall back to search engines only for niche or unlisted libraries

### SPA / JS-Rendered Sites → chrome-devtools Browser
- Pure JS-rendered SPA sites (e.g. icourse163, most modern frontend apps) return empty shells to search engines and fetch tools
- Telltale sign: `fetchWebContent` returns empty JSON or minimal content; search results are irrelevant
- Solution: open in chrome-devtools → wait for render → `take_snapshot` to capture real DOM
- Typical SPA sites: MOOC platforms, React/Vue/Angular admin panels, most `app.` subdomains

### Emergency Fallback → Built-in WebSearch / WebFetch
- Only use when all other tools are unavailable
- Never as first choice

## Decision Flow

```
User query
  ├── "How do I use X / what's the API / how to configure" → context7
  ├── "Search X" (Chinese)  → web-search + Baidu
  ├── "Search X" (English)  → tavily
  ├── "Fetch this page"     → check if SPA first
  │   ├── Not SPA → tavily_extract (international) / web-search fetchWebContent (domestic)
  │   └── SPA    → chrome-devtools browser rendering
  ├── "Research X"          → tavily_research
  └── All above failed      → built-in WebSearch
```

## Important Notes

- Always explicitly specify `engines` when calling web-search; never rely on the default (Bing only) unless the user wants English results
- context7: max 3 calls per question — use sparingly
- tavily: rate limit of 20 requests/min — don't spam
- Built-in WebSearch is bad at Chinese — never use it for Chinese content
- SPA sites: don't waste time trying fetch/tavily_extract — go straight to the browser
