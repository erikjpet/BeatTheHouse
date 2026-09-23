Set-StrictMode -Version Latest

function Get-Rw062RequiredPublicProperty {
    param(
        [AllowNull()]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )
    if ($null -eq $InputObject) {
        throw "$Context is missing."
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context is missing required public property '$Name'."
    }
    return $property.Value
}


function Select-GrandFareMachineJamChoice {
    param(
        [Parameter(Mandatory = $true)]$EventPopup,
        [Parameter(Mandatory = $true)]$Talk,
        [Parameter(Mandatory = $true)]$HeatLevel
    )

    $talkVisible = Get-Rw062RequiredPublicProperty -InputObject $Talk -Name 'visible' -Context 'Talk surface'
    if ($talkVisible -isnot [bool] -or [bool]$talkVisible) {
        throw 'Grand fare recovery refuses a visible, missing, or non-boolean TalkDock state.'
    }

    $eventVisible = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'visible' -Context 'Event popup'
    if ($eventVisible -isnot [bool] -or -not [bool]$eventVisible) {
        throw 'Grand fare recovery requires one explicitly visible event popup before applying its allowlist.'
    }
    $eventId = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'event_id' -Context 'Event popup'
    if ($eventId -isnot [string] -or [string]$eventId -cne 'machine_jam') {
        throw "Grand fare recovery refuses unknown event '$eventId'."
    }
    $blocking = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'blocking' -Context 'machine_jam event'
    $dismissible = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'dismissible' -Context 'machine_jam event'
    $popupType = Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'popup_type' -Context 'machine_jam event'
    if ($blocking -isnot [bool] -or -not [bool]$blocking -or
        $dismissible -isnot [bool] -or [bool]$dismissible -or
        $popupType -isnot [string] -or [string]$popupType -cne 'triggered_event') {
        throw 'The public machine_jam modal shape changed; Grand fare recovery will not guess through it.'
    }

    $choiceIds = @(Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'choice_ids' -Context 'machine_jam event')
    $exactWaitIds = @($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq 'wait' })
    $exactPushIds = @($choiceIds | Where-Object { $_ -is [string] -and [string]$_ -ceq 'push' })
    if ($choiceIds.Count -ne 2 -or $exactWaitIds.Count -ne 1 -or $exactPushIds.Count -ne 1) {
        throw 'The public machine_jam choice-id allowlist must contain exactly one wait and one push.'
    }

    $choices = @(Get-Rw062RequiredPublicProperty -InputObject $EventPopup -Name 'choices' -Context 'machine_jam event')
    if ($choices.Count -ne 2) {
        throw "The public machine_jam event must expose exactly two rendered choices; found $($choices.Count)."
    }
    $expectedConsequences = @{
        wait = 'Bankroll -3; Heat -3'
        push = 'Heat +6'
    }
    foreach ($choiceId in @('wait', 'push')) {
        $matches = @($choices | Where-Object {
            $idProperty = $_.PSObject.Properties['id']
            $null -ne $idProperty -and $idProperty.Value -is [string] -and [string]$idProperty.Value -ceq $choiceId
        })
        if ($matches.Count -ne 1) {
            throw "The public machine_jam choice '$choiceId' is missing or ambiguous."
        }
        $choice = $matches[0]
        $enabled = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'enabled' -Context "machine_jam choice '$choiceId'"
        $requiresConfirm = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'requires_confirm' -Context "machine_jam choice '$choiceId'"
        $consequence = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'consequence_summary' -Context "machine_jam choice '$choiceId'"
        $impact = Get-Rw062RequiredPublicProperty -InputObject $choice -Name 'impact_summary' -Context "machine_jam choice '$choiceId'"
        if ($enabled -isnot [bool] -or -not [bool]$enabled) {
            throw "The public machine_jam choice '$choiceId' is disabled or has a non-boolean enabled state."
        }
        if ($requiresConfirm -isnot [bool] -or -not [bool]$requiresConfirm) {
            throw "The public machine_jam choice '$choiceId' no longer requires its visible confirmation step."
        }
        $expected = [string]$expectedConsequences[$choiceId]
        if ($consequence -isnot [string] -or [string]$consequence -cne $expected -or
            $impact -isnot [string] -or [string]$impact -cne $expected) {
            throw "The public machine_jam consequence for '$choiceId' changed; Grand fare recovery will not guess through it."
        }
    }

    if ($HeatLevel -isnot [byte] -and $HeatLevel -isnot [sbyte] -and
        $HeatLevel -isnot [int16] -and $HeatLevel -isnot [uint16] -and
        $HeatLevel -isnot [int32] -and $HeatLevel -isnot [uint32] -and
        $HeatLevel -isnot [int64] -and $HeatLevel -isnot [uint64]) {
        throw 'Grand fare recovery requires an integral public heat level.'
    }
    if ([long]$HeatLevel -lt 0) {
        throw 'Grand fare recovery refuses a negative public heat level.'
    }

    if ([long]$HeatLevel -le 24) {
        return 'push'
    }
    return 'wait'
}
