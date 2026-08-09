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
$PayloadDirectory = [System.IO.Path]::GetFullPath($PayloadDirectory)
$OutputPath = [System.IO.Path]::GetFullPath($OutputPath)

if (-not (Test-Path -LiteralPath $InstallerScript -PathType Leaf)) {
    throw "缺少 Windows NSIS 安装器脚本：$InstallerScript"
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
