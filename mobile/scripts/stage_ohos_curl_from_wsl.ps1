param(
    [string]$LyciumRoot = '/home/dgh18/work/tpc_c_cplusplus/lycium',
    [string[]]$Architectures = @('arm64-v8a', 'armeabi-v7a'),
    [string]$PluginRoot = 'F:\package_flutter\ohos_http\ohos',
    [string]$OhpmRoot,
    [switch]$SkipNativeCacheReset
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$entryLibsRoot = Join-Path $repoRoot 'ohos\entry\libs'
$curlHeadersRoot = Join-Path $repoRoot 'ohos\entry\src\main\cpp\thirdparty\curl'
if ([string]::IsNullOrWhiteSpace($OhpmRoot)) {
    $OhpmRoot = Join-Path $repoRoot 'ohos\oh_modules\.ohpm'
}

$wslDistroName = (& wsl.exe sh -lc 'printf %s "$WSL_DISTRO_NAME"' | Select-Object -Last 1).Trim()
if ([string]::IsNullOrWhiteSpace($wslDistroName)) {
    throw 'Unable to determine the active WSL distribution name.'
}

$libraries = @(
    [pscustomobject]@{
        Package = 'curl'
        VersionedName = 'libcurl.so.4.8.0'
        OutputNames = @('libcurl.so', 'libcurl.so.4', 'libcurl.so.4.8.0')
    },
    [pscustomobject]@{
        Package = 'nghttp2'
        VersionedName = 'libnghttp2.so.14.28.4'
        OutputNames = @('libnghttp2.so.14', 'libnghttp2.so.14.28.4')
    },
    [pscustomobject]@{
        Package = 'zstd_1_5_6'
        VersionedName = 'libzstd.so.1.5.6'
        OutputNames = @('libzstd.so.1', 'libzstd.so.1.5.6')
    },
    [pscustomobject]@{
        Package = 'zlib_1_3_1'
        VersionedName = 'libz.so.1.3.1'
        OutputNames = @('libz.so', 'libz.so.1', 'libz.so.1.3.1')
    }
)

function Test-WslPath {
    param([string]$LinuxPath)

    & wsl.exe sh -lc 'test -e "$1"' sh $LinuxPath
    return $LASTEXITCODE -eq 0
}

function Get-WslWindowsPath {
    param([string]$LinuxPath)

    $windowsPathSuffix = $LinuxPath -replace '/', '\\'
    return "\\wsl.localhost\$wslDistroName$windowsPathSuffix"
}

function Copy-WslFile {
    param(
        [string]$LinuxSource,
        [string]$WindowsDestination
    )

    if (-not (Test-WslPath -LinuxPath $LinuxSource)) {
        throw "WSL source file not found: $LinuxSource"
    }

    $windowsSource = Get-WslWindowsPath -LinuxPath $LinuxSource
    $destinationDir = Split-Path -Parent $WindowsDestination
    New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    Copy-Item -Path $windowsSource -Destination $WindowsDestination -Force
}

function Copy-WslDirectory {
    param(
        [string]$LinuxSource,
        [string]$WindowsDestination
    )

    if (-not (Test-WslPath -LinuxPath $LinuxSource)) {
        throw "WSL source directory not found: $LinuxSource"
    }

    $windowsSource = Get-WslWindowsPath -LinuxPath $LinuxSource
    if (Test-Path $WindowsDestination) {
        Remove-Item -Path $WindowsDestination -Recurse -Force
    }
    New-Item -ItemType Directory -Path $WindowsDestination -Force | Out-Null
    Copy-Item -Path (Join-Path $windowsSource '*') -Destination $WindowsDestination -Recurse -Force
}

function Reset-NativeBuildState {
    $generatedPaths = @(
        (Join-Path $repoRoot 'ohos\entry\.cxx'),
        (Join-Path $repoRoot 'ohos\entry\build\default\intermediates\cmake')
    )

    foreach ($generatedPath in $generatedPaths) {
        if (Test-Path $generatedPath) {
            Remove-Item -Path $generatedPath -Recurse -Force
        }
    }
}

function Remove-RuntimeClosure {
    param(
        [string]$Directory,
        [object[]]$Libraries
    )

    if (-not (Test-Path $Directory)) {
        return
    }

    foreach ($library in $Libraries) {
        foreach ($outputName in $library.OutputNames) {
            $candidate = Join-Path $Directory $outputName
            if (Test-Path $candidate) {
                Remove-Item -Path $candidate -Force
            }
        }
    }
}

$ohpmPackageRoots = @()
if (Test-Path $OhpmRoot) {
    $ohpmPackageRoots = @(Get-ChildItem -Path $OhpmRoot -Directory -Filter 'ohos_http@*=*' |
        ForEach-Object { Join-Path $_.FullName 'oh_modules\ohos_http' } |
        Where-Object { Test-Path $_ })
}

foreach ($arch in $Architectures) {
    $headerSource = "$LyciumRoot/usr/curl/$arch/include"
    $headerDestination = Join-Path $curlHeadersRoot "$arch\include"
    Copy-WslDirectory -LinuxSource $headerSource -WindowsDestination $headerDestination

    $pluginLibRoot = Join-Path (Join-Path $PluginRoot 'libs') $arch
    New-Item -ItemType Directory -Path $pluginLibRoot -Force | Out-Null

    foreach ($library in $libraries) {
        $versionedSource = "$LyciumRoot/usr/$($library.Package)/$arch/lib/$($library.VersionedName)"
        foreach ($outputName in $library.OutputNames) {
            $outputPath = Join-Path $pluginLibRoot $outputName
            Copy-WslFile -LinuxSource $versionedSource -WindowsDestination $outputPath

            foreach ($ohpmPackageRoot in $ohpmPackageRoots) {
                $ohpmArchLibRoot = Join-Path (Join-Path $ohpmPackageRoot 'libs') $arch
                $ohpmOutputPath = Join-Path $ohpmArchLibRoot $outputName
                Copy-WslFile -LinuxSource $versionedSource -WindowsDestination $ohpmOutputPath
            }
        }
    }

    Remove-RuntimeClosure -Directory (Join-Path $entryLibsRoot $arch) -Libraries $libraries
}

if (-not $SkipNativeCacheReset) {
    Reset-NativeBuildState
}

Write-Host "Staged curl prebuilts into $(Join-Path $PluginRoot 'libs') and $curlHeadersRoot"
if ($ohpmPackageRoots.Count -gt 0) {
    Write-Host "Mirrored curl prebuilts into generated OHPM packages under $OhpmRoot"
}
Write-Host "Removed duplicate curl runtime libraries from $entryLibsRoot"