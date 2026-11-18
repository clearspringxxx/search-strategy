# 联网搜索 MCP 策略 - Windows 导入脚本
# 安装 MCP 服务器 + 将策略复制到 ~/.claude/strategies/，通过 @ 引用加载

$ErrorActionPreference = "Continue"

Write-Host "联网搜索 MCP 策略 - 导入" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "百度AI搜索用于中文搜索，需要 API Key" -ForegroundColor Yellow
Write-Host "注册地址: https://console.bce.baidu.com/ai-search/qianfan/ais/console/apiKey" -ForegroundColor DarkCyan
Write-Host ""
$BaiduKey = Read-Host "请输入百度AI搜索 API Key (直接回车跳过)"

Write-Host ""
Write-Host "Bright Data 用于网页抓取，需要 API Token" -ForegroundColor Yellow
Write-Host "API Key 获取: https://brightdata.com/cp/setting/users" -ForegroundColor DarkCyan
Write-Host "（未注册请先到 https://brightdata.com 注册）" -ForegroundColor DarkCyan
Write-Host ""
$BrightDataKey = Read-Host "请输入 Bright Data API Token (直接回车跳过)"

Write-Host ""
Write-Host "Tavily 用于英文搜索，需要 API Key" -ForegroundColor Yellow
Write-Host "注册地址: https://tavily.com" -ForegroundColor DarkCyan
Write-Host ""
$TavilyKey = Read-Host "请输入 Tavily API Key (直接回车跳过)"

Write-Host ""
Write-Host "检查前置依赖..." -ForegroundColor Cyan

$nodeVer = & node -v 2>&1 | Out-String
if ($nodeVer -match "v(\d+)") {
    $nodeMajor = [int]$Matches[1]
    if ($nodeMajor -lt 18) {
        Write-Host "Node.js 版本过低（当前 $($nodeVer.Trim())，需要 18+）: https://nodejs.org/" -ForegroundColor Red
        Read-Host "按 Enter 退出"
        exit 1
    }
    Write-Host "Node.js $($nodeVer.Trim())" -ForegroundColor Green
}
else {
    Write-Host "未安装 Node.js，请先安装: https://nodejs.org/" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

if (Get-Command claude -ErrorAction SilentlyContinue) {
    $claudeCheck = & claude --version 2>&1 | Out-String
    Write-Host "Claude Code $($claudeCheck.Trim())" -ForegroundColor Green
}
else {
    Write-Host "未安装 Claude Code，请先安装" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

Write-Host ""
Write-Host "检测已安装的 MCP 服务..." -ForegroundColor Cyan

$installedNames = @()
$listOutput = & claude mcp list 2>&1 | Out-String
if ($listOutput) {
    $lines = $listOutput -split "`n"
    foreach ($line in $lines) {
        # 匹配 "name:" 格式，name可能包含连字符
        if ($line.Trim() -match '^([a-zA-Z0-9_-]+):') {
            $installedNames += $Matches[1]
        }
    }
}

function Test-Installed($name) {
    return $installedNames -contains $name
}

Write-Host ""
Write-Host "开始安装 MCP 服务器..." -ForegroundColor Cyan
Write-Host ""

function Install-Mcp($name, $displayName, $transport, $url) {
    if (Test-Installed $name) {
        Write-Host "  [$name] 已安装，跳过（若连接异常：claude mcp remove $name 后重跑本脚本）" -ForegroundColor DarkGray
        return
    }

    Write-Host "  [$name] 安装 $displayName ..." -ForegroundColor Yellow
    $output = & claude mcp add --scope user --transport $transport $name $url 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "  [$name] 安装成功" -ForegroundColor Green
    }
    else {
        Write-Host "  [$name] 安装失败 (exit code: $exitCode)" -ForegroundColor Red
        if ($output) {
            Write-Host "  [$name] 输出: $output" -ForegroundColor DarkGray
        }
    }
}

# baidu-search (SSE connection)
if ($BaiduKey) {
    $baiduUrl = "http://appbuilder.baidu.com/v2/ai_search/mcp/sse?api_key=Bearer+$BaiduKey"
    Install-Mcp "baidu-search" "百度AI搜索" "sse" $baiduUrl
}
else {
    Write-Host "  [baidu-search] 跳过 (未提供 API Key)" -ForegroundColor DarkGray
}

# bright-data（官方推荐的 Remote MCP，无需本地安装）
if ($BrightDataKey) {
    $brightDataUrl = "https://mcp.brightdata.com/mcp?token=$BrightDataKey"
    Install-Mcp "bright-data" "网页抓取（Remote MCP）" "http" $brightDataUrl
}
else {
    Write-Host "  [bright-data] 跳过 (未提供 API Token)" -ForegroundColor DarkGray
}

# context7（一键安装：ctx7 setup 走 OAuth，自动写入 MCP 配置、规则与 skill）
if (Test-Installed "context7") {
    Write-Host "  [context7] 已安装，跳过（若需重装：npx -y ctx7 remove 后重跑本脚本）" -ForegroundColor DarkGray
}
else {
    Write-Host "  [context7] 一键安装 技术文档查询（将打开浏览器 OAuth 登录）..." -ForegroundColor Yellow
    & npx -y ctx7 setup --mcp --claude --yes
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [context7] 安装成功" -ForegroundColor Green
    }
    else {
        Write-Host "  [context7] 安装失败 (exit code: $LASTEXITCODE)，可稍后手动执行: npx -y ctx7 setup --mcp --claude" -ForegroundColor Red
    }
}

