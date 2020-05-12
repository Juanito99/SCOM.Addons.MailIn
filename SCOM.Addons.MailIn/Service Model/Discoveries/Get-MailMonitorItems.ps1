param($sourceId, $managedEntityId, $XMLConfigFilePath)

$api           = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$Global:Error.Clear()
$ErrorActionPreference = 'Continue' 

$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3100,4,"SCOM Addons MailIn Get-MailMonitorItem Started - Source $($sourceId) `
	managEnt $($managedEntityId) XMLConfigFilePath-$($XMLConfigFilePath)-!!")

$XMLConfigFilePath = $XMLConfigFilePath -replace '[^\p{L}\p{Nd}/\\/:/\.]', ''

if ([System.IO.File]::Exists($XMLConfigFilePath)) {
  $foo = "bar"
} else {
  $api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3101,1,"XMLConfigFile not found in: $($XMLConfigFilePath). Script terminated. ")
  exit 
}

$allMailMonitorItems = New-object -TypeName System.Collections.Generic.List[psobject]

$xmlFile = [xml](Get-Content -Path $XMLConfigFilePath)

foreach($itm in $xmlFile.MailInMonitorList.MailMonitorItem) {
	
  [string]$uniqueTitle                  = $itm.UniqueTitle		-replace '\s','_'
  [string]$description                  = $itm.Description		
  [string]$mailFrom                     = $itm.MailFrom			-replace '\s','_'
  [string]$mailSubject                  = $itm.MailSubject		-replace '\s','_'
  [string]$mailBody                     = $itm.MailBody			
  [string]$mailSourceServer             = $itm.MailSourceServer	-replace '\s','_'
  [string]$SCOMAlertResetType           = $itm.SCOMAlertResetType
  [string]$SCOMAlertResetTimeInSeconds  = $itm.SCOMAlertResetTimeInSeconds

  if ([String]::IsNullOrEmpty($uniqueTitle)) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3110,2,"MailItem: $description $mailFrom $mailSubject `
	$mailBody $mailSourceServer has no UniqueTitle. Skipped! . ")
	continue
	}

  if ([String]::IsNullOrEmpty($mailFrom)) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3110,2,"MailItem: $description $uniqueTitle $mailSubject `
	$mailBody $mailSourceServer has no MailFrom. Skipped! . ")
	continue
  }
  if ([String]::IsNullOrEmpty($SCOMAlertResetType)) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3110,4,"MailItem: $description $mailFrom $mailSubject `
	$mailBody $mailSourceServer $uniqueTitle has SCOMAlertResetType, defaulting to TIMER based.. ")
	$SCOMAlertResetType = "Timer"
  }
  if ([String]::IsNullOrEmpty($SCOMAlertResetTimeInSeconds) -and ($SCOMAlertResetType -ieq 'Timer') ) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3110,3,"MailItem: $description $mailFrom $mailSubject `
	$mailBody $mailSourceServer $uniqueTitle has SCOMAlertResetType Time and no value, defaulting to 3600 seconds . ")
	$SCOMAlertResetTimeInSeconds = 3600
  }
  if ($SCOMAlertResetType -ieq 'Manual') { 
	$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3110,2,"MailItem: $description $mailFrom $mailSubject `
	$mailBody $mailSourceServer $uniqueTitle has SCOMAlertResetType to Manal and value in SCOMAlertimerValue $($SCOMAlertResetTimeInSeconds), set to 0 ")
	[string]$SCOMAlertResetTimeInSeconds = "0"
  }
  if ([String]::IsNullOrEmpty($description))      { $description = "" }  
  if ([String]::IsNullOrEmpty($mailSubject))      { $mailSubject = "" }
  if ([String]::IsNullOrEmpty($mailBody))         { $mailBody = "" }
  if ([String]::IsNullOrEmpty($mailSourceServer)) { $mailSourceServer = "" }

  $mItmProps = @{
	UniqueTitle                  = $uniqueTitle
	Description                  = $description
	MailFrom                     = $mailFrom
	MailSubject                  = $mailSubject
	MailBody                     = $mailBody
	MailSourceServer             = $mailSourceServer
	SCOMAlertResetType           = $SCOMAlertResetType
	SCOMAlertResetTimeInSeconds  = $SCOMAlertResetTimeInSeconds
  }

  $mItmObj = New-Object -TypeName psobject -Property $mItmProps 

  $allMailMonitorItems.Add($mItmObj)

} #end foreach($itm in $xmlFile.MailInMonitorList.MailMonitorItem) {}

$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3111,2,"allMonitorItems Count: $($allMailMonitorItems.count)  ")

foreach ($mItm in $allMailMonitorItems) {
		
	if ($mItm.SCOMAlertResetType -ieq 'Manual') {
		$displayName = 'MailMonitor-' + $mItm.UniqueTitle + '-ManualReset'
		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem.ManualReset']$")
	} else {
		$displayName = 'MailMonitor-' + $mItm.UniqueTitle + '-TimerReset'
		$instance = $discoveryData.CreateClassInstance("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem.TimerReset']$")
	}

	$api.LogScriptEvent('SCOM.Addons.MailIn GetMailMonitorItems.ps1',3121,4,"Adding $($displayName) ")
	
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/UniqueTitle$",$mItm.UniqueTitle)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/Description$",$mItm.Description)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/MailFrom$",$mItm.MailFrom)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/MailSubject$",$mItm.MailSubject)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/MailBody$",$mItm.MailBody)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/MailSourceServer$",$mItm.MailSourceServer)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/SCOMAlertResetType$",$mItm.SCOMAlertResetType)
	$instance.AddProperty("$MPElement[Name='SCOM.Addons.MailIn.MailMonitorItem']/SCOMAlertResetTimeInSeconds$",$mItm.SCOMAlertResetTimeInSeconds)
	$instance.AddProperty("$MPElement[Name='System!System.Entity']/DisplayName$", $displayName)
	$discoveryData.AddInstance($instance)		
	
}

$discoveryData