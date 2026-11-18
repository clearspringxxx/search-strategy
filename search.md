## 联网搜索调用策略

### 工具路由

| 场景 | 触发信号 | 调用 |
|------|---------|------|
| 技术文档 | "怎么用 / API / 配置 / 参数 / 版本"、库名 + 用法/示例 | `context7`：`resolve-library-id` → `query-docs` |
| 中文搜索 | 中文新闻 / 社区 / 政策 / 时效 / 人物，无明确库文档意图 | `baidu-search`；需要全文时 `bright-data` |
| 英文搜索 | 英文关键词；"研究一下 / 对比 / 方案" | `tavily_search`；`tavily_research` / `tavily_crawl` / `tavily_map` |
| 抓取网页 | "抓取这个网页" / 给定 URL | 国内站 `bright-data`；国外站 `tavily_extract` |
| 下载兜底 | git / npm / pip / curl 网络层错误 | 官方替代通道/国内加速优先 → `node ~/.claude/skills/ccproxy/ccproxy.mjs run -- <命令>`（未安装 skill 时用仓库内 `ccproxy/ccproxy.mjs`） |
| 登录墙 / 反爬 | 抓取被拦截 / 需要登录 | `ego-browser`；诊断 `chrome-devtools` |
| 全部不可用 | 以上均失败 | 内置 `WebSearch` / `WebFetch` |

### 路由优先级

1. **内容类型 > 语言**：中文技术文档也走 `context7`
2. **报错排错**：查 API 用法 → `context7`；找现成解决方案 → 按语言走搜索
3. **多意图拆分**：搜索、抓取、下载分步路由，不合并到单一工具
4. 命中多条时，按决策流顺序执行

### 决策流

```
用户提问
  ├── 技术文档（含中文技术文档） → context7
  ├── 中文通用 → baidu-search（+ bright-data 抓全文）
  ├── 英文通用 → tavily
  ├── 抓网页 → bright-data（国内）/ tavily_extract（国外）
  ├── 下载遇网络错误 → 替代通道优先 → ccproxy 兜底（端口默认 7897/7890，可 /ccproxy port 修改）
  └── 全部不可用 → WebSearch/WebFetch → ego-browser（诊断用 chrome-devtools）
```

### 调用规则

- tavily 与内置 WebSearch 不用于中文内容
- 技术文档优先 context7，未收录再走搜索引擎
- MCP 搜索不走代理；ccproxy 仅用于下载兜底
- 同一工具失败最多重试一次，随后降级
- 摘要够用不抓全文；抓全文只取前 1–3 条
