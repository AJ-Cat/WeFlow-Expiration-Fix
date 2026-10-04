# ============================================
# WeFlow 临时绕过时间锁启动脚本
# 作用：临时改系统时间，启动 WeFlow，10 秒后恢复时间并同步
# 要求：以管理员身份运行 PowerShell
# ============================================

$ErrorActionPreference = "Stop"

# 检查管理员权限
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "请以管理员身份运行此脚本。" -ForegroundColor Red
    Pause
    exit 1
}

# ===== 配置区 =====
# 要临时设置到的时间（必须早于 wcdb_api.dll 的过期时间 2026-09-30 23:59:59）
$FakeDate = Get-Date "2026-07-31 12:00:00"

# 启动后等待多少秒再恢复系统时间
$WaitSeconds = 10
# ==================

# ===== 自动查找 WeFlow 路径 =====
# 备用路径列表（按优先级排序）
$possiblePaths = @(
    # 1. 当前用户默认安装（Squirrel 安装器默认位置）
    (Join-Path $env:LOCALAPPDATA "Programs\WeFlow\WeFlow.exe"),
    # 2. 所有用户默认安装（64 位 Program Files）
    (Join-Path $env:ProgramFiles "WeFlow\WeFlow.exe"),
    # 3. 所有用户默认安装（32 位 Program Files，仅 32 位系统或 32 位安装）
    (Join-Path ${env:ProgramFiles(x86)} "WeFlow\WeFlow.exe")
)

# 逐一检查，选择第一个存在的路径
$WeFlowPath = $null
foreach ($path in $possiblePaths) {
    if ($path -and (Test-Path $path)) {
        $WeFlowPath = $path
        break
    }
}

if (-not $WeFlowPath) {
    Write-Host "找不到 WeFlow，已尝试以下路径：" -ForegroundColor Red
    foreach ($path in $possiblePaths) {
        Write-Host "  - $path" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "请手动修改脚本中的 `$possiblePaths 列表，加入你的 WeFlow 路径。" -ForegroundColor Yellow
    Pause
    exit 1
}

Write-Host "找到 WeFlow：$WeFlowPath" -ForegroundColor Green
Write-Host ""

# 可选：关闭已有的 WeFlow 进程，避免旧进程干扰
# Get-Process WeFlow -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "[1/6] 记录当前系统时间..."
$originalTime = Get-Date
Write-Host "      当前时间：$originalTime"

Write-Host "[2/6] 停止 Windows 时间服务 (W32Time)..."
Stop-Service -Name W32Time -Force -ErrorAction SilentlyContinue

Write-Host "[3/6] 将系统时间设置为 $FakeDate ..."
Set-Date -Date $FakeDate

Write-Host "[4/6] 启动 WeFlow..."
Start-Process -FilePath $WeFlowPath

Write-Host "[5/6] 等待 $WaitSeconds 秒，让 WeFlow 完成初始化..."
Start-Sleep -Seconds $WaitSeconds

Write-Host "[6/6] 恢复系统时间到 $originalTime ..."
Set-Date -Date $originalTime

Write-Host "      启动 Windows 时间服务并强制同步..."
Start-Service -Name W32Time -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
w32tm /resync /force | Out-Null

Write-Host ""
Write-Host "完成。WeFlow 应已启动，系统时间已恢复。" -ForegroundColor Green
Write-Host "如果 WeFlow 仍提示 -101，说明它在启动后重新检查了时间。" -ForegroundColor Yellow
Pause
