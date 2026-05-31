$key = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'User')

if ([string]::IsNullOrWhiteSpace($key)) {
    $key = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Process')
}

if ([string]::IsNullOrWhiteSpace($key)) {
    $key = [Environment]::GetEnvironmentVariable('DEEPSEEK_API_KEY', 'Machine')
}

if ([string]::IsNullOrWhiteSpace($key)) {
    Write-Error 'DEEPSEEK_API_KEY is not set.'
    exit 1
}

Write-Output $key.Trim()
