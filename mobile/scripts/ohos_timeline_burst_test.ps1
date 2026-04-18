param(
  [string]$HdcPath = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe',
  [string]$BundleName = 'com.dgh18.immich',
  [string]$WindowName = 'immich0',
  [string]$OutputRoot = '',
  [int]$KeepAwakeMs = 3600000,
  [switch]$SkipHilogReset,
  [int]$SettleSeconds = 60,
  [string]$ReadyLogPattern = 'isKeepScreenOn: 0',
  [int]$ReadyLogTimeoutSeconds = 60,
  [int]$CooldownSeconds = 30,
  [int]$BurstFrames = 5,
  [int]$BurstDelayMs = 200,
  [int]$DownFlingCount = 3,
  [int]$DownVelocity = 30000,
  [int]$DownStepLength = 1600,
  [int]$UpFlingCount = 3,
  [int]$UpVelocity = 30000,
  [int]$UpStepLength = 1600
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-HdcShell {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command
  )

  $output = & $HdcPath shell $Command 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "hdc shell failed: $Command`n$output"
  }
  return $output
}

function Invoke-HdcFileRecv {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RemotePath,
    [Parameter(Mandatory = $true)]
    [string]$LocalPath
  )

  $output = & $HdcPath file recv $RemotePath $LocalPath 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "hdc file recv failed: $RemotePath -> $LocalPath`n$output"
  }
  return $output
}

function Invoke-DirectionalFling {
  param(
    [Parameter(Mandatory = $true)]
    [int]$Direction,
    [Parameter(Mandatory = $true)]
    [int]$Velocity,
    [Parameter(Mandatory = $true)]
    [int]$StepLength,
    [Parameter(Mandatory = $true)]
    [int]$Count
  )

  for ($index = 1; $index -le $Count; $index++) {
    Invoke-HdcShell "uitest uiInput dircFling $Direction $Velocity $StepLength" | Out-Null
  }
}

function Capture-Burst {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  $burstDir = Join-Path $runDir $Name
  New-Item -ItemType Directory -Force -Path $burstDir | Out-Null

  for ($index = 1; $index -le $BurstFrames; $index++) {
    $remotePath = "/data/local/tmp/${Name}_$index.jpeg"
    Invoke-HdcShell "snapshot_display -f $remotePath" | Out-Null
    Start-Sleep -Milliseconds $BurstDelayMs
  }

  for ($index = 1; $index -le $BurstFrames; $index++) {
    $remotePath = "/data/local/tmp/${Name}_$index.jpeg"
    $localPath = Join-Path $burstDir ("frame_{0}.jpeg" -f $index)
    Invoke-HdcFileRecv -RemotePath $remotePath -LocalPath $localPath | Out-Null
  }
}

function Get-PatternCount {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Pattern
  )

  return (Select-String -Path $Path -Pattern $Pattern -SimpleMatch | Measure-Object).Count
}

function Get-FirstRegexMatchValue {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$Pattern
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    return ''
  }

  $match = Select-String -Path $Path -Pattern $Pattern | Select-Object -First 1
  if ($null -eq $match) {
    return ''
  }

  $groups = $match.Matches[0].Groups
  if ($groups.Count -lt 2) {
    return ''
  }
  return $groups[1].Value
}

function Get-MemMetricValueKb {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$MetricName
  )

  $escapedMetricName = [regex]::Escape($MetricName)
  $pattern = "^\s*$escapedMetricName\s+(\d+)"
  $value = Get-FirstRegexMatchValue -Path $Path -Pattern $pattern
  if ([string]::IsNullOrWhiteSpace($value)) {
    return -1
  }
  return [int]$value
}

function Get-CpuUsagePercent {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$ProcessName
  )

  $escapedProcessName = [regex]::Escape($ProcessName)
  $pattern = "^\s*\d+\s+([0-9]+\.[0-9]+)%.*$escapedProcessName\s*$"
  return Get-FirstRegexMatchValue -Path $Path -Pattern $pattern
}

