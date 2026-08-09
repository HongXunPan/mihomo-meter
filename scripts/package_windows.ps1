[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [string]$PublishDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [string]$MakeNsisPath = "makensis.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ($Version -cnotmatch "^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$") {
    throw "Windows 版本号必须使用无前导零的 X.Y.Z 格式。"
}

$PublishDirectory = [System.IO.Path]::GetFullPath($PublishDirectory)
$OutputDirectory = [System.IO.Path]::GetFullPath($OutputDirectory)
$DirectoryComparison = [System.StringComparison]::OrdinalIgnoreCase
$TrimCharacters = [char[]]@(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar)
$PublishPrefix = $PublishDirectory.TrimEnd($TrimCharacters) +
    [System.IO.Path]::DirectorySeparatorChar

if (-not (Test-Path -LiteralPath $PublishDirectory -PathType Container)) {
    throw "Windows 发布目录不存在：$PublishDirectory"
}
if ($OutputDirectory.Equals($PublishDirectory, $DirectoryComparison) -or
    $OutputDirectory.StartsWith($PublishPrefix, $DirectoryComparison)) {
    throw "Windows 打包输出目录不得等于或位于发布目录内部。"
}

$ExecutablePath = Join-Path $PublishDirectory "MihomoMeter.Windows.App.exe"
if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
    throw "Windows 发布目录缺少 MihomoMeter.Windows.App.exe。"
}

$PriFiles = @(Get-ChildItem -LiteralPath $PublishDirectory -File -Filter "*.pri")
if ($PriFiles.Count -eq 0) {
    throw "Windows 发布目录缺少 WinUI 应用 PRI。"
}

$ExpectedFileVersion = "${Version}.0"
$ActualFileVersion = [System.Diagnostics.FileVersionInfo]::GetVersionInfo(
    $ExecutablePath).FileVersion
if ($ActualFileVersion -ne $ExpectedFileVersion) {
    throw "Windows 可执行文件版本 $ActualFileVersion 与打包版本 $ExpectedFileVersion 不一致。"
}

$ForbiddenNames = @(
    "settings.json",
    "traffic.sqlite3",
    "quota.sqlite3",
    "connection-analytics.sqlite3",
    "profiles.yaml",
    "profiles.yml"
)
$ForbiddenExtensions = @(
    ".appx",
    ".dmp",
    ".key",
    ".log",
    ".msix",
    ".msixbundle",
    ".p12",
    ".pem",
    ".pfx",
    ".snk"
)
$PublishFiles = @(
    Get-ChildItem -LiteralPath $PublishDirectory -File -Recurse |
        Sort-Object FullName
)
$ForbiddenFiles = @(
    $PublishFiles | Where-Object {
        $_.Name -in $ForbiddenNames -or
        $_.Extension.ToLowerInvariant() -in $ForbiddenExtensions
    }
)
if ($ForbiddenFiles.Count -ne 0) {
    $ForbiddenList = ($ForbiddenFiles.FullName -join ", ")
    throw "Windows 发布目录包含禁止打包的文件：$ForbiddenList"
}

$PackageFiles = @(
    $PublishFiles | Where-Object { $_.Extension.ToLowerInvariant() -ne ".pdb" }
)
if ($PackageFiles.Count -eq 0) {
    throw "Windows 发布目录没有可打包文件。"
}

$PayloadDirectory = Join-Path (
    Split-Path -Parent $OutputDirectory) "windows-package-payload"
$PayloadDirectory = [System.IO.Path]::GetFullPath($PayloadDirectory)
if ($PayloadDirectory.Equals($PublishDirectory, $DirectoryComparison) -or
    $PayloadDirectory.StartsWith($PublishPrefix, $DirectoryComparison) -or
    $PayloadDirectory.Equals($OutputDirectory, $DirectoryComparison)) {
    throw "Windows 安装器载荷目录必须与发布目录和输出目录隔离。"
}

if (Test-Path -LiteralPath $OutputDirectory) {
    Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
}
if (Test-Path -LiteralPath $PayloadDirectory) {
    Remove-Item -LiteralPath $PayloadDirectory -Recurse -Force
}
New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
New-Item -ItemType Directory -Path $PayloadDirectory | Out-Null

