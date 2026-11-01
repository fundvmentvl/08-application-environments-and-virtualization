# CEN4025 Assignment 7 - Evidence 10
# Lightweight HTTP Scalability Test
# Compatible with Windows PowerShell 5.1

Add-Type -AssemblyName System.Net.Http
$uri = "http://localhost:8080/api/appointments"
$totalRequests = 100
$concurrencyLevels = @(1, 5, 20)
$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(10)
$summary = @()
try {
    foreach ($concurrency in $concurrencyLevels) {
        # Warm up the HTTP client before measurement.
        $warmup = $client.GetAsync($uri).GetAwaiter().GetResult()
        $warmup.EnsureSuccessStatusCode() | Out-Null
        $warmup.Dispose()
        $successful = 0
        $failed = 0
        $timer = [System.Diagnostics.Stopwatch]::StartNew()
        # Execute requests in batches of up to the concurrency limit.
        for ($start = 0; $start -lt $totalRequests; $start += $concurrency) {
            $batchSize = [Math]::Min(
                    $concurrency,
                    $totalRequests - $start
            )
            $tasks = @()
            for ($i = 0; $i -lt $batchSize; $i++) {
                $tasks += $client.GetAsync($uri)
            }
            foreach ($task in $tasks) {
                try {
                    $response = $task.GetAwaiter().GetResult()
                    if ($response.IsSuccessStatusCode) {
                        $successful++
                    }
                    else {
                        $failed++
                    }
                    $response.Dispose()
                }
                catch {
                    $failed++
                }
            }
        }
        $timer.Stop()
        $duration = $timer.Elapsed.TotalSeconds
        $throughput = [Math]::Round(
                $successful / $duration, 2
        )
        $summary += [PSCustomObject]@{
            Concurrency = $concurrency
            TotalRequests = $totalRequests
            Successful = $successful
            Failed = $failed
            DurationSeconds = [Math]::Round($duration, 3)
            RequestsPerSecond = $throughput
            ErrorRate = [Math]::Round(
                    ($failed / $totalRequests) * 100, 2
            )
        }
    }
}
finally {
    $client.Dispose()
}

Write-Host ""
Write-Host "=== LIGHTWEIGHT SCALABILITY SUMMARY ==="
$summary |
        Format-Table Concurrency, TotalRequests, Successful, Failed, `
        DurationSeconds, RequestsPerSecond, ErrorRate -AutoSize
