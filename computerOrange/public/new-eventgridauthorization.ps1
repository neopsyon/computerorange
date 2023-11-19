function New-EventGridAuthorization {
    $AccessToken = (Get-AzAccessToken -ResourceUrl "https://graph.microsoft.com").Token 
    $dateTime = (Get-Date).AddMinutes(4230)
    $dateTimeString = $dateTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssK")
    $uri = "https://graph.microsoft.com/beta/subscriptions"
    $headers = @{
        "Authorization"        = "Bearer $AccessToken"
        "x-ms-enable-features" = "EventGrid"
    }
    $body = @{
        changeType         = "Updated,Deleted,Created"
        notificationUrl    = "EventGrid:?azuresubscriptionid=44b89b2a-f593-4aa9-a510-15f7c1f4dbab&resourcegroup=core-production-eus-rg&partnertopic=default&location=eastus"
        resource           = "users"
        expirationDateTime = $dateTimeString
        clientState        = "mysecret"
    } | ConvertTo-Json
    Invoke-RestMethod -Uri $URI -Headers $Headers -Body $Body -Method POST -ContentType "application/json"
}