function Get-HitchCount {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [Parameter(Mandatory = $true)]
    [string]$ThresholdLabel
  )

  $escapedThresholdLabel = [regex]::Escape($ThresholdLabel)
  $pattern = "^\s*$escapedThresholdLabel\s+(\d+)"
  $value = Get-FirstRegexMatchValue -Path $Path -Pattern $pattern
  if ([string]::IsNullOrWhiteSpace($value)) {
    return ''
  }
  return $value
}

function Get-DeltaValue {
  param(
    [Parameter(Mandatory = $true)]
    [int]$BeforeValue,
    [Parameter(Mandatory = $true)]
    [int]$AfterValue
  )

  if ($BeforeValue -lt 0 -or $AfterValue -lt 0) {
    return ''
  }
  return [string]($AfterValue - $BeforeValue)
}

function Resolve-ProcessPid {
  $psOutput = Invoke-HdcShell "ps -ef | grep $BundleName"
  $lines = $psOutput -split "\r?\n"
  foreach ($line in $lines) {
    $trimmedLine = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
      continue
    }
    if ($trimmedLine.Contains('grep ') -or $trimmedLine.Contains(' sh -c ')) {
      continue
    }
    if (-not $trimmedLine.EndsWith($BundleName)) {
      continue
    }
    $columns = $trimmedLine -split '\s+'
    if ($columns.Length -lt 2) {
      continue
    }
    if ($columns[1] -match '^\d+$') {
      return [int]$columns[1]
    }
  }
  return $null
}

function Capture-ProcessDiagnostics {
  param(
    [Parameter(Mandatory = $true)]
    [string]$StageName
  )

  $processPid = Resolve-ProcessPid
  if ($null -eq $processPid) {
    Write-Warning "failed to resolve process pid for $BundleName at stage=$StageName"
    return
  }

  $psPath = Join-Path $runDir ("process_{0}_ps.txt" -f $StageName)
  $memPath = Join-Path $runDir ("process_{0}_mem.txt" -f $StageName)

  Invoke-HdcShell "ps -ef | grep $BundleName" | Set-Content -LiteralPath $psPath -Encoding utf8
  Invoke-HdcShell "hidumper --mem $processPid --prune" | Set-Content -LiteralPath $memPath -Encoding utf8

  if ($StageName -eq 'after' -or $StageName -eq 'cooldown') {
    $cpuPath = Join-Path $runDir ("process_{0}_cpuusage.txt" -f $StageName)
    Invoke-HdcShell "hidumper --cpuusage $processPid" | Set-Content -LiteralPath $cpuPath -Encoding utf8
  }
}

function Wait-ForReadySignal {
  if ([string]::IsNullOrWhiteSpace($ReadyLogPattern)) {
    if ($SettleSeconds -gt 0) {
      Write-Output "waitMode=fixed"
      Write-Output "waitSeconds=$SettleSeconds"
      Start-Sleep -Seconds $SettleSeconds
    }
    return
  }

  Write-Output "waitMode=logPattern"
  Write-Output "readyLogPattern=$ReadyLogPattern"
  $deadline = (Get-Date).AddSeconds($ReadyLogTimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    $hilogText = Invoke-HdcShell 'hilog -x'
    if ($hilogText -match [regex]::Escape($ReadyLogPattern)) {
      Write-Output 'readyLogPatternMatched=true'
      return
    }
    Start-Sleep -Seconds 5
  }

  Write-Warning "ready log pattern not found within $ReadyLogTimeoutSeconds seconds: $ReadyLogPattern"
}

if (-not (Test-Path -LiteralPath $HdcPath)) {
  throw "hdc not found: $HdcPath"
}

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
  $OutputRoot = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'tmp\timeline_burst_test'
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runDir = Join-Path $OutputRoot $timestamp
New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Write-Output "runDir=$runDir"

Invoke-HdcShell 'power-shell wakeup' | Out-Null
Invoke-HdcShell "power-shell timeout -o $KeepAwakeMs" | Out-Null
if (-not $SkipHilogReset) {
  Invoke-HdcShell 'hilog -r' | Out-Null
}
Invoke-HdcShell "hidumper -s RenderService -a 'fpsClear $WindowName'" | Out-Null

Wait-ForReadySignal
Capture-ProcessDiagnostics -StageName 'before'

