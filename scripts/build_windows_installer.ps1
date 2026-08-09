[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$PayloadDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$MakeNsisPath = "makensis.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Version -cnotmatch "^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$") {
    throw "Windows 版本号必须使用无前导零的 X.Y.Z 格式。"
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$InstallerScript = Join-Path $RepositoryRoot "platform/windows/installer/MihomoMeter.nsi"
$InstallerSourceFiles = @(
    $InstallerScript
    (Join-Path $RepositoryRoot "platform/windows/installer/MihomoMeter.InstallDirectory.nsh")
)
$PayloadDirectory = [System.IO.Path]::GetFullPath($PayloadDirectory)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

function Assert-Utf8BomSource {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "缺少 Windows NSIS 安装器源文件：$Path"
    }

    $Bytes = [System.IO.File]::ReadAllBytes($Path)
    if ($Bytes.Length -lt 3 -or
        $Bytes[0] -ne 0xEF -or
        $Bytes[1] -ne 0xBB -or
        $Bytes[2] -ne 0xBF) {
        throw "Windows NSIS 安装器源文件必须使用带 BOM 的 UTF-8：$Path"
    }

    try {
        $StrictUtf8 = [System.Text.UTF8Encoding]::new($true, $true)
        $Content = $StrictUtf8.GetString($Bytes)
    }
    catch {
        throw "Windows NSIS 安装器源文件包含无效 UTF-8：$Path"
    }

    foreach ($Character in $Content.ToCharArray()) {
        $CodePoint = [int]$Character
        if (($CodePoint -ge 0x0080 -and $CodePoint -le 0x009F) -or
            ($CodePoint -ge 0x00C0 -and $CodePoint -le 0x024F) -or
            $CodePoint -eq 0xFFFD) {
            throw "Windows NSIS 安装器源文件疑似包含乱码字符：$Path"
        }
    }
}

foreach ($InstallerSourceFile in $InstallerSourceFiles) {
    Assert-Utf8BomSource -Path $InstallerSourceFile
}
if (-not (Test-Path -LiteralPath $PayloadDirectory -PathType Container)) {
    throw "Windows 安装器载荷目录不存在：$PayloadDirectory"
}
if (-not (Test-Path -LiteralPath (
        Join-Path $PayloadDirectory "MihomoMeter.Windows.App.exe") -PathType Leaf)) {
    throw "Windows 安装器载荷缺少 MihomoMeter.Windows.App.exe。"
}
if ([System.IO.Path]::GetExtension($OutputPath) -cne ".exe") {
    throw "Windows 安装器输出必须使用 .exe 扩展名。"
}

$Compiler = Get-Command $MakeNsisPath -CommandType Application -ErrorAction Stop
$OutputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Force
}

$CompilerArguments = @(
    "/V2",
    "/INPUTCHARSET",
    "UTF8",
    "/DAPP_VERSION=$Version",
    "/DPAYLOAD_DIRECTORY=$PayloadDirectory",
    "/DOUTPUT_FILE=$OutputPath",
    $InstallerScript
)
& $Compiler.Source @CompilerArguments
if ($LASTEXITCODE -ne 0) {
    throw "Windows NSIS 安装器编译失败，退出码：$LASTEXITCODE"
}
if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw "Windows NSIS 编译完成后没有生成安装器。"
}

$ExpectedFileVersion = "${Version}.0"
$InstallerVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($OutputPath)
if ($InstallerVersion.FileVersion -ne $ExpectedFileVersion) {
    throw "Windows 安装器文件版本 $($InstallerVersion.FileVersion) 与 $ExpectedFileVersion 不一致。"
}
if ($InstallerVersion.ProductVersion -ne $Version) {
    throw "Windows 安装器产品版本 $($InstallerVersion.ProductVersion) 与 $Version 不一致。"
}

Write-Host "Windows NSIS 安装器已生成：$OutputPath"
