param($sourceId, $managedEntityId, $AlertRetentionHours)

$api  = New-Object -ComObject 'MOM.ScriptAPI'

$Global:Error.Clear()
$ErrorActionPreference = 'Continue'

$api.LogScriptEvent('SCOM.Addons.MailIn Clean-GenericMailAlerts.ps1',6000,4,"SCOM Addons MailIn Clean-GenericMailAlerts Rule Started - Source $($sourceId) `
	managEnt $($managedEntityId) #RetentionHours:$($AlertRetentionHours)  ")


$allGenericMailAlerts    = 0
$closedGenericMailAlerts = 0
$alertRuleId   = Get-SCOMRule -Name 'SCOM.Addons.MailIn.Generic.Alert.Rule' | Select-Object -ExpandProperty Id
$allOpenAlerts = Get-ScomAlert -ResolutionState 0 | Where-Object {$_.RuleId -eq $alertRuleId}

$allGenericMailAlerts = $allOpenAlerts.count

if ($allGenericMailAlerts -gt 1) {
	
	foreach ($alert in $allOpenAlerts) {

		$timeSinceAlertInHours = (New-Timespan -Start $alert.TimeRaised -End (Get-Date)).TotalHours -as [int]	
  
		If ($timeSinceAlertInHours -ge $AlertRetentionHours ) { 
			$alertComment = "Autoclosed by rule SCOM.Addons.MailIn.CloseAlerts.Rule. AlertRentionInHours: $($AlertRetentionHours) - `
				Time since raise in hours: $($timeSinceAlertInHours)  "
			$alert | Set-SCOMAlert -ResolutionState 255 -Comment $alertComment
			$closedGenericMailAlerts = $closedGenericMailAlerts + 1
		} 

	}
}

$genericAlertInfo = "All Generic Mail Alerts: $($allGenericMailAlerts), Closed: $($closedGenericMailAlerts)"



$allCleanEmlArchiveAlerts    = 0
$closedCleanEmlArchiveAlerts = 0
$alertRuleId   = Get-SCOMRule -Name 'SCOM.Addons.MailIn.CleanEmlArchive.Rule' | Select-Object -ExpandProperty Id
$allOpenAlerts = Get-ScomAlert -ResolutionState 0 | Where-Object {$_.RuleId -eq $alertRuleId}

$allCleanEmlArchiveAlerts    = $allOpenAlerts.count
if ($allCleanEmlArchiveAlerts -gt 1) {
	foreach ($alert in $allOpenAlerts) {

		$timeSinceAlertInHours = (New-Timespan -Start $alert.TimeRaised -End (Get-Date)).TotalHours -as [int]	  

		If ($timeSinceAlertInHours -gt 1) { 
			$alertComment = "Autoclosed by rule SCOM.Addons.MailIn.CloseAlerts.Rule. Info messges closed if older than 1 hour. - `
				Time since raise in hours: $($timeSinceAlertInHours)  "
			$alert | Set-SCOMAlert -ResolutionState 255 -Comment $alertComment
			$closedCleanEmlArchiveAlerts = $closedCleanEmlArchiveAlerts + 1
		} 

	} 
}

$cleanEmlArchiveAlertInfo = "All Clean Eml Archive Alerts: $($allCleanEmlArchiveAlerts), Closed: $($closedCleanEmlArchiveAlerts)"



$allCloseAlertsAlerts    = 0
$closedCloseAlertsAlerts = 0
$alertRuleId   = Get-SCOMRule -Name 'SCOM.Addons.MailIn.CloseAlerts.Rule' | Select-Object -ExpandProperty Id
$allOpenAlerts = Get-ScomAlert -ResolutionState 0 | Where-Object {$_.RuleId -eq $alertRuleId}
$allCloseAlertsAlerts    = $allOpenAlerts.count

if ($allCloseAlertsAlerts -gt 1) {
	foreach ($alert in $allOpenAlerts) {

		$timeSinceAlertInHours = (New-Timespan -Start $alert.TimeRaised -End (Get-Date)).TotalHours -as [int]	  

		If ($timeSinceAlertInHours -gt 1) { 
			$alertComment = "Autoclosed by rule SCOM.Addons.MailIn.CloseAlerts.Rule. Info messges closed if older than 1 hour. - `
				Time since raise in hours: $($timeSinceAlertInHours)  "
			$alert | Set-SCOMAlert -ResolutionState 255 -Comment $alertComment
			$closedCloseAlertsAlerts = $closedCloseAlertsAlerts + 1
		} 

	} 
}

$closedAlertsAlertInfo = "All CloseAlerts Alerts: $($allCloseAlertsAlerts), Closed: $($closedCloseAlertsAlerts)"

$api.LogScriptEvent('SCOM.Addons.MailIn Clean-GenericMailAlerts.ps1',6001,4,"SCOM Addons MailIn Clean-GenericMailAlerts Rule `
	`nGenericAlertInfo: $($genericAlertInfo) `
	`nCleanEmlArchiveAlertInfo: $($cleanEmlArchiveAlertInfo) `
	`nClosedAlertsAlertInfo: $($closedAlertsAlertInfo) ")

$title = 'This rule (SCOM.Addons.MailIn.CloseAlerts.Rule) closes all GenericAlertMails older than: ' + $AlertRetentionHours + ' hours. All info messages are deleted after 1 hour.'

if ($allGenericMailAlerts -gt 1) {
	$bag = $api.CreatePropertybag()					
	$bag.AddValue("Title",$title)	
	$bag.AddValue("GenericAlertInfo",$genericAlertInfo)
	$bag.AddValue("CleanEmlArchiveAlertInfo",$cleanEmlArchiveAlertInfo)	
	$bag.AddValue("ClosedAlertsAlertInfo",$closedAlertsAlertInfo)			
	$bag.AddValue("Result","BAD")		
	$bag
} else {
	$foo = 'No bag. - Rule message with 0 does not make sense.'
}

