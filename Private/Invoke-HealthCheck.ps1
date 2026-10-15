function Invoke-HealthCheck {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][uri]$Uri,
        [ValidateRange(1, 100)][int]$Retries = 5,
        [ValidateRange(0, 60)][int]$DelaySeconds = 2,
        [ValidateRange(1, 120)][int]$TimeoutSec = 5
    )
    for ($attempt = 1; $attempt -le $Retries; $attempt++) {
        $healthy = $false
        try {
            $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
            $statusCode = [int]$response.StatusCode
            if ($statusCode -ge 200 -and $statusCode -le 299) { $healthy = $true }
        }
        catch {
            $statusCode = $null
            $exception = $_.Exception
            while ($null -ne $exception) {
                if ($exception -is [System.Net.WebException] -and $null -ne $exception.Response) {
                    $statusCode = [int]$exception.Response.StatusCode
                    break
                }
                $exception = $exception.InnerException
            }
            if ($null -ne $statusCode -and $statusCode -ge 200 -and $statusCode -le 299) { $healthy = $true }
        }
        if ($healthy) { return $true }
        if ($attempt -lt $Retries -and $DelaySeconds -gt 0) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }
    return $false
}
