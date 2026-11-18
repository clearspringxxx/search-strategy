## Web Search Invocation Strategy

### Tool Routing

| Scenario | Trigger signals | Invocation |
|----------|-----------------|-----------|
| Technical docs | "how to use / API / config / options / version", library + usage/example | `context7`: `resolve-library-id` → `query-docs` |
| Chinese search | Chinese news / community / policy / time-sensitive / people; no clear library-doc intent | `baidu-search`; `bright-data` for full text |
| English search | English keywords; "research / compare / options" | `tavily_search`; `tavily_research` / `tavily_crawl` / `tavily_map` |
| Fetch a page | "fetch this page" / given URL | `bright-data` (domestic) / `tavily_extract` (international) |
| Download fallback | git / npm / pip / curl network-layer errors | official alternatives/domestic mirrors first → `node ~/.claude/skills/ccproxy/ccproxy.mjs run -- <command>` (or repo `ccproxy/ccproxy.mjs` if skill not installed) |
| Login wall / anti-bot | crawl blocked / login required | `ego-browser`; diagnose with `chrome-devtools` |
| Nothing works | all above failed | Built-in `WebSearch` / `WebFetch` |

### Routing Priority

1. **Content type > language**: Chinese technical docs still go to `context7`
2. **Troubleshooting**: API usage → `context7`; ready-made solutions → language-based search
3. **Split multi-intent queries**: route search, fetch, and download separately
4. On multiple matches, follow the decision-flow order

### Decision Flow

```text
User query
  ├── Technical docs (including Chinese docs) → context7
  ├── Chinese general → baidu-search (+ bright-data for full text)
  ├── English general → tavily
  ├── Fetch page → bright-data (domestic) / tavily_extract (international)
  ├── Download network error → alternatives first → ccproxy last resort (default ports 7897/7890; /ccproxy port to change)
  └── All unavailable → WebSearch/WebFetch → ego-browser (chrome-devtools for diagnosis)
```

### Invocation Rules

- Never use tavily or built-in WebSearch for Chinese content
- context7 first for technical docs; fall back to search engines only for unlisted libraries
- MCP search never uses a proxy; ccproxy is for download fallback only
- Retry the same tool at most once, then fall back
- Snippets first; fetch full text only for the top 1-3 results
