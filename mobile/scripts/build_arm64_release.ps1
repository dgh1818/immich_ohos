$env:PATH = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
Set-Location 'F:\immich_ohos\mobile'
flutter build hap --release --target-platform ohos-arm64 2>&1 | Tee-Object -FilePath 'F:\immich_ohos\mobile\build_arm64_log.txt'
