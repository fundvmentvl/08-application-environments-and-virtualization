# Assignment 7 - Sequential Performance Baseline
# Workload: 20 sequential HTTP GET requests
$uri = "http://localhost:8080/api/appointments"
$results = @()
for ($i = 1; $i -le 20; $i++) {
   $timer = [System.Diagnostics.Stopwatch]::StartNew()
   $success = $true
   try {
       Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10 |
           Out-Null
   }
   catch {
       $success = $false
   }
   finally {
       $timer.Stop()
   }
   $results += [PSCustomObject]@{
       Request        = $i
       ResponseTimeMs = [math]::Round(
           $timer.Elapsed.TotalMilliseconds, 2
       )
       Success        = $success
   }
}
$results | Format-Table -AutoSize
$stats = $results |
   Measure-Object -Property ResponseTimeMs `
       -Average -Minimum -Maximum
$successful = @($results | Where-Object { $_.Success }).Count
$failed = $results.Count - $successful
Write-Host "`n=== BASELINE PERFORMANCE SUMMARY ==="
Write-Host "Workload: Sequential"
Write-Host "Total Requests: $($results.Count)"
Write-Host "Successful Requests: $successful"
Write-Host "Failed Requests: $failed"
Write-Host "Average Response Time: $([math]::Round($stats.Average,3)) ms"
Write-Host "Minimum Response Time: $($stats.Minimum) ms"
Write-Host "Maximum Response Time: $($stats.Maximum) ms"
Write-Host "Error Rate: $([math]::Round(($failed / $results.Count)*100,2))%"