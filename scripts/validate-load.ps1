# Assignment 7 - Evidence 08
# Request Correctness and Error Validation Under Load
# Windows PowerShell 5.1 compatible

$uri = "http://localhost:8080/api/appointments"
$clientCount = 20
$requestsPerClient = 2
$expectedSlots = @(
    "SLOT-001",
    "SLOT-002",
    "SLOT-003",
    "SLOT-004"
)

$jobs = 1..$clientCount | ForEach-Object {
    $clientId = $_
    Start-Job -ArgumentList $clientId, $requestsPerClient, $uri, $expectedSlots -ScriptBlock {
        param($client, $count, $endpoint, $slots)
        for ($i = 1; $i -le $count; $i++) {
            $valid = $false
            $errorMessage = ""
            try {
                $response = Invoke-RestMethod -Uri $endpoint -Method Get -TimeoutSec 10
                $json = ConvertTo-Json -InputObject $response -Depth 10 -Compress
                $valid = $true
                foreach ($slot in $slots) {
                    if (-not $json.Contains($slot)) {
                        $valid = $false
                        $errorMessage = "Missing expected slot: $slot"
                        break
                    }
                }
            }
            catch {
                $errorMessage = $_.Exception.Message
            }

            [PSCustomObject]@{
                Client = $client
                Request = $i
                ValidResponse = $valid
                Error = $errorMessage
            }
        }
    }
}

$results = @($jobs | Wait-Job | Receive-Job)
$jobs | Remove-Job
$results | Select-Object Client, Request, ValidResponse, Error | Format-Table -AutoSize
$validCount = @($results | Where-Object { $_.ValidResponse }).Count
$invalidCount = $results.Count - $validCount
Write-Host "`n=== REQUEST CORRECTNESS SUMMARY ==="
Write-Host "Background Jobs: $clientCount"
Write-Host "Requests Per Job: $requestsPerClient"
Write-Host "Total Requests: $($results.Count)"
Write-Host "Valid Responses: $validCount"
Write-Host "Invalid or Failed Responses: $invalidCount"

if ($results.Count -gt 0) {
    $errorRate = [math]::Round(
            ($invalidCount / $results.Count) * 100, 2
    )
    Write-Host "Validation Error Rate: $errorRate%"
}
