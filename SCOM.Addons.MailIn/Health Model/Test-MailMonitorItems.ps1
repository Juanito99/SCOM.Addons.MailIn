param($sourceId, $managedEntityId, $XMLConfigFilePath, $SCOMAlertResetType, $NoOfLinesFromTop, $EmlDirectory, $EmlArchive)

$api           = New-Object -ComObject 'MOM.ScriptAPI'
$discoveryData = $api.CreateDiscoveryData(0, $sourceId, $managedEntityId)

$Global:Error.Clear()
$ErrorActionPreference = 'Continue' 

$xmlConfigDir             = (Get-Item -Path $XMLConfigFilePath).DirectoryName
$globalSCOMAlertResetType = $SCOMAlertResetType

$localComputerName     = $env:COMPUTERNAME
$localComputerDomain   = ([System.DirectoryServices.ActiveDirectory.Domain]::GetComputerDomain()).Name
$ComputerName          = $localComputerName + '.' + $localComputerDomain

$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItems.ps1',4000,4,"SCOM Addons MailIn Test-MailMonitorItems Started - Source $($sourceId) `
	managEnt $($managedEntityId) XMLConfigFilePath-$($XMLConfigFilePath) and SCOMAlertResetType: $($SCOMAlertResetType) in EmlDirectory $($EmlDirectory)!! on $($ComputerName)")

$XMLConfigFilePath = $XMLConfigFilePath -replace '[^\p{L}\p{Nd}/\\/:/\.]', ''

if ([System.IO.File]::Exists($XMLConfigFilePath)) {
  $foo = "bar"
} else {
  $api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4100,1,"XMLConfigFile not found in: $($XMLConfigFilePath). Script terminated. ")
  exit 
} 

if (Test-Path -Path $EmlDirectory) {
	$foo = "bar"
} else {
	$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1.ps1',4030,1,"SCOM Addons MailIn Monitor - EmlFolder not found!  Looking for: $($EmlDirectory) Script ended.")
	exit 		
}


Function Convert-EmlFile {    

	param  (        
		$EmlFileName    
	)
		
	$adoStream = New-Object -ComObject 'ADODB.Stream'  
	$adoStream.Open()
	$adoStream.LoadFromFile($EmlFileName)    
	$cdoMessageObject = New-Object -ComObject 'CDO.Message'    
	$cdoMessageObject.DataSource.OpenObject($adoStream, '_Stream')
	
	return $cdoMessageObject

} #End Function Convert-EmlFile


$emlFiles = Get-ChildItem -Path $EmlDirectory -Filter *.eml

$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4001,4,"SCOM Addons MailIn - Found No: EML Messages: $($emlFiles.count)")

$allMails = New-object -TypeName System.Collections.Generic.List[psobject]

$regPatReceived = '(?i)(<?Received: from )[\w\.\- ()\[\]]+by'

#preparing objects
foreach ($eml in $emlFiles) {
 
  $bodyHTML = ''
  $bodyText = ''
	
  $emlContent   = Get-Content $eml.FullName -TotalCount 100

  $recvdNo      = [regex]::Matches($emlContent, $regPatReceived).count
  $recvdNoIndex = $recvdNo -1
  $receivedBy   = [regex]::Matches($emlContent, $regPatReceived)[$recvdNoIndex].Value
  $receivedBy   = [regex]::Replace($receivedBy,'(?i)Received: from |(?i) by','')
	
  $emlObj = Convert-EmlFile -EmlFileName $eml.FullName
  
  $bodyHTML = $emlObj.HTMLBody
  $bodyText = $emlObJ.TextBody

  if ($bodyHTML -eq $null -or $bodyHTML -eq '') { $bodyHTML = 'n.a.' } 
  if ($bodyText -eq $null -or $bodyText -eq '') { $bodyText = 'n.a.' }
  if ($bodyText -eq 'n.a.') { $bodyText = $bodyHTML }

  $bodyText = [Regex]::Replace($bodyText,'<[^>]*>',' ')
  $bodyText = [Regex]::Replace($bodyText,'\\s+',' ')
  $bodyText = $bodyText.Trim()
  $bodyText = $bodyText | Select-Object -First $NoOfLinesFromTop
  
  $mailProps = @{
	  mailFrom         = $emlObj.From          -replace '\s','_'
	  mailBody         = $bodyText 
	  mailSubject      = $emlObj.Subject       -replace '\s','_'
	  mailReceived     = $emlobj.ReceivedTime
	  mailSendTime     = $emlObj.SentOn
	  mailRecipient    = $emlObj.To
	  mailSourceServer = $receivedBy           -replace '\s','_'
	  mailFileName     = $eml.FullName    
  }

  $mailObject = New-Object -TypeName psobject -Property $mailProps 
  $allMails.Add($mailObject)  

} #end foreach ($eml in $emlFiles) {}


