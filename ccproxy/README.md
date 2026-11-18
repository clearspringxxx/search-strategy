# ccproxy

命令级代理工具，**最后兜底方案**，以 Claude Code Skill 形式封装：只在确认是网络层问题、且官方替代通道/国内加速都不可用时，把**单条命令**通过本地代理执行。

**默认行为（不用代理）：**

1. 原样直连执行
2. 网络问题先走官方替代通道或国内加速（GitHub → codeload tarball/API，npm → npmmirror，pip → 清华镜像）
3. 排除非网络错误（404 / 401 / 权限 / 磁盘）
4. 以上都不可用，才用本工具兜底

**它不是：**

- 不是全局代理配置工具——不写任何配置文件，没有 init / change / reset / 全局模式
- 不代理 MCP 搜索调用（baidu-search / tavily / context7 直达）
- 不是遇到网络问题就用的第一选择

## 安装（可选）

search-strategy 的导入脚本会询问是否安装（同意后复制到 `~/.claude/skills/ccproxy`），并可按两级流程修改端口。也可手动复制：

```bash
# 在项目根目录执行
cp -r ./ccproxy ~/.claude/skills/ccproxy
```

不安装也可以直接运行 `ccproxy/ccproxy.mjs`。

## 代理检测

按顺序 TCP 探测，先到先用：

| 优先级 | 软件 | 地址 |
|--------|------|------|
| 1 | Clash Verge | `127.0.0.1:7897` |
| 2 | FlClash | `127.0.0.1:7890` |

两个都没启动时，命令不会执行，提示启动代理软件后返回退出码 `2`。

## 修改代理端口

默认 Clash Verge `7897`、FlClash `7890`。用户可自行修改，修改保存在 `~/.claude/ccproxy.json`（仅在修改时创建）：

```bash
# 查看当前配置；在真实终端中运行时会进入两级修改流程
node ccproxy.mjs port

# 非交互保存（skill / 脚本使用）
node ccproxy.mjs port --set "Clash Verge=7898"
node ccproxy.mjs port --set "FlClash=7891"
```

两级流程：第一级选修改哪个代理软件，第二级输入新端口；**每一级的最后一项都是“不修改，直接退出并保持默认”**。作为 skill 使用时，`/ccproxy port` 走同样的两级询问。配置文件不存在或无效时，一律使用默认值。

## 用法

```bash
# 兜底：通过代理执行单条命令（-- 之后的全部参数原样传给命令）
node ccproxy.mjs run -- git clone https://github.com/owner/repo
node ccproxy.mjs run -- npm install
node ccproxy.mjs run -- pip install -r requirements.txt

# 只检测当前代理，不执行命令
node ccproxy.mjs detect
```

可选：`npm link` 之后可以直接用 `ccproxy run -- ...`。

## 注入的环境变量

| 变量 | 用途 |
|------|------|
| `HTTP_PROXY` / `HTTPS_PROXY` | curl / git / pip / python 等通用代理 |
| `ALL_PROXY` | 兼容只读 ALL_PROXY 的工具 |
| `npm_config_proxy` / `npm_config_https_proxy` | npm 自己的配置体系 |
| `NO_PROXY=localhost,127.0.0.1,::1` | 本地回环永远直连 |

POSIX 平台会额外注入小写变体（`http_proxy` 等）。命令的退出码原样透传。

## 触发条件（以下全部满足才用）

- 确认是网络层问题（超时 / ECONNRESET / TLS 错误 / `npm ERR! network`）
- 官方替代通道和国内加速都不可用
- 命令确实需要访问国外资源

**不满足触发条件时：**

- 首次网络错误 → 先换官方替代通道
- 404 / 401 / 权限 / 磁盘问题 → 非网络问题，不用代理
- MCP 搜索 → 不经过本工具
- 国内站点 → 直连

## 工作流程

搜索（MCP，不走代理）→ 找到资源 → 直连 / 替代通道 → 仍失败 → ccproxy 包一层（兜底）→ 仍失败 → 报告并询问，不无限重试。
