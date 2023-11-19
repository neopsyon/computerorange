function Invoke-ChatGPT {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ApiKey,

        [string]$GPTModel = 'gpt-3.5-turbo',

        [Parameter(Mandatory)]
        [string]$Question
    )
    process {
        $splat = @{
            Uri     = 'https://api.openai.com/v1/chat/completions'
            Method  = 'Post'
            Headers = @{
                'content-type'  = 'application/json'
                'Authorization' = 'Bearer {0}' -f $ApiKey
            }
            Body    = (ConvertTo-Json -InputObject (
                    @{
                        model    = $GPTModel
                        messages = @(
                            @{
                                role    = 'user'
                                content = $Question
                            }
                        )
                    }
                ) -Depth 100)
        }
        Invoke-RestMethod @splat
    }
}