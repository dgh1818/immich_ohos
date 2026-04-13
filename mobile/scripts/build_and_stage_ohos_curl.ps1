param(
    [string]$WorkspaceRoot = '/mnt/f/immich_ohos/mobile',
    [string]$LocalTpcRoot = '/home/dgh18/work/tpc_c_cplusplus',
    [string]$LyciumRoot = '/home/dgh18/work/tpc_c_cplusplus/lycium',
    [string]$SdkRoot = '/home/dgh18/ohos-sdk-linux-6.1.0.818/command-line-tools/sdk/default/openharmony',
    [string[]]$Architectures = @('arm64-v8a', 'armeabi-v7a'),
    [string[]]$Packages = @('curl')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-WslPathFromWindows {
    param([string]$WindowsPath)

    $fullWindowsPath = [System.IO.Path]::GetFullPath($WindowsPath)
    if ($fullWindowsPath -notmatch '^(?<drive>[A-Za-z]):\\(?<rest>.*)$') {
        throw "Unsupported Windows path for WSL conversion: $WindowsPath"
    }

    $drive = $Matches.drive.ToLowerInvariant()
    $rest = $Matches.rest -replace '\\', '/'
    return "/mnt/$drive/$rest"
}

$buildScriptWindows = Join-Path $PSScriptRoot 'build_curl_wsl.sh'
$stageScriptWindows = Join-Path $PSScriptRoot 'stage_ohos_curl_from_wsl.ps1'
$buildScriptWsl = Get-WslPathFromWindows -WindowsPath $buildScriptWindows

$sourceTpcRoot = "$WorkspaceRoot/third_party/tpc_c_cplusplus"
$wslArgs = @(
    'env'
    "WORKSPACE_ROOT=$WorkspaceRoot"
    "SOURCE_TPC_ROOT=$sourceTpcRoot"
    "LOCAL_TPC_ROOT=$LocalTpcRoot"
    "LYCIUM_ROOT=$LyciumRoot"
    "SDK_ROOT=$SdkRoot"
    'bash'
    $buildScriptWsl
) + $Packages

& wsl.exe @wslArgs
if ($LASTEXITCODE -ne 0) {
    throw 'WSL curl build failed.'
}

& $stageScriptWindows -LyciumRoot $LyciumRoot -Architectures $Architectures
if ($LASTEXITCODE -ne 0) {
    throw 'Staging curl prebuilts failed.'
}

Write-Host 'WSL curl build and OHOS staging completed successfully.'