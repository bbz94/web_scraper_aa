# install choco
Write-Host "Installing choco:"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# install dependecies
Write-Host "Installing choco install googlechrome"
choco install googlechrome  -y
Write-Host "Installing choco install chromedriver"
choco install chromedriver -y
Write-Host "Installing choco install powershell-core"
choco install powershell-core -y

if (!(Get-Module -ListAvailable -Name Selenium)) {
    Write-Host "Installing Install-Module Selenium -Force"
    Install-Module Selenium -Force
}
else {
    Write-Host "Selenium module already installed"
}