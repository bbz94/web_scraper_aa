param(
    $rootPath = "$env:temp\ss",
    $telegramtoken = $(Get-AutomationVariable -Name 'telegramtoken'),
    $telegramchatid = $(Get-AutomationVariable -Name 'telegramchatid'),
    $path = "$rootPath\report\ss_moto_$((get-date).tostring('dd_MM_yyyy')).html",
    $pathCaravan = "$rootPath\report\ss_caravan_$((get-date).tostring('dd_MM_yyyy')).html",
    $dbPath = "$rootPath\db.txt",
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

$uri = 'https://raw.githubusercontent.com/bbz94/web_scraper_aa/main/webScraperAAScripts/defaultSs.html'
Invoke-WebRequest -Uri $uri -OutFile "$rootPath\default.html"

# functions
Function Send-TelegramMessage {
    Param([Parameter(Mandatory = $true)]
    [String]$message,
    [String]$telegramtoken,
    [String]$telegramchatid
    )
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $Response = Invoke-RestMethod -Uri "https://api.telegram.org/bot$($Telegramtoken)/sendMessage?chat_id=$($Telegramchatid)&text=$($Message)"
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
    
    Invoke-RestMethod -Uri $uri -Form $Form -Method Post
}

if(!(Test-Path $dbPath)){
    new-item -ItemType File -Path $dbPath
}

# models
$models = 'tenere', 'transalp', 'nx', 'Xt660', 'africa','KLR','Z400','KLX','CRF450','XT250','CRF300','Beta 500','Beta 390'

# get pages
$pages = @()
foreach ($model in $models) {
    $uri = "https://www.ss.lv/lv/transport/moto-transport/motorcycles/search-result/?q=$model"
    $WebRequest = Invoke-WebRequest -Method Get -Uri $uri -UseBasicParsing
    $pages += $WebRequest.Content
}

# get adds
$pattern = '<tr id="tr_\d\d\d\d\d\d\d\d[\s\S]*?€<\/td><\/tr>'
$adds = ([regex]::Matches($pages, $pattern).Value) -replace '/msg/', 'https://www.ss.lv//msg/'
$dbContent = get-content -Path $dbPath
$newAdds = @()
foreach ($add in $adds){
    # get cost
    $patternCost = '\d*,*\d*\s\s€'
    $price = ([regex]::Matches($(($add -replace '</b>','') -replace '<b>',''), $patternCost).value -replace ',') -replace '  €'
    if($price.count -gt 1){
        $price = $price[-1]
    }
    # add adds info to db
    $pattern = 'href=".+?html" id='
    $id = (([regex]::Matches($add, $pattern).Value) -split '/')[-1] -replace '" id=',''
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
    $htmlAdds = ($newAdds | sort price | where html -NotLike "*dienā*").html

    # create new file in temp directory
    $html = (get-content -path $defaultHtmlPath) -replace 'addsToAddHere', $htmlAdds | out-file $path

    # send telgram message
    Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending ss moto file:'
    Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $path
}else{
    write-host "Nothing to send"
}

# # models
# $models = 'fiat', 'ford', 'renault', 'volkswagen', 'opel', 'mercedes-benz'

# # get pages
# $pages = @()
# foreach ($model in $models) {
#     $uri = "https://www.ss.lv/lv/transport/cargo-cars/campings/search-result/?q=$($model)"
#     $WebRequest = Invoke-WebRequest -Method Get -Uri $uri -UseBasicParsing
#     $pages += $WebRequest.Content
# }

$pages = ''
$uri = "https://www.ss.lv/lv/transport/cargo-cars/campings"
$WebRequest = Invoke-WebRequest -Method Get -Uri $uri -UseBasicParsing
$pages = $WebRequest.Content

#vans
$models = 'Renault master', 'Fiat ducato', 'Volkswagen crafter', 'Mercedes sprinter', 'Ford transit', 'Citroen jumper', 'xc70'

foreach ($model in $models) {
    $uri = "https://www.ss.lv/lv/transport/cars/search-result/?q=$($model)"
    $WebRequest = Invoke-WebRequest -Method Get -Uri $uri -UseBasicParsing
    $pages += $WebRequest.Content
}

# get adds
$pattern = '<tr id="tr_\d\d\d\d\d\d\d\d[\s\S]*?€<\/td><\/tr>'
$adds = ([regex]::Matches($pages, $pattern).Value) -replace '/msg/', 'https://www.ss.lv//msg/'
$dbContent = get-content -Path $dbPath
$newAdds = @()
foreach ($add in $adds){
    # get cost
    $patternCost = '\d*,*\d*\s\s€'
    $price = ([regex]::Matches($(($add -replace '</b>','') -replace '<b>',''), $patternCost).value -replace ',') -replace '  €'
    if($price.count -gt 1){
        $price = $price[-1]
    }
    # add adds info to db
    $pattern = 'href=".+?html" id='
    $id = (([regex]::Matches($add, $pattern).Value) -split '/')[-1] -replace '" id=',''
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
    $htmlAdds = ($newAdds | sort price | where html -NotLike "*dienā*").html
    # create new file in temp directory

    # create new file in temp directory
    $html = (get-content -path $defaultHtmlPath) -replace 'addsToAddHere', $htmlAdds | out-file $pathCaravan

    # send telgram message
    Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending ss caravan file:'
    Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $pathCaravan
}else{
    write-host "Nothing to send"
}