$allMailMonitorItems = New-object -TypeName System.Collections.Generic.List[psobject]

$xmlFile = [xml](Get-Content -Path $XMLConfigFilePath)

foreach($itm in $xmlFile.MailInMonitorList.MailMonitorItem) {
	  
  [string]$uniqueTitle                 = $itm.UniqueTitle		-replace '\s','_'
  [string]$description                 = $itm.Description		
  [string]$mailFrom                    = $itm.MailFrom			-replace '\s','_'
  [string]$mailSubject                 = $itm.MailSubject		-replace '\s','_'
  [string]$mailBody                    = $itm.MailBody			
  [string]$mailSourceServer            = $itm.MailSourceServer	-replace '\s','_'
  [string]$SCOMAlertResetType          = $itm.SCOMAlertResetType
  [int]$SCOMAlertResetTimeInSeconds    = $itm.SCOMAlertResetTimeInSeconds

	if ([String]::IsNullOrEmpty($uniqueTitle)) { 
		$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4110,2,"MailItem: $description $mailFrom $mailSubject `
		$mailBody $mailSourceServer has no UniqueTitle. Skipped! . ")
		continue
	}
	if ([String]::IsNullOrEmpty($mailFrom)) { 
		$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4110,2,"MailItem: $description $uniqueTitle $mailSubject `
		$mailBody $mailSourceServer has no MailFrom. Skipped! . ")
		continue
	}
	if ([String]::IsNullOrEmpty($SCOMAlertResetType)) {  
		$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4110,4,"MailItem: $description $mailFrom $mailSubject `
		$mailBody $mailSourceServer $uniqueTitle has no SCOMAlertResetType, defaulting to TIMER based.. ")
		$SCOMAlertResetType = "Timer"
		$SCOMAlertResetTimeInSeconds = 3600
	}
	if (($SCOMAlertResetType -ieq "Timer") -and ($SCOMAlertResetTimeInSeconds -lt 900)) {
		$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4110,2,"MailItem: $description $mailFrom $mailSubject `
		$mailBody $mailSourceServer $uniqueTitle has a SCOMAlertResetTimerInSeconds of. `n $($SCOMAlertResetTimeInSeconds) To avoid malfunction, it is set to 900 ( 15 minutes ). ")		
		$SCOMAlertResetTimeInSeconds = 3600
	}
	
	if ([String]::IsNullOrEmpty($description))      { $description = "" }  
	if ([String]::IsNullOrEmpty($mailSubject))      { $mailSubject = "" }
	if ([String]::IsNullOrEmpty($mailBody))         { $mailBody = "" }
	if ([String]::IsNullOrEmpty($mailSourceServer)) { $mailSourceServer = "" }

	$mItmProps = @{
		UniqueTitle                 = $uniqueTitle
		Description                 = $description
		MailFrom                    = $mailFrom
		MailSubject                 = $mailSubject
		MailBody                    = $mailBody
		MailSourceServer            = $mailSourceServer
		SCOMAlertResetType          = $SCOMAlertResetType
		SCOMAlertResetTimeInSeconds = $SCOMAlertResetTimeInSeconds
	}

	$mItmObj = New-Object -TypeName psobject -Property $mItmProps 

	$allMailMonitorItems.Add($mItmObj)

} #end foreach($itm in $xmlFile.MailInMonitorList.MailMonitorItem) {}

#$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4111,2,"allMonitorItems Count: $($allMailMonitorItems.count)  ")

$filteredItems = ''
if ($globalSCOMAlertResetType -ieq 'Manual') {
	$filteredItems = $allMailMonitorItems | Where-Object { $_.SCOMAlertResetType -ieq 'Manual' }
} else {
	$filteredItems = $allMailMonitorItems | Where-Object { $_.SCOMAlertResetType -ieq 'Timer' }
}

#resetting monitors if time is up.
if ($globalSCOMAlertResetType -ieq 'Timer') {
	
	foreach ($fItem in $filteredItems) {
					
		$uniqueTitle                 = ''
		$description                 = ''
		$mailFrom                    = ''
		$mailSubject                 = ''
		$mailBody                    = ''
		$mailSourceServer            = ''
		$SCOMAlertResetType          = ''
		$SCOMAlertResetTimeInSeconds = ''
		
		[string]$uniqueTitle                 = $fItem.UniqueTitle
		[string]$description                 = $fItem.Description		
		[string]$mailFrom                    = $fItem.MailFrom	
		[string]$mailSubject                 = $fItem.MailSubject
		[string]$mailBody                    = $fItem.MailBody			
		[string]$mailSourceServer            = $fItem.MailSourceServer
		[string]$SCOMAlertResetType          = $fItem.SCOMAlertResetType
		[string]$SCOMAlertResetTimeInSeconds = $fItem.SCOMAlertResetTimeInSeconds

		$monFileName = "_AlertRaised_" + $uniqueTitle + "_" + $SCOMAlertResetTimeInSeconds + "_DoNotDelete_.txt" 	
		$monFilePath = Join-Path -Path $xmlConfigDir -ChildPath $monFileName
		
		if ([System.IO.File]::Exists($monFilePath)) {

			$monFilelastWriteTime    = Get-Item -Path $monFilePath | Select-Object -ExpandProperty LastWriteTime	
			$timeSinceAlertInSeconds = (New-Timespan -Start $monFilelastWriteTime -End (Get-Date)).TotalSeconds -as [int]	
			[int]$definedResetTime   = $fItem.SCOMAlertResetTimeInSeconds
				
			if ($timeSinceAlertInSeconds -le $definedResetTime) {
				$foo = " -- NO RESET because: timeSinceAlert $($timeSinceAlertInSeconds) - MaxAge: $($definedResetTime)"
			} else {				
				$bag = $api.CreatePropertybag()			
				$bag.AddValue("UniqueTitle",$($uniqueTitle))
				$bag.AddValue("MailSubject",$($mailSubject))			
				$bag.AddValue("MailFrom",$($mailFrom))		
				$bag.AddValue("MailBody", "Time to reset. - Seconds found in XML $($SCOMAlertResetTimeInSeconds)")	
				$bag.AddValue("MailSourceServer",$($mailSourceServer))	
				$bag.AddValue("mMetaInfo"," The monitor was timer resetted.`n Value has been taken from $($XMLConfigFilePath)`n`n If no value set, default one is 3600 seconds.")		
				$bag.AddValue("State","Success")					
				$bag	
			}
		} else {  
			$foo = 'No need to check. No Alert happened yet.'
		}

	} # end foreach ($fItem in $filteredItems) {}

} else  {  

	$foo = 'Manual reset Monitor!'

} # end if ($globalSCOMAlertResetType -ieq 'Timer') {}