try {
    foreach ($File in $PackageFiles) {
        $RelativePath = [System.IO.Path]::GetRelativePath(
            $PublishDirectory,
            $File.FullName)
        $DestinationPath = Join-Path $PayloadDirectory $RelativePath
        $DestinationDirectory = Split-Path -Parent $DestinationPath
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
        [System.IO.File]::Copy($File.FullName, $DestinationPath, $true)
    }

    $PayloadFiles = @(
        Get-ChildItem -LiteralPath $PayloadDirectory -File -Recurse |
            Sort-Object FullName
    )
    if ($PayloadFiles.Count -ne $PackageFiles.Count) {
        throw "Windows 统一打包载荷与已验证发布文件数量不一致。"
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    $ArchiveName = "Mihomo-Meter-$Version-windows-x64-portable.zip"
    $ArchivePath = Join-Path $OutputDirectory $ArchiveName
    $Archive = [System.IO.Compression.ZipFile]::Open(
        $ArchivePath,
        [System.IO.Compression.ZipArchiveMode]::Create)
    $FixedTimestamp = [System.DateTimeOffset]::Parse("1980-01-01T00:00:00Z")
    try {
        foreach ($File in $PayloadFiles) {
            $RelativePath = [System.IO.Path]::GetRelativePath(
                $PayloadDirectory,
                $File.FullName).Replace("\", "/")
            $EntryName = "Mihomo Meter/$RelativePath"
            $Entry = $Archive.CreateEntry(
                $EntryName,
                [System.IO.Compression.CompressionLevel]::Optimal)
            $Entry.LastWriteTime = $FixedTimestamp
            $SourceStream = $File.OpenRead()
            $DestinationStream = $Entry.Open()
            try {
                $SourceStream.CopyTo($DestinationStream)
            }
            finally {
                $DestinationStream.Dispose()
                $SourceStream.Dispose()
            }
        }
    }
    finally {
        $Archive.Dispose()
    }

    $ArchiveRead = [System.IO.Compression.ZipFile]::OpenRead($ArchivePath)
    try {
        $EntryNames = @($ArchiveRead.Entries | ForEach-Object { $_.FullName })
        if ($EntryNames -notcontains "Mihomo Meter/MihomoMeter.Windows.App.exe") {
            throw "Windows 便携 ZIP 缺少应用可执行文件。"
        }
        if (@($EntryNames | Where-Object { $_ -like "Mihomo Meter/*.pri" }).Count -eq 0) {
            throw "Windows 便携 ZIP 缺少 WinUI 应用 PRI。"
        }
        if (@($EntryNames | Where-Object {
                    $_.ToLowerInvariant().EndsWith(".pdb")
                }).Count -ne 0) {
            throw "Windows 便携 ZIP 不得包含 PDB。"
        }
    }
    finally {
        $ArchiveRead.Dispose()
    }

    $InstallerName = "Mihomo-Meter-$Version-windows-x64-setup.exe"
    $InstallerPath = Join-Path $OutputDirectory $InstallerName
    & (Join-Path $PSScriptRoot "build_windows_installer.ps1") `
        -Version $Version `
        -PayloadDirectory $PayloadDirectory `
        -OutputPath $InstallerPath `
        -MakeNsisPath $MakeNsisPath

    $Assets = @(
        Get-Item -LiteralPath $ArchivePath
        Get-Item -LiteralPath $InstallerPath
    ) | Sort-Object Name
    $ChecksumLines = @(
        foreach ($Asset in $Assets) {
            $HashResult = Get-FileHash -LiteralPath $Asset.FullName -Algorithm SHA256
            $Hash = $HashResult.Hash.ToLowerInvariant()
            "$Hash  $($Asset.Name)"
        }
    )
    $ChecksumPath = Join-Path $OutputDirectory "SHA256SUMS"
    $ChecksumContent = ($ChecksumLines -join "`n") + "`n"
    [System.IO.File]::WriteAllText(
        $ChecksumPath,
        $ChecksumContent,
        [System.Text.UTF8Encoding]::new($false))

    $ExpectedOutputNames = @($ArchiveName, $InstallerName, "SHA256SUMS") | Sort-Object
    $ActualOutputNames = @(
        Get-ChildItem -LiteralPath $OutputDirectory -File |
            Select-Object -ExpandProperty Name |
            Sort-Object
    )
    if (($ActualOutputNames -join "`n") -cne ($ExpectedOutputNames -join "`n")) {
        throw "Windows W3-1 输出目录必须且只能包含 ZIP、安装器和 SHA256SUMS。"
    }
}
finally {
    if (Test-Path -LiteralPath $PayloadDirectory) {
        Remove-Item -LiteralPath $PayloadDirectory -Recurse -Force
    }
}

Write-Host "Windows W3-1 便携 ZIP、NSIS 安装器与 SHA256SUMS 已生成：$OutputDirectory"
