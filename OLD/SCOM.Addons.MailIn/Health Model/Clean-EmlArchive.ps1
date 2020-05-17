param($sourceId, $managedEntityId, $EmlArchive, $EmlRetentionHours)

$api  = New-Object -ComObject 'MOM.ScriptAPI'

$Global:Error.Clear()
$ErrorActionPreference = 'Continue'

$api.LogScriptEvent('SCOM.Addons.MailIn Clean-EmlArchive.ps1',5000,4,"SCOM Addons MailIn Clean-EmlArchive Rule Started - Source $($sourceId) `
	managEnt $($managedEntityId) EmlArc: $($EmlArchive) #RetentionHours:$($EmlRetentionHours)  ")


if (Test-Path -Path $EmlArchive) {
	$foo = "bar"
} else {
	$api.LogScriptEvent('SCOM.Addons.MailIn Clean-EmlArchive.ps1',5001,1,"SCOM Addons MailIn Rule - EmlArchive folder not found!`
		Looking for: $($EmlArchive). Exiting cleanup script..")
	exit
}

$noEmlArchiveFiles = 0
$emlArchiveFiles   = Get-ChildItem -Path $EmlArchive -Filter *.eml
$noEmlArchiveFiles = $emlArchiveFiles.Count

$arrDeletedEmlFiles = New-Object -TypeName System.Collections.ArrayList

if ($noEmlArchiveFiles -gt 1) {
	
	foreach ($emlFile in $emlArchiveFiles) {
		
		$timeSinceAlertInHours = (New-Timespan -Start $emlFile.LastWriteTime -End (Get-Date)).TotalHours -as [int]	
  
		If ($timeSinceAlertInHours -ge $EmlRetentionHours ) {
						
			$emlItem = ""
			$emlItem = $emlFile.Name + '_timeSinceAlertInHours_' + $timeSinceAlertInHours 
			$arrDeletedEmlFiles.Add($emlItem)    
			Remove-Item -Path $emlFile.FullName -Force

		} #end If ($timeSinceAlertInHours -ge $EmlRetentionHours ) {}

	} #end foreach ($emlFile in $emlArchiveFiles) {}
		
	$title    = "Removes archived eml files in folder $($EmlArchive) older than $($EmlRetentionHours) hours."
	$EmlCount = $noEmlArchiveFiles
	$EmlToDel = $arrDeletedEmlFiles.Count
	$EmlInfo  = $arrDeletedEmlFiles -join "; "

	$api.LogScriptEvent('SCOM.Addons.MailIn Clean-EmlArchive.ps1',5002,4,"SCOM Addons MailIn Clean-EmlArchive Rule `
		Title: $($title) `n EmlCount: $($EmlCount) `n EmlToDel: $($EmlToDel) `n EmlInfo: $($EmlInfo) ")

	if ($arrDeletedEmlFiles.Count -gt 0) {
		$bag = $api.CreatePropertybag()					
		$bag.AddValue("Title",$title)	
		$bag.AddValue("EmlCount",$EmlCount)
		$bag.AddValue("EmlToDel",$EmlToDel)	
		$bag.AddValue("EmlInfo",$EmlInfo)			
		$bag.AddValue("Result","BAD")		
		$bag
	} else {
		$foo = 'No bag. - Rule message with 0 does not make sense.'
	}
	
} #end if ($emlArchiveFiles.count -gt 1) {}

