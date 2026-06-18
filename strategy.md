# 联网搜索 MCP 使用策略

## 工具优先级

根据场景选择工具，不要无脑用默认的：

### 中文搜索 → web-search (engines: ["baidu"])
- 百度最稳，国内直连无障碍
- 搜技术文章可指定 engines: ["csdn"] 或 engines: ["juejin"]
- 需要多源覆盖时 engines: ["baidu", "bing"]

### 英文搜索 → tavily
- 服务端抓取，不需要直连国外站，国内环境反而更省心
- AI 自动整理结果，省去筛选成本
- 需要深度研究用 tavily_research
- 需要批量抓取/站点地图用 tavily_crawl / tavily_map

### 查技术文档 → context7
- React / Next.js / Tailwind / Prisma 等主流库优先用这个
- 比搜索引擎精准，返回官方文档 + 代码示例
- 小众库或未收录的库才退化到搜索引擎

### SPA / JS 渲染网站 → chrome-devtools 浏览器
- 纯 JS 渲染的 SPA 网站（如 icourse163、大部分现代前端站），搜索引擎和抓取工具全部只能拿到空壳
- 特征：fetchWebContent 返回空 JSON 或极少内容，搜索结果不相关
- 解决：用 chrome-devtools 打开浏览器 → 等待加载 → take_snapshot 获取真实 DOM
- 典型 SPA 站点：icourse163、各大学 MOOC 平台、React/Vue/Angular 构建的后台管理系统

### 应急兜底 → 内置 WebSearch / WebFetch
- 仅在以上工具都不可用时使用
- 不要作为首选

## 选择流程

```
用户提问
  ├── "xxx 怎么用 / API 是什么 / 配置怎么写" → context7
  ├── "搜一下 xxx"（中文）→ web-search + 百度
  ├── "搜索 xxx"（英文）→ tavily
  ├── "抓取这个网页" → 先判断是否 SPA
  │     ├── 非 SPA → tavily_extract（国外站）/ web-search fetchWebContent（国内站）
  │     └── SPA → chrome-devtools 浏览器渲染
  ├── "研究一下 xxx 话题" → tavily_research
  └── 以上都挂了 → 内置 WebSearch
```

## 注意事项

- 调用 web-search 时必须显式指定 engines，不要用默认的 bing（除非用户要英文搜索）
- context7 每个问题最多调用 3 次，省着用
- tavily 有频率限制（20次/分钟），不要批量轰炸
- 内置 WebSearch 中文效果差，不要用来搜中文内容
- SPA 网站不要浪费时间尝试 fetch/tavily_extract，直接用浏览器
