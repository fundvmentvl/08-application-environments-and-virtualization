# CEN4025 Assignment 7 - Evidence 09
# Throughput and Scalability Test
# Compatible with Windows PowerShell 5.1
#
# Three workloads:
# 1 background job  x 100 requests
# 5 background jobs x 20 requests
# 20 background jobs x 5 requests
#
# Total requests remain constant at 100 per test.
$uri = "http://localhost:8080/api/appointments"
$configurations = @(
    @{ Clients = 1; RequestsPerClient = 100 },
    @{ Clients = 5; RequestsPerClient = 20 },
    @{ Clients = 20; RequestsPerClient = 5 }
)
$summary = @()
foreach ($config in $configurations) {
    $clientCount = $config.Clients
    $requestsPerClient = $config.RequestsPerClient
    Write-Host ""
    Write-Host "Running test with $clientCount background job(s)..."
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $jobs = 1..$clientCount | ForEach-Object {
        Start-Job -ArgumentList $requestsPerClient, $uri -ScriptBlock {
            param($requestCount, $endpoint)
            for ($i = 1; $i -le $requestCount; $i++) {
                try {
                    Invoke-RestMethod -Uri $endpoint `
                       -Method Get -TimeoutSec 10 | Out-Null
                    [PSCustomObject]@{
                        Success = $true
                    }
                }
                catch {
                    [PSCustomObject]@{
                        Success = $false
                    }
                }
            }
        }
    }
    $results = @($jobs | Wait-Job | Receive-Job)
    $jobs | Remove-Job
    $timer.Stop()
    $total = $results.Count
    $successful = @($results | Where-Object { $_.Success }).Count
    $failed = $total - $successful
    $seconds = $timer.Elapsed.TotalSeconds
    $throughput = if ($seconds -gt 0) {
        [math]::Round($total / $seconds, 2)
    }
    else {
        0
    }
    $summary += [PSCustomObject]@{
        Clients = $clientCount
        TotalRequests = $total
        Successful = $successful
        Failed = $failed
        DurationSeconds = [math]::Round($seconds, 3)
        RequestsPerSecond = $throughput
        ErrorRate = if ($total -gt 0) {
            [math]::Round(($failed / $total) * 100, 2)
        }
        else {
            0
        }
    }
}
Write-Host ""
Write-Host "=== THROUGHPUT AND SCALABILITY SUMMARY ==="
$summary |
        Format-Table Clients, TotalRequests, Successful, Failed, `
       DurationSeconds, RequestsPerSecond, ErrorRate -AutoSize