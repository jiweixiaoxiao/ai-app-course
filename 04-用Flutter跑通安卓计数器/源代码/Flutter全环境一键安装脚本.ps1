<#
Flutter 环境一键安装 · 第 04 课片尾资料 · v1.5
课程固定 Flutter 3.29.0，官方 Windows 构建为 x64。用安卓真机练习。
给豆包：先读脚本并说明将安装的组件、环境变量、镜像设置和许可。
本人阅读并同意 Android SDK 条款、同意本次安装后，可在 Windows PowerShell 中运行
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "本脚本完整路径" -NonInteractive -AcceptAndroidLicenses
跟踪本次进程的退出码及 %TEMP%\flutter_install_log.txt。

发放前自检：加 -DryRun 跑一遍，全部装进 %TEMP% 的临时目录，不写注册表、不动已装的工具，
等同一次全新机器演练。建议连同 -VerifyBuild 使用：
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "本脚本完整路径" -NonInteractive -AcceptAndroidLicenses -VerifyBuild -DryRun

v1.5 相对 v1.4 的变化（均来自 2026-11-26 Windows 11 真机实测）：
  1. 默认不再要求管理员权限：环境变量全部写入「用户级」，工具装到用户目录。
     只有把 $installEmulator 改为 $true 才需要提权（启用 Windows 功能）。
  2. JDK 检测加入用户级 Android Studio（%LOCALAPPDATA%\Programs\Android Studio）。
  3. cmdline-tools 下载补 SHA1 校验（与官方清单 repository2-3.xml 比对）。
  4. Gradle 镜像分两处：Maven 依赖用 ~/.gradle/init.gradle 把阿里云仓库排在官方仓库前面
     （镜像没有的组件自动回退官方源）；Gradle 分发包（wrapper）改 Flutter 工程模板里的
     distributionUrl 指向华为云同名 ZIP（init 脚本对 wrapper 首次下载来不及生效，实测已排除该做法）。
      注意 v1.4 的 init 脚本用 settingsEvaluated，对 AGP / Kotlin 插件不生效（实测 375 个文件镜像 0 个），
      这里改用 beforeSettings 管插件、beforeProject 管主构建的工程依赖；allprojects 会把镜像仓库塞进
      Flutter 的 includeBuild 构建，导致插件解析直接失败（实测 3 秒挂掉）。
  5. 写完环境变量后广播 WM_SETTINGCHANGE，并提示「完全退出终端再重开」。
  6. 新增可选的真实构建验证（-VerifyBuild）：建临时工程跑 flutter build apk --debug，
     能提前暴露 sdkmanager.bat 起不来、Gradle 里找不到 git 这两类 doctor 查不出的问题。
  7. JDK 加版本闸门：Flutter 3.29.0 的工程固定 Gradle 8.10.2（官方支持 Java 8~23）。
     Android Studio 自带 JDK 高于 23 时不采用（实测 JBR 25 下 Kotlin DSL 工程构建失败），
     改用免安装的 Temurin 17：Adoptium 官方 API 取文件名与校验值，国内镜像下载同名 ZIP 并核对
     （华为云 Adoptium 路径实测返回过限流网页而非文件，所以清华在前、华为云在后，校验不过自动换下一个）。
  8. 除 JAVA_HOME 外，另执行 flutter config --jdk-dir 显式指定 JDK
     （Flutter 选 JDK 的顺序是 jdk-dir 配置 > Studio 自带 JDK > JAVA_HOME）。
  9. Flutter 工程模板里的 wrapper 追加 distributionSha256Sum（仅当 SDK 用的是课程固定 Gradle 8.10.2）。
 10. 关闭下载进度条：Windows PowerShell 5.1 画进度条会拖慢大文件下载。
     实测同一 191MB 文件，开进度条约 135 秒，关掉约 15 秒。
 11. PortableGit 补大小与 SHA256 校验（v1.4 是直接解压），来源顺序为 npmmirror → 清华 → GitHub。
 12. 当前终端 PATH 里没有 System32 时，在本脚本进程内补上（不改系统设置）。
 13. 5.1 下原生命令的 stderr 会被全局的 Stop 当成致命错误：
     Get-JavaMajor 里局部放宽，-VerifyBuild 段只看退出码。
#>

param(
    [switch]$NonInteractive,
    [switch]$AcceptAndroidLicenses,
    [switch]$VerifyBuild,
    [switch]$DryRun
)

# ========== 可配置参数 ==========
$flutterVersion = "3.29.0"          # 与下面的官方归档路径和 SHA-256 配套
$flutterArchive = "stable/windows/flutter_windows_3.29.0-stable.zip"
$flutterSha256 = "0b0080912f856b66843a2061bc73e73ab1ea20b68f068100956da69783b4ca70"
$installRoot = if ($env:USERPROFILE) { Join-Path $env:USERPROFILE "develop" } else { "C:\src" }   # Flutter SDK 安装根目录（用户可写、无空格）
$androidSdkPath = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT } else { "$env:LOCALAPPDATA\Android\Sdk" }

$installAndroidStudio = $false      # Agent 全流程不需要 IDE；想要图形界面开发再改 $true
$installEmulator = $false           # $true=自动配置安卓模拟器（额外下载约 2GB，需要管理员）；$false=跳过
$avdName = "Pixel_API34"            # 自动创建的模拟器名称
$doVerifyBuild = $VerifyBuild       # $true=装完建临时工程真实构建一次（首跑约 5 分钟）

# Flutter 官方国内镜像
$pubHostedUrl = "https://pub.flutter-io.cn"
$flutterStorageUrl = "https://storage.flutter-io.cn"

# Android SDK 必备组件版本
$androidPlatform = "android-35"
$buildToolsVersion = "34.0.0"

# 独立 JDK（Android Studio 自带 JDK 不可用或版本过新时使用）
$jdkMajor = 17                    # Flutter 3.29.0 的工程模板固定 Gradle 8.10.2，配 JDK 17（已实测）
$maxJavaMajorForStudio = 23       # Studio 自带 JDK 高于此主版本则不采用：Gradle 8.10.2 官方最高支持 Java 23
$jdkInstallRoot = Join-Path $env:LOCALAPPDATA "Programs\Java"   # 免安装 JDK 解压位置（无需管理员）
$adoptiumApi = "https://api.adoptium.net/v3/assets/latest/$jdkMajor/hotspot?architecture=x64&image_type=jdk&os=windows&vendor=eclipse"
$adoptiumMirrors = @(
    "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/$jdkMajor/jdk/x64/windows/",  # 两次实测校验通过（约 190MB，2 分钟）
    "https://mirrors.huaweicloud.com/Adoptium/$jdkMajor/jdk/x64/windows/"        # 备选：实测不稳定，曾返回限流网页而非文件
)
# 每个来源都下载与官方 API 同名的 ZIP，并核对官方 SHA256，所以换镜像不影响安全性；校验不过自动换下一个

