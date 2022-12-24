#Variables
$telegramtoken = Get-AutomationVariable -Name 'telegramtoken'
$telegramchatid = Get-AutomationVariable -Name 'telegramchatid'
$resourceGroup = Get-AutomationVariable -Name 'resourceGroup'
$vmName = Get-AutomationVariable -Name 'vmName'


Write-Output "appId = $appId / tenantId = $tenantId"

#Connect Az account
# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with system-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

$scriptBlock = @'
    $rootPath = "$env:temp\ss"

    # create temp directory
    if(!(test-path -Path  $rootPath)){
        Write-Host "New directory created $rootPath"
        New-Item -Path $rootPath -ItemType Directory
    }

    # variables
    $dbPath = "$rootPath\db.txt"
    $domain = "ss.lv"
    $htmlPath = "$rootPath\ss_caravan_$((get-date).tostring('dd_MM_yyyy')).html"
    $htmlPathMoto = "$rootPath\ss_moto_$((get-date).tostring('dd_MM_yyyy')).html"
    $defaultHtmlPath = "$rootPath\default.html"

    # get automation account variables
    $telegramtoken = telegramtokenToReplace
    $telegramchatid = telegramchatidToReplace

    # install choco
    Write-Host "Installing choco:"
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # install dependecies
    Write-Host "Installing choco install googlechrome --version=108.0.5359.99"
    choco install googlechrome --version=108.0.5359.99 -y
    Write-Host "Installing choco install chromedriver --version=108.0.5359.710"
    choco install chromedriver --version=108.0.5359.710 -y
    if (!(Get-Module -ListAvailable -Name Selenium)) {
        Write-Host "Installing Install-Module Selenium -Force"
        Install-Module Selenium -Force
    }
    else {
        Write-Host "Selenium module already installed"
    }
'@

$date = get-date -Format 'ddMMyyy_HHmmss'
$scriptPath = "webScraperSs"+$Date+".ps1"
#The cmdlet only accepts a file, so temporarily write the script to disk using runID as a unique name
Out-File -FilePath $scriptPath -InputObject $scriptBlock
#Replace private key
(((Get-Content -Path $scriptPath) -replace "telegramtokenToReplace",$telegramtoken) -replace "telegramchatidToReplace",$telegramchatid) | Out-File -FilePath $scriptPath
$scriptFile = get-item $scriptpath
$fullPath = $scriptfile.fullname

$jobIDs= New-Object System.Collections.Generic.List[System.Object]

#Start Vm
write-host "Start-AzVM -Name $vmName -ResourceGroupName $resourceGroup -NoWait"
$startAzVM = Start-AzVM -Name $vmName -ResourceGroupName $resourceGroup -NoWait

#Wait until Vm will be in running state
do{
    #Start-Sleep -Seconds 30
    $vmStatus = Get-AzVm -Name $vmName -ResourceGroupName $resourceGroup -Status
}while (!($vmStatus.Statuses.displayStatus[1] -eq 'VM running'))
#Wait more
#Start-Sleep -Seconds 180

Write-Output "Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -Name $VmName -CommandId 'RunPowerShellScript' -ScriptPath $fullPath"
$AzVMRunCommand = Invoke-AzVMRunCommand -ResourceGroupName $resourceGroup -Name $VmName -CommandId 'RunPowerShellScript' -ScriptPath $fullPath

# message
$AzVMRunCommand.Value | ConvertTo-Json -Depth 100

# write error
if ($AzVMRunCommand.Value.Message -match "ERROR:"){
    Write-Error "$($AzVMRunCommand.Value.Message)"
	throw "$($AzVMRunCommand.Value.Message)"
}

#Clean up our variables:
Remove-Item -Path $fullPath