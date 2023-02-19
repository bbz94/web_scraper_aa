# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect to Azure with user-assigned managed identity
$AzureContext = (Connect-AzAccount -Identity).context

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

#Start script on each machine
$resourceGroup = Get-AutomationVariable -Name 'resourceGroup'
$vmName = Get-AutomationVariable -Name 'vmName'

#Start Vm
$startAzVM = Start-AzVM -Name $vmName -ResourceGroupName $resourceGroup -NoWait

#Wait until Vm will be in running state
do{
    Start-Sleep -Seconds 5
    $vmStatus = Get-AzVm -Name $vmName -ResourceGroupName $resourceGroup -Status
}while (!($vmStatus.Statuses.displayStatus[1] -eq 'VM running'))

# Trigger other runbooks
Start-AutomationRunbook -Name "web-scraper-install-pre" -RunOn $vmName
Start-AutomationRunbook -Name "web-scraper-ss" -RunOn $vmName
Start-AutomationRunbook -Name "web-scraper-autoplius" -RunOn $vmName
Start-AutomationRunbook -Name "web-scraper-auto24" -RunOn $vmName
Start-AutomationRunbook -Name "web-scraper-mednieki" -RunOn $vmName

# Slleep for 10 min
Start-Sleep -Seconds 600
Start-AutomationRunbook -Name "web-scraper-stop-vm"