[CmdletBinding()]
param(
    [switch]$RunTests
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$ExpectedRustVersion = "1.97.1"
$RustTarget = "x86_64-pc-windows-msvc"
$RustToolchain = $null

if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    throw "未找到 rustup，无法构建共享核心。"
}

foreach ($Candidate in @($ExpectedRustVersion, "stable")) {
    $Version = & rustup run $Candidate rustc --version 2>$null
    if ($LASTEXITCODE -eq 0 -and $Version -like "rustc $ExpectedRustVersion *") {
        $RustToolchain = $Candidate
        break
    }
}
if ($null -eq $RustToolchain) {
    throw "未找到完整的 Rust $ExpectedRustVersion 工具链。"
}

$RustCompilerPath = & rustup which rustc --toolchain $RustToolchain
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $RustCompilerPath -PathType Leaf)) {
    throw "无法定位 Rust $ExpectedRustVersion 编译器。"
}
$RustBinDirectory = Split-Path -Parent $RustCompilerPath
$env:PATH = "$RustBinDirectory$([System.IO.Path]::PathSeparator)$env:PATH"

$InstalledTargets = @(& rustup target list --toolchain $RustToolchain --installed)
if ($LASTEXITCODE -ne 0 -or $RustTarget -notin $InstalledTargets) {
    throw "Rust $ExpectedRustVersion 未安装目标 $RustTarget。"
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$ManifestPath = Join-Path $RepositoryRoot "SharedCore/Cargo.toml"
$env:CARGO_TARGET_DIR = Join-Path $RepositoryRoot ".build/shared-core"

if ($RunTests) {
    & rustup run $RustToolchain cargo test `
        --manifest-path $ManifestPath `
        --locked `
        --target $RustTarget
    if ($LASTEXITCODE -ne 0) {
        throw "共享核心 Rust 单元测试失败。"
    }
}

& rustup run $RustToolchain cargo build `
    --manifest-path $ManifestPath `
    --locked `
    --release `
    --target $RustTarget
if ($LASTEXITCODE -ne 0) {
    throw "Windows 共享核心构建失败。"
}

$LibraryPath = Join-Path $env:CARGO_TARGET_DIR `
    "$RustTarget/release/mihomo_meter_shared_core.dll"
if (-not (Test-Path -LiteralPath $LibraryPath -PathType Leaf)) {
    throw "Windows 共享核心 DLL 不存在：$LibraryPath"
}

Write-Host "Windows 共享核心构建通过：$LibraryPath"
