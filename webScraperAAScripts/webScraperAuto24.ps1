param(
    $rootPath = "$env:temp\auto24",
    $telegramtoken = $(Get-AutomationVariable -Name 'telegramtoken'),
    $telegramchatid = $(Get-AutomationVariable -Name 'telegramchatid'),
    $dbPath = "$rootPath\db.txt",
    $domain = "eng.auto24.ee",
    $htmlPath = "$rootPath\report\auto24_caravan_$((get-date).tostring('dd_MM_yyyy')).html",
    $htmlPathMoto = "$rootPath\report\auto24_moto_$((get-date).tostring('dd_MM_yyyy')).html",
    $defaultHtmlPath = "$rootPath\defaultAuto24.html"
)

# create temp directory
if(!(test-path -Path  $rootPath)){
    Write-Host "New directory created $rootPath"
    New-Item -Path $rootPath -ItemType Directory
}

if(!(test-path -Path "$rootPath\report")){
    Write-Host "New directory created $rootPath\report"
    New-Item -Path "$rootPath\report" -ItemType Directory
}

$uri = 'https://raw.githubusercontent.com/bbz94/web_scraper_aa/main/webScraperAAScripts/defaultAuto24.html'
Invoke-WebRequest -Uri $uri -OutFile "$rootPath\defaultauto24.html"

# functions
Function Send-TelegramMessage {
    Param([Parameter(Mandatory = $true)]
    [String]$message,
    [String]$telegramtoken,
    [String]$telegramchatid
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($Telegramtoken)/sendMessage?chat_id=$($Telegramchatid)&text=$($Message)" -UseBasicParsing
}

Function Send-TelegramFile {
    Param([Parameter(Mandatory = $true)]
    [String]$filePath,
    [String]$telegramtoken,
    [String]$telegramchatid
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $uri = "https://api.telegram.org/bot$($telegramtoken)/sendDocument"
    $Form = @{
        chat_id  = $telegramchatid
        document = Get-item $filePath
    }
    
    Invoke-RestMethod -Uri $uri -Form $Form -Method Post -UseBasicParsing
}

# open browser
$command = @'
    # modules
    import-module Selenium -Force
    # open browser
    $Driver = Start-SeChrome -WebDriverDirectory 'C:\ProgramData\chocolatey\lib\chromedriver\tools'
    $userAgent = $driver.executescript("return navigator.userAgent;")
    Enter-SeUrl 'https://eng.auto24.ee/kasutatud/nimekiri.php?bn=2&a=113115&aj=&ae=8&af=50&otsi=search' -Driver $Driver
    $cookies = Get-SeCookie -Target $Driver
    Stop-SeDriver -Target $Driver
'@

Invoke-Expression -Command $command

# get session cookies
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.UserAgent = $userAgent
foreach($cookie in $cookies){
    if($($cookie.name) -notlike '_gat'){
        $command = '$session'+".Cookies.Add((New-Object System.Net.Cookie('$($cookie.name)', '$($cookie.value)', '$($cookie.path)', '$($cookie.domain)')))"
        write-host $command
        Invoke-Expression $command
    }
}

function Get-SeleniumPage ($uri) {
    # open browser
    $command = @'
        # modules
        import-module Selenium -Force
        # open browser
        $Driver = Start-SeChrome -WebDriverDirectory 'C:\ProgramData\chocolatey\lib\chromedriver\tools'
        $userAgent = $driver.executescript("return navigator.userAgent;")
        Enter-SeUrl 'ReplaceUri' -Driver $Driver
        $page = $driver.PageSource
        Stop-SeDriver -Target $Driver
'@
    $command = $command -replace 'ReplaceUri', $uri

    Invoke-Expression -Command $command
    return $page
}

$pages = ''
$uri = 'https://eng.auto24.ee/kasutatud/nimekiri.php?bn=2&a=113115&ae=1&af=50&otsi=search&ak=0'
$pages += Get-SeleniumPage -uri $uri


# get vans
$models = 'master', 'ducato', 'crafter', 'sprinter', 'transit', 'jumper', 'xc70'

foreach ($model in $models) {
    $uri = "https://eng.auto24.ee/kasutatud/nimekiri.php?bn=2&a=100&c=$($model)&ae=1&af=50&ssid=90862069&ak=0"
    $uri
    $pages += Get-SeleniumPage -uri $uri
}

# get adds
$pattern = '<div class="result-row item[\s\S]*?class="row-link" target="_self"><\/a>[\s\S]*?<\/div>'
$adds = [regex]::Matches($pages, $pattern).Value
$dbContent = get-content -Path $dbPath
$newAdds = @()
foreach ($add in $adds){
    # get cost
    $patternCost = 'price">&euro;\d*,*\d*'
    $priceArr = [regex]::Matches($add, $patternCost).value
    if($priceArr.count -gt 1){
        $price = ($priceArr[-1] -replace 'price">&euro;') -replace ','
    }else{
        $price = ($priceArr -replace 'price">&euro;') -replace ','
    }
    # add adds info to db
    $pattern = '\/vehicles\/\d*'
    $id = (([regex]::Matches($add, $pattern).Value) -split '-')[-1]
    if($dbContent -notcontains $id){
        $id | add-content -Path $dbPath
        $table = '' | select price, html
        $table.price = [int]$price
        $table.html = $add
        $newAdds += $table
    }
}

# send if new exist exist
if($newAdds){
    # sort table 
    $htmlAdds = ($newAdds | sort price).html
    # create new file in temp directory
    $html = (get-content -path $defaultHtmlPath) -replace 'addsToAddHere', $htmlAdds | out-file $htmlPath

    # send telgram message
    Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending auto24 caravan file:'
    Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $htmlPath
}else{
    write-host "Nothing to send"
}

# get enduro
$pages = @()
$models = 'tenere', 'transalp', 'nx', 'Xt660', 'africa','KLR','Z400','KLX','CRF450','XT250','CRF300','Beta 500','Beta 390'

foreach ($model in $models) {
    $uri = "https://eng.auto24.ee/kasutatud/nimekiri.php?bn=2&a=100&c=$($model)&ae=1&af=50&ssid=90862069&ak=0"
    $uri
    $pages += Get-SeleniumPage -uri $uri
}

# get adds
$pattern = '<div class="result-row item[\s\S]*?class="row-link" target="_self"><\/a>[\s\S]*?<\/div>'
$adds = [regex]::Matches($pages, $pattern).Value
$dbContent = get-content -Path $dbPath
$newAdds = @()
foreach ($add in $adds){
    # get cost
    $patternCost = 'price">&euro;\d*,*\d*'
    $priceArr = [regex]::Matches($add, $patternCost).value
    if($priceArr.count -gt 1){
        $price = ($priceArr[-1] -replace 'price">&euro;') -replace ','
    }else{
        $price = ($priceArr -replace 'price">&euro;') -replace ','
    }
    # add adds info to db
    $pattern = '\/vehicles\/\d*'
    $id = (([regex]::Matches($add, $pattern).Value) -split '-')[-1]
    if($dbContent -notcontains $id){
        $id | add-content -Path $dbPath
        $table = '' | select price, html
        $table.price = [int]$price
        $table.html = $add
        $newAdds += $table
    }
}

# send if new exist exist
if($newAdds){
    # sort table 
    $htmlAdds = ($newAdds | sort price).html
    # create new file in temp directory
    $html = (get-content -path $defaultHtmlPath) -replace 'addsToAddHere', $htmlAdds | out-file $htmlPathMoto

    # send telgram message
    Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending auto24 moto file:'
    Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $htmlPathMoto
}else{
    write-host "Nothing to send"
}