param(
    [string]$PluginRoot = 'F:\package_flutter\ohos_http\ohos',
    [string]$BuildLibRoot,
    [string]$CmakeObjRoot,
    [string]$EntryLibRoot,
    [string]$OhpmRoot,
    [string]$OhosNativeSdkRoot = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\native',
    [string]$DartApiDlRoot,
    [string]$CurlIncludeRoot,
    [string]$BuildType = 'RelWithDebInfo',
    [string[]]$Architectures = @('arm64-v8a'),
    [switch]$BuildNative,
    [switch]$FfiOnly
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
if ([string]::IsNullOrWhiteSpace($DartApiDlRoot)) {
    $DartApiDlRoot = Join-Path $repoRoot 'third_party\jni\src\include'
}
if ([string]::IsNullOrWhiteSpace($CurlIncludeRoot)) {
    $CurlIncludeRoot = Join-Path $repoRoot 'ohos\entry\src\main\cpp\thirdparty\curl'
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

$librariesToCopy = if ($FfiOnly) {
    @('libohos_http_ffi.so')
} else {
    $runtimeLibraries
}

$sharedRuntimeLibraries = $runtimeLibraries | Where-Object { $_ -ne 'libohos_http_ffi.so' }

function Remove-RuntimeClosure {
    param(
        [string]$Directory,
        [string[]]$Libraries = $runtimeLibraries
    )

    if (-not (Test-Path $Directory)) {
        return
    }

    foreach ($library in $Libraries) {
        $candidate = Join-Path $Directory $library
        if (Test-Path $candidate) {
            Remove-Item -Path $candidate -Force
        }
    }
}

function Copy-RuntimeClosure {
    param(
        [string[]]$SourceDirs,
        [string]$DestinationDir,
        [string[]]$Libraries = $librariesToCopy
    )

    if (-not (Test-Path $DestinationDir)) {
        New-Item -ItemType Directory -Path $DestinationDir -Force | Out-Null
    }

    foreach ($library in $Libraries) {
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

function ConvertTo-CmakePath {
    param(
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path).Replace('\', '/')
}

function Build-NativeLibrary {
    param(
        [string]$Architecture
    )

    $cmake = Join-Path $OhosNativeSdkRoot 'build-tools\cmake\bin\cmake.exe'
    $ninja = Join-Path $OhosNativeSdkRoot 'build-tools\cmake\bin\ninja.exe'
    $toolchain = Join-Path $OhosNativeSdkRoot 'build\cmake\ohos.toolchain.cmake'

    foreach ($requiredPath in @($cmake, $ninja, $toolchain, $DartApiDlRoot)) {
        if (-not (Test-Path $requiredPath)) {
            throw "Required native build path does not exist: $requiredPath"
        }
    }

    $sourceDir = Join-Path $PluginRoot 'src\main\cpp'
    $buildDir = Join-Path (Join-Path $PluginRoot 'build_manual') $Architecture
    $libsDir = Join-Path (Join-Path $PluginRoot 'libs') $Architecture
    $curlIncludeDir = Join-Path (Join-Path $CurlIncludeRoot $Architecture) 'include'

    if (-not (Test-Path $curlIncludeDir)) {
        throw "Required curl include directory does not exist: $curlIncludeDir"
    }
    if (-not (Test-Path $libsDir)) {
        New-Item -ItemType Directory -Path $libsDir -Force | Out-Null
    }

    $configureArgs = @(
        '-S', (ConvertTo-CmakePath -Path $sourceDir),
        '-B', (ConvertTo-CmakePath -Path $buildDir),
        '-G', 'Ninja',
        "-DCMAKE_MAKE_PROGRAM=$(ConvertTo-CmakePath -Path $ninja)",
        "-DCMAKE_TOOLCHAIN_FILE=$(ConvertTo-CmakePath -Path $toolchain)",
        "-DCMAKE_BUILD_TYPE=$BuildType",
        '-DOHOS_STL=c++_shared',
        "-DOHOS_ARCH=$Architecture",
        "-DDART_API_DL_ROOT=$(ConvertTo-CmakePath -Path $DartApiDlRoot)",
        "-DOHOS_HTTP_CURL_INCLUDE_DIR=$(ConvertTo-CmakePath -Path $curlIncludeDir)"
    )

    & $cmake @configureArgs
    if ($LASTEXITCODE -ne 0) {
        throw "CMake configure failed for $Architecture with exit code $LASTEXITCODE"
    }

    & $cmake --build $buildDir --target ohos_http_ffi --config $BuildType
    if ($LASTEXITCODE -ne 0) {
        throw "CMake build failed for $Architecture with exit code $LASTEXITCODE"
    }

    $builtLibrary = Join-Path $buildDir 'libohos_http_ffi.so'
    if (-not (Test-Path $builtLibrary)) {
        throw "Native build did not produce $builtLibrary"
    }

    Copy-Item -Path $builtLibrary -Destination (Join-Path $libsDir 'libohos_http_ffi.so') -Force
}

$ohpmPackageRoots = @()
if (Test-Path $OhpmRoot) {
    $ohpmPackageRoots = @(Get-ChildItem -Path $OhpmRoot -Directory -Filter 'ohos_http@*=*' |
        ForEach-Object { Join-Path $_.FullName 'oh_modules\ohos_http' } |
        Where-Object { Test-Path $_ })
}

foreach ($arch in $Architectures) {
    if ($BuildNative) {
        Build-NativeLibrary -Architecture $arch
    }

    $pluginDestinationDir = Join-Path (Join-Path $PluginRoot 'libs') $arch
    $sourceDirs = @(
        $pluginDestinationDir,
        (Join-Path $BuildLibRoot $arch),
        (Join-Path $CmakeObjRoot $arch),
        (Join-Path $EntryLibRoot $arch)
    ) | Where-Object { Test-Path $_ }

    if ($sourceDirs.Count -eq 0) {
        throw "No runtime library source directories found for architecture $arch"
    }

    Copy-RuntimeClosure -SourceDirs $sourceDirs -DestinationDir $pluginDestinationDir

    foreach ($ohpmPackageRoot in $ohpmPackageRoots) {
        $ohpmDestinationDir = Join-Path (Join-Path $ohpmPackageRoot 'libs') $arch
        $ohpmSourceDirs = @($sourceDirs + $pluginDestinationDir) | Select-Object -Unique
        Copy-RuntimeClosure -SourceDirs $ohpmSourceDirs -DestinationDir $ohpmDestinationDir
        if ($FfiOnly) {
            Remove-RuntimeClosure -Directory $ohpmDestinationDir -Libraries $sharedRuntimeLibraries
        }
    }

    Remove-RuntimeClosure -Directory (Join-Path $EntryLibRoot $arch) -Libraries $runtimeLibraries
}

Write-Host "Staged ohos_http plugin runtime libraries into $(Join-Path $PluginRoot 'libs')"
if ($ohpmPackageRoots.Count -gt 0) {
    Write-Host "Mirrored ohos_http runtime libraries into generated OHPM packages under $OhpmRoot"
}
Write-Host "Removed duplicate curl runtime libraries from $EntryLibRoot"