foreach ($mail in $allMails) {
	
	foreach ($fItem in $filteredItems) {
	
		$bSendAlert     = $false

		$fiSubject      = ''
		$fiFrom         = ''
		$fiBody         = ''
		$fiSourceServer = ''
		$fiUniqueTitle  = ''
		$fiAlertTimer   = ''
		
		$bMailFrom         = $false
		$bMailSubject      = $false
		$bMailSourceServer = $false
		$bMailBody         = $false
				
		$fiSubject      = $fItem.MailSubject
		$fiFrom         = $fItem.mailFrom
		$fiBody         = $fItem.MailBody
		$fiSourceServer = $fItem.MailSourceServer  
		$fiUniqueTitle  = $fItem.UniqueTitle  
		$fiAlertTimer   = $fItem.SCOMAlertResetTimeInSeconds
	
	if ($fiFrom -ne '') {
		if ($($mail.mailFrom) -match "$($fiFrom)") { 		
			$bMailFrom = $true
		} else { 		
			$bMailFrom = $false 
		} 			  
	}
	if ($fiSubject -ne '') {
		if ($mail.mailSubject -match "$($fiSubject)") {        		
			$bMailSubject = $true
		} else { 		
			$bMailSubject = $false
		}
	}	
	if ($fiSourceServer -ne '')	{
		if ($mail.mailSourceServer -match "$($fiSourceServer)") { 		
			$bMailSourceServer = $true
		} else { 		
			$bMailSourceServer = $false
		}
	}
	if ($fiBody -ne '') {
		if ($mail.mailBody -match "$($fiBody)") { 			
			$bMailBody = $true
		} else { 			
			$bMailBody = $false
		}
	}		

	if ($fiFrom -ne '' -and $fiSubject -ne '' -and $fiSourceServer -ne '' -and $fiBody -ne '') {
		if ($bMailFrom -and $bMailSubject -and $bMailSourceServer -and $bMailBody) {		  
			$bSendAlert = $true		
		}
	} elseif ($fiFrom -ne '' -and $fiSubject -ne '' -and $fiSourceServer -ne '') {
		if ($bMailFrom -and $bMailSubject -and $bMailSourceServer)  {		  		
			$bSendAlert = $true		  
		}
	} elseif ($fiFrom -ne '' -and $fiSubject -ne '') {
		if ($bMailFrom -and $bMailSubject)  {		  		
			$bSendAlert = $true		  
		}      
	} elseif ($fiFrom -ne '' -and $fiSourceServer -ne '') {
		if ($bMailFrom -and $bMailSourceServer) {		  
			$bSendAlert = $true		  
		}      
	} elseif ($fiFrom -ne '' -and $fiBody -ne '') {
		if ($bMailFrom -and $bMailBody) {		  		  		  
			$bSendAlert      = $true		  
		}          
	} elseif ($fiSourceServer -ne '' -and $fiBody -ne '') {
		if ($bMailSourceServer -and $bMailBody) {				
			$bSendAlert = $true		
		}          
	} 

	if ($bSendAlert) {

		$mMetaInfo  = "`n Send at:`t$($mail.mailSendTime)`n Received at:`t$($mail.mailReceived)`n Addressed to:`t$($mail.mailRecipient) `
			`n Send by Host:`t$($mail.mailSourceServer)`n Subject:`t$($mail.mailSubject) "			

		$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4003,4,"SCOM Addons MailIn Monitor BAG `n
			UniqueTitle $($fiUniqueTitle) `n
			mSubject: $($fiSubject) `t mail.MailSubject $($mail.mailSubject)`n
			mFrom: $($fiFrom) `t mail.mailFrom $($mail.mailFrom)`n 
			mfSubject $($fiSubject) `t mail.mailSubject $($mail.mailSubject)`n
			mfBody $($fiBody) `t mail.mailBody: $($mail.mailBody)`n  				 
			mfSourceServer $($fiSourceServer) `t mail.mailSourceServer $($mail.mailSourceServer) `n
			`n`n mMetaInfo: $($mMetaInfo) " )

			$bag = $api.CreatePropertybag()			
			$bag.AddValue("UniqueTitle",$fiUniqueTitle)
			$bag.AddValue("MailSubject",$mail.mailSubject)			
			$bag.AddValue("MailFrom",$mail.mailFrom)		
			$bag.AddValue("MailBody",$mail.mailBody)	
			$bag.AddValue("MailSourceServer",$fiSourceServer)	
			$bag.AddValue("mMetaInfo",$mMetaInfo)		
			$bag.AddValue("State","Failure")			
			$bag			

			$monFileName = "_AlertRaised_" + $fiUniqueTitle + "_" + $fiAlertTimer + "_DoNotDelete_.txt" 
			$null = New-Item -Path $xmlConfigDir -ItemType File -Name $monFileName -Value $abc -Force

			$bSendAlert = $true		
			Move-Item -Path $mail.mailFileName -Destination $emlArchive -Force			

			if ($error) {
				$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4033,1,"SCOM Addons MailIn Error $($error) ")
			} else {
				$api.LogScriptEvent('SCOM.Addons.MailIn Test-MailMonitorItem.ps1',4033,4,"SCOM Addons MailIn NO Error ")
			} 	  
							   
		} else {

		  $foo = "no bag"

		} # end if ($bSendAlert -eq $true)

	} # end foreach ($fItem in $filteredItems) {}

} # end foreach ($mail in $allMails) {}

