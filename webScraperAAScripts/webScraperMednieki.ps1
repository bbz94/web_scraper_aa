param(
    $user =  $(Get-AutomationVariable -Name 'user'),
    $password =  $(Get-AutomationVariable -Name 'password'),
    $rootPath = "$env:temp\llkc_mednieki",
    $defaultHtmlPath = "$rootPath\default.html",
    $htmlPath = "$rootPath\report\mednieki_wrong_answers_$((get-date).tostring('dd_MM_yyyy')).html",
    $telegramtoken = $(Get-AutomationVariable -Name 'telegramtoken'),
    $telegramchatid = $(Get-AutomationVariable -Name 'telegramchatid')
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
####################
# Get access token #
####################
$url = 'https://talmaciba.llkc.lv/login/index.php'
# modules
import-module Selenium -Force
# open browser
$Driver = Start-SeChrome -WebDriverDirectory 'C:\ProgramData\chocolatey\lib\chromedriver\tools'
$userAgent = $driver.executescript("return navigator.userAgent;")
Enter-SeUrl $url -Driver $Driver
$Element = Find-SeElement -Driver $Driver -Id "username"
Send-SeKeys -Element $Element -Keys $user
$Element = Find-SeElement -Driver $Driver -Id "password"
Send-SeKeys -Element $Element -Keys $password
$Element = Find-SeElement -Driver $Driver -Id "loginbtn"
Invoke-SeClick -Element $Element
$cookies = Get-SeCookie -Target $Driver
Stop-SeDriver -Target $Driver
 
# get session cookies
$session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$session.UserAgent = $userAgent
foreach ($cookie in $cookies) {
    if ($($cookie.name) -notlike '_gat') {
        $command = '$session' + ".Cookies.Add((New-Object System.Net.Cookie('$($cookie.name)', '$($cookie.value)', '$($cookie.path)', '$($cookie.domain)')))"
        write-host $command
        Invoke-Expression $command
    }
}


###################
# get report urls #
###################
$uri = 'https://talmaciba.llkc.lv/mod/quiz/view.php?id=2202'
$webRequest = Invoke-WebRequest -Method Get -Uri $uri -WebSession $Session

$pattern = 'atbildes" href=[\s\S]*?>Pārskats'
$reports = [regex]::Matches($($webRequest.Content), $pattern).Value
$reportUrls = $reports | % { ($_ -split '"')[2] + "&showall=1" }
$reportUrls

# get reports
$qTable = @()
$reportUrls | % {
    $webRequest = Invoke-WebRequest -Method Get -Uri $_ -WebSession $Session
    # get all questions
    $pattern = 'que multichoice deferredfeedback[\s\S]*?<\/div><\/div><\/div><\/div>'
    $questions = [regex]::Matches($($webRequest.Content), $pattern).Value | % {
        $t = '' | select state, question, a, b, c , correct, html
        $t.state = (($_ -split 'deferredfeedback ')[1] -split '">')[0]
        $t.question = (($_ -split '"qtext">')[1] -split '</div>')[0]
        $t.a = (($_ -split '">a. </span><div class="flex-fill ml-1">')[1] -split '</div>')[0]
        $t.b = (($_ -split '">b. </span><div class="flex-fill ml-1">')[1] -split '</div>')[0]
        $t.c = (($_ -split '">c. </span><div class="flex-fill ml-1">')[1] -split '</div>')[0]
        $t.correct = (($_ -split 'class="rightanswer">')[1] -split '</div>')[0]
        $qTable += $t
        # add to html report
        if ($t.state -match 'incorrect') {
            $htmlToAdd = '<div id="question-136977-58" class="' + $_
            if ($_ -match 'Attēlā') {
                try{
                $a = $_
                $imgSrcHtml = [regex]::Matches($_, '<br><img src="https[\s\S]*?.(jpg|png)').Value
                $imgUrl = ($imgSrcHtml -split '"')[-1]
                $webRequest = Invoke-WebRequest -Method Get -Uri $imgUrl -WebSession $Session
                $base64Img = [convert]::ToBase64String(($webRequest.content))
                $imgSrcStr = "data:image/jpg;base64,$base64Img"
                $htmlToAdd = '<div id="question-136977-58" class="' + $(($_ -replace $numberHtml, $numberHtmlCorNum) -replace $imgUrl, $imgSrcStr)
                }catch{
                    write-host "Error: $_ Array: $a imgUrl: $imgUrl" 

                }
            }
            $t.html = $htmlToAdd
        }
    }
}

#############################################
# create html based on wrong question count #
#############################################
$htmlT = @()
[int]$i = 0
$qTable | where state -eq 'incorrect' | group-object question | sort count, question -Descending  | % {
    # add number
    $i++
    $group = $_.group
    if ($group.count -gt 1) {
        $group = $group[0]
    }
    $numberHtml = (($group.html -split 'Jautājums ')[1] -split '</h3>')[0]
    $number = [regex]::Matches($($numberHtml), '\d').Value -join ''
 
    # fix number for report
    $numberHtmlCorNum = $numberHtml -replace $number, $i
    $htmlT += ($group.html -replace 'Nepareizs', "Nepareizs $($_.count)") -replace $numberHtml, $numberHtmlCorNum
}


# create new file in temp directory
$html = (get-content -path $defaultHtmlPath) -replace 'htmlToReplace', $htmlT | out-file $htmlPath

# send telgram message
Send-TelegramMessage -telegramtoken $telegramtoken -telegramchatid $telegramchatid -message 'Sending mednieki wrong answers file:'
Send-TelegramFile -telegramtoken $telegramtoken -telegramchatid $telegramchatid -filePath $htmlPath
