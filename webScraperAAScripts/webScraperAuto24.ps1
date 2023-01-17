param(
    $rootPath = "$env:temp\auto24",
    $telegramtoken = '',
    $telegramchatid = '',
    $dbPath = "$rootPath\db.txt",
    $domain = "eng.auto24.ee",
    $htmlPath = "$rootPath\report\auto24_caravan_$((get-date).tostring('dd_MM_yyyy')).html",
    $htmlPathMoto = "$rootPath\report\auto24_moto_$((get-date).tostring('dd_MM_yyyy')).html",
    $defaultHtmlPath = "$rootPath\default.html"
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

$uri = 'https://raw.githubusercontent.com/bbz94/web_scraper_aa/main/webScraperAAScripts/defaultAutoplius.html'
Invoke-WebRequest -Uri $uri -OutFile "$rootPath\default.html"

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
    Enter-SeUrl 'https://eng.auto24.ee/kasutatud/nimekiri.php?bn=3&a=113115&aj=&ssid=86270152&b=8&ae=8&af=50&otsi=search' -Driver $Driver
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

# get pages
$models = '14', '7', '8', '12','20'
$pages = @()
foreach ($model in $models[0]) {
    $uri = "https://eng.auto24.ee/kasutatud/nimekiri.php?bn=2&a=113115&aj=&ssid=86270152&b=$($model)&ae=8&af=100&otsi=search"
    $uri
    $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $uri `
                                    -WebSession $session                              
    $pages += $WebRequest.Content
}

# get vans
$models = 'Renault master', 'Fiat ducato', 'Volkswagen crafter', 'Mercedes sprinter', 'Ford transit', 'Citroen jumper'

foreach ($model in $models) {
    $uri = "https://lv.autoplius.lt/sludinajumi/lietotas-automasinas?qt=$($model)&slist=1866085383&order_by=3&order_direction=DESC"
    $uri
    $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $uri -WebSession $session `
                                        -Headers @{
                                    "authority"="lv.autoplius.lt"
                                    "method"="GET"
                                    "path"="/sludinajumi/lietotas-automasinas?make_id=54&model_id=412"
                                    "scheme"="https"
                                    "accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
                                    "accept-encoding"="gzip, deflate, br"
                                    "accept-language"="en-US,en;q=0.9"
                                    "cache-control"="max-age=0"
                                    "sec-ch-ua"="`"Opera GX`";v=`"89`", `"Chromium`";v=`"103`", `"_Not:A-Brand`";v=`"24`""
                                    "sec-ch-ua-mobile"="?0"
                                    "sec-ch-ua-platform"="`"Windows`""
                                    "sec-fetch-dest"="document"
                                    "sec-fetch-mode"="navigate"
                                    "sec-fetch-site"="none"
                                    "sec-fetch-user"="?1"
                                    "upgrade-insecure-requests"="1"
                                    };
    start-sleep -Seconds 2                                
    $pages += $WebRequest.Content
}

# get adds
$pattern = '<div class="result-row item-odd[\s\S]*?"_self"><\/a>\s*<\/div>'
$adds = [regex]::Matches($pages, $pattern).Value
$dbContent = get-content -Path $dbPath
$newAdds = @()
foreach ($add in $adds){
    # get cost
    $patternCost = 'price">&euro;\d*,*\d*<'
    $price = ((([regex]::Matches($add, $patternCost).value -split ';')[1]) -split '<') -replace ',',''
    # add adds info to db
    $pattern = '\/vehicles\/\d*'
    $id = (([regex]::Matches($add, $pattern).Value) -split '/vehicles/')[-1]
    $idToReplace = ([regex]::Matches($add, $pattern).Value)[-1]
    #if($dbContent -notcontains $id){
        $id | add-content -Path $dbPath
        $table = '' | select price, html
        $table.price = [int]$price[0]
        $table.html = $add -replace $idToReplace,"$($domain+$idToReplace+'/')"
        $newAdds += $table
    #}
}

# send if new exist exist
if($newAdds){
    # sort table 
    $htmlAdds = ($newAdds | sort price).html
    # create new file in temp directory
    $html = ((get-content -path $defaultHtmlPath) -replace 'addsToAddHere', $htmlAdds) -replace 'src=""data-','' | out-file $htmlPath

    # send telgram message
    Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending autoplius caravan file:'
    Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $htmlPath
}else{
    write-host "Nothing to send"
}

# get enduro
$pages = @()
$models = 'tenere', 'transalp', 'nx', 'Xt660', 'africa','KLR','Z400','KLX','CRF450','XT250','CRF300','Beta 500','Beta 390'

foreach ($model in $models) {
    $uri = "https://lv.autoplius.lt/sludinajumi/motocikli-motociklistu-apgerbs/motocikli?qt=$($model)&slist=1881749082&order_by=1&order_direction=DESC"
    $uri
    $WebRequest = Invoke-WebRequest -UseBasicParsing -Uri $uri -WebSession $session `
                                        -Headers @{
                                    "authority"="lv.autoplius.lt"
                                    "method"="GET"
                                    "path"="/sludinajumi/lietotas-automasinas?make_id=54&model_id=412"
                                    "scheme"="https"
                                    "accept"="text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.9"
                                    "accept-encoding"="gzip, deflate, br"
                                    "accept-language"="en-US,en;q=0.9"
                                    "cache-control"="max-age=0"
                                    "sec-ch-ua"="`"Opera GX`";v=`"89`", `"Chromium`";v=`"103`", `"_Not:A-Brand`";v=`"24`""
                                    "sec-ch-ua-mobile"="?0"
                                    "sec-ch-ua-platform"="`"Windows`""
                                    "sec-fetch-dest"="document"
                                    "sec-fetch-mode"="navigate"
                                    "sec-fetch-site"="none"
                                    "sec-fetch-user"="?1"
                                    "upgrade-insecure-requests"="1"
                                    };
    start-sleep -Seconds 2                                
    $pages += $WebRequest.Content
}

# get adds
$pattern = '<a[\n\r\s]+href="((https?:\/\/)|(\/)|(..\/))(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?.html"[\n\r\s]+class="announcement-item"[\n\r\s]+target="_blank"[\s\S]*?<\/a>'
$adds = [regex]::Matches($pages, $pattern).Value
$dbContent = get-content -Path $dbPath
$newAdds = @()
foreach ($add in $adds){
    # get cost
    $patternCost = '\d*\s\d*\s\d*\&euro'
    $price = ([regex]::Matches($add, $patternCost).value -replace ' ','') -replace '&euro'
    # add adds info to db
    $pattern = '((https?:\/\/)|(\/)|(..\/))(\w+:{0,1}\w*@)?(\S+)(:[0-9]+)?(\/|\/([\w#!:.?+=&%@!\-\/]))?.html'
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
    $html = ((get-content -path $defaultHtmlPath) -replace 'addsToAddHere', $htmlAdds) -replace 'src=""data-','' | out-file $htmlPathMoto

    # send telgram message
    Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending autoplius moto file:'
    Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $htmlPathMoto
}else{
    write-host "Nothing to send"
}


<div class="result-row item-odd[\s\S]*?<\/span><\/div>