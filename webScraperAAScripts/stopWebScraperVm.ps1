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
$stopAzVM = Stop-AzVM -Name $vmName -ResourceGroupName $resourceGroup -NoWait -Force