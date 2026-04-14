param(
    [string]$PluginRoot = 'F:\package_flutter\ohos_http\ohos',
    [string]$BuildLibRoot,
    [string]$CmakeObjRoot,
    [string]$EntryLibRoot,
    [string]$OhpmRoot,
    [string[]]$Architectures = @('arm64-v8a')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($BuildLibRoot)) {
    $BuildLibRoot = Join-Path $repoRoot 'ohos\entry\build\default\intermediates\libs\default'
}
if ([string]::IsNullOrWhiteSpace($CmakeObjRoot)) {
    $CmakeObjRoot = Join-Path $repoRoot 'ohos\entry\build\default\intermediates\cmake\default\obj'
}
if ([string]::IsNullOrWhiteSpace($EntryLibRoot)) {
    $EntryLibRoot = Join-Path $repoRoot 'ohos\entry\libs'
}
if ([string]::IsNullOrWhiteSpace($OhpmRoot)) {
    $OhpmRoot = Join-Path $repoRoot 'ohos\oh_modules\.ohpm'
}

$runtimeLibraries = @(
    'libohos_http_ffi.so',
    'libc++_shared.so',
    'libcurl.so',
    'libcurl.so.4',
    'libcurl.so.4.8.0',
    'libnghttp2.so.14',
    'libnghttp2.so.14.28.4',
    'libz.so',
    'libz.so.1',
    'libz.so.1.3.1',
    'libzstd.so.1',
    'libzstd.so.1.5.6'
)

function Remove-RuntimeClosure {
    param(
        [string]$Directory
    )

    if (-not (Test-Path $Directory)) {
        return
    }

    foreach ($library in $runtimeLibraries) {
        $candidate = Join-Path $Directory $library
        if (Test-Path $candidate) {
            Remove-Item -Path $candidate -Force
        }
    }
}

function Copy-RuntimeClosure {
    param(
        [string[]]$SourceDirs,
        [string]$DestinationDir
    )

    if (-not (Test-Path $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    foreach ($library in $runtimeLibraries) {
        $sourceFile = $null
        foreach ($sourceDir in $SourceDirs) {
            if ([string]::IsNullOrWhiteSpace($sourceDir)) {
                continue
            }

            $candidate = Join-Path $sourceDir $library
            if (Test-Path $candidate) {
                $sourceFile = $candidate
                break
            }
        }

        if ($null -eq $sourceFile) {
            $sourcesText = ($SourceDirs -join ', ')
            throw "Required runtime library not found in any source directory: $library | sources=$sourcesText"
        }

        $destinationFile = Join-Path $DestinationDir $library
        $sourcePath = [System.IO.Path]::GetFullPath($sourceFile)
        $destinationPath = [System.IO.Path]::GetFullPath($destinationFile)
        if ($sourcePath.Equals($destinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        Copy-Item -Path $sourceFile -Destination $destinationFile -Force
    }
}

$ohpmPackageRoots = @()
if (Test-Path $OhpmRoot) {
    $ohpmPackageRoots = @(Get-ChildItem -Path $OhpmRoot -Directory -Filter 'ohos_http@*=*' |
        ForEach-Object { Join-Path $_.FullName 'oh_modules\ohos_http' } |
        Where-Object { Test-Path $_ })
}

foreach ($arch in $Architectures) {
    $pluginDestinationDir = Join-Path (Join-Path $PluginRoot 'libs') $arch
    $sourceDirs = @(
        (Join-Path $BuildLibRoot $arch),
        (Join-Path $CmakeObjRoot $arch),
        (Join-Path $EntryLibRoot $arch),
        $pluginDestinationDir
    ) | Where-Object { Test-Path $_ }

    if ($sourceDirs.Count -eq 0) {
        throw "No runtime library source directories found for architecture $arch"
    }

    Copy-RuntimeClosure -SourceDirs $sourceDirs -DestinationDir $pluginDestinationDir

    foreach ($ohpmPackageRoot in $ohpmPackageRoots) {
        $ohpmDestinationDir = Join-Path (Join-Path $ohpmPackageRoot 'libs') $arch
        $ohpmSourceDirs = @($sourceDirs + $pluginDestinationDir) | Select-Object -Unique
        Copy-RuntimeClosure -SourceDirs $ohpmSourceDirs -DestinationDir $ohpmDestinationDir
    }

    Remove-RuntimeClosure -Directory (Join-Path $EntryLibRoot $arch)
}

Write-Host "Staged ohos_http plugin runtime libraries into $(Join-Path $PluginRoot 'libs')"
if ($ohpmPackageRoots.Count -gt 0) {
    Write-Host "Mirrored ohos_http runtime libraries into generated OHPM packages under $OhpmRoot"
}
Write-Host "Removed duplicate curl runtime libraries from $EntryLibRoot"