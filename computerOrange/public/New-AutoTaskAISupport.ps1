function New-AutoTaskAISupport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ApiUserName,

        [Parameter(Mandatory)]
        [string]$ApiSecret,

        [Parameter(Mandatory)]
        [string]$ApiIntegrationCode,

        [Parameter(Mandatory)]
        [string]$GPTApiKey,

        [Alias('Client')]
        [string]$ClientCompany,

        [int]$Hours = 24
    )
    begin {
        $ErrorActionPreference = 'Stop'
        $moduleList = 'AutoTask'
        foreach ($module in $moduleList) {
            if (-not (Get-Module $module -ListAvailable)) {
                Install-Module $module -Scope CurrentUser -Force -Confirm:$false
            }
        }
        try {
            $apiEncryptedPassword = ConvertTo-SecureString -String ('{0}' -f $ApiSecret) -AsPlainText -Force
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $ApiUserName, $apiEncryptedPassword
            Connect-AtwsWebAPI -Credential $credential -ApiTrackingIdentifier $ApiIntegrationCode
        }
        catch {
            throw 'Cant connect to Auototask API'
        }
        $dateTime = (Get-Date).AddHours(-$Hours)
    }
    process {
        try {
            $tickets = Get-AtwsTicket -CreateDate $dateTime -GreaterThan CreateDate
            Write-Verbose "Ticket count: $($tickets.count)"
        }
        catch {
            throw 'Cannot fetch Auto Task tickets.'
            Write-Error $_
        }
        foreach ($ticket in $tickets) {
            $ticketContact = Get-AtwsContact -Id $ticket.CreatorResourceID
            if (![string]::isnullorwhitespace($ticketContact)) {
                # For tickets opened by a customer - do the following:
                if ($ClientCompany) {
                    if ($ticketContact.EMailAddress -notlike "*$ClientCompany") {
                        continue
                    }
                }
                $ticketTimeEntry = Get-AtwsTimeEntry -TicketID $ticket.Id
                $ticketNotes = @(Get-AtwsTicketNote -TicketID $ticket.Id)
                if (([string]::isnullorwhitespace($ticketTimeEntry)) -and ($ticketNotes.Count -eq 1)) {
                    Write-Verbose "Ticket with id: $($ticket.Id) does not have a first response, trying to answer."
                    $customerName = '{0} {1}' -f $ticketContact.FirstName, $ticketContact.LastName
                    try {
                        $prompt = New-AutoTaskAIPrompt -CustomerName $CustomerName -IssueDescription $ticket.Description
                    }
                    catch {
                        throw 'Cannot create ChatGPT Prompt.'
                        Write-Error $_
                    }
                    try {
                        $chatResponse = Invoke-ChatGPT -ApiKey $GPTApiKey -Question $prompt -GPTModel 'gpt-4'
                    }
                    catch {
                        throw 'Unable to call ChatGPI API.'
                        Write-Error $_
                    }
                    if (([bool]($chatResponse.choices.message.psobject.properties.Name -match 'content')) -and ($null -ne $chatResponse.choices.message.content)) {
                        $noteDescription = $chatResponse.choices.message.content.Replace('"', '')
                    }
                    else {
                        throw 'ChatGPT response does not contain proper response field.'
                    }
                    try {
                        # [void](New-AtwsTicketNote -TicketID $ticket.id -Description $noteDescription -NoteType 'Customer Correspondence' -Publish 'All Autotask Users' -Title 'Customer Support - First Response')
                    }
                    catch {
                        throw 'Cannot add the note to the Auto Task ticket.'
                        Write-Error $_
                    }
                    return([PSCustomObject]@{
                            Ticket   = $ticket
                            Contact  = $ticketContact
                            Response = $noteDescription
                        }
                    )
                }
            }
        }
    }
}