$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepositoryRoot = Split-Path -Parent $PSScriptRoot
$WindowsRoot = Join-Path $RepositoryRoot "platform/windows"
$Project = Join-Path $RepositoryRoot "platform/windows/MihomoMeter.Windows.App/MihomoMeter.Windows.App.csproj"
$OutputDirectory = Join-Path $RepositoryRoot ".codex-tmp/windows-w0-publish"

python (Join-Path $PSScriptRoot "validate_windows_w0.py")
if ($LASTEXITCODE -ne 0) {
    throw "Windows W0 静态契约检查失败。"
}

if (Test-Path -LiteralPath $OutputDirectory) {
    Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
}

Push-Location $WindowsRoot
try {
    dotnet restore $Project -p:Platform=x64
    if ($LASTEXITCODE -ne 0) {
        throw "Windows W0 NuGet 还原失败。"
    }

    dotnet build $Project `
        --configuration Release `
        --no-restore `
        -p:Platform=x64
    if ($LASTEXITCODE -ne 0) {
        throw "Windows W0 Release 构建失败。"
    }

    dotnet publish $Project `
        --configuration Release `
        --runtime win-x64 `
        --self-contained true `
        --no-restore `
        --output $OutputDirectory `
        -p:Platform=x64
    if ($LASTEXITCODE -ne 0) {
        throw "Windows W0 自包含发布失败。"
    }
}
finally {
    Pop-Location
}

$RequiredFiles = @(
    "MihomoMeter.Windows.App.exe",
    "run-w0-gate.cmd"
)
foreach ($RelativePath in $RequiredFiles) {
    $Path = Join-Path $OutputDirectory $RelativePath
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Windows W0 发布目录缺少 $RelativePath"
    }
}

$PriFiles = @(Get-ChildItem -LiteralPath $OutputDirectory -File -Filter "*.pri")
if ($PriFiles.Count -eq 0) {
    throw "Windows W0 发布目录缺少 WinUI 应用 PRI。"
}

$PackagedArtifacts = @(
    Get-ChildItem -LiteralPath $OutputDirectory -File |
        Where-Object { $_.Extension -in @(".msix", ".msixbundle", ".appx") }
)
if ($PackagedArtifacts.Count -ne 0) {
    throw "Windows W0 发布目录不得包含 MSIX 或 APPX 产物。"
}

Write-Host "Windows W0 Release 构建与自包含发布检查通过。"
