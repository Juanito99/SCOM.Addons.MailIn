param($sourceId, $managedEntityId, $NoOfLinesFromTop, $EmlDirectory, $EmlArchive, $XMLConfigFilePath)

$api  = New-Object -ComObject 'MOM.ScriptAPI'

$Global:Error.Clear()
$ErrorActionPreference = 'Continue'

$xmlConfigDir  = (Get-Item -Path $XMLConfigFilePath).DirectoryName

$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3000,4,"SCOM Addons MailIn Rule Started - Source $($sourceId) `
	managEnt $($managedEntityId) EmlDir: $($EmlDirectory) EmlArc: $($EmlArchive) #LinesFT:$($NoOfLinesFromTop)  ")

if (Test-Path -Path $EmlDirectory) {
	$foo = "bar"
} else {
	$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3030,1,"SCOM Addons MailIn Rule - EmlFolder not found!  Looking for: $($EmlDirectory) Script ended.")
	exit 		
}

if (Test-Path -Path $EmlArchive) {
	$foo = "bar"
} else {
	$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3030,2,"SCOM Addons MailIn Rule - EmlArchive folder not found!  Looking for: $($EmlArchive). Folder will be created now.")
	New-Item -Path $EmlArchive	 		
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

$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3001,4,"SCOM Addons MailIn - `
	Found No: EML Messages: $($emlFiles.count)")

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
  $bodyText =[Regex]::Replace($bodyText,'\\s+',' ')
  $bodyText = $bodyText.Trim()
  
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


#getting all defined monitors
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
  [string]$SCOMAlertResetTimeInSeconds = $itm.SCOMAlertResetTimeInSeconds

  if ([String]::IsNullOrEmpty($uniqueTitle)) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3110,2,"MailItem: $description $mailFrom $mailSubject `
	$mailBody $mailSourceServer has no UniqueTitle. Skipped! . ")
	continue
	}

  if ([String]::IsNullOrEmpty($mailFrom)) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3110,2,"MailItem: $description $uniqueTitle $mailSubject `
	$mailBody $mailSourceServer has no MailFrom. Skipped! . ")
	continue
  }
  if ([String]::IsNullOrEmpty($SCOMAlertResetType)) { 
	$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3110,4,"MailItem: $description $mailFrom $mailSubject `
	$mailBody $mailSourceServer $uniqueTitle has SCOMAlertResetType, defaulting to TIMER based.. ")
	$SCOMAlertResetType = "Timer"
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

$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3111,2,"allMonitorItems Count: $($allMailMonitorItems.count)  ")

$allAlertMails = New-object -TypeName System.Collections.Generic.List[psobject]

foreach ($mail in $allMails) {
	
	foreach ($mItem in $allMailMonitorItems) {
	
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
				
		$fiSubject      = $mItem.MailSubject
		$fiFrom         = $mItem.mailFrom
		$fiBody         = $mItem.MailBody
		$fiSourceServer = $mItem.MailSourceServer  
		$fiUniqueTitle  = $mItem.UniqueTitle  
		$fiAlertTimer   = $mItem.SCOMAlertResetTimeInSeconds
	
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

			$foo = 'Will be handled as Monitor.'
			$allAlertMails.Add($mail)
		
		} # end if ($bSendAlert -eq $true)

	} # end foreach ($mItem in $filteredItems) {}

} # end foreach ($mail in $allMails) {}

$allEmlForRule  = Compare-Object -ReferenceObject $allMails -DifferenceObject $allAlertMails -Property mailFileName | Select-Object -ExpandProperty mailFileName

foreach ($emlForRule in $allEmlForRule) {

	$mail = $allMails | Where-Object {$_.mailFileName -eq $emlForRule }
	
	$mMetaInfo  = "`nSend at:`t$($mail.mailSendTime)`nReceived at:`t$($mail.mailReceived)`nAddressed to:`t$($mail.mailRecipient)`
			`nSend by Host:`t$($mail.mailSourceServer)`nSubject:`t$($mail.mailSubject)`nBody:`t$($mail.mailBody) "				

	$api.LogScriptEvent('SCOM.Addons.MailIn Generic-MailMonitorRule.ps1',3200,4,"SCOM Addons MailIn Rule BAG `n `
	mail.MailSubject $($mail.mailSubject) `n `
	mail.mailFrom $($mail.mailFrom) `n `
	mail.mailSubject $($mail.mailSubject) `
	mail.mailBody: $($mail.mailBody) `n  `				 
	mail.mailSourceServer $($mail.mailSourceServer) `n
	`n`n mMetaInfo: $($mMetaInfo) " )

	$bag = $api.CreatePropertybag()					
	$bag.AddValue("mSubject",$mail.mailSubject)	
	$bag.AddValue("mFrom",$mail.mailFrom)
	$bag.AddValue("mBody",$mail.mailBody)	
	$bag.AddValue("mMetaInfo",$mMetaInfo)		
	$bag.AddValue("Result","BAD")		
	$bag

	$monFileName = "_AlertRaised_viaRule_" + $($mail.MailSubject) + "_DoNotDelete_.txt" 
	$null = New-Item -Path $xmlConfigDir -ItemType File -Name $monFileName -Value $mMetaInfo -Force
						
	Move-Item -Path $mail.mailFileName -Destination $emlArchive -Force		

}

