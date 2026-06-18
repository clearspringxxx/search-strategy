# 🔍 联网搜索 MCP 策略

> 一套经过实战验证的 Claude Code 联网搜索工具组合策略，让 AI 在不同场景下选择最合适的搜索工具。

## 为什么需要这个？

Claude Code 内置的 WebSearch 和 WebFetch 能力有限（中文差、SPA 站抓不到），而社区有多个优秀的 MCP 搜索工具各有所长。本策略帮你**组合使用**这些工具，覆盖中英文搜索、技术文档、SPA 网站等各种场景。

## 工具清单

| 工具 | 类型 | 项目地址 | 一句话介绍 |
|------|------|----------|-----------|
| **tavily** | MCP 服务 | [tavily.com](https://www.tavily.com/) | AI 搜索引擎，服务端抓取，自动整理结果 |
| **web-search** | MCP 服务 | [npm: open-websearch](https://www.npmjs.com/package/open-websearch) | 多引擎聚合（百度/Bing/Google/DuckDuckGo/CSDN/掘金等） |
| **context7** | MCP 服务 | [GitHub: upstash/context7](https://github.com/upstash/context7) | 主流库技术文档精准查询 |
| **chrome-devtools** | MCP 服务 | [npm: chrome-devtools-mcp](https://www.npmjs.com/package/chrome-devtools-mcp) | 浏览器自动化，SPA 网站终极方案 |

## 策略总览

```
用户提问
  ├── "xxx 怎么用 / API 是什么 / 配置怎么写" → context7
  ├── "搜一下 xxx"（中文）→ web-search + 百度
  ├── "搜索 xxx"（英文）→ tavily
  ├── "抓取这个网页" → 先判断是否 SPA
  │     ├── 非 SPA → tavily_extract（国外站）/ web-search fetchWebContent（国内站）
  │     └── SPA → chrome-devtools 浏览器渲染
  ├── "研究一下 xxx 话题" → tavily_research
  └── 以上都挂了 → 内置 WebSearch（兜底）
```

## 各工具详解

### 1. 中文搜索 → web-search + 百度

**最佳场景**：中文通用搜索、国内技术文章

- 百度最稳，国内直连无障碍
- 搜技术文章可指定 `engines: ["csdn"]` 或 `engines: ["juejin"]`
- 需要多源覆盖时 `engines: ["baidu", "bing"]`

**注意**：必须显式指定 `engines`，默认只用 Bing。

### 2. 英文搜索 → tavily

**最佳场景**：英文搜索、需要 AI 整理结果、批量抓取

- 服务端抓取，不需要直连国外站，国内环境反而更省心
- AI 自动整理结果，省去筛选成本
- 需要深度研究用 `tavily_research`
- 需要批量抓取/站点地图用 `tavily_crawl` / `tavily_map`

### 3. 查技术文档 → context7

**最佳场景**：查 React / Next.js / Tailwind / Prisma 等主流库的用法

- 比搜索引擎精准，返回官方文档 + 代码示例
- 支持版本指定（如 Next.js v14 vs v15）
- 小众库或未收录的库才退化到搜索引擎

### 4. SPA 网站 → chrome-devtools 浏览器

**最佳场景**：纯 JS 渲染的 SPA 网站（icourse163、大部分现代前端站）

- SPA 网站搜索引擎和抓取工具只能拿到空壳
- 用浏览器渲染获取真实 DOM 内容
- 特征：fetch 返回空 JSON 或极少内容

### 5. 应急兜底 → 内置 WebSearch / WebFetch

- 仅在以上工具都不可用时使用
- 不要作为首选

## 工具对比

| 能力 | 内置搜索 | tavily | web-search | context7 |
|------|---------|--------|------------|----------|
| 中文搜索 | ❌ 差 | ⚠️ 一般 | ✅ 支持百度 | ❌ |
| 英文搜索 | ⚠️ 一般 | ✅ 好 | ✅ 多引擎 | ❌ |
| 技术文档 | ❌ | ⚠️ | ⚠️ | ✅ 精准 |
| AI 整理 | ❌ | ✅ | ❌ | ❌ |
| SPA 抓取 | ❌ | ❌ | ❌ | ❌ |
| 需要 API Key | ❌ | ✅ | ❌ | ❌ |

## 安装指南

### 前置要求

- [Claude Code](https://claude.ai/code) 已安装
- [Node.js](https://nodejs.org/) 18+
- [Chrome 浏览器](https://www.google.com/chrome/)（chrome-devtools 需要）

### 快速安装脚本（Windows）

提供了一键安装脚本，交互式引导完成所有 MCP 服务的安装：

```powershell
# 双击运行（推荐）
setup.bat

# 或在 PowerShell 中执行
powershell -ExecutionPolicy Bypass -File setup.ps1
```

脚本功能：
- 交互式输入 Tavily API Key（可跳过）
- 自动检测 Node.js 和 Claude Code 是否已安装
- 自动跳过已安装的 MCP 服务，支持重复运行
- 自动安装策略文件到 `~/.claude/CLAUDE.md`，已有文件时支持跳过/追加/覆盖
- 所有命令后台静默执行，无额外弹窗

### 手动安装

```bash
# tavily（需要 API Key，去 https://tavily.com 注册获取）
claude mcp add --scope user tavily --transport http "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_API_KEY"

# web-search（免费，无需 API Key）
claude mcp add --scope user web-search -- cmd /c npx -y open-websearch@latest

# context7（免费，无需 API Key）
claude mcp add --scope user context7 --transport http "https://mcp.context7.com/mcp"

# chrome-devtools（需要 Chrome 浏览器）
claude mcp add --scope user chrome-devtools -- cmd /c npx chrome-devtools-mcp@latest
```

> 将 `YOUR_API_KEY` 替换为你的 Tavily API Key。其他工具免费无需注册。

### 验证安装

```bash
claude mcp list
```

所有工具应该显示 `✔ Connected`。

## 使用建议

1. **日常搜索**：中文用 web-search + 百度，英文用 tavily
2. **查技术文档**：优先 context7，比搜索引擎快且准
3. **SPA 网站**：直接用 chrome-devtools，不要浪费时间尝试其他工具
4. **深度研究**：用 tavily_research，它会自动从多个来源综合信息

## 策略文件

[strategy.md](strategy.md) 是 Claude Code 的策略配置文件，包含完整的搜索工具选择规则。将其复制到 `~/.claude/` 目录下并重命名为 `CLAUDE.md`，即可全局生效：

```bash
# Windows
copy strategy.md %USERPROFILE%\.claude\CLAUDE.md

# Mac/Linux
cp strategy.md ~/.claude/CLAUDE.md
```

## 适配其他 AI 工具

本策略不仅适用于 Claude Code，也适用于任何支持 MCP 的 AI 编程工具：

- [Cursor](https://cursor.sh/)
- [Windsurf](https://codeium.com/windsurf)
- [Cline](https://github.com/cline/cline)
- [Continue](https://continue.dev/)

## 许可证

MIT
