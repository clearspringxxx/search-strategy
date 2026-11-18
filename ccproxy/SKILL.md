---
name: ccproxy
description: 命令级下载代理（最后兜底）。仅当 git clone / npm install / pip install / curl 等命令出现确认的网络层错误，且官方替代通道（codeload tarball、api.github.com）与国内加速（npmmirror、清华镜像）都不可用时，用它将单条命令通过本地代理执行。默认检测 Clash Verge 127.0.0.1:7897 或 FlClash 127.0.0.1:7890；用 `/ccproxy port` 可两级询问修改端口。不用于 MCP 搜索、非网络错误或国内站点。
argument-hint: "[port | run -- <命令> | detect]"
---

# ccproxy

命令级代理。只作用于**单条命令**，不做全局代理配置；仅在用户主动修改端口时写入 `~/.claude/ccproxy.json`。

## 触发前提（必须全部满足）

1. 命令报的是网络层错误：超时 / ECONNRESET / TLS 错误 / `npm ERR! network` / `curl 56`
2. 已尝试官方替代通道或国内加速且不可用：
   - GitHub → `codeload.github.com/<owner>/<repo>/tar.gz/refs/heads/main` 或 `api.github.com`
   - npm → `--registry=https://registry.npmmirror.com`
   - pip → `-i https://pypi.tuna.tsinghua.edu.cn/simple`
3. 已排除非网络错误（404 / 401 / 权限 / 磁盘）

## 用法

```bash
node ${CLAUDE_SKILL_DIR}/ccproxy.mjs run -- <命令>
node ${CLAUDE_SKILL_DIR}/ccproxy.mjs detect
```

- 自动检测：Clash Verge `127.0.0.1:7897` → FlClash `127.0.0.1:7890`（可修改）
- 都未启动：命令不执行，提示启动代理软件（退出码 2）
- 注入 `HTTP_PROXY` / `HTTPS_PROXY` / `ALL_PROXY` / `npm_config_proxy` / `npm_config_https_proxy` / `NO_PROXY`，命令退出码原样透传
- 兜底仍失败：报告并询问，不无限重试

## 修改端口（/ccproxy port）

默认端口：Clash Verge `7897`、FlClash `7890`。用户修改后保存在 `~/.claude/ccproxy.json`，`detect` / `run` 自动使用新端口。

当用户触发 `/ccproxy port` 时，**用 AskUserQuestion 分两级询问**（不要运行交互式 shell 命令，Bash 环境非 TTY）：

1. 先读取当前配置：

   ```bash
   node ${CLAUDE_SKILL_DIR}/ccproxy.mjs port
   ```

2. **第一级**：问“修改哪一个代理软件”，选项按此顺序：
   - Clash Verge（当前端口 xxxx）
   - FlClash（当前端口 xxxx）
   - **不修改，退出（保持默认）——放在最后一项**

3. 用户选择某个软件后，**第二级**：问“新的端口是多少”（1-65535），选项：
   - 该软件默认端口（Clash Verge=7897 / FlClash=7890）
   - **不修改，退出（保持当前）——放在最后一项**
   - 用户可通过“其他”输入任意端口

4. 两级都做出修改选择后保存：

   ```bash
   node ${CLAUDE_SKILL_DIR}/ccproxy.mjs port --set "<软件名>=<端口>"
   ```

5. 任意一级选择“不修改” → 不执行保存，直接结束并保持原配置。
