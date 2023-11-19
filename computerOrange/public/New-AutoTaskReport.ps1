function New-AutoTaskReport {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ApiUserName,

        [Parameter(Mandatory)]
        [string]$ApiSecret,

        [Parameter(Mandatory)]
        [string]$ApiIntegrationCode,

        [Parameter(Mandatory)]
        [string]$WebhookUrl,

        [Parameter(Mandatory)]
        [string]$ChatGPTApiKey,

        [int]$Hours = 23
    )
    begin {
        $moduleList = 'AutoTask'
        foreach ($module in $moduleList) {
            if (-not (Get-Module $module -ListAvailable)) {
                Install-Module $module -Scope CurrentUser -Force -Confirm:$false
            }
        }
        $apiEncryptedPassword = ConvertTo-SecureString -String ('{0}' -f $ApiSecret) -AsPlainText -Force
        $credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $ApiUserName, $apiEncryptedPassword
        Connect-AtwsWebAPI -Credential $credential -ApiTrackingIdentifier $ApiIntegrationCode
        $date = (Get-Date).AddHours(-$hours)
        $autoTaskData = [System.Collections.ArrayList]::new()
    }
    process {
        $timeEntries = Get-AtwsTimeEntry -All | Where-Object {$_.LastModifiedDateTime -gt $date}
        $userIds = $timeEntries.LastModifiedUserID | Select-Object -Unique
        foreach ($userId in $userIds) {
            $user = Get-AtwsResource -Id $userId
            $userObject = [PSCustomObject]@{
                FirstName   = $user.FirstName
                LastName    = $user.LastName
                Email       = $user.Email
                UserId      = $user.Id
                Tickets     = [System.Collections.ArrayList]::new()
                SummaryTime = 0
            }
            foreach ($timeEntry in $timeEntries) {
                if ($timeEntry.LastModifiedUserID -eq $userId) {
                    $ticket = $false
                    $ticketAccount = $false
                    if ($timeEntry.PSObject.Properties.Name -contains 'TicketID' -and $null -ne $timeEntry.TicketID) {
                        $ticket = Get-AtwsTicket -Id $timeEntry.TicketID
                        $ticketAccount = Get-AtwsAccount -Id $ticket.AccountID
                    }
                    $timeEntryData = [PSCustomObject]@{
                        Ticket      = if ($ticket) { $ticket.Title } else { $timeEntry.TypeLabel }
                        Account     = if ($ticketAccount) { $ticketAccount.AccountName } else { 'Computer Orange' }
                        Notes       = $timeEntry.SummaryNotes
                        HoursWorked = $timeEntry.HoursWorked
                        NonBillable = $timeEntry.NonBillable
                    }
                    [void]($userObject.Tickets.Add($timeEntryData))
                    $userObject.SummaryTime += $timeEntry.HoursWorked
                }
            }
            [void]($autoTaskData.Add($userObject))
        }
    }
    end {
        foreach ($userObject in $autoTaskData) {
            # Create the payload for the Teams webhook
            $payload = @{
                "@type"    = "MessageCard"
                "@context" = "http://schema.org/extensions"
                "summary"  = "AutoTask Report"
                "sections" = @()
            }
    
            $section = @{
                "activityTitle"    = "$($userObject.FirstName) $($userObject.LastName) - $([System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date).AddDays(-1), 'Eastern Standard Time').ToString('dd-MM-yyyy'))"
                "activitySubtitle" = "$($userObject.Email)"
                "activityText"     = "Total hours: $($userObject.SummaryTime)"
                "facts"            = @()
            }
    
            foreach ($ticket in $userObject.Tickets) {
                $rephrasedNotes = $null
                if ($ticket.Notes.Length -gt 100) {
                    $rephrasedNotes = Invoke-ChatGPT -ApiKey $ChatGPTApiKey -Question ('Shorten/rephrase the following text to one sentence and the maximum of 100 characters: {0}' -f $ticket.Notes)
                    $rephrasedNotes = $rephrasedNotes.choices.message.content -replace '\s*\(\d+\s+characters\)', ''
                }

                $section.facts += @{
                    "name"  = "Ticket"
                    "value" = $ticket.Ticket
                },
                @{
                    "name"  = "Account"
                    "value" = $ticket.Account
                },
                @{
                    "name"  = "Notes"
                    "value" = if ($null -ne $rephrasedNotes) { $rephrasedNotes } else { $ticket.Notes }
                },
                @{
                    "name"  = "Hours Worked"
                    "value" = $ticket.HoursWorked
                },
                @{
                    "name"  = "Non-Billable"
                    "value" = $ticket.NonBillable
                }
            }
    
            $payload.sections += $section
    
            # Convert the payload to a JSON string
            $payloadJson = $payload | ConvertTo-Json -Depth 4
    
            # Send the payload to the Teams webhook
            try {
                Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payloadJson -ContentType 'application/json'
            }
            catch {
                Start-Sleep -Seconds 5
                Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $payloadJson -ContentType 'application/json'
            }
        }
    }
}