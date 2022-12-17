$rootPath = "$env:temp\autoplius_crawler"

# create temp directory
if(!(test-path -Path  $rootPath)){
    Write-Host "New directory created $rootPath"
    New-Item -Path $rootPath -ItemType Directory
}

# variables
$dbPath = "$rootPath\db.txt"
$domain = "autoplius.lt"
$htmlPath = "$rootPath\autoplius_caravan_$((get-date).tostring('dd_MM_yyyy')).html"
$htmlPathMoto = "$rootPath\autoplius_moto_$((get-date).tostring('dd_MM_yyyy')).html"
$defaultHtmlPath = "$rootPath\default.html"

# get automation account variables
$telegramtoken = Get-AutomationVariable -Name 'telegramtoken'
$telegramchatid = Get-AutomationVariable -Name 'telegramchatid'

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