if ($DownFlingCount -gt 0) {
  Invoke-DirectionalFling -Direction 3 -Velocity $DownVelocity -StepLength $DownStepLength -Count $DownFlingCount
  Capture-Burst -Name 'down'
}

if ($UpFlingCount -gt 0) {
  Invoke-DirectionalFling -Direction 2 -Velocity $UpVelocity -StepLength $UpStepLength -Count $UpFlingCount
  Capture-Burst -Name 'up'
}

Capture-ProcessDiagnostics -StageName 'after'
if ($CooldownSeconds -gt 0) {
  Start-Sleep -Seconds $CooldownSeconds
  Capture-ProcessDiagnostics -StageName 'cooldown'
}

$fpsPath = Join-Path $runDir 'render_service_fps.txt'
$hitchsPath = Join-Path $runDir 'render_service_hitchs.txt'
$fpsCountPath = Join-Path $runDir 'render_service_fps_count.txt'
$hilogPath = Join-Path $runDir 'timeline_hilog.txt'
$summaryPath = Join-Path $runDir 'summary.txt'

Invoke-HdcShell "hidumper -s RenderService -a 'fps $WindowName'" | Set-Content -LiteralPath $fpsPath -Encoding utf8
Invoke-HdcShell "hidumper -s RenderService -a 'hitchs $WindowName'" | Set-Content -LiteralPath $hitchsPath -Encoding utf8
Invoke-HdcShell "hidumper -s RenderService -a 'fpsCount'" | Set-Content -LiteralPath $fpsCountPath -Encoding utf8
Invoke-HdcShell 'hilog -x' | Set-Content -LiteralPath $hilogPath -Encoding utf8

$beforeMemPath = Join-Path $runDir 'process_before_mem.txt'
$afterMemPath = Join-Path $runDir 'process_after_mem.txt'
$cooldownMemPath = Join-Path $runDir 'process_cooldown_mem.txt'
$afterCpuPath = Join-Path $runDir 'process_after_cpuusage.txt'
$cooldownCpuPath = Join-Path $runDir 'process_cooldown_cpuusage.txt'

$pssBeforeKb = Get-MemMetricValueKb -Path $beforeMemPath -MetricName 'Total'
$pssAfterKb = Get-MemMetricValueKb -Path $afterMemPath -MetricName 'Total'
$pssCooldownKb = Get-MemMetricValueKb -Path $cooldownMemPath -MetricName 'Total'
$arkTsHeapBeforeKb = Get-MemMetricValueKb -Path $beforeMemPath -MetricName 'ark ts heap'
$arkTsHeapAfterKb = Get-MemMetricValueKb -Path $afterMemPath -MetricName 'ark ts heap'
$arkTsHeapCooldownKb = Get-MemMetricValueKb -Path $cooldownMemPath -MetricName 'ark ts heap'
$graphBeforeKb = Get-MemMetricValueKb -Path $beforeMemPath -MetricName 'Graph'
$graphAfterKb = Get-MemMetricValueKb -Path $afterMemPath -MetricName 'Graph'
$graphCooldownKb = Get-MemMetricValueKb -Path $cooldownMemPath -MetricName 'Graph'
$nativeHeapBeforeKb = Get-MemMetricValueKb -Path $beforeMemPath -MetricName 'native heap'
$nativeHeapAfterKb = Get-MemMetricValueKb -Path $afterMemPath -MetricName 'native heap'
$nativeHeapCooldownKb = Get-MemMetricValueKb -Path $cooldownMemPath -MetricName 'native heap'
$cpuAfterPercent = Get-CpuUsagePercent -Path $afterCpuPath -ProcessName $BundleName
$cpuCooldownPercent = Get-CpuUsagePercent -Path $cooldownCpuPath -ProcessName $BundleName
$hitch16Count = Get-HitchCount -Path $hitchsPath -ThresholdLabel 'more than 16.67 ms'
$hitch33Count = Get-HitchCount -Path $hitchsPath -ThresholdLabel 'more than 33 ms'
$hitch66Count = Get-HitchCount -Path $hitchsPath -ThresholdLabel 'more than 66 ms'

