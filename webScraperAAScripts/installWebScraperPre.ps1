# install choco
[Enum]::GetNames([Net.SecurityProtocolType]) -contains 'Tls12'
Write-Host "Installing choco:"
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# install dependecies
Write-Host "Installing choco install googlechrome"
choco install googlechrome  -y
Write-Host "Installing choco install chromedriver"
choco install chromedriver -y

if(!(test-path -path 'C:\PowerShell7')){
    Write-Host "Installing PowerShell-7.3.1-win-x64.zip"
    Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.3.1/PowerShell-7.3.1-win-x64.zip' -OutFile "$env:temp\PowerShell-7.3.1-win-x64.zip"
    Expand-Archive -Path "$env:temp\PowerShell-7.3.1-win-x64.zip" -DestinationPath 'C:\PowerShell7'
}

if (!(Get-Module -ListAvailable -Name Selenium)) {
    Write-Host "Installing Install-Module Selenium -Force"
    Install-Module Selenium -Force
}
else {
    Write-Host "Selenium module already installed"
}
