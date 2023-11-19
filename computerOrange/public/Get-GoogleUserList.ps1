function Get-GoogleUserList {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$DomainName
    )
    process {
        Invoke-RestMethod -Uri "https://admin.googleapis.com/admin/directory/v1/users?domain=$DomainName" -Headers $script:authorizationHeader
    }
}