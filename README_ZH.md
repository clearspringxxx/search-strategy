<p align="center">
  <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License">
  <img src="https://img.shields.io/badge/platform-Claude%20Code-orange.svg" alt="Platform">
  <img src="https://img.shields.io/badge/MCP-4%20servers-brightgreen.svg" alt="MCP Servers">
</p>

# 🔍 联网搜索 MCP 策略

> 一套 Claude Code MCP 搜索工具组合策略——让 AI 在不同场景下自动选择最合适的搜索引擎。

[English](README.md) | 简体中文

## 目录

- [为什么需要](#为什么需要)
- [工具清单](#工具清单)
- [策略总览](#策略总览)
- [工具详解](#各工具详解)
- [对比一览](#工具对比)
- [安装指南](#安装指南)
- [使用建议](#使用建议)
- [适配其他工具](#适配其他-ai-工具)
- [许可证](#许可证)

## 为什么需要？

Claude Code 内置的 `WebSearch` / `WebFetch` 中文差、SPA 站抓不到。社区有多个优秀 MCP 搜索工具各有所长，本策略帮你**组合使用**，覆盖中英文搜索、技术文档、SPA 网站等全部场景。

## 工具清单

| 工具 | 类型 | 链接 | 简介 |
|------|------|------|------|
| **tavily** | MCP 服务 | [tavily.com](https://www.tavily.com/) | AI 搜索引擎，服务端抓取 + 自动整理结果 |
| **web-search** | MCP 服务 | [npm: open-websearch](https://www.npmjs.com/package/open-websearch) | 多引擎聚合（百度 / Bing / Google / DuckDuckGo / CSDN / 掘金） |
| **context7** | MCP 服务 | [GitHub: upstash/context7](https://github.com/upstash/context7) | 主流库技术文档精准查询，返回代码示例 |
| **chrome-devtools** | MCP 服务 | [npm: chrome-devtools-mcp](https://www.npmjs.com/package/chrome-devtools-mcp) | 浏览器自动化，SPA 网站终极方案 |

## 策略总览

```
用户提问
  ├── "xxx 怎么用 / API 是什么" → context7
  ├── "搜一下 xxx"（中文）      → web-search + 百度
  ├── "Search xxx"（英文）      → tavily
  ├── "抓取这个网页"            → 判断是否 SPA
  │   ├── 非 SPA → tavily_extract / web-search fetchWebContent
  │   └── SPA    → chrome-devtools 浏览器渲染
  ├── "研究 xxx"               → tavily_research
  └── 以上都挂了                → 内置 WebSearch（兜底）
```

## 各工具详解

### 1. 中文搜索 → web-search + 百度

- 百度最稳，国内直连无障碍
- 技术文章可指定 `engines: ["csdn"]` 或 `engines: ["juejin"]`
- 多源覆盖用 `engines: ["baidu", "bing"]`
- ⚠️ 必须显式指定 `engines`，默认只有 Bing

### 2. 英文搜索 → tavily

- 服务端抓取，国内环境反而更省心
- AI 自动整理结果，省去筛选成本
- `tavily_research` 深度研究 / `tavily_crawl` 批量抓取 / `tavily_map` 站点地图

### 3. 技术文档 → context7

- React / Next.js / Tailwind / Prisma 等主流库优先
- 比搜索引擎精准，返回官方文档 + 代码示例
- 支持版本指定；小众库退化到搜索引擎

### 4. SPA 网站 → chrome-devtools

- 纯 JS 渲染的 SPA（icourse163、现代前端站），搜索引擎只能拿到空壳
- 用浏览器渲染获取真实 DOM：`take_snapshot` → 直接拿到页面内容
- 特征：fetch 返回空 JSON 或极少内容

### 5. 兜底 → 内置 WebSearch / WebFetch

- 仅在以上工具全部不可用时使用
- 不要作为首选

## 工具对比

| 能力 | 内置搜索 | tavily | web-search | context7 |
|------|:-------:|:------:|:----------:|:--------:|
| 中文搜索 | ❌ | ⚠️ | ✅ | ❌ |
| 英文搜索 | ⚠️ | ✅ | ✅ | ❌ |
| 技术文档 | ❌ | ⚠️ | ⚠️ | ✅ |
| AI 整理 | ❌ | ✅ | ❌ | ❌ |
| SPA 抓取 | ❌ | ❌ | ❌ | ❌ |
| 需要 Key | ❌ | ✅ | ❌ | ❌ |

## 安装指南

### 前置要求

- [Claude Code](https://claude.ai/code) 已安装
- [Node.js](https://nodejs.org/) 18+
- [Chrome](https://www.google.com/chrome/)（chrome-devtools 需要）

### 一键安装（推荐）

```powershell
# 双击 setup.bat，或在 PowerShell 中：
powershell -ExecutionPolicy Bypass -File setup.ps1
```

脚本功能：交互输入 Tavily Key → 检测依赖 → 安装 MCP → 选择策略语言（中文/English） → 部署策略 → 展示状态总览。

### 手动安装

```bash
# tavily（需 API Key：https://tavily.com 注册）
claude mcp add --scope user tavily --transport http "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_KEY"

# web-search（免费）
claude mcp add --scope user web-search -- cmd /c npx -y open-websearch@latest

# context7（免费）
claude mcp add --scope user context7 --transport http "https://mcp.context7.com/mcp"

# chrome-devtools（需 Chrome）
claude mcp add --scope user chrome-devtools -- cmd /c npx chrome-devtools-mcp@latest
```

### 验证

```bash
claude mcp list
```

### 部署策略文件

将策略文件复制到 Claude Code 配置目录（英文版用 `strategy_en.md`）：

```bash
# Windows
copy strategy.md %USERPROFILE%\.claude\CLAUDE.md

# Mac / Linux
cp strategy.md ~/.claude/CLAUDE.md
```

## 使用建议

1. **日常搜索**：中文 → web-search + 百度，英文 → tavily
2. **技术文档**：context7 优先，比搜索引擎快且准
3. **SPA 网站**：直接 chrome-devtools，别浪费时间试其他工具
4. **深度研究**：tavily_research，自动多源综合

## 适配其他 AI 工具

本策略适用于任何支持 MCP 的 AI 编程工具：[Cursor](https://cursor.sh/) · [Windsurf](https://codeium.com/windsurf) · [Cline](https://github.com/cline/cline) · [Continue](https://continue.dev/)

## 许可证

[MIT](LICENSE)
