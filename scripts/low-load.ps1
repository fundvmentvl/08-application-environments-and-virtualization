# Assignment 7 - Concurrent Load Test
# Workload: 20 overlapping PowerShell background jobs
# Compatible with Windows PowerShell 5.1
$uri = "http://localhost:8080/api/appointments"
$jobs = 1..20 | ForEach-Object {
    $requestNumber = $_
    Start-Job -ArgumentList $requestNumber, $uri -ScriptBlock {
        param($number, $endpoint)
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        $success = $true
        try {
            Invoke-RestMethod -Uri $endpoint `
               -Method Get -TimeoutSec 10 | Out-Null
        }
        catch {
            $success = $false
        }
        finally {
            $timer.Stop()
        }
        [PSCustomObject]@{
            Request        = $number
            ResponseTimeMs = [math]::Round(
                    $timer.Elapsed.TotalMilliseconds, 2
            )
            Success        = $success
        }
    }
}
$results = @($jobs | Wait-Job | Receive-Job)
$jobs | Remove-Job
$results |
        Sort-Object Request |
        Select-Object Request, ResponseTimeMs, Success |
        Format-Table -AutoSize
$stats = $results |
        Measure-Object -Property ResponseTimeMs `
       -Average -Minimum -Maximum
$successful = @($results | Where-Object { $_.Success }).Count
$failed = $results.Count - $successful
Write-Host "`n=== CONCURRENT-LOAD SUMMARY ==="
Write-Host "Parallel Jobs: 20"
Write-Host "Total Requests: $($results.Count)"
Write-Host "Successful Requests: $successful"
Write-Host "Failed Requests: $failed"
Write-Host "Average Response Time: $([math]::Round($stats.Average,3)) ms"
Write-Host "Minimum Response Time: $($stats.Minimum) ms"
Write-Host "Maximum Response Time: $($stats.Maximum) ms"
if ($results.Count -gt 0) {
    $errorRate = [math]::Round(
            ($failed / $results.Count) * 100, 2
    )
    Write-Host "Error Rate: $errorRate%"
}