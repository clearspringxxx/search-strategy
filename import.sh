#!/bin/bash
# 联网搜索 MCP 策略 - Linux/Mac 导入脚本
# 安装 MCP 服务器 + 将策略复制到 ~/.claude/strategies/，通过 @ 引用加载

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
STRATEGIES_DIR="$CLAUDE_DIR/strategies"

echo "联网搜索 MCP 策略 - 导入"
echo "================================"
echo ""

# 检查依赖
echo "检查前置依赖..."

if ! command -v node &>/dev/null; then
    echo "错误: 未安装 Node.js，请先安装: https://nodejs.org/"
    exit 1
fi
NODE_MAJOR=$(node -p "process.versions.node.split('.')[0]")
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "错误: Node.js 版本过低（当前 $(node -v)，需要 18+）: https://nodejs.org/"
    exit 1
fi
echo "Node.js $(node -v)"

if ! command -v claude &>/dev/null; then
    echo "错误: 未安装 Claude Code，请先安装"
    exit 1
fi
echo "Claude Code $(claude --version 2>/dev/null || echo 'unknown')"

echo ""

# 收集 API Keys
echo "百度AI搜索用于中文搜索，需要 API Key"
echo "注册地址: https://console.bce.baidu.com/ai-search/qianfan/ais/console/apiKey"
echo ""
read -rp "请输入百度AI搜索 API Key (直接回车跳过): " BAIDU_KEY

echo ""
echo "Bright Data 用于网页抓取，需要 API Token"
echo "API Key 获取: https://brightdata.com/cp/setting/users"
echo "（未注册请先到 https://brightdata.com 注册）"
echo ""
read -rp "请输入 Bright Data API Token (直接回车跳过): " BRIGHTDATA_KEY

echo ""
echo "Tavily 用于英文搜索，需要 API Key"
echo "注册地址: https://tavily.com"
echo ""
read -rp "请输入 Tavily API Key (直接回车跳过): " TAVILY_KEY

echo ""
echo "开始安装 MCP 服务器..."
echo ""

