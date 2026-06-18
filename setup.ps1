# 联网搜索 MCP 一键安装脚本 (Windows PowerShell)
# 使用方法: powershell -ExecutionPolicy Bypass -File setup.ps1

$ErrorActionPreference = "Continue"

Write-Host "联网搜索 MCP 策略 - 一键安装" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Tavily 是一个 AI 搜索引擎，需要 API Key 才能使用" -ForegroundColor Yellow
Write-Host "注册地址: https://tavily.com" -ForegroundColor DarkCyan
Write-Host ""
$TavilyKey = Read-Host "请输入 Tavily API Key (直接回车跳过)"

Write-Host ""
Write-Host "检查前置依赖..." -ForegroundColor Cyan

$nodeVer = & node -v 2>&1 | Out-String
if ($nodeVer -match "v\d+") {
    Write-Host "Node.js $($nodeVer.Trim())" -ForegroundColor Green
}
else {
    Write-Host "未安装 Node.js，请先安装: https://nodejs.org/" -ForegroundColor Red
    Read-Host "按 Enter 退出"
    exit 1
}

$claudeCheck = & claude --version 2>&1 | Out-String
if ($LASTEXITCODE -eq 0) {
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
        if ($line.Trim() -match '^(\S+):') {
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

function Install-Mcp($name, $displayName, $extraArgs) {
    if (Test-Installed $name) {
        Write-Host "  [$name] 已安装，跳过" -ForegroundColor DarkGray
        return
    }

    Write-Host "  [$name] 安装 $displayName ..." -ForegroundColor Yellow
    $output = & claude mcp add --scope user $name @extraArgs 2>&1
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

Install-Mcp "web-search"      "多引擎搜索"     @("--", "cmd", "/c", "npx", "-y", "open-websearch@latest")
Install-Mcp "context7"        "技术文档查询"   @("--transport", "http", "https://mcp.context7.com/mcp")
Install-Mcp "chrome-devtools" "浏览器自动化"   @("--", "cmd", "/c", "npx", "chrome-devtools-mcp@latest")

if ($TavilyKey) {
    $tavilyUrl = "https://mcp.tavily.com/mcp/?tavilyApiKey=$TavilyKey"
    Install-Mcp "tavily" "AI 搜索引擎" @("--transport", "http", $tavilyUrl)
}
else {
    Write-Host "  [tavily] 跳过 (未提供 API Key)" -ForegroundColor DarkGray
}

Write-Host ""
Write-Host "[5/5] 安装策略文件..." -ForegroundColor Cyan
Write-Host ""

# 选择语言版本
Write-Host "选择策略语言版本:" -ForegroundColor Yellow
Write-Host "  [1] 简体中文 (strategy.md)" -ForegroundColor Cyan
Write-Host "  [2] English   (strategy_en.md)" -ForegroundColor DarkCyan
Write-Host ""
$langChoice = Read-Host "请选择 (1/2，默认 1)"
if ($langChoice -eq "2") {
    $strategyName = "strategy_en.md"
    $langLabel = "English"
}
else {
    $strategyName = "strategy.md"
    $langLabel = "简体中文"
}
Write-Host "已选择: $langLabel" -ForegroundColor Green
Write-Host ""

$claudeDir = "$env:USERPROFILE\.claude"
$strategySrc = Join-Path $PSScriptRoot $strategyName
$strategyDst = Join-Path $claudeDir "CLAUDE.md"

$srcExists = Test-Path $strategySrc
$dstExists = Test-Path $strategyDst

if (-not $srcExists) {
    Write-Host "未找到 $strategyName，跳过策略安装" -ForegroundColor Yellow
}
elseif ($dstExists) {
    Write-Host "检测到已有策略文件: $strategyDst" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  [1] 跳过 - 保持现有内容不变" -ForegroundColor DarkGray
    Write-Host "  [2] 追加 - 将新策略追加到末尾" -ForegroundColor Cyan
    Write-Host "  [3] 覆盖 - 替换为新策略" -ForegroundColor Red
    Write-Host ""
    $choice = Read-Host "请选择 (1/2/3)"
    if ($choice -eq "2") {
        $content = Get-Content $strategySrc -Raw
        Add-Content -Path $strategyDst -Value "`n`n$content"
        Write-Host "策略已追加到现有文件" -ForegroundColor Green
    }
    elseif ($choice -eq "3") {
        Copy-Item $strategySrc $strategyDst -Force
        Write-Host "策略文件已覆盖" -ForegroundColor Green
    }
    else {
        Write-Host "跳过策略文件安装" -ForegroundColor DarkGray
    }
}
else {
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }
    Copy-Item $strategySrc $strategyDst
    Write-Host "策略文件 ($langLabel) 已安装到 $strategyDst" -ForegroundColor Green
}

Write-Host ""
Write-Host "安装完成!" -ForegroundColor Green
Write-Host ""

# 自动展示四个联网 MCP 的状态
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host "  联网搜索 MCP 状态" -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan

$watchNames = @("web-search", "context7", "chrome-devtools", "tavily")
$mcpOutput = & claude mcp list 2>&1 | Out-String
$ok = 0; $fail = 0

if ($mcpOutput) {
    $lines = $mcpOutput -split "`n"
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^(\S+):') {
            $name = $Matches[1]
            if ($watchNames -contains $name) {
                if ($trimmed -match 'Failed') {
                    Write-Host ("  {0,-20} [FAIL] not connected" -f $name) -ForegroundColor Red
                    $fail++
                }
                else {
                    Write-Host ("  {0,-20} [OK]   connected" -f $name) -ForegroundColor Green
                    $ok++
                }
            }
        }
    }
}

Write-Host ("-" * 50) -ForegroundColor DarkGray
Write-Host ("  总计: {0} | 正常: {1} | 异常: {2}" -f ($ok + $fail), $ok, $fail) -ForegroundColor Cyan
Write-Host ("=" * 50) -ForegroundColor Cyan
Write-Host ""
