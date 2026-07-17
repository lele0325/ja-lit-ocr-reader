$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Host.UI.RawUI.WindowTitle = '日语文献 OCR 校读工具 - 本地版'
Set-Location -LiteralPath $PSScriptRoot

$Port = if ($env:JA_LIT_PORT) { [int]$env:JA_LIT_PORT } else { 7860 }
$BaseUrl = "http://127.0.0.1:$Port"
$HealthUrl = "$BaseUrl/api/health"
$VenvDir = Join-Path $PSScriptRoot '.venv'
$VenvPython = Join-Path $VenvDir 'Scripts\python.exe'
$ReqFile = Join-Path $PSScriptRoot 'requirements.txt'
$ReqStamp = Join-Path $VenvDir '.requirements.sha256'

function Test-ThisApp {
    try {
        $client = New-Object System.Net.WebClient
        $client.Proxy = $null
        $result = $client.DownloadString($HealthUrl)
        return ($result -match 'ja-lit-local')
    } catch { return $false }
}

function Get-Sha256([string]$Path) {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '')
        } finally { $sha.Dispose() }
    } finally { $stream.Dispose() }
}

if (Test-ThisApp) {
    Write-Host '工具已经在运行，正在打开网页……' -ForegroundColor Green
    Start-Process $BaseUrl
    exit 0
}

# 查找 Python。优先用 Windows 的 py 启动器，其次使用 python 命令。
$PythonCommand = $null
$PythonArgs = @()
if (Get-Command py.exe -ErrorAction SilentlyContinue) {
    $PythonCommand = 'py.exe'
    $PythonArgs = @('-3')
} elseif (Get-Command python.exe -ErrorAction SilentlyContinue) {
    $PythonCommand = 'python.exe'
} else {
    Write-Host '没有检测到 Python。' -ForegroundColor Red
    Write-Host '请先从 https://www.python.org/downloads/windows/ 安装 Python 3.10 或更高版本。'
    Write-Host '安装时请勾选「Add Python to PATH」，装好后重新双击本启动文件。'
    exit 1
}

try {
    $versionText = & $PythonCommand @PythonArgs -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')"
    $parts = $versionText.Trim().Split('.')
    if ([int]$parts[0] -lt 3 -or ([int]$parts[0] -eq 3 -and [int]$parts[1] -lt 10)) {
        throw "检测到 Python $versionText，需要 Python 3.10 或更高版本。"
    }
} catch {
    Write-Host "Python 检查失败：$($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $VenvPython)) {
    Write-Host '首次运行：正在创建本工具专用的独立环境……' -ForegroundColor Cyan
    & $PythonCommand @PythonArgs -m venv $VenvDir
    if ($LASTEXITCODE -ne 0) { throw '创建 Python 独立环境失败。' }
}

$CurrentHash = Get-Sha256 $ReqFile
$SavedHash = if (Test-Path -LiteralPath $ReqStamp) { (Get-Content -LiteralPath $ReqStamp -Raw).Trim() } else { '' }
if ($CurrentHash -ne $SavedHash) {
    Write-Host '正在安装/更新所需组件（只在首次运行或程序更新后执行）……' -ForegroundColor Cyan
    & $VenvPython -m pip install --disable-pip-version-check -r $ReqFile
    if ($LASTEXITCODE -ne 0) {
        # Windows/代理软件退出后常会留下失效的 HTTP(S)_PROXY；自动清除后重试。
        Write-Host '当前代理不可用，正在尝试直接连接……' -ForegroundColor Yellow
        $proxyNames = @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','http_proxy','https_proxy','all_proxy')
        $savedProxy = @{}
        foreach ($name in $proxyNames) {
            $savedProxy[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $null, 'Process')
        }
        & $VenvPython -m pip install --disable-pip-version-check -r $ReqFile
        if ($LASTEXITCODE -ne 0) {
            Write-Host '直连失败，正在尝试清华大学 PyPI 镜像……' -ForegroundColor Yellow
            & $VenvPython -m pip install --disable-pip-version-check `
                -i 'https://pypi.tuna.tsinghua.edu.cn/simple' -r $ReqFile
        }
        foreach ($name in $proxyNames) {
            [Environment]::SetEnvironmentVariable($name, $savedProxy[$name], 'Process')
        }
        if ($LASTEXITCODE -ne 0) {
            throw '组件安装失败。请确认网络可用，或打开代理软件后重新双击启动。'
        }
    }
    Set-Content -LiteralPath $ReqStamp -Value $CurrentHash -Encoding ASCII
}

# 若端口被其他程序占用，给出明确提示，避免误开别的网页。
$occupied = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners() |
    Where-Object { $_.Port -eq $Port }
if ($occupied) {
    Write-Host "端口 $Port 已被其他程序占用，无法启动。请关闭占用该端口的程序后重试。" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "本地工具正在运行：$BaseUrl" -ForegroundColor Green
Write-Host '网页会自动打开。工作期间请不要关闭这个黑色窗口。' -ForegroundColor Yellow
Write-Host '完成后直接关闭本窗口，即可停止本地工具。'
Write-Host ''

# 另启一个短暂的隐藏进程，等服务就绪后再打开浏览器，避免打开过早看到连接失败。
$escapedHealth = $HealthUrl.Replace("'", "''")
$escapedBase = $BaseUrl.Replace("'", "''")
$waitScript = @"
for (`$i = 0; `$i -lt 60; `$i++) {
    try {
        `$wc = New-Object System.Net.WebClient
        `$wc.Proxy = `$null
        `$r = `$wc.DownloadString('$escapedHealth')
        if (`$r -match 'ja-lit-local') { Start-Process '$escapedBase'; exit }
    } catch {}
    Start-Sleep -Milliseconds 500
}
"@
if ($env:JA_LIT_NO_BROWSER -ne '1') {
    Start-Process powershell.exe -WindowStyle Hidden -ArgumentList @('-NoProfile','-Command',$waitScript)
}

$env:PYTHONUTF8 = '1'
& $VenvPython -m waitress --host=127.0.0.1 --port=$Port --threads=8 --channel-timeout=1800 server:app
exit $LASTEXITCODE