is_yes() {
    case "$1" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

install_mcp() {
    local name="$1"
    local display="$2"
    local transport="$3"
    local url="$4"

    if claude mcp list 2>/dev/null | grep -q "^${name}:"; then
        echo "  [$name] 已安装，跳过（若连接异常：claude mcp remove $name 后重跑本脚本）"
        return
    fi

    echo "  [$name] 安装 $display ..."
    if claude mcp add --scope user --transport "$transport" "$name" "$url" 2>/dev/null; then
        echo "  [$name] 安装成功"
    else
        echo "  [$name] 安装失败"
    fi
}

# baidu-search（SSE连接）
if [ -n "$BAIDU_KEY" ]; then
    BAIDU_URL="http://appbuilder.baidu.com/v2/ai_search/mcp/sse?api_key=Bearer+$BAIDU_KEY"
    install_mcp "baidu-search" "百度AI搜索" sse "$BAIDU_URL"
else
    echo "  [baidu-search] 跳过 (未提供 API Key)"
fi

# bright-data（官方推荐的 Remote MCP，无需本地安装）
if [ -n "$BRIGHTDATA_KEY" ]; then
    BRIGHTDATA_URL="https://mcp.brightdata.com/mcp?token=$BRIGHTDATA_KEY"
    install_mcp "bright-data" "网页抓取（Remote MCP）" http "$BRIGHTDATA_URL"
else
    echo "  [bright-data] 跳过 (未提供 API Token)"
fi

# context7（一键安装：ctx7 setup 走 OAuth，自动写入 MCP 配置、规则与 skill）
if claude mcp list 2>/dev/null | grep -q "^context7:"; then
    echo "  [context7] 已安装，跳过（若需重装：npx -y ctx7 remove 后重跑本脚本）"
elif npx -y ctx7 setup --mcp --claude --yes; then
    echo "  [context7] 安装成功"
else
    echo "  [context7] 安装失败，可稍后手动执行: npx -y ctx7 setup --mcp --claude"
fi

# tavily
if [ -n "$TAVILY_KEY" ]; then
    install_mcp "tavily" "AI 搜索引擎" http "https://mcp.tavily.com/mcp/?tavilyApiKey=$TAVILY_KEY"
else
    echo "  [tavily] 跳过 (未提供 API Key)"
fi

echo ""
echo "可选：安装 ccproxy skill（下载兜底，MCP 搜索不使用）"
read -rp "是否安装? (y/N, 默认 N): " INSTALL_CCPROXY

if is_yes "$INSTALL_CCPROXY"; then
    CCPROXY_SRC="$SCRIPT_DIR/ccproxy"
    CCPROXY_DST="$CLAUDE_DIR/skills/ccproxy"

    if [ ! -f "$CCPROXY_SRC/ccproxy.mjs" ]; then
        echo "  [ccproxy] 未找到 $CCPROXY_SRC，跳过安装"
    else
        mkdir -p "$CCPROXY_DST"
        cp "$CCPROXY_SRC/SKILL.md" "$CCPROXY_SRC/ccproxy.mjs" "$CCPROXY_SRC/package.json" "$CCPROXY_SRC/README.md" "$CCPROXY_DST/"
        echo "  [ccproxy] 已安装到: $CCPROXY_DST"

        CONFIG_JSON=$(node "$CCPROXY_DST/ccproxy.mjs" port --json 2>/dev/null || echo '{}')
        VERGE_PORT=$(printf '%s' "$CONFIG_JSON" | node -e 'const s=require("fs").readFileSync(0,"utf8")||"{}";let c={};try{c=JSON.parse(s)}catch{};process.stdout.write(String(c["Clash Verge"]??7897))' 2>/dev/null || echo "7897")
        FL_PORT=$(printf '%s' "$CONFIG_JSON" | node -e 'const s=require("fs").readFileSync(0,"utf8")||"{}";let c={};try{c=JSON.parse(s)}catch{};process.stdout.write(String(c["FlClash"]??7890))' 2>/dev/null || echo "7890")

        echo "  默认代理端口：Clash Verge 127.0.0.1:$VERGE_PORT，FlClash 127.0.0.1:$FL_PORT"
        read -rp "  是否修改代理端口? (y/N, 默认 N): " CHANGE_PORT

        if is_yes "$CHANGE_PORT"; then
            echo ""
            echo "  修改哪一个代理软件？"
            echo "    [1] Clash Verge（当前 $VERGE_PORT）"
            echo "    [2] FlClash（当前 $FL_PORT）"
            echo "    [3] 不修改，退出（保持默认）"
            read -rp "  请选择 (1/2/3, 默认 3): " PICK

            TARGET_NAME=""
            TARGET_PORT=""
            if [ "$PICK" = "1" ]; then TARGET_NAME="Clash Verge"; TARGET_PORT="$VERGE_PORT"
            elif [ "$PICK" = "2" ]; then TARGET_NAME="FlClash"; TARGET_PORT="$FL_PORT"
            fi

            if [ -n "$TARGET_NAME" ]; then
                echo ""
                echo "  输入 $TARGET_NAME 的新端口（1-65535）"
                echo "    [0] 不修改，退出（保持当前 $TARGET_PORT）"
                read -rp "  新端口: " PORT_INPUT

                if [ -n "$PORT_INPUT" ] && [ "$PORT_INPUT" != "0" ]; then
                    if [[ "$PORT_INPUT" =~ ^[0-9]+$ ]] && [ "$PORT_INPUT" -ge 1 ] && [ "$PORT_INPUT" -le 65535 ]; then
                        if node "$CCPROXY_DST/ccproxy.mjs" port --set "$TARGET_NAME=$PORT_INPUT" >/dev/null; then
                            echo "  [ccproxy] 端口已保存：$TARGET_NAME → 127.0.0.1:$PORT_INPUT"
                        else
                            echo "  [ccproxy] 端口保存失败"
                        fi
                    else
                        echo "  [ccproxy] 端口无效，保持原配置"
                    fi
                else
                    echo "  [ccproxy] 已退出，端口未修改"
                fi
            else
                echo "  [ccproxy] 已退出，端口未修改"
            fi
        else
            echo "  [ccproxy] 使用默认端口"
        fi
    fi
else
    echo "  [ccproxy] 跳过安装"
fi

echo ""
echo "导入策略文件..."
echo ""

# 选择语言版本
echo "选择策略语言版本:"
echo "  [1] 简体中文 (search.md)"
echo "  [2] English   (search_en.md)"
echo ""
read -rp "请选择 (1/2，默认 1): " LANG_CHOICE

if [ "$LANG_CHOICE" = "2" ]; then
    STRATEGY_NAME="search_en.md"
    LANG_LABEL="English"
else
    STRATEGY_NAME="search.md"
    LANG_LABEL="简体中文"
fi
echo "已选择: $LANG_LABEL"
echo ""

STRATEGY_SRC="$SCRIPT_DIR/$STRATEGY_NAME"
STRATEGY_DST="$STRATEGIES_DIR/search.md"

if [ ! -f "$STRATEGY_SRC" ]; then
    echo "错误: 未找到 $STRATEGY_NAME"
    exit 1
fi

# 确保目录存在
mkdir -p "$STRATEGIES_DIR"

# 复制策略文件
cp "$STRATEGY_SRC" "$STRATEGY_DST"
echo "策略文件已复制到: $STRATEGY_DST"

# 在 CLAUDE.md 中添加 @ 引用
CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
REF_LINE="@~/.claude/strategies/search.md"

if [ -f "$CLAUDE_MD" ]; then
    if ! grep -qF "$REF_LINE" "$CLAUDE_MD"; then
        echo "" >> "$CLAUDE_MD"
        echo "$REF_LINE" >> "$CLAUDE_MD"
        echo "已添加引用到: $CLAUDE_MD"
    else
        echo "引用已存在，无需重复添加。"
    fi
else
    echo "$REF_LINE" > "$CLAUDE_MD"
    echo "已创建并添加引用: $CLAUDE_MD"
fi

echo ""
echo "导入完成！新会话生效。"
echo ""

# 真实可用性验证：对每个 MCP 执行一次实际工具调用
echo "=================================================="
echo "  联网搜索 MCP 真实可用性验证"
echo "=================================================="

VERIFY_SCRIPT="$SCRIPT_DIR/verify-mcp.mjs"
if [ -f "$VERIFY_SCRIPT" ]; then
    node "$VERIFY_SCRIPT" || echo "验证未全部通过，请检查上方 [FAIL] 项"
else
    echo "未找到 verify-mcp.mjs，跳过真实验证"
fi
echo ""
