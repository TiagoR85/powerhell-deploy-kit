BeforeAll {
    . (Join-Path (Split-Path -Parent $PSScriptRoot) '_Import.ps1')
    $script:module = Get-Module powerhell-deploy-kit
}

Describe 'Invoke-HealthCheck (unit, mocked IWR)' {
    BeforeEach {
        $script:uri = [uri]'http://health.test/ready'
    }

    It 'returns true on the first 200 response' {
        Mock -ModuleName powerhell-deploy-kit Invoke-WebRequest { [pscustomobject]@{ StatusCode = 200 } }
        $result = & $script:module { param($u) Invoke-HealthCheck -Uri $u -Retries 3 -DelaySeconds 0 } $script:uri
        $result | Should -BeTrue
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName powerhell-deploy-kit -Times 1 -Exactly
    }

    It 'treats 201 as healthy' {
        Mock -ModuleName powerhell-deploy-kit Invoke-WebRequest { [pscustomobject]@{ StatusCode = 201 } }
        $result = & $script:module { param($u) Invoke-HealthCheck -Uri $u -Retries 2 -DelaySeconds 0 } $script:uri
        $result | Should -BeTrue
    }

    It 'does not treat 500 as healthy' {
        Mock -ModuleName powerhell-deploy-kit Invoke-WebRequest { [pscustomobject]@{ StatusCode = 500 } }
        $result = & $script:module { param($u) Invoke-HealthCheck -Uri $u -Retries 2 -DelaySeconds 0 } $script:uri
        $result | Should -BeFalse
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName powerhell-deploy-kit -Times 2 -Exactly
    }

    It 'retries connection failures and stops after -Retries' {
        Mock -ModuleName powerhell-deploy-kit Invoke-WebRequest { throw 'connection refused' }
        $result = & $script:module { param($u) Invoke-HealthCheck -Uri $u -Retries 3 -DelaySeconds 0 } $script:uri
        $result | Should -BeFalse
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName powerhell-deploy-kit -Times 3 -Exactly
    }

    It 'recovers when the service comes up mid-retries' {
        $global:PdkHealthCalls = 0
        Mock -ModuleName powerhell-deploy-kit Invoke-WebRequest {
            $global:PdkHealthCalls++
            if ($global:PdkHealthCalls -lt 3) { throw 'starting' }
            [pscustomobject]@{ StatusCode = 200 }
        }
        try {
            $result = & $script:module { param($u) Invoke-HealthCheck -Uri $u -Retries 5 -DelaySeconds 0 } $script:uri
            $result | Should -BeTrue
            $global:PdkHealthCalls | Should -Be 3
        }
        finally {
            Remove-Variable -Name PdkHealthCalls -Scope Global -ErrorAction SilentlyContinue
        }
    }

    It 'returns false when the request keeps throwing (defensive catch path)' {
        Mock -ModuleName powerhell-deploy-kit Invoke-WebRequest { throw 'boom' }
        $result = & $script:module { param($u) Invoke-HealthCheck -Uri $u -Retries 1 -DelaySeconds 0 } $script:uri
        $result | Should -BeFalse
        Should -Invoke -CommandName Invoke-WebRequest -ModuleName powerhell-deploy-kit -Times 1 -Exactly
    }
}

Describe 'Invoke-HealthCheck (loopback integration)' {
    BeforeAll {
        $script:stopFile = Join-Path $TestDrive 'listener-stop.txt'
        $tcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $tcp.Start()
        $script:port = ([System.Net.IPEndPoint]$tcp.LocalEndpoint).Port
        $tcp.Stop()
        $script:listenerJob = Start-Job -ScriptBlock {
            param($StopFile, $Port)
            $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
            $listener.Start()
            while (-not (Test-Path -LiteralPath $StopFile)) {
                if ($listener.Pending()) {
                    $client = $listener.AcceptTcpClient()
                    try {
                        $stream = $client.GetStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $requestLine = $reader.ReadLine()
                        while ($null -ne ($line = $reader.ReadLine()) -and $line -ne '') { }
                        if ($null -ne $requestLine) {
                            $body = '{"status":"ok"}'
                            $payload = "HTTP/1.1 200 OK`r`nContent-Type: application/json`r`nContent-Length: $($body.Length)`r`nConnection: close`r`n`r`n$body"
                            $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
                            $stream.Write($bytes, 0, $bytes.Length)
                            $stream.Flush()
                        }
                    }
                    catch { }
                    finally { $client.Close() }
                }
                else {
                    Start-Sleep -Milliseconds 25
                }
            }
            $listener.Stop()
        } -ArgumentList $script:stopFile, $script:port

        $ready = $false
        for ($i = 0; $i -lt 60 -and -not $ready; $i++) {
            try {
                $client = New-Object System.Net.Sockets.TcpClient
                $client.Connect('127.0.0.1', $script:port)
                $ready = $client.Connected
                $client.Close()
            }
            catch {
                Start-Sleep -Milliseconds 250
            }
        }
        if (-not $ready) { throw 'Loopback listener failed to start' }
    }

    AfterAll {
        Set-Content -LiteralPath $script:stopFile -Value 'stop'
        $null = Wait-Job -Job $script:listenerJob -Timeout 15
        Remove-Job -Job $script:listenerJob -Force -ErrorAction SilentlyContinue
    }

    It 'returns true against a real HTTP 200 loopback server' {
        $healthUri = [uri]"http://127.0.0.1:$($script:port)/"
        $result = & (Get-Module powerhell-deploy-kit) { param($u) Invoke-HealthCheck -Uri $u -Retries 3 -DelaySeconds 0 -TimeoutSec 5 } $healthUri
        $result | Should -BeTrue
    }

    It 'returns false when nothing is listening on the port' {
        $freeTcp = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
        $freeTcp.Start()
        $freePort = ([System.Net.IPEndPoint]$freeTcp.LocalEndpoint).Port
        $freeTcp.Stop()
        $healthUri = [uri]"http://127.0.0.1:$freePort/"
        $result = & (Get-Module powerhell-deploy-kit) { param($u) Invoke-HealthCheck -Uri $u -Retries 1 -DelaySeconds 0 -TimeoutSec 2 } $healthUri
        $result | Should -BeFalse
    }
}
