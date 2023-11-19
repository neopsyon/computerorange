function Get-GoogleForm {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$FormId = '1GfRsCQMx2H5-cHjRUCSKY8UAAdHOMvgQdHd_NJASAPI'
    )
    process {
        $response = Invoke-RestMethod -Uri ('https://forms.googleapis.com/v1/forms/{0}' -f $FormId) -Headers $script:authorizationHeader
        return($response)
    }
}