$summaryLines = @(
  "use_repeat_key=$(Get-PatternCount -Path $hilogPath -Pattern 'Use repeat key')"
  "sliding_window_updated=$(Get-PatternCount -Path $hilogPath -Pattern 'Sliding window updated')"
  "jpeg_hw_decoder=$(Get-PatternCount -Path $hilogPath -Pattern 'JPEGHWDECODER')"
  "create_pixel_map_success=$(Get-PatternCount -Path $hilogPath -Pattern 'CreatePixelMap success')"
  "render_service_hitch_over_16_67ms=$hitch16Count"
  "render_service_hitch_over_33ms=$hitch33Count"
  "render_service_hitch_over_66ms=$hitch66Count"
  "pss_before_kb=$pssBeforeKb"
  "pss_after_kb=$pssAfterKb"
  "pss_cooldown_kb=$pssCooldownKb"
  "pss_delta_after_kb=$(Get-DeltaValue -BeforeValue $pssBeforeKb -AfterValue $pssAfterKb)"
  "pss_delta_cooldown_kb=$(Get-DeltaValue -BeforeValue $pssBeforeKb -AfterValue $pssCooldownKb)"
  "ark_ts_heap_before_kb=$arkTsHeapBeforeKb"
  "ark_ts_heap_after_kb=$arkTsHeapAfterKb"
  "ark_ts_heap_cooldown_kb=$arkTsHeapCooldownKb"
  "ark_ts_heap_delta_after_kb=$(Get-DeltaValue -BeforeValue $arkTsHeapBeforeKb -AfterValue $arkTsHeapAfterKb)"
  "ark_ts_heap_delta_cooldown_kb=$(Get-DeltaValue -BeforeValue $arkTsHeapBeforeKb -AfterValue $arkTsHeapCooldownKb)"
  "graph_before_kb=$graphBeforeKb"
  "graph_after_kb=$graphAfterKb"
  "graph_cooldown_kb=$graphCooldownKb"
  "graph_delta_after_kb=$(Get-DeltaValue -BeforeValue $graphBeforeKb -AfterValue $graphAfterKb)"
  "graph_delta_cooldown_kb=$(Get-DeltaValue -BeforeValue $graphBeforeKb -AfterValue $graphCooldownKb)"
  "native_heap_before_kb=$nativeHeapBeforeKb"
  "native_heap_after_kb=$nativeHeapAfterKb"
  "native_heap_cooldown_kb=$nativeHeapCooldownKb"
  "native_heap_delta_after_kb=$(Get-DeltaValue -BeforeValue $nativeHeapBeforeKb -AfterValue $nativeHeapAfterKb)"
  "native_heap_delta_cooldown_kb=$(Get-DeltaValue -BeforeValue $nativeHeapBeforeKb -AfterValue $nativeHeapCooldownKb)"
  "immich_cpu_after_percent=$cpuAfterPercent"
  "immich_cpu_cooldown_percent=$cpuCooldownPercent"
)
$summaryLines | Set-Content -LiteralPath $summaryPath -Encoding utf8

Write-Output "downBurst=$(Join-Path $runDir 'down')"
Write-Output "upBurst=$(Join-Path $runDir 'up')"
Write-Output "fps=$fpsPath"
Write-Output "hitchs=$hitchsPath"
Write-Output "fpsCount=$fpsCountPath"
Write-Output "hilog=$hilogPath"
Write-Output "summary=$summaryPath"
Write-Output "processBeforePs=$(Join-Path $runDir 'process_before_ps.txt')"
Write-Output "processBeforeMem=$(Join-Path $runDir 'process_before_mem.txt')"
Write-Output "processAfterPs=$(Join-Path $runDir 'process_after_ps.txt')"
Write-Output "processAfterMem=$(Join-Path $runDir 'process_after_mem.txt')"
Write-Output "processAfterCpu=$(Join-Path $runDir 'process_after_cpuusage.txt')"
Write-Output "processCooldownMem=$(Join-Path $runDir 'process_cooldown_mem.txt')"
Write-Output "processCooldownCpu=$(Join-Path $runDir 'process_cooldown_cpuusage.txt')"