# tavily
if ($TavilyKey) {
    $tavilyUrl = "https://mcp.tavily.com/mcp/?tavilyApiKey=$TavilyKey"
    Install-Mcp "tavily" "AI搜索引擎" "http" $tavilyUrl
}
else {
    Write-Host "  [tavily] 跳过 (未提供 API Key)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "可选：安装 ccproxy skill（下载兜底，MCP 搜索不使用）" -ForegroundColor Yellow
$installCcproxy = Read-Host "是否安装? (y/N, 默认 N)"
if ($installCcproxy -match '^(y|yes)$') {
    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    $ccproxySrc = Join-Path $PSScriptRoot "ccproxy"
    $ccproxyDst = Join-Path (Join-Path $claudeDir "skills") "ccproxy"

    if (-not (Test-Path (Join-Path $ccproxySrc "ccproxy.mjs"))) {
        Write-Host "  [ccproxy] 未找到 $ccproxySrc，跳过安装" -ForegroundColor Red
    }
    else {
        New-Item -ItemType Directory -Path $ccproxyDst -Force | Out-Null
        foreach ($f in @("SKILL.md", "ccproxy.mjs", "package.json", "README.md")) {
            $src = Join-Path $ccproxySrc $f
            if (Test-Path $src) { Copy-Item $src (Join-Path $ccproxyDst $f) -Force }
        }
        Write-Host "  [ccproxy] 已安装到: $ccproxyDst" -ForegroundColor Green

        $vergePort = 7897
        $flPort = 7890
        $json = & node (Join-Path $ccproxyDst "ccproxy.mjs") port --json 2>$null
        if ($LASTEXITCODE -eq 0 -and $json) {
            try {
                $cfg = $json | ConvertFrom-Json
                if ($cfg.PSObject.Properties.Name -contains "Clash Verge") { $vergePort = [int]$cfg.'Clash Verge' }
                if ($cfg.PSObject.Properties.Name -contains "FlClash") { $flPort = [int]$cfg.'FlClash' }
            }
            catch { }
        }

        Write-Host "  默认代理端口：Clash Verge 127.0.0.1:$vergePort，FlClash 127.0.0.1:$flPort" -ForegroundColor DarkGray
        $changePort = Read-Host "  是否修改代理端口? (y/N, 默认 N)"
        if ($changePort -match '^(y|yes)$') {
            Write-Host ""
            Write-Host "  修改哪一个代理软件？"
            Write-Host "    [1] Clash Verge（当前 $vergePort）" -ForegroundColor Cyan
            Write-Host "    [2] FlClash（当前 $flPort）" -ForegroundColor Cyan
            Write-Host "    [3] 不修改，退出（保持默认）" -ForegroundColor DarkGray
            $pick = Read-Host "  请选择 (1/2/3, 默认 3)"

            $targetName = $null
            $targetPort = 0
            if ($pick -eq "1") { $targetName = "Clash Verge"; $targetPort = $vergePort }
            elseif ($pick -eq "2") { $targetName = "FlClash"; $targetPort = $flPort }

            if ($targetName) {
                Write-Host ""
                Write-Host "  输入 $targetName 的新端口（1-65535）"
                Write-Host "    [0] 不修改，退出（保持当前 $targetPort）" -ForegroundColor DarkGray
                $portInput = Read-Host "  新端口"

                if ($portInput -and $portInput -ne "0") {
                    $newPort = 0
                    if ([int]::TryParse($portInput, [ref]$newPort) -and $newPort -ge 1 -and $newPort -le 65535) {
                        & node (Join-Path $ccproxyDst "ccproxy.mjs") port --set "$targetName=$newPort" | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "  [ccproxy] 端口已保存：$targetName → 127.0.0.1:$newPort" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  [ccproxy] 端口保存失败" -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "  [ccproxy] 端口无效，保持原配置" -ForegroundColor Red
                    }
                }
                else {
                    Write-Host "  [ccproxy] 已退出，端口未修改" -ForegroundColor DarkGray
                }
            }
            else {
                Write-Host "  [ccproxy] 已退出，端口未修改" -ForegroundColor DarkGray
            }
        }
        else {
            Write-Host "  [ccproxy] 使用默认端口" -ForegroundColor DarkGray
        }
    }
}
else {
    Write-Host "  [ccproxy] 跳过安装" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "导入策略文件..." -ForegroundColor Cyan
Write-Host ""

# 选择语言版本
Write-Host "选择策略语言版本:" -ForegroundColor Yellow
Write-Host "  [1] 简体中文 (search.md)" -ForegroundColor Cyan
Write-Host "  [2] English   (search_en.md)" -ForegroundColor DarkCyan
Write-Host ""
$langChoice = Read-Host "请选择 (1/2, 默认 1)"
if ($langChoice -eq "2") {
    $strategyName = "search_en.md"
    $langLabel = "English"
}
else {
    $strategyName = "search.md"
    $langLabel = "简体中文"
}
Write-Host "已选择: $langLabel" -ForegroundColor Green
Write-Host ""

$claudeDir = Join-Path $env:USERPROFILE ".claude"
$strategiesDir = Join-Path $claudeDir "strategies"
$strategySrc = Join-Path $PSScriptRoot $strategyName
$strategyDst = Join-Path $strategiesDir "search.md"

# 检查源文件
if (-not (Test-Path $strategySrc)) {
    Write-Host "未找到 $strategyName，跳过策略导入" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

# 确保 strategies 目录存在
if (-not (Test-Path $strategiesDir)) {
    New-Item -ItemType Directory -Path $strategiesDir -Force | Out-Null
    Write-Host "已创建目录: $strategiesDir" -ForegroundColor DarkGray
}

# 复制策略文件
Copy-Item $strategySrc $strategyDst -Force
Write-Host "策略文件已复制到: $strategyDst" -ForegroundColor Green

# 添加引用到 CLAUDE.md
$claudeMd = Join-Path $claudeDir "CLAUDE.md"
$refLine = "@~/.claude/strategies/search.md"

if (Test-Path $claudeMd) {
    $content = Get-Content $claudeMd -Raw -Encoding UTF8
    if ([string]::IsNullOrEmpty($content) -or $content -notmatch [regex]::Escape($refLine)) {
        Add-Content -Path $claudeMd -Value "`n$refLine" -Encoding UTF8
        Write-Host "已添加引用到: $claudeMd" -ForegroundColor Green
    }
    else {
        Write-Host "引用已存在，无需重复添加" -ForegroundColor Yellow
    }
}
else {
    Set-Content -Path $claudeMd -Value $refLine -Encoding UTF8
    Write-Host "已创建并添加引用: $claudeMd" -ForegroundColor Green
}

Write-Host ""
Write-Host "导入完成！重启 Claude Code 生效" -ForegroundColor Green
Write-Host ""

# 真实可用性验证：对每个 MCP 执行一次实际工具调用
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "  联网搜索 MCP 真实可用性验证" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

$verifyScript = Join-Path $PSScriptRoot "verify-mcp.mjs"
if (Test-Path $verifyScript) {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    & node $verifyScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "验证未全部通过，请检查上方 [FAIL] 项" -ForegroundColor Red
    }
}
else {
    Write-Host "未找到 verify-mcp.mjs，跳过真实验证" -ForegroundColor Yellow
}
Write-Host ""
