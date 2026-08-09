param(
    [string]$Version = "0.0.0"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

if ($Version -cnotmatch "^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$") {
    throw "Windows 版本号必须使用无前导零的 X.Y.Z 格式。"
}

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$WindowsRoot = Join-Path $RepositoryRoot "platform/windows"
$Solution = Join-Path $WindowsRoot "MihomoMeter.Windows.slnx"
$AppProject = Join-Path $WindowsRoot "MihomoMeter.Windows.App/MihomoMeter.Windows.App.csproj"
$TestProject = Join-Path $WindowsRoot "MihomoMeter.Windows.Tests/MihomoMeter.Windows.Tests.csproj"
$OutputDirectory = Join-Path $RepositoryRoot ".codex-tmp/windows-publish"
$PackageDirectory = Join-Path $RepositoryRoot ".codex-tmp/windows-package"

python (Join-Path $PSScriptRoot "validate_windows.py")
if ($LASTEXITCODE -ne 0) {
    throw "Windows 静态契约检查失败。"
}

if (Test-Path -LiteralPath $OutputDirectory) {
    Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
}

Push-Location $WindowsRoot
try {
    dotnet restore $Solution
    if ($LASTEXITCODE -ne 0) {
        throw "Windows solution 还原失败。"
    }

    dotnet test $TestProject `
        --configuration Release `
        --no-restore
    if ($LASTEXITCODE -ne 0) {
        throw "Windows Core 单元测试失败。"
    }

    dotnet build $AppProject `
        --configuration Release `
        --no-restore `
        -p:Platform=x64 `
        "-p:Version=$Version" `
        "-p:FileVersion=${Version}.0" `
        "-p:AssemblyVersion=${Version}.0"
    if ($LASTEXITCODE -ne 0) {
        throw "Windows App Release 构建失败。"
    }

    dotnet publish $AppProject `
        --configuration Release `
        --runtime win-x64 `
        --self-contained true `
        --no-restore `
        --output $OutputDirectory `
        -p:Platform=x64 `
        "-p:Version=$Version" `
        "-p:FileVersion=${Version}.0" `
        "-p:AssemblyVersion=${Version}.0"
    if ($LASTEXITCODE -ne 0) {
        throw "Windows App 自包含发布失败。"
    }
}
finally {
    Pop-Location
}

$RequiredFiles = @(
    "MihomoMeter.Windows.App.exe"
)
foreach ($RelativePath in $RequiredFiles) {
    $Path = Join-Path $OutputDirectory $RelativePath
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Windows 发布目录缺少 $RelativePath"
    }
}

$PriFiles = @(Get-ChildItem -LiteralPath $OutputDirectory -File -Filter "*.pri")
if ($PriFiles.Count -eq 0) {
    throw "Windows 发布目录缺少 WinUI 应用 PRI。"
}

$PackagedArtifacts = @(
    Get-ChildItem -LiteralPath $OutputDirectory -File |
        Where-Object { $_.Extension -in @(".msix", ".msixbundle", ".appx") }
)
if ($PackagedArtifacts.Count -ne 0) {
    throw "Windows 发布目录不得包含 MSIX 或 APPX 产物。"
}

if (Test-Path -LiteralPath (Join-Path $OutputDirectory "run-w0-gate.cmd")) {
    throw "Windows 当前阶段发布目录不得包含历史 run-w0-gate.cmd。"
}

$BundledSqliteFiles = @(
    Get-ChildItem -LiteralPath $OutputDirectory -File |
        Where-Object { $_.Name -like "e_sqlite3*" }
)
if ($BundledSqliteFiles.Count -ne 0) {
    throw "Windows 当前阶段必须复用系统 winsqlite3.dll，不得携带 e_sqlite3。"
}

& (Join-Path $PSScriptRoot "package_windows.ps1") `
    -Version $Version `
    -PublishDirectory $OutputDirectory `
    -OutputDirectory $PackageDirectory

Write-Host "Windows 单元测试、Release 构建、自包含发布与 W3-0 打包检查通过。"
