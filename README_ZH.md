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
- [调用规则](#调用规则)
- [工具详解](#各工具详解)
- [安装指南](#安装指南)
- [文件说明](#文件说明)
- [许可证](#许可证)

## 为什么需要？

搜索不是一个工具能覆盖的：中文内容、英文研究、库文档、网页抓取各有更合适的服务。缺少统一规则时，常见问题是选错工具、重复抓取浪费额度、失败后不知道按什么顺序降级。

本项目提供一套**调用层策略 + 安装脚本**：

- `search.md`：只保留路由信息——场景、触发信号、优先级（内容类型 > 语言）、降级顺序，减少歧义
- 安装脚本：一次装好四个 MCP（baidu-search、bright-data、context7、tavily）
- 可选兜底：ccproxy 命令级代理（仅在下载遇网络问题时使用），以及 ego-browser / chrome-devtools 的浏览器兜底说明

## 工具清单

| 工具 | 类型 | 链接 | 简介 |
|------|------|------|------|
| **baidu-search** | MCP 服务 | [百度AI搜索](https://cloud.baidu.com/doc/AppBuilder/s/zm8pn5cju) | 百度AI搜索，中文质量最好 |
| **bright-data** | MCP 服务 | [brightdata.com](https://brightdata.com/) | 专业网页抓取，支持JS渲染 |
| **tavily** | MCP 服务 | [tavily.com](https://www.tavily.com/) | AI 搜索引擎，服务端抓取 + 自动整理结果 |
| **context7** | MCP 服务 | [GitHub: upstash/context7](https://github.com/upstash/context7) | 主流库技术文档精准查询，返回代码示例 |

> **说明**：baidu-search 和 bright-data 组合使用，作为中文搜索完整方案。
>
> **说明**：ccproxy 为可选兜底工具（位于 `ccproxy/`）；导入脚本会在四个 MCP 之后询问是否安装到 `~/.claude/skills/ccproxy`，并可两级询问修改代理端口。ego-lite（提供 ego-browser skill）和 chrome-devtools-mcp 不在脚本范围内，需自行安装，见下文《其他工具（自行安装）》。

## 策略总览

```
用户提问
  ├── "xxx 怎么用 / API 是什么" → context7
  ├── "搜一下 xxx"（中文）      → baidu-search + bright-data
  ├── "Search xxx"（英文）      → tavily
  ├── "抓取这个网页"            → bright-data（国内站）/ tavily_extract（国外站）
  ├── "研究 xxx"               → tavily_research
  ├── 下载遇网络问题            → 先替代通道，仍不可用才用 ccproxy（兜底）
  └── 以上都挂了                → 内置 WebSearch → 浏览器兜底（ego-browser / chrome-devtools）
```

## 调用规则

- 中文搜索走 baidu-search + bright-data；英文搜索走 tavily；技术文档优先 context7
- 内容类型优先于语言：中文技术文档仍走 context7
- 报错排错：问 API 用法走 context7；找现成解决方案按语言走搜索
- 多意图请求拆分，搜索、抓取、下载分步路由
- tavily 与内置 WebSearch 不用于中文内容
- context7 未收录的小众库才退化到搜索引擎
- 摘要够用不抓全文；抓全文只取前 1–3 条
- 同一工具失败最多重试一次，随后降级
- MCP 搜索不走代理；代理只用于下载兜底
- ccproxy 端口默认 Clash Verge 7897 / FlClash 7890，可用 `/ccproxy port` 两级询问修改（保存在 `~/.claude/ccproxy.json`）

## 各工具详解

### 1. 中文搜索 → baidu-search + bright-data

- baidu-search：百度AI搜索，中文质量最好，返回摘要+URL
- bright-data：专业网页抓取，支持JS渲染，返回完整内容
- 工作流程：baidu-search 搜索找URL → bright-data 抓取完整内容

### 2. 英文搜索 → tavily

- 服务端抓取，国内环境反而更省心
- AI 自动整理结果，省去筛选成本
- `tavily_research` 深度研究 / `tavily_crawl` 批量抓取 / `tavily_map` 站点地图

### 3. 技术文档 → context7

- React / Next.js / Tailwind / Prisma 等主流库优先
- 比搜索引擎精准，返回官方文档片段 + 代码示例
- 支持版本指定；小众库退化到搜索引擎

### 4. 兜底 → 内置 WebSearch / WebFetch → 浏览器

- 仅在以上工具全部不可用时使用
- 下载/克隆/安装遇网络问题：先官方替代通道/国内加速，排除非网络错误后仍不可用才用 ccproxy 兜底
- 登录墙 / 反爬导致抓取失败时：ego-browser 负责操作，chrome-devtools 负责诊断

## 安装指南

### 前置要求

- [Claude Code](https://claude.ai/code) 已安装
- [Node.js](https://nodejs.org/) 18+

### 快速导入（推荐）

#### Windows

双击 `import.bat`，或终端执行：

```powershell
.\import.ps1
```

#### Linux / macOS

```bash
chmod +x ./import.sh && ./import.sh
```

脚本会依次安装四个 MCP（bright-data 使用官方 Remote MCP，无需本地安装；context7 使用 `ctx7 setup` 一键安装），然后询问是否安装可选的 ccproxy 兜底 skill（可选修改代理端口）。最后通过 `verify-mcp.mjs` 对每个已安装的 MCP 执行一次真实工具调用验证（会消耗少量查询额度）。

### 手动安装

```bash
# baidu-search（SSE 连接，无需额外依赖）
claude mcp add --scope user --transport sse baidu-search "http://appbuilder.baidu.com/v2/ai_search/mcp/sse?api_key=Bearer+YOUR_API_KEY"

# bright-data（官方 Remote MCP；API Key 获取：https://brightdata.com/cp/setting/users）
claude mcp add --scope user --transport http bright-data "https://mcp.brightdata.com/mcp?token=YOUR_TOKEN"

# tavily（需 API Key：https://tavily.com 注册）
claude mcp add --scope user --transport http tavily "https://mcp.tavily.com/mcp/?tavilyApiKey=YOUR_KEY"

# context7（一键安装：浏览器 OAuth 登录，自动写入 MCP 配置、规则与 skill）
npx -y ctx7 setup --mcp --claude --yes
```

部署策略文件（英文版用 `search_en.md`）：

```bash
# 复制策略到 strategies 目录
mkdir -p ~/.claude/strategies
cp search.md ~/.claude/strategies/search.md

# 添加引用到 CLAUDE.md
echo "@~/.claude/strategies/search.md" >> ~/.claude/CLAUDE.md
```

### 其他工具（自行安装）

以下工具不由导入脚本安装，按需选择：

#### ego-lite（浏览器兜底，复用登录态）

- 项目：[citrolabs/ego-lite](https://github.com/citrolabs/ego-lite)（MIT）
- 用途：登录墙 / 反爬场景下由 agent 操作真实浏览器；agent 在独立 Space 中运行，不抢占你的标签页；复用本机 Chrome 登录态
- 平台：macOS（Apple Silicon / Intel）、Windows x64；Linux 在路线图中
- 安装（二选一）：
  - 下载安装包：https://lite.ego.app
  - 只装 skill，首次浏览器任务时再引导安装应用：
    ```bash
    npx skills add citrolabs/ego-lite
    ```
- 首次启动可选择迁移 Chrome 数据（登录态、Cookie、扩展、书签）
- 使用：在 agent 中执行 `/ego-browser <任务描述>`

#### chrome-devtools-mcp（浏览器诊断 / 自动化）

- 项目：[ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)（Apache-2.0）
- 用途：页面性能追踪、网络 / 控制台诊断、浏览器自动化，本地驱动 Chrome
- 前置：Node.js LTS（`^20.19.0 || ^22.12.0 || >=23`）、Chrome 稳定版
- 安装：
  ```bash
  claude mcp add --scope user chrome-devtools -- npx -y chrome-devtools-mcp@latest
  ```
- Claude Code 也可通过插件安装：
  ```
  /plugin marketplace add ChromeDevTools/chrome-devtools-mcp
  /plugin install chrome-devtools-mcp@chrome-devtools-plugins
  ```
- 隐私：默认上报使用统计，如需关闭，在启动参数加 `--no-usage-statistics`（或设置 `CHROME_DEVTOOLS_MCP_NO_USAGE_STATISTICS=1`）

### 验证

```bash
claude mcp list      # 连接状态
node verify-mcp.mjs  # 真实工具调用验证（仅四个搜索 MCP）
```

## 适配其他 AI 工具

本策略适用于任何支持 MCP 的 AI 编程工具：[Cursor](https://cursor.sh/) · [Windsurf](https://codeium.com/windsurf) · [Cline](https://github.com/cline/cline) · [Continue](https://continue.dev/)

## 文件说明

- `search.md` — 调用层（中文）：工具路由 + 决策流 + 调用规则；完整说明见本 README
- `search_en.md` — 调用层（English）
- `import.bat` / `import.ps1` / `import.sh` — 导入脚本（仅安装四个 MCP）
- `verify-mcp.mjs` — 真实可用性验证脚本（MCP 握手 + 实际工具调用）
- `ccproxy/` — 命令级代理 skill（可选兜底，不由导入脚本安装）

## 许可证

[MIT](LICENSE)
