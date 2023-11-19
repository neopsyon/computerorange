function Get-GoogleApiAccessToken {
    param (
        [string]$GoogleAccessJson, 
        [string]$Scope, 
        [string]$TargetUserEmail 
    )
    $jsonContent = ConvertFrom-Json -InputObject $GoogleAccessJson -Depth 10
    $ServiceAccountEmail = $jsonContent.client_email
    $PrivateKey = $jsonContent.private_key -replace '-----BEGIN PRIVATE KEY-----\n' -replace '\n-----END PRIVATE KEY-----\n' -replace '\n'
    $header = @{
        alg = "RS256" 
        typ = "JWT" 
    }
    $headerBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($header | ConvertTo-Json))) 
    $timestamp = [Math]::Round((Get-Date -UFormat %s)) 
    $claimSet = @{
        iss   = $ServiceAccountEmail 
        scope = $Scope 
        aud   = "https://oauth2.googleapis.com/token" 
        exp   = $timestamp + 3600 
        iat   = $timestamp 
        sub   = $TargetUserEmail 
    }
    $claimSetBase64 = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($claimSet | ConvertTo-Json))) 
    $signatureInput = $headerBase64 + "." + $claimSetBase64 
    $signatureBytes = [System.Text.Encoding]::UTF8.GetBytes($signatureInput) 
    $privateKeyBytes = [System.Convert]::FromBase64String($PrivateKey) 
    $rsaProvider = [System.Security.Cryptography.RSA]::Create() 
    $bytesRead = $null
    $rsaProvider.ImportPkcs8PrivateKey($privateKeyBytes, [ref]$bytesRead) 
    $signature = $rsaProvider.SignData($signatureBytes, [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1) 
    $signatureBase64 = [System.Convert]::ToBase64String($signature) 
    $jwt = $headerBase64 + "." + $claimSetBase64 + "." + $signatureBase64 
    $body = @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer" 
        assertion  = $jwt 
    }
    $response = Invoke-RestMethod -Uri "https://oauth2.googleapis.com/token" -Method POST -Body $body -ContentType "application/x-www-form-urlencoded" 
    $script:authorizationHeader = @{Authorization = 'Bearer {0}' -f $response.access_token}
}