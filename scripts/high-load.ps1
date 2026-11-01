# Assignment 7 - High Concurrent-Load Test
# 20 background jobs, 5 requests per job
# Total: 100 HTTP GET requests
# Compatible with Windows PowerShell 5.1
$uri = "http://localhost:8080/api/appointments"
$clientCount = 20
$requestsPerClient = 5
$jobs = 1..$clientCount | ForEach-Object {
    $client = $_
    Start-Job -ArgumentList $client, $requestsPerClient, $uri -ScriptBlock {
        param($clientId, $requestCount, $endpoint)
        for ($i = 1; $i -le $requestCount; $i++) {
            $requestNumber = (($clientId - 1) * $requestCount) + $i
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $success = $true
            try {
                Invoke-RestMethod -Uri $endpoint -Method Get -TimeoutSec 10 |
                        Out-Null
            }
            catch {
                $success = $false
            }
            finally {
                $timer.Stop()
            }
            [PSCustomObject]@{
                Request        = $requestNumber
                Client         = $clientId
                ResponseTimeMs = [math]::Round(
                        $timer.Elapsed.TotalMilliseconds, 2
                )
                Success        = $success
            }
        }
    }
}
$results = @($jobs | Wait-Job | Receive-Job)
$jobs | Remove-Job
$results |
        Sort-Object Request |
        Select-Object Request, Client, ResponseTimeMs, Success |
        Format-Table -AutoSize
$stats = $results |
        Measure-Object -Property ResponseTimeMs -Average -Minimum -Maximum
$successful = @($results | Where-Object { $_.Success }).Count
$failed = $results.Count - $successful
$errorRate = [math]::Round(
        ($failed / $results.Count) * 100, 2
)
Write-Host "`n=== HIGH CONCURRENT-LOAD SUMMARY ==="
Write-Host "Concurrent Clients: $clientCount"
Write-Host "Requests Per Client: $requestsPerClient"
Write-Host "Total Requests: $($results.Count)"
Write-Host "Successful Requests: $successful"
Write-Host "Failed Requests: $failed"
Write-Host "Average Response Time: $([math]::Round($stats.Average,3)) ms"
Write-Host "Minimum Response Time: $($stats.Minimum) ms"
Write-Host "Maximum Response Time: $($stats.Maximum) ms"
Write-Host "Error Rate: $errorRate%"