# Gradle 分发包（课程固定版本；SHA256 取自 https://services.gradle.org/distributions/gradle-8.10.2-all.zip.sha256）
$gradleVersionPinned = "8.10.2"
$gradleDistSha256 = "2ab88d6de2c23e6adae7363ae6e29cbdd2a709e992929b48b6530fd0c7133bd6"

# PortableGit（非管理员时使用）。大小与 SHA256 已与「安装包\PortableGit-2.56.1-64-bit.7z.exe」归档核对。
$pgVersion = "2.56.1"
$pgName = "PortableGit-$pgVersion-64-bit.7z.exe"
$pgSize = 60125512
$pgSha256 = "9dd04a608ceb5f6ab32a73709e0ecb159d211da71b697c45ff81f6dd0c6b49c7"
$pgSources = @(
    "https://registry.npmmirror.com/-/binary/git-for-windows/v$pgVersion.windows.1/$pgName",                 # 实测可用
    "https://mirrors.tuna.tsinghua.edu.cn/github-release/git-for-windows/git/LatestRelease/$pgName",         # 只保留最新版，旧版下架后会 404
    "https://github.com/git-for-windows/git/releases/download/v$pgVersion.windows.1/$pgName"                 # 官方，国内常被重置
)

# cmdline-tools（与下方 SHA1 配套；SHA1 取自官方清单 https://dl.google.com/android/repository/repository2-3.xml）
$cmdToolsBuild = "11076708"
$cmdToolsSha1 = "3d2917302740f476999a091bc5558837c7a863c5"
$gradleUserHome = Join-Path $env:USERPROFILE ".gradle"
$gitUserDir = Join-Path $env:LOCALAPPDATA "Programs\Git"
# =================================

# 自检模式（-DryRun）：完整走完 10 个步骤和真实构建，但不改动本机任何现有配置。
#   Flutter、JDK、Git、Android SDK、Gradle 缓存、pub 缓存全部指向 %TEMP% 下的临时目录；
#   环境变量只写入本进程，不写注册表、不广播。跑完按提示删除该临时目录即可。
if ($DryRun) {
    $dryRoot = Join-Path $env:TEMP ("flutter-dryrun-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Path $dryRoot -Force | Out-Null
    $installRoot = Join-Path $dryRoot "develop"
    $androidSdkPath = Join-Path $dryRoot "android-sdk"
    $jdkInstallRoot = Join-Path $dryRoot "java"
    $gitUserDir = Join-Path $dryRoot "git"
    $gradleUserHome = Join-Path $dryRoot "gradle-home"
    $LogFile = Join-Path $dryRoot "install.log"
    $env:GRADLE_USER_HOME = $gradleUserHome
    $env:PUB_CACHE = Join-Path $dryRoot "pub-cache"
    Write-Host "自检模式（-DryRun）" -ForegroundColor Magenta
    Write-Host "  临时目录：$dryRoot" -ForegroundColor Magenta
    Write-Host "  不写注册表环境变量，不动现有的 Flutter / Android Studio / Git / JDK 安装，也不动 ~/.gradle 与 pub 缓存。" -ForegroundColor Magenta
}

if ($NonInteractive -and -not $AcceptAndroidLicenses) {
    Write-Host "无人值守安装前，请本人先阅读 Android SDK 许可。确认同意后，再带 -AcceptAndroidLicenses 运行。"
    exit 1
}

# 全局设置
$ProgressPreference = "SilentlyContinue"
$needReboot = $false
if (-not $LogFile) { $LogFile = Join-Path $env:TEMP "flutter_install_log.txt" }

# 统一出口：写结果标记、停日志；仅人工模式暂停窗口
function Stop-Script([int]$Code) {
    if ($Code -eq 0) {
        Write-Host "`nINSTALL_RESULT: SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "`nINSTALL_RESULT: FAILED (exit code $Code)" -ForegroundColor Red
    }
    try { Stop-Transcript | Out-Null } catch { }
    if (-not $NonInteractive) { Read-Host "`n按回车键关闭脚本窗口" }
    exit $Code
}

function Test-IsAdmin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --------------------------
# 步骤1：权限判断（默认无需管理员）
# --------------------------
Write-Host "`n=== 1/10 检查权限 ===" -ForegroundColor Cyan
if ($installEmulator -and -not (Test-IsAdmin)) {
    Write-Host "启用模拟器需要开启 Windows 功能，即将弹出授权窗口，请点「是」..." -ForegroundColor Yellow
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($NonInteractive) { $argList += " -NonInteractive" }
    if ($AcceptAndroidLicenses) { $argList += " -AcceptAndroidLicenses" }
    if ($VerifyBuild) { $argList += " -VerifyBuild" }
    try {
        # -Wait：父进程等提权子进程跑完再退出，Agent 能拿到真实退出码
        $p = Start-Process powershell.exe -ArgumentList $argList -Verb RunAs -PassThru -Wait
        exit $p.ExitCode
    } catch {
        Write-Host "管理员授权被取消，未执行安装" -ForegroundColor Red
        exit 1
    }
}
$ErrorActionPreference = "Stop"
# Windows PowerShell 5.1 画下载进度条会拖慢大文件下载。实测同一 191MB 文件（5.1 控制台窗口）：
# 开进度条 134.9 / 134.5 秒，关进度条 15.2 / 15.8 秒。所以这里关掉，下载期间看不到进度条属正常。
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Host ("安装中止：" + $_.Exception.Message) -ForegroundColor Red
    Stop-Script 1
}
Start-Transcript -Path $LogFile -Force | Out-Null
Write-Host "安装日志：$LogFile" -ForegroundColor Gray
if (Test-IsAdmin) {
    Write-Host "当前以管理员运行" -ForegroundColor Green
} else {
    Write-Host "当前为普通用户权限：工具将安装到用户目录，环境变量写入用户级（无需 UAC）" -ForegroundColor Green
}
# 兜底：当前终端的 PATH 里没有 System32 时，where、robocopy 这类系统命令会找不到（PATH 被改坏的机器上出现过）。
# 只补本进程的 PATH，不改动系统或用户的 Path 设置。
$sys32Dir = Join-Path $env:SystemRoot "System32"
if ((Test-Path -LiteralPath $sys32Dir) -and -not (@($env:Path -split ';' | Where-Object { $_.TrimEnd('\') -ieq $sys32Dir }).Count)) {
    $env:Path = "$sys32Dir;$env:SystemRoot;$env:Path"
    Write-Warning "当前终端的 PATH 里没有 System32，已在本脚本进程内补上（不改动系统设置）。"
}

# --------------------------
# 步骤2：检测系统架构
# --------------------------
Write-Host "`n=== 2/10 检测系统架构 ===" -ForegroundColor Cyan
$nativeArch = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
# 以操作系统原生架构为准，避免 ARM 上的 x64 仿真进程误选发行包。
$processors = @(Get-CimInstance Win32_Processor)
if ($processors.Count -eq 0 -or $processors[0].Architecture -ne 9 -or $nativeArch -ne "AMD64") {
    Write-Host "本课程固定的 Flutter 3.29.0 只有 Windows x64 发行包。"
    Write-Host "这台电脑不是 x64：请在 64 位 x64 电脑上跟做，或回到跟做手册 A 段按实际架构检查。" -ForegroundColor Yellow
    Stop-Script 1
}
$arch = "x64"
Write-Host "已确认 Windows x64。"

# --------------------------
# 步骤3：检查 winget 包管理器
# --------------------------
Write-Host "`n=== 3/10 检查系统包管理器 winget ===" -ForegroundColor Cyan
$wingetOk = $false
try {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        winget --version | Out-Null
        $wingetOk = ($LASTEXITCODE -eq 0)
    } else {
        # 非管理员会话里 winget 可能不在 PATH，但实体存在于 WindowsApps
        $wg = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\winget.exe"
        if (Test-Path $wg) { $script:wingetExe = $wg; & $wg --version | Out-Null; $wingetOk = ($LASTEXITCODE -eq 0) }
    }
} catch { $wingetOk = $false }
if (-not $wingetOk) {
    Write-Host "未检测到 winget 包管理器" -ForegroundColor Red
    Write-Host "请先在微软应用商店安装「应用安装程序」，或升级 Windows 系统后重试" -ForegroundColor Yellow
    Stop-Script 1
}
if (-not $script:wingetExe) { $script:wingetExe = "winget.exe" }
Write-Host "winget 已就绪（$($script:wingetExe)）" -ForegroundColor Green

# --------------------------
# 步骤4：安装 Git（Flutter 强制依赖）
# --------------------------
Write-Host "`n=== 4/10 安装 Git ===" -ForegroundColor Cyan

# 免安装的 PortableGit：依次试国内镜像与官方地址，每个来源都核对大小与 SHA256（与官方发布包一致才解压）。
# 返回 $true / $false。GitHub 直连在国内常被重置，所以放最后。
# 摘要计算一律走 .NET，不依赖 Get-FileHash。
# 原因（实测）：被别的程序调用、标准输出被重定向的 Windows PowerShell 5.1 里，Get-FileHash 可能根本不可用，
# 表现为“无法将 Get-FileHash 项识别为 cmdlet”，会把下载成功误判成校验失败。.NET 的方式同时能流式读大文件。
function Get-FileSha([string]$path, [string]$algorithm) {
    $alg = [System.Security.Cryptography.HashAlgorithm]::Create($algorithm)
    $fs = $null
    try {
        $fs = [System.IO.File]::OpenRead($path)
        ([System.BitConverter]::ToString($alg.ComputeHash($fs)) -replace '-', '').ToLower()
    } finally {
        if ($fs) { $fs.Dispose() }
        if ($alg) { $alg.Dispose() }
    }
}

# 解压：优先用系统自带的 tar.exe。实测 Expand-Archive 在目标目录偏深时会失败
# （Flutter 包里 dart-sdk 有一批路径极深的文件，路径超过 260 字符就报“未能找到路径的一部分”），
# 而 tar.exe 能正常解出；tar 也更快。目标机器没有 tar.exe 时退回 Expand-Archive。
function Expand-Zip([string]$zip, [string]$dest) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $tarExe = Join-Path $env:SystemRoot "System32\tar.exe"
    if (Test-Path -LiteralPath $tarExe) {
        & $tarExe -xf $zip -C $dest
        if ($LASTEXITCODE -eq 0) { return }
        Write-Warning "tar 解压失败（退出码 $LASTEXITCODE），改用 Expand-Archive 重试：$zip"
        Remove-Tree $dest
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
    }
    Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
}

# 递归删除：Remove-Item -Recurse 遇到超过 260 字符的深路径会报“找不到路径的一部分”并中断。
# 这里用 .NET 的 \\?\ 前缀删除；万一仍失败，用空目录镜像同步兜底。
function Remove-Tree([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    $full = [IO.Path]::GetFullPath($path).TrimEnd('\')
    try {
        [IO.Directory]::Delete('\\?\' + $full, $true)
        return
    } catch { }
    try {
        $empty = Join-Path $env:TEMP ("empty-" + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        & "$env:SystemRoot\System32\robocopy.exe" $empty $full /MIR /NFL /NDL /NJH /NJS /NC /NS /NP 2>&1 | Out-Null
        Remove-Item -LiteralPath $empty -Force -Recurse -ErrorAction SilentlyContinue
        [IO.Directory]::Delete('\\?\' + $full, $true)
    } catch {
        Write-Warning "清理 $full 未完成（不影响安装）：$($_.Exception.Message)"
    }
}

function Get-GitPortable([string]$targetDir) {
    $stage = Join-Path $env:TEMP ("git-setup-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        $file = Join-Path $stage $pgName
        $downloadOK = $false
        foreach ($u in $pgSources) {
            try {
                Write-Host "下载 PortableGit $pgVersion：$u"
                Invoke-WebRequest -Uri $u -OutFile $file -UseBasicParsing
                $size = (Get-Item -LiteralPath $file).Length
                if ($size -ne $pgSize) { throw ("文件大小不符（实际 $size 字节，应为 $pgSize 字节）") }
                $hash = Get-FileSha $file "SHA256"
                if ($hash -ne $pgSha256) { throw ("SHA256 不符（实际 $hash）") }
                $downloadOK = $true
                break
            } catch {
                Write-Warning "$u 下载或校验失败：$($_.Exception.Message)"
            }
            Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
        }
        if (-not $downloadOK) { Write-Warning "PortableGit 各来源均未通过校验。"; return $false }
        # 7z 自解压包：-y 静默，-o 指定目录（路径含空格时必须带引号）
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $file
        $psi.Arguments = "-y -o`"$targetDir`""
        $psi.UseShellExecute = $false
        $pr = [System.Diagnostics.Process]::Start($psi)
        $pr.WaitForExit()
        if ($pr.ExitCode -ne 0 -or -not (Test-Path (Join-Path $targetDir "cmd\git.exe") -PathType Leaf)) {
            Remove-Tree $targetDir
            Write-Warning "PortableGit 解压失败（退出码 $($pr.ExitCode)）。"
            return $false
        }
        Write-Host "PortableGit 大小与 SHA256 校验通过，已解压到 $targetDir" -ForegroundColor Green
        return $true
    } catch {
        Write-Warning "PortableGit 处理失败：$($_.Exception.Message)"
        return $false
    } finally {
        Remove-Tree $stage
    }
}

$gitReady = $false
$gitCmd = Get-Command git.exe -ErrorAction SilentlyContinue
if ($gitCmd) { git --version | Out-Null; $gitReady = ($LASTEXITCODE -eq 0) }
if ($DryRun) {
    # 自检模式忽略本机已装的 Git，强制走一次 PortableGit 下载校验解压，覆盖正式流程才会走到的分支
    $gitReady = $false
    $gitCmd = $null
}
if ($gitReady) {
    Write-Host "Git 已安装（$(Split-Path $gitCmd.Source -Parent)），跳过本步骤" -ForegroundColor Green
} else {
    # 非管理员：winget 的 Git.Git 包会要求提权。改用官方 PortableGit 解压到用户目录。
    $gitUserExe = Join-Path $gitUserDir "cmd\git.exe"
    if (Test-Path $gitUserExe) {
        Write-Host "发现用户目录已有 Git，直接沿用：$gitUserDir" -ForegroundColor Green
    } elseif (Test-IsAdmin) {
        Write-Host "正在静默安装 Git，请稍候..." -ForegroundColor Yellow
        & $script:wingetExe install --id Git.Git -e --silent --accept-source-agreements --accept-package-agreements
        if ($LASTEXITCODE -ne 0) { throw "Git 安装失败（winget 返回 $LASTEXITCODE）。" }
        Write-Host "Git 安装完成" -ForegroundColor Green
    } else {
        Write-Host "当前为普通用户：下载官方 PortableGit 解压到 $gitUserDir（无需管理员）" -ForegroundColor Yellow
        if (-not (Get-GitPortable $gitUserDir)) {
            throw "PortableGit 下载、校验或解压均未成功（原因见上方告警）。"
        }
        Write-Host "Git 安装完成：$gitUserDir" -ForegroundColor Green
    }
}
# 让本脚本后续步骤（flutter doctor 等）能用上刚装好的 Git
$gitCmdDir = $null
foreach ($c in @((Get-Command git.exe -ErrorAction SilentlyContinue).Source, $gitUserExe, "C:\Program Files\Git\cmd\git.exe")) {
    if ($c -and (Test-Path $c)) { $gitCmdDir = Split-Path $c -Parent; break }
}
if ($gitCmdDir) { $env:Path = "$gitCmdDir;" + $env:Path }
git --version | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Git 未能运行。" }

# 取 JDK 的主版本号：优先读 release 文件，读不到再运行 java -version。
function Get-JavaMajor([string]$javaHome) {
    # Windows PowerShell 5.1 下，原生命令的 stderr 走 2>&1 会被全局的 Stop 当成致命错误，这里局部放宽
    $ErrorActionPreference = 'Continue'
    if (-not $javaHome) { return $null }
    $rel = Join-Path $javaHome "release"
    if (Test-Path -LiteralPath $rel -PathType Leaf) {
        $line = Get-Content -LiteralPath $rel | Where-Object { $_ -match '^JAVA_VERSION="' } | Select-Object -First 1
        if ("$line" -match 'JAVA_VERSION="(\d+)') { return [int]$matches[1] }
    }
    try {
        $exe = Join-Path $javaHome "bin\java.exe"
        if (Test-Path -LiteralPath $exe -PathType Leaf) {
            $v = (& $exe -version 2>&1 | Select-Object -First 1) -join ''
            if ("$v" -match 'version "(\d+)') { return [int]$matches[1] }
        }
    } catch { }
    return $null
}

# 免安装 JDK：从 Adoptium 官方 API 取文件名与 SHA256，再从国内镜像下载同名 ZIP 并核对，解压到用户目录。
# 返回 JDK 目录；任一步失败返回 $null（调用方会继续尝试其它方式）。
function Get-JdkByZip {
    try {
        $meta = Invoke-RestMethod -Uri $adoptiumApi -UseBasicParsing -TimeoutSec 30
        $pkg = @($meta)[0].binary.package
        if (-not $pkg.name -or -not $pkg.checksum) { throw "Adoptium API 返回缺少文件名或校验值" }
    } catch {
        Write-Warning "Adoptium API 不可用，跳过免安装 JDK：$($_.Exception.Message)"
        return $null
    }
    $name = [string]$pkg.name
    $sha = ([string]$pkg.checksum).ToLower()
    $sources = @($adoptiumMirrors | ForEach-Object { "$_" + $name }) + @([string]$pkg.link)
    $stage = Join-Path $env:TEMP ("jdk-setup-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        $zip = Join-Path $stage $name
        $downloadOK = $false
        foreach ($u in $sources) {
            try {
                Write-Host "下载 Temurin JDK $jdkMajor：$u"
                Invoke-WebRequest -Uri $u -OutFile $zip -UseBasicParsing
                if ((Get-FileSha $zip "SHA256") -ne $sha) { throw ("文件摘要与 Adoptium 官方校验值不符（实际 {0} 字节，应为 {1} 字节）" -f (Get-Item -LiteralPath $zip).Length, $pkg.size) }
                $downloadOK = $true
                break
            } catch {
                Write-Warning "$u 下载或校验失败：$($_.Exception.Message)"
            }
            Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        }
        if (-not $downloadOK) { Write-Warning "JDK 镜像与官方地址下载均未通过校验。"; return $null }
        Expand-Zip $zip $stage
        $javaExe = Get-ChildItem -LiteralPath $stage -Recurse -Filter "java.exe" | Where-Object { $_.Directory.Name -eq "bin" } | Select-Object -First 1
        if (-not $javaExe) { throw "JDK 压缩包里缺少 bin\java.exe" }
        $unpackedHome = Split-Path $javaExe.DirectoryName -Parent
        New-Item -ItemType Directory -Path $jdkInstallRoot -Force | Out-Null
        $dest = Join-Path $jdkInstallRoot (Split-Path $unpackedHome -Leaf)
        if (Test-Path -LiteralPath $dest) { Remove-Tree $dest }
        [IO.Directory]::Move($unpackedHome, $dest)
        Write-Host "JDK SHA256 校验通过（与 Adoptium 官方一致）" -ForegroundColor Green
        return $dest
    } catch {
        Write-Warning "免安装 JDK 处理失败：$($_.Exception.Message)"
        return $null
    } finally {
        Remove-Tree $stage
    }
}

# --------------------------
# 步骤5：配置 JDK（Android Studio 为可选）
# --------------------------
Write-Host "`n=== 5/10 配置 JDK ===" -ForegroundColor Cyan
$studioCandidates = @(
    "C:\Program Files\Android\Android Studio",
    (Join-Path $env:LOCALAPPDATA "Programs\Android Studio")
)
$javaPath = $null
$studioInstalled = $false
foreach ($sp in $studioCandidates) {
    $jbr = Join-Path $sp "jbr"
    if ((Test-Path (Join-Path $sp "bin\studio64.exe")) -and (Test-Path (Join-Path $jbr "bin\java.exe"))) {
        $jbrMajor = Get-JavaMajor $jbr
        if ($null -ne $jbrMajor -and $jbrMajor -gt $maxJavaMajorForStudio) {
            # 实测：JBR 25 跑课程固定的 Gradle 8.10.2，Kotlin DSL 工程构建失败（IllegalArgumentException: 25.0.4.1）
            Write-Host "检测到 Android Studio 自带 JDK $jbrMajor（$jbr）" -ForegroundColor Yellow
            Write-Host "课程固定 Flutter $flutterVersion 使用 Gradle $gradleVersionPinned，官方最高支持 Java $maxJavaMajorForStudio，不采用该 JDK，改用下方独立 JDK $jdkMajor。" -ForegroundColor Yellow
            continue
        }
        $studioPath = $sp; $studioJbr = $jbr; $javaPath = $jbr; $studioInstalled = $true
        Write-Host "检测到已安装的 Android Studio，复用其内置 JDK（$jbr）" -ForegroundColor Green
        break
    }
}
if (-not $javaPath -and $installAndroidStudio) {
    if (Test-IsAdmin) {
        Write-Host "正在下载并静默安装 Android Studio（约 1.5GB，需耐心等待）..." -ForegroundColor Yellow
        & $script:wingetExe install --id Google.AndroidStudio -e --silent --accept-source-agreements --accept-package-agreements
        $studioPath = $studioCandidates[0]; $studioJbr = Join-Path $studioPath "jbr"
        if ($LASTEXITCODE -eq 0 -and (Test-Path $studioJbr)) {
            $javaPath = $studioJbr; $studioInstalled = $true
            Write-Host "Android Studio 安装完成" -ForegroundColor Green
            $studioBat = Join-Path $studioPath "bin\studio.bat"
            if (Test-Path $studioBat) {
                Write-Host "正在静默安装 Flutter / Dart 插件（约 1-3 分钟）..." -ForegroundColor Yellow
                & $studioBat installPlugins io.flutter Dart | Out-Null
                Write-Host "插件安装流程执行完毕" -ForegroundColor Green
            }
            $newJbrMajor = Get-JavaMajor $javaPath
            if ($null -ne $newJbrMajor -and $newJbrMajor -gt $maxJavaMajorForStudio) {
                Write-Host "新装的 Android Studio 自带 JDK $newJbrMajor，超出 Gradle $gradleVersionPinned 的支持范围（Java $maxJavaMajorForStudio），改用下方独立 JDK。" -ForegroundColor Yellow
                $javaPath = $null
            }
        } else {
            Write-Host "Android Studio 安装失败，改用独立 JDK 继续（不影响 Agent 命令行开发）" -ForegroundColor Yellow
        }
    } else {
        Write-Host "普通用户权限下不自动安装 Android Studio。请按课程 B3 步骤手动安装（免安装版解压到用户目录即可），或改用下方独立 JDK。" -ForegroundColor Yellow
    }
}

if (-not $javaPath) {
    # 先沿用已有的 JDK 17（本脚本的免安装目录、系统级或用户级 Temurin），没有再下载
    $jdkRoots = @($jdkInstallRoot, "C:\Program Files\Eclipse Adoptium", (Join-Path $env:LOCALAPPDATA "Programs\Eclipse Adoptium"))
    $jdkDir = $null
    foreach ($r in $jdkRoots) {
        $d = Get-ChildItem $r -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($d -and (Test-Path (Join-Path $d.FullName "bin\java.exe") -PathType Leaf)) { $jdkDir = $d; break }
    }
    if (-not $jdkDir) {
        $zipJdk = Get-JdkByZip
        if ($zipJdk) { $jdkDir = Get-Item -LiteralPath $zipJdk }
    }
    if (-not $jdkDir) {
        Write-Host "免安装方式不可用，改用 winget 静默安装 Temurin $jdkMajor JDK（约 190MB）..." -ForegroundColor Yellow
        & $script:wingetExe install --id EclipseAdoptium.Temurin.17.JDK -e --silent --accept-source-agreements --accept-package-agreements --scope user
        foreach ($r in $jdkRoots) {
            $d = Get-ChildItem $r -Directory -Filter "jdk-17*" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
            if ($d) { $jdkDir = $d; break }
        }
    }
    if ($jdkDir) {
        $javaPath = $jdkDir.FullName
        Write-Host "JDK 就绪：$javaPath" -ForegroundColor Green
    } else {
        Write-Host "JDK 安装失败，无法继续安装 Android SDK 组件" -ForegroundColor Red
        Stop-Script 1
    }
}

$env:JAVA_HOME = $javaPath
$env:ANDROID_HOME = $androidSdkPath
$env:ANDROID_SDK_ROOT = $androidSdkPath

# --------------------------
# 步骤6：下载安装 Flutter SDK
# --------------------------
Write-Host "`n=== 6/10 安装 Flutter SDK ===" -ForegroundColor Cyan
$flutterPath = Join-Path $installRoot "flutter"

$knownFlutter = Get-Command flutter.bat -ErrorAction SilentlyContinue
if ($knownFlutter) {
    $flutterPath = Split-Path (Split-Path $knownFlutter.Source -Parent) -Parent
    Write-Host "沿用 PATH 中的 Flutter：$flutterPath"
} elseif (Test-Path (Join-Path $flutterPath "bin\flutter.bat") -PathType Leaf) {
    Write-Host "沿用已有 Flutter：$flutterPath"
} elseif (Test-Path $flutterPath) {
    throw "$flutterPath 已存在但缺少 bin\flutter.bat。请检查原目录，或另选空安装位置。"
} else {
    New-Item -ItemType Directory -Path $installRoot -Force | Out-Null
    $stage = Join-Path $installRoot ("flutter-setup-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $stage | Out-Null
    try {
        $zipSavePath = Join-Path $stage "flutter.zip"
        $downloadOK = $false
        foreach ($source in @($flutterStorageUrl, "https://storage.googleapis.com")) {
            $downloadUrl = "$source/flutter_infra_release/releases/$flutterArchive"
            try {
                Write-Host "下载 Flutter $flutterVersion（约 1.1GB，期间不显示进度条）：$downloadUrl"
                Invoke-WebRequest -Uri $downloadUrl -OutFile $zipSavePath -UseBasicParsing
                if ((Get-FileSha $zipSavePath "SHA256") -ne $flutterSha256.ToLower()) {
                    throw "文件摘要与官方 Windows 发布清单不符"
                }
                if ($source -ne $flutterStorageUrl) {
                    $flutterStorageUrl = $source
                    $pubHostedUrl = "https://pub.dev"
                    Write-Host "归档已从官方源取得，后续 Flutter 下载也使用官方源。"
                }
                $downloadOK = $true
                break
            } catch {
                Write-Warning "$downloadUrl 下载或校验失败：$($_.Exception.Message)"
            }
        }
        if (-not $downloadOK) { throw "Flutter 镜像和官方归档下载均未通过校验。" }
        Expand-Zip $zipSavePath $stage
        if (-not (Test-Path (Join-Path $stage "flutter\bin\flutter.bat") -PathType Leaf)) { throw "归档中缺少 flutter.bat。" }
        [IO.Directory]::Move((Join-Path $stage "flutter"), $flutterPath)
    } finally {
        Remove-Tree $stage
    }
}
$flutterBat = Join-Path $flutterPath "bin\flutter.bat"



# --------------------------
# 步骤7：安装 Android SDK 核心组件（纯命令行，无需 IDE）
# --------------------------
Write-Host "`n=== 7/10 安装 Android SDK 核心组件 ===" -ForegroundColor Cyan

New-Item -ItemType Directory -Path (Join-Path $androidSdkPath "cmdline-tools") -Force | Out-Null
$cmdToolsDir = Join-Path $androidSdkPath "cmdline-tools\latest"

$sdkManager = Join-Path $cmdToolsDir "bin\sdkmanager.bat"
if (-not (Test-Path $sdkManager -PathType Leaf)) {
    if (Test-Path $cmdToolsDir) { throw "已有 $cmdToolsDir 但缺少 sdkmanager.bat；请检查该目录后重试。" }
    $toolsStage = Join-Path (Split-Path $cmdToolsDir -Parent) ("setup-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $toolsStage | Out-Null
    try {
        $cmdToolsUrl = "https://dl.google.com/android/repository/commandlinetools-win-${cmdToolsBuild}_latest.zip"
        $cmdToolsZip = Join-Path $toolsStage "tools.zip"
        Invoke-WebRequest -Uri $cmdToolsUrl -OutFile $cmdToolsZip -UseBasicParsing
        # 校验：清单里的 checksum 类型为 sha1
        $actualSha1 = Get-FileSha $cmdToolsZip "SHA1"
        if ($actualSha1 -ne $cmdToolsSha1) { throw "cmdline-tools 摘要与官方清单不符（实际 $actualSha1）。" }
        Write-Host "cmdline-tools SHA1 校验通过" -ForegroundColor Green
        Expand-Zip $cmdToolsZip $toolsStage
        $unpacked = Join-Path $toolsStage "cmdline-tools"
        if (-not (Test-Path (Join-Path $unpacked "bin\sdkmanager.bat"))) { throw "Android 工具包里缺少 sdkmanager.bat。" }
        [IO.Directory]::Move($unpacked, $cmdToolsDir)
    } finally {
        Remove-Tree $toolsStage
    }
}
Write-Host "检查 Android SDK 许可。"
if ($AcceptAndroidLicenses) {
    1..30 | ForEach-Object { "y" } | & $sdkManager "--sdk_root=$androidSdkPath" --licenses
} else {
    & $sdkManager "--sdk_root=$androidSdkPath" --licenses
}
if ($LASTEXITCODE -ne 0) { throw "Android SDK 许可处理失败。" }
& $sdkManager "--sdk_root=$androidSdkPath" "platform-tools" "platforms;$androidPlatform" "build-tools;$buildToolsVersion"
if ($LASTEXITCODE -ne 0) { throw "Android SDK 核心组件安装失败（$LASTEXITCODE）。" }
foreach ($required in @("platform-tools\adb.exe", "platforms\$androidPlatform\android.jar", "build-tools\$buildToolsVersion\aapt.exe")) {
    if (-not (Test-Path (Join-Path $androidSdkPath $required) -PathType Leaf)) { throw "缺少 Android SDK 文件：$required" }
}
# 许可是否真的落盘（sdkmanager 返回 0 不代表许可证文件已写入）
if (-not (Test-Path (Join-Path $androidSdkPath "licenses\android-sdk-license"))) {
    throw "未找到 licenses\android-sdk-license。请手动运行 sdkmanager --licenses 接受许可后重试。"
}
Write-Host "Android SDK 许可已落盘" -ForegroundColor Green


# --------------------------
# 步骤8：预置 Gradle 国内镜像（Agent 首次构建的关键加速）
# --------------------------
Write-Host "`n=== 8/10 配置 Gradle 国内镜像 ===" -ForegroundColor Cyan
$gradleDir = $gradleUserHome
$initFile = Join-Path $gradleDir "init.gradle"
if ((Test-Path $initFile) -or (Test-Path (Join-Path $gradleDir "init.gradle.kts"))) {
    Write-Host "已存在 Gradle 初始化文件，保留用户原有配置，跳过" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $gradleDir -Force | Out-Null
    $gradleInit = @'
// Aliyun mirrors for Flutter/Android builds (auto-generated by install script v1.5)
// 镜像仓库排在工程自己声明的 google() / mavenCentral() / gradlePluginPortal() 之前，优先从镜像取；
// 镜像上没有的组件会自动回退到工程原有的官方仓库。
def addAliyunMirrors = { repos ->
    repos.maven { name = 'aliyun-google';        url = 'https://maven.aliyun.com/repository/google' }        // 对应 google()
    repos.maven { name = 'aliyun-public';        url = 'https://maven.aliyun.com/repository/public' }        // 对应 mavenCentral()
    repos.maven { name = 'aliyun-gradle-plugin'; url = 'https://maven.aliyun.com/repository/gradle-plugin' } // 对应 gradlePluginPortal()
}
// AGP、Kotlin 插件是在 settings.gradle 的 plugins {} 里解析的，必须用 beforeSettings 才来得及。
// 实测：用 settingsEvaluated 时 375 个依赖文件全部仍走官方源（镜像 0 个），换成 beforeSettings 后生效。
beforeSettings { settings -> settings.pluginManagement.repositories(addAliyunMirrors) }
// 工程依赖只加给主构建。不能用 allprojects：那会把镜像仓库也塞进 Flutter 通过 includeBuild 引入的
// packages/flutter_tools/gradle 构建，该构建的 settings 锁定了仓库来源，会直接报
// "Build was configured to prefer settings repositories over project repositories" 并让插件解析失败
// （实测 allprojects 版本 3 秒就失败，beforeProject + 只判主构建后 2 分 16 秒构建成功）。
gradle.beforeProject { p ->
    if (p.gradle.parent == null) {
        p.buildscript.repositories(addAliyunMirrors)
        p.repositories(addAliyunMirrors)
    }
}
'@
    [System.IO.File]::WriteAllText($initFile, $gradleInit, [System.Text.UTF8Encoding]::new($false))
    Write-Host "已配置 Gradle 阿里云镜像：镜像排在官方仓库前，镜像没有的组件回退官方源" -ForegroundColor Green
}
# 第二段：Gradle 分发包（wrapper）镜像。
# 注意时机：init 脚本要等 Gradle 解压并启动后才执行，而 wrapper 下载发生在那之前，
#           所以「用 init 脚本改写 distributionUrl」对首次下载无效（2026-11-26 实测：
#           gradlew 直接去 services.gradle.org 取包并 404，init 脚本根本没运行）。
# 有效做法：直接改 Flutter 自带的工程模板，只影响之后新建的工程，不动已有项目。
$wrapperTmpl = Join-Path $flutterPath "packages\flutter_tools\templates\app\android.tmpl\gradle\wrapper\gradle-wrapper.properties.tmpl"
if (-not (Test-Path $wrapperTmpl -PathType Leaf)) {
    Write-Warning "未找到 Flutter 工程模板 $wrapperTmpl，跳过 wrapper 分发包镜像（不影响安装）。"
} else {
    $tmplText = [System.IO.File]::ReadAllText($wrapperTmpl)
    $official = "https\://services.gradle.org/distributions/"
    $mirrored = "https\://mirrors.huaweicloud.com/gradle/"
    if ($tmplText.Contains($official)) {
        # 先备份原模板，便于学员还原为官方地址
        $bak = "$wrapperTmpl.v14-official.bak"
        if (-not (Test-Path $bak)) { Copy-Item -LiteralPath $wrapperTmpl -Destination $bak }
        $newText = $tmplText.Replace($official, $mirrored)
        # 模板里的 Gradle 版本是占位符，只有当前 SDK 实际用课程固定版本时，才追加官方 SHA256（版本不同则校验值不同，不能硬写）
        $gradleUtils = Join-Path $flutterPath "packages\flutter_tools\lib\src\android\gradle_utils.dart"
        $sdkGradleVersion = $null
        if (Test-Path -LiteralPath $gradleUtils -PathType Leaf) {
            $gm = Select-String -LiteralPath $gradleUtils -Pattern "templateDefaultGradleVersion\s*=\s*'([^']+)'" | Select-Object -First 1
            if ($gm) { $sdkGradleVersion = $gm.Matches[0].Groups[1].Value }
        }
        if ($sdkGradleVersion -eq $gradleVersionPinned -and -not $newText.Contains("distributionSha256Sum")) {
            $newText = $newText.TrimEnd() + "`ndistributionSha256Sum=$gradleDistSha256`n"
            Write-Host "已给模板加上 Gradle 分发包 SHA256 校验（与官方值一致）" -ForegroundColor Green
        }
        [System.IO.File]::WriteAllText($wrapperTmpl, $newText, [System.Text.UTF8Encoding]::new($false))
        Write-Host "已把 Flutter 工程模板的 Gradle 分发包地址指向华为云同名 ZIP（仅影响之后新建的工程）" -ForegroundColor Green
        Write-Host "  如需还原为官方地址：把 $bak 覆盖回原文件即可" -ForegroundColor Gray
    } elseif ($tmplText.Contains($mirrored)) {
        Write-Host "Flutter 工程模板已指向华为云，跳过" -ForegroundColor Green
    } else {
        Write-Warning "模板里的 distributionUrl 不是预期格式，未改动：$wrapperTmpl"
    }
}

# --------------------------
# 步骤9：自动配置安卓模拟器（可选，无 IDE 也可用）
# --------------------------
Write-Host "`n=== 9/10 配置安卓模拟器 ===" -ForegroundColor Cyan
$emulatorReady = $false
if (-not $installEmulator) {
    Write-Host "已配置为跳过模拟器（如需启用，把脚本顶部 installEmulator 改为 true）" -ForegroundColor Yellow
} else {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    if ($cpu.VirtualizationFirmwareEnabled -eq $false) {
        Write-Host "检测到 BIOS 虚拟化（VT-x / AMD-V）未开启！" -ForegroundColor Red
        Write-Host "   模拟器将无法硬件加速。请重启进入 BIOS 开启虚拟化后重新运行本脚本" -ForegroundColor Yellow
    }

    foreach ($feat in @("HypervisorPlatform", "VirtualMachinePlatform")) {
        $f = Get-WindowsOptionalFeature -Online -FeatureName $feat
        if ($f.State -ne "Enabled") {
            Write-Host "正在启用 Windows 功能：$feat ..." -ForegroundColor Yellow
            $r = Enable-WindowsOptionalFeature -Online -FeatureName $feat -All -NoRestart
            if ($r.RestartNeeded) { $needReboot = $true }
        }
    }
    Write-Host "模拟器硬件加速（WHPX）已就绪（重启后生效）" -ForegroundColor Green

    $sysImg = "system-images;android-34;google_apis;x86_64"
    Write-Host "正在下载模拟器与系统镜像（约 2GB，需耐心等待）..." -ForegroundColor Yellow
    & $sdkManager "emulator" $sysImg --sdk_root=$androidSdkPath
    if ($LASTEXITCODE -eq 0) {
        Write-Host "模拟器与系统镜像安装完成" -ForegroundColor Green
    } else {
        throw "所选模拟器组件下载失败（$LASTEXITCODE）。"
    }

    $avdManager = Join-Path $cmdToolsDir "bin\avdmanager.bat"
    $avdDir = Join-Path $env:USERPROFILE ".android\avd"
    if (Test-Path (Join-Path $avdDir "$avdName.avd")) {
        Write-Host "模拟器 $avdName 已存在，跳过创建" -ForegroundColor Green
        $emulatorReady = $true
    } else {
        Write-Host "正在创建模拟器 $avdName ..." -ForegroundColor Yellow
        1..5 | ForEach-Object { "no" } | & $avdManager create avd -n $avdName -k $sysImg -d "pixel_6" --force
        if ($LASTEXITCODE -eq 0) {
            Write-Host "模拟器 $avdName 创建完成（命令行即可启动，无需 IDE）" -ForegroundColor Green
            $emulatorReady = $true
        } else {
            throw "创建所选模拟器失败（$LASTEXITCODE）。"
        }
    }
}

# --------------------------
# 步骤10：配置环境变量（用户级，无需管理员）
# --------------------------
Write-Host "`n=== 10/10 配置环境变量 ===" -ForegroundColor Cyan

$envScope = if (Test-IsAdmin -and $installEmulator) { "Machine" } else { "User" }
$userPath = if ($DryRun) { $env:Path } else { [Environment]::GetEnvironmentVariable("Path", $envScope) }
$newPath = $userPath
$flutterBin = Join-Path $flutterPath "bin"
$platformToolsPath = Join-Path $androidSdkPath "platform-tools"
$emulatorPath = Join-Path $androidSdkPath "emulator"

$pathsToAdd = @($flutterBin, $platformToolsPath)
if ($gitCmdDir) { $pathsToAdd = @($gitCmdDir) + $pathsToAdd }
if ($emulatorReady) { $pathsToAdd += $emulatorPath }
foreach ($p in $pathsToAdd) {
    $norm = $p.Trim().Trim('"').TrimEnd("\")
    $exists = $false
    foreach ($e in ($newPath -split ";")) {
        if ($e.Trim().Trim('"').TrimEnd("\") -ieq $norm) { $exists = $true; break }
    }
    if (-not $exists) { $newPath = "$newPath;$p" }
}
if ($DryRun) {
    Write-Host "自检模式：PATH 与其余环境变量只在本进程内生效，不写注册表、不广播。" -ForegroundColor Magenta
} elseif ($newPath -ne $userPath) {
    [Environment]::SetEnvironmentVariable("Path", $newPath, $envScope)
    Write-Host "已更新 $envScope 级 PATH（Flutter / platform-tools$(if ($gitCmdDir) { ' / Git' })$(if ($emulatorReady) { ' / emulator' })）" -ForegroundColor Green
} else {
    Write-Host "PATH 已包含所需路径，跳过" -ForegroundColor Green
}

if (-not $DryRun) {
    [Environment]::SetEnvironmentVariable("PUB_HOSTED_URL", $pubHostedUrl, $envScope)
    [Environment]::SetEnvironmentVariable("FLUTTER_STORAGE_BASE_URL", $flutterStorageUrl, $envScope)
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, $envScope)
    [Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $androidSdkPath, $envScope)
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaPath, $envScope)
    Write-Host "所有环境变量已写入 $envScope 级" -ForegroundColor Green
}

# 广播环境变量变更，让资源管理器等新启动的程序拿到新 PATH
if ($DryRun) {
    Write-Host "自检模式：跳过环境变量广播" -ForegroundColor Magenta
} else {
    try {
        Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        $r = [UIntPtr]::Zero
        [Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$r) | Out-Null
        Write-Host "已广播环境变量变更" -ForegroundColor Green
    } catch {
        Write-Warning "环境变量广播失败（不影响安装）：$($_.Exception.Message)"
    }
}

# 让当前脚本进程也拿到新值
if ($DryRun) {
    $env:Path = $newPath
} else {
    $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
if ($gitCmdDir) { $env:Path = "$gitCmdDir;" + $env:Path }
$env:JAVA_HOME = $javaPath
$env:ANDROID_HOME = $androidSdkPath
$env:ANDROID_SDK_ROOT = $androidSdkPath
$env:PUB_HOSTED_URL = $pubHostedUrl
$env:FLUTTER_STORAGE_BASE_URL = $flutterStorageUrl

# --------------------------
# 核实命令是否在新配置中工作，以及 doctor 是否认可安卓工具链。
git --version
if ($LASTEXITCODE -ne 0) { throw "Git 未能运行。" }
& (Join-Path $javaPath "bin\java.exe") -version
if ($LASTEXITCODE -ne 0) { throw "所选 JDK 未能运行。" }
& (Join-Path $platformToolsPath "adb.exe") version
if ($LASTEXITCODE -ne 0) { throw "ADB 未能运行。" }
& $flutterBat --version
if ($LASTEXITCODE -ne 0) { throw "Flutter 未能运行。" }
if ($javaPath) {
    # Flutter 选 JDK 的顺序是：jdk-dir 配置 > Android Studio 自带 JDK > JAVA_HOME。
    # 所以只写 JAVA_HOME 不够，必须显式指定，否则装了新版 Studio 的机器仍会用它自带的 JDK。
    & $flutterBat config --jdk-dir="$javaPath" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "flutter config --jdk-dir 设置失败。" }
    Write-Host "已指定 Flutter 使用 JDK：$javaPath" -ForegroundColor Green
}
$oldEncoding = [Console]::OutputEncoding
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $report = @(& $flutterBat doctor -v)
    $doctorExit = $LASTEXITCODE
} finally {
    [Console]::OutputEncoding = $oldEncoding
}
$report | ForEach-Object { Write-Host $_ }
$plain = ($report -join [Environment]::NewLine) -replace '\x1b\[[0-9;]*m', ''
# 只看 Android toolchain 这一项：没装 Android Studio、没连手机、没配模拟器时 doctor 也会返回非零，
# 那些不影响命令行开发，用退出码判断会把正常机器误判成失败。
if ($plain -notmatch '(?im)^\s*\[(?:✓|√|v)\]\s+Android toolchain\b') {
    if ($doctorExit -ne 0) { Write-Warning "flutter doctor 退出码 $doctorExit。" }
    throw "Flutter doctor 未确认 Android toolchain 通过。请让豆包看上面这段输出，修复后再检查。"
}
if ($doctorExit -ne 0) {
    Write-Warning "flutter doctor 退出码为 $doctorExit：其余项目（如未装 Android Studio、未连接手机）不影响命令行开发，可忽略。"
}
Write-Host "安卓环境检查通过。" -ForegroundColor Green

# --------------------------
# 可选：真实构建验证。doctor 查不出 Gradle 阶段的问题，这里实跑一次。
# --------------------------
if ($doVerifyBuild) {
    # flutter / Gradle 会往 stderr 写普通警告；5.1 下若保持 Stop，这些警告会中断脚本，成败只看退出码
    $ErrorActionPreference = 'Continue'
    Write-Host "`n=== 附加：真实构建验证（首次约 5 分钟） ===" -ForegroundColor Cyan
    $verifyRoot = Join-Path $env:TEMP ("flutter-verify-" + [Guid]::NewGuid())
    try {
        New-Item -ItemType Directory -Path $verifyRoot | Out-Null
        Push-Location $verifyRoot
        try {
            & $flutterBat create --platforms=android verify_app 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) { throw "临时工程创建失败。" }
            Push-Location (Join-Path $verifyRoot "verify_app")
            try {
                & $flutterBat build apk --debug 2>&1 | ForEach-Object { Write-Host $_ }
                if ($LASTEXITCODE -ne 0) { throw "真实构建失败。常见原因：JAVA_HOME 未生效、Gradle 里找不到 git、依赖下载超时。请把上面输出发给豆包。" }
                $apk = Join-Path $verifyRoot "verify_app\build\app\outputs\flutter-apk\app-debug.apk"
                if (-not (Test-Path $apk)) { throw "构建结束但未找到 APK。" }
                Write-Host "真实构建验证通过：$apk" -ForegroundColor Green
            } finally { Pop-Location }
        } finally { Pop-Location }
    } finally {
        Remove-Tree $verifyRoot
    }
}

Write-Host "重新打开终端（Windows Terminal 请完全退出后重开，不要只开新标签页）；用手册 C、D 连接手机并运行计数器。"
if ($DryRun) { Write-Host "自检模式结束：以上均装在 $dryRoot 内，可直接删除该目录。" -ForegroundColor Magenta }
if ($needReboot) { Write-Host "本次更改了 Windows 虚拟化功能，使用模拟器前请重启。" }
Stop-Script 0
