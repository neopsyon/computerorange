function New-GoogleUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [string]$LastName,

        [Parameter(Mandatory)]
        [string]$Email,

        [Parameter(Mandatory)]
        [securestring]$Password
    )
    process {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        $body = ConvertTo-Json -InputObject @{
            primaryEmail               = $Email
            emails                     = @(
                @{
                    address    = $Email
                    type       = "work"
                    customType = ""
                    primary    = $true
                }
            )
            name                       = @{
                fullName    = '{0} {1}' -f $FirstName, $LastName
                displayName = '{0} {1}' -f $FirstName, $LastName
                givenName   = $FirstName
                familyName  = $LastName
            }
            suspended                  = $false
            password                   = $plainPassword
            changePasswordAtNextLogin  = $true
            ipWhitelisted              = $false
            isAdmin                    = $false
            includeInGlobalAddressList = $true
        }
        Invoke-RestMethod -Uri 'https://admin.googleapis.com/admin/directory/v1/users' -Method POST -Headers $script:authorizationHeader -Body $body -ContentType 'application/json'
    }
}