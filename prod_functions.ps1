#!/usr/bin/pwsh

function replaceUmlaut($text){
    $name = $text -replace 'ö','oe' 
    $name = $name -replace 'ä','ae' 
    $name = $name -replace 'ü','ue' 
    $name = $name -replace 'ß','ss' 
    $name = $name -replace 'Ö','Oe' 
    $name = $name -replace 'Ü','Ue' 
    $name = $name -replace 'Ä','Ae'
    return $name
}

function escapeSymbols($original){
    $pattern = $original -replace '\[','\['
    $pattern = $pattern -replace '\]','\]'
    $pattern = $pattern -replace '\|','\|'
    $pattern = $pattern -replace '\(','\('
    $pattern = $pattern -replace '\)','\)'
    $pattern = $pattern -replace '\?','\?'
    $pattern = $pattern -replace '\+','\+'
    $pattern = $pattern -replace '\^','\^'
    $pattern = $pattern -replace '\.','\.'
    $pattern = $pattern -replace '\*','\*'
    return $pattern
}

function insertLink($textWithLink){
    $processedText = $textWithLink
    if($processedText -match '\[\^.*\]'){
        foreach($case in $Matches.GetEnumerator()){
            $link = $case.Value
            $link = $link -replace '\[|\]|\^',''
            $url = ($test.fields.attachment | Where-Object{$_.filename -eq "$link"}).content
            $ProgressPreference = 'SilentlyContinue'
            if(!(Test-Path $PSScriptRoot/$($test.id))){
                mkdir $PSScriptRoot/$($test.id)
            }
            Invoke-WebRequest `
                -Method Get `
                -Headers $headers `
                -Uri $url `
                -OutFile "$PSScriptRoot/$($test.id)/$link"
            
            $body = [System.IO.File]::ReadAllBytes("$PSScriptRoot/$($test.id)/$link")
            $linkProcessed = [uri]::EscapeDataString($link)
            $uri = "$vsts/_apis/wit/attachments?fileName=$linkProcessed&api-version=7.1-preview.3"
            $upload = Invoke-RestMethod `
                -Method Post `
                -ContentType "application/octet-stream"`
                -Headers $vstsHeaders `
                -Uri $uri `
                -Body $body
            $pattern = escapeSymbols $case.Value
            Remove-Item "$PSScriptRoot/$($test.id)/$link"
            "$link::$($upload.url)" | Out-File "$PSScriptRoot/$($test.id)/attachments.lst" -Append
            $processedText = $processedText -replace $pattern,$('<a href=\"{0}\">{1}</a>' -f $upload.url, $link)
        }
    }
    foreach($case in $(Select-String '\[[^[]+\|http[^[]+\]' -input $processedText -AllMatches | ForEach-Object {$_.matches.Value})){
        $link = $case -replace '\[|\]',''
        $label = $link.split('|')[0]
        if($label -match '\*.*\*'){
            $label = $label -replace '\*',''
            $label = "<b>$label</b>"
        }
        $link = $link.split('|')[-1]
        $pattern = escapeSymbols $case
        $processedText = $processedText -replace $pattern,$('<a href=\"{0}\">{1}</a>' -f $link, $label)
    }
    foreach($case in $(Select-String '\[http[^[]+\]' -input $processedText -AllMatches | ForEach-Object {$_.matches.Value})){
        $link = $case -replace '\[|\]',''
        $pattern = escapeSymbols $case
        $processedText = $processedText -replace $pattern,$('<a href=\"{0}\">{0}</a>' -f $link, $link)
    }
    foreach($case in $(Select-String '\(MED-\d+\)' -input $processedText -AllMatches | ForEach-Object {$_.matches.Value})){
        $id = $case -replace '\(|\)',''
        $pattern = escapeSymbols $case
        $processedText = $processedText -replace $pattern,$('<a href=\"{0}\">({1})</a>' -f "$jira/browse/$id", $id)
    }
    return $processedText
}

function processDescription($jiraDescription){
    $vstsDescription = ''
    if($jiraDescription){
        $j = 0
        $lines = ($jiraDescription -replace "`r`n","`n").split("`n")
        while($j -lt $lines.Count){
            $line = $lines[$j]
            $line = $line -replace '\\','\\'
            $line = $line -replace '"','\"'
            $line = $line -replace '\{code:.*\}','<pre><code>'
            $line = $line -replace '\{code\}','</code></pre>'
            $line = insertLink $line
            if($line.Length -eq 0){
                $vstsDescription += "<div><br> </div>"
            }
            elseif($line -match 'h\d\. '){
                $headerWeight = $Matches[0].Substring(0,2)
                $header = $line -replace 'h\d\. ',''
                $vstsDescription += "<$headerWeight>$header</$headerWeight>"
            }
            elseif($line -match '\*\*'){
                $list = $line -replace '\*\* ',''
                if($lines[$j - 1] -notmatch '\*\* '){
                    if($j + 1 -eq $lines.Count){
                        $vstsDescription += "<ul><li>$list</li></ul>" #one line, last line
                    }
                    elseif($lines[$j + 1] -notmatch '\*\* '){
                        $vstsDescription += "<ul><li>$list</li></ul>" #one line, not last
                    }
                    else{
                        $vstsDescription += "<ul><li>$list</li>" #first line of the list
                    }
                }
                else{
                    if($j + 1 -eq $lines.Count){
                        $vstsDescription += "<li>$list</li></ul>"
                    }
                    elseif($lines[$j + 1] -notmatch '\*\* '){
                        $vstsDescription += "<li>$list</li></ul>"
                    }
                    else{
                        $vstsDescription += "<li>$list</li>"
                    }
                }
            }
            else{
                $line = $line -replace '^ \*',' -'
                foreach($pattern in $(Select-String '\*[^*]+\*' -input $line -AllMatches | ForEach-Object {$_.matches.Value})){
                    $bold = $pattern.split('*')[1]
                    $bold = "<b>$bold</b>"
                    $regPattern = $pattern -replace '\*','\*'
                    $line = $line -replace $regPattern,$bold
                }
                $line = $line -replace '\\\\\[','['
                $line = $line -replace '\\\\\]',']'
                $line = $line -replace '\s','&nbsp;'
                $line = $line -replace '<a&nbsp;href','<a href'
                $vstsDescription += "<div>$line</div>"
            }
            $j++
        }
    }
    return $vstsDescription
}

function processStep($stepText){
    $formatted = $stepText -replace '&','&amp;amp;'
    $formatted = $formatted -replace '\\','\\'
    $formatted = $formatted -replace '<','&amp;lt;'
    $formatted = $formatted -replace '>','&amp;gt;'
    $formatted = $formatted -replace "\n",'&lt;BR/&gt;'
    $formatted = $formatted -replace '\*\*\*','    -'
    $formatted = $formatted -replace '\*\*','  •'
    foreach($pattern in $(Select-String '\*[^*]+\*' -input $formatted -AllMatches | ForEach-Object {$_.matches.Value})){
        $bold = $pattern.split('*')[1]
        $bold = "&lt;B&gt;$bold&lt;/B&gt;"
        $regPattern =  escapeSymbols $pattern
        $formatted = $formatted -replace $regPattern,$bold
    }
    if($formatted -match '\[.*http.*\]'){
        $link = $Matches[0] -replace '\[|\]',''
        $tip = $link.split('|')[0]
        $url = $link.split('|')[1]
        $pattern = escapeSymbols $Matches[0]
        $formatted = $formatted -replace "$pattern","$tip -&amp;gt; &lt;A&gt;$url&lt;/A&gt;"
    }
    '<parameterizedString isformatted="true">&lt;DIV&gt;&lt;P&gt;{0}&lt;BR/&gt;&lt;/P&gt;&lt;/DIV&gt;</parameterizedString>' -f $formatted
}

function getSteps(){
    $uri = "$zephyrAPI/teststep/$($test.id)"
    $steps = Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri $uri
    $null | Out-File $PSScriptRoot/vstsSteps.stp
    if($steps.stepBeanCollection.Length -gt 0){
        '<steps id="0" last="{0}">' -f ($steps.stepBeanCollection.Count + 1) | Out-File $PSScriptRoot/vstsSteps.stp
        $index = 2

        $ProgressPreference = 'SilentlyContinue'

        foreach($step in $steps.stepBeanCollection){
            '<step id="{0}" type="ValidateStep">' -f $index | Out-File $PSScriptRoot/vstsSteps.stp -Append
            processStep $step.step | Out-File $PSScriptRoot/vstsSteps.stp -Append
            processStep $step.result | Out-File $PSScriptRoot/vstsSteps.stp -Append
            '<description/></step>' | Out-File $PSScriptRoot/vstsSteps.stp -Append
            foreach($attachment in $step.attachmentsMap){
                if(!(Test-Path $PSScriptRoot/$($test.id))){
                    mkdir $PSScriptRoot/$($test.id)
                }
                Invoke-WebRequest `
                    -Method Get `
                    -Headers $headers `
                    -Uri "$jira/plugins/servlet/schedule/viewAttachment?id=$($attachment.fileId)&name=$($attachment.fileName)" `
                    -OutFile "$PSScriptRoot/$($test.id)/$index`_$($attachment.fileName)"
            }
            if($step.htmlData.Length -gt 0){
                if(!(Test-Path $PSScriptRoot/$($test.id))){
                    mkdir $PSScriptRoot/$($test.id)
                }
                $step.htmlData | Out-File "$PSScriptRoot/$($test.id)/$index`_TEST-DATA.html"
            }
            $index++
        }

        '</steps>' | Out-File $PSScriptRoot/vstsSteps.stp -Append
    }

}

function createTestCase(){
    $key = $test.key
    $fields = @(
        ('{{"op":"add","path":"/fields/System.Title","value":"{0}"}}' -f $summary),
        ('{{"op":"add","path":"/fields/System.State","value":"{0}"}}' -f $status),
        #('{{"op":"add","path":"/relations/-","value":{{"rel":"System.LinkTypes.Related","url":"{0}"}}}}' -f $relation1),
        #('{{"op":"add","path":"/relations/-","value":{{"rel":"System.LinkTypes.Hierarchy-Forward","url":"{0}"}}}}' -f $relation2),
        ('{{"op":"add","path":"/fields/System.AreaPath","value":"{0}"}}' -f "EPAM TEST"),
        ('{{"op":"add","path":"/fields/System.TeamProject","value":"{0}"}}' -f "EPAM TEST"),
        ('{{"op":"add","path":"/fields/System.IterationPath","value":"{0}"}}' -f "EPAM TEST"),
        ('{"op":"add","path":"/fields/System.WorkItemType","value":"Test Case"}'),
        ('{{"op":"add","path":"/fields/System.Tags","value":"{0}"}}' -f $tags),
        ('{{"op":"add","path":"/fields/Custom.12c2e0b1-59f8-49d8-ba89-69264906c00e","value":"{0}"}}' -f $priority), #Custom.12c2e0b1-59f8-49d8-ba89-69264906c00e
        ('{{"op":"add","path":"/fields/Custom.JiraIssueID","value":"{0}"}}' -f $key),
        ('{{"op":"add","path":"/fields/Microsoft.VSTS.TCM.Steps","value":"{0}"}}' -f $allSteps), 
        ('{{"op":"add","path":"/fields/System.Description","value":"{0}"}}' -f $description)
    )

    if($assignedTo.Length -gt 0){
        $fields += ('{{"op":"add","path":"/fields/System.AssignedTo","value":{{"displayName":"{0}"}}}}' -f $assignedTo)
    }

    if($testSpecification.Length -gt 0){
        $fields += ('{{"op":"add","path":"/fields/Custom.testspecification","value":"{0}"}}' -f $testSpecification)
    }

    $body = '[{0}]' -f $($fields -join ',')

    $body | Out-File $PSScriptRoot/body.json

    $contentType = 'application/json-patch+json'

    $uri = "$vsts/_apis/wit/workitems/`$Test%20Case?bypassRules=true&api-version=7.1-preview.3"

    Invoke-RestMethod -Method Post `
        -Uri $uri `
        -Headers $vstsHeaders `
        -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
        -ContentType $contentType
}

function witAttachments(){
    param(
        $url,
        $comment,
        $name
    )

    $processedName = replaceUmlaut $name

    $body = @"
    [
        {
            "op": "add",
            "path": "/relations/-",
            "value": {
                "rel": "AttachedFile",
                "url": "$url",
                "attributes": {
                    "name": "$processedName",
                    "comment": "$comment"
                }
            }
        }
    ]
"@
    $uri = "$vsts/_apis/wit/workitems/$($testCase.id)?api-version=7.1-preview.3"
    Write-Host "Adding attachments" -ForegroundColor Yellow
    Invoke-RestMethod `
        -Method Patch `
        -Uri $uri `
        -Headers $vstsHeaders `
        -ContentType 'application/json-patch+json' `
        -Body $body | Out-Null
}

function addAttachments(){

    if(Test-Path "$PSScriptRoot/$($test.id)"){
        $files = Get-ChildItem "$PSScriptRoot/$($test.id)" | Where-Object{$_.Name -ne 'attachments.lst'}
        foreach($file in $files){
            $stepNo = $file.Name.split('_')[0]
            $fileName = $file.Name -replace '^\d+_',''
            $body = [System.IO.File]::ReadAllBytes("$($file.FullName)")
            $uri = "$vsts/_apis/wit/attachments?fileName=$fileName&api-version=7.1-preview.3"
            $upload = Invoke-RestMethod `
                -Method Post `
                -ContentType "application/octet-stream"`
                -Headers $vstsHeaders `
                -Uri $uri `
                -Body $body
    
            witAttachments -name $fileName -url $upload.url -comment "[TestStep=$stepNo]:"
        }
    }
    if(Test-Path "$PSScriptRoot/$($test.id)/attachments.lst"){
        $attached=@()
        foreach($line in Get-Content "$PSScriptRoot/$($test.id)/attachments.lst"){
            $newObject = New-Object -TypeName psobject
            $newObject | Add-Member -MemberType NoteProperty -Name "Name" -Value $line.split('::')[0]
            $newObject | Add-Member -MemberType NoteProperty -Name "Url" -Value $line.split('::')[1]
            $attached += $newObject
        }
    }
    foreach($attachment in $test.fields.attachment){
        if($attachment.filename -in $attached.Name){
            witAttachments -name $attachment.filename -url ($attached | Where-Object{$_.Name -eq $attachment.filename}).Url
        }
        else{
            $ProgressPreference = 'SilentlyContinue'
            if(!(Test-Path $PSScriptRoot/$($test.id))){
                mkdir $PSScriptRoot/$($test.id)
            }
            $url = $attachment.content
            Invoke-WebRequest `
                -Method Get `
                -Headers $headers `
                -Uri $url `
                -OutFile "$PSScriptRoot/$($test.id)/$($attachment.filename)"
            $body = [System.IO.File]::ReadAllBytes("$PSScriptRoot/$($test.id)/$($attachment.filename)")
            $linkProcessed = [uri]::EscapeDataString($($attachment.filename))
            $uri = "$vsts/_apis/wit/attachments?fileName=$linkProcessed&api-version=7.1-preview.3"
            $upload = Invoke-RestMethod `
                -Method Post `
                -ContentType "application/octet-stream"`
                -Headers $vstsHeaders `
                -Uri $uri `
                -Body $body
            witAttachments -name $attachment.filename -url $upload.url
        }
    }
}

function cutName($text){
    $title = $(replaceUmlaut $text).split("`n")[0]
    $title = $title -replace '"','\"'
    if($title.Length -gt 128){
        return $title.Substring(0,128)
    }
    else{
        return $title
    }
}

function processComment($text){
    $comment = $text -replace "`n", "\n"
    $comment = $comment -replace '"','\"'
    $comment = replaceUmlaut $comment
}

function processConfiguration(){
    if($execution.comment.Length -gt 0){
        $configuration = $execution.comment
        $uri = "$vsts/_apis/testplan/configurations?api-version=7.1-preview.1"
        $configurations = Invoke-RestMethod `
            -Method Get `
            -Headers $vstsHeaders `
            -ContentType 'application/json' `
            -Uri $uri
        $defaultConfigId = ($configurations.value | Where-Object{$_.name -eq 'Windows 10'}).id
        #$configuration
        $thisConfiguration = $configurations.value | Where-Object{$_.name.Replace(' ','').Replace('"','\"') -eq $(cutName $configuration).Replace(' ','')}
        if(!$thisConfiguration){
            Write-Host "Creating configuration $(cutName $configuration)" -ForegroundColor DarkCyan
            $uri = "$vsts/_apis/testplan/configurations?api-version=7.1-preview.1"
            #$description = $configuration -replace "\\n","`n"
            $body = @"
            {
                "name": "$(cutName $configuration)",
                "description": "$(processComment $configuration)",
                "isDefault": false,
                "state": "active"
            }
"@
            #"$body"
            $thisConfiguration = Invoke-RestMethod `
                -Method Post `
                -Headers $vstsHeaders `
                -Body $body `
                -Uri $uri `
                -ContentType 'application/json'
        }
        Write-Host "Assigning configuration $(cutName $configuration)"
        $uri = "$vsts/_api/_testManagement/GetAvailableConfigurationsForTestCases?__v=5"
        $body = '{{"testCases":"[{{\"testCaseId\":{0},\"suiteId\":{1}}}]"}}' -f $testCaseId, $testSuite.id
        $currentConfigurations = Invoke-RestMethod `
                                    -Method Post `
                                    -Headers $vstsHeaders `
                                    -ContentType 'application/json' `
                                    -Uri $uri `
                                    -Body $body
        $configurationsList = @()
        foreach($config in $currentConfigurations.__wrappedArray){
            if($config.isAssigned -and $config.id -ne $defaultConfigId){
                $configurationsList += $config.id
            }
        }
        if($thisConfiguration.id -notin $configurationsList){
            $configurationsList += $thisConfiguration.id
        }
        $uri = "$vsts/_api/_testManagement/AssignConfigurationsToTestCases?__v=5"
        $body = '{{"testCases":"[{{\"testCaseId\":{0},\"suiteId\":{1}}}]","configurations":[{2}]}}' -f $testCaseId, $testSuite.id, $($configurationsList -join ',')
        #"$body"
        Invoke-RestMethod `
            -Method Post `
            -Headers $vstsHeaders `
            -ContentType 'application/json' `
            -Uri $uri `
            -Body $body
    }
}

function getOutcome($status){
    switch($status){
        "-1"{
            $outcome = 8 #not executed
        }
        "1"{
            $outcome = 2 #passed
        }
        "2"{
            $outcome = 3 #failed
        }
        "3"{
            $outcome = 13 # in progress
        }
        "4"{
            $outcome = 7 # blocked
        }
    }
    return $outcome
}

function returnJiraIssueId($id){
    $uri = "$vsts/_apis/wit/workitems/$id`?api-version=7.1-preview.3"
    $workItem = Invoke-RestMethod `
        -Method Get `
        -Headers $vstsHeaders `
        -ContentType 'application/json' `
        -Uri $uri
    return $workItem.fields.'Custom.JiraIssueID'
}

function setTestsStatuses($testSuite){
    $uri = "$vsts/_apis/test/Plans/$($plan.id)/Suites/$($testSuite.id)/points?api-version=7.1-preview.2"
    $points = Invoke-RestMethod `
        -Method Get `
        -Headers $vstsHeaders `
        -ContentType 'application/json' `
        -Uri $uri
    foreach($point in $points.value){
        $thisExecution = $executions.executions | Where-Object{$_.issueKey -eq $(returnJiraIssueId $point.testCase.id) `
            -and $(cutName $_.comment).Replace(' ','').Replace('Windows10','') -eq $point.configuration.name.Replace(' ','').Replace('"','\"').Replace('Windows10','')}
        $outcome = getOutcome $thisExecution.executionStatus
        $body = @"
        [
            {
                "id": "$($point.id)",
                "results": {
                    "outcome": $outcome
                }
            }
        ]
"@
        $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/Suites/$($testSuite.id)/TestPoint?api-version=7.1-preview.2"
        Write-Host "Set test $($point.testCase.id) execution status to $outcome" -ForegroundColor DarkMagenta
        Invoke-RestMethod `
            -Method Patch `
            -Headers $vstsHeaders `
            -Uri $uri `
            -Body $body `
            -ContentType 'application/json' | Out-Null
    }
}

function toAdd($id){
    $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/Suites/$($testSuite.id)/TestCase?api-version=7.1-preview.3"
    $testCases = Invoke-RestMethod `
        -Method Get `
        -Headers $vstsHeaders `
        -ContentType 'application/json' `
        -Uri $uri
    if($id -in $testCases.value.workitem.id){
        return $false
    }
    else{
        return $true
    }
}

function getRunId(){
    $body = @"
    {
        "contributionIds": [
            "ms.vss-test-web.testcase-results-data-provider"
        ],
        "dataProviderContext": {
            "properties": {
                "testCaseId": $(queryItems $execution.issueKey),
                "sourcePage": {
                    "url": "$vsts/_testPlans/execute?planId=$($plan.id)&suiteId=$($suite.id)",
                    "routeId": "ms.vss-test-web.testplans-hub-refresh-route",
                    "routeValues": {
                        "project": "EPAM TEST",
                        "pivots": "execute",
                        "controller": "ContributedPage",
                        "action": "Execute",
                        "serviceHost": "$collectionId ($organizationName)"
                    }
                }
            }
        }
    }
"@
    $uri = "https://dev.azure.com/$organizationName/_apis/Contribution/HierarchyQuery/project/$projectName`?api-version=6.1-preview.1"
    $response = Invoke-RestMethod `
        -Method Post `
        -Headers $vstsHeaders `
        -ContentType 'application/json' `
        -Uri $uri `
        -Body $body
    return $response.dataProviders.'ms.vss-test-web.testcase-results-data-provider'.results[0]
}

function makeHex($number){
    $hex = "{0:X}" -f $number
    return '{0}{1}' -f $("0"*$(8 - $hex.Length)), $hex
}

function checkUser($user){
    $uri = "https://vsaex.dev.azure.com/$organizationName/_apis/userentitlements?`$filter=name+eq+'$user'&api-version=6.0-preview.3"

    $users = Invoke-RestMethod `
        -Method Get `
        -Uri $uri `
        -Headers $vstsHeaders `
        -ContentType 'application/json'
    
    return $users.members
}

function addStepAttachments(){
    $uri = "$zephyrApi/attachment/attachmentsByEntity?entityId=$($step.id)&entityType=TESTSTEPRESULT"
    $response = Invoke-RestMethod `
        -Method Get `
        -Headers $headers `
        -ContentType 'application/json' `
        -Uri $uri
    if(!(Test-Path $PSScriptRoot/attachments)){
        mkdir $PSScriptRoot/attachments
    }
    $ProgressPreference = 'SilentlyContinue'
    foreach($item in $response.data){
        $uri = "$jira/plugins/servlet/schedule/viewAttachment?id=$($item.fileId)&name=$($item.fileName)"
        Invoke-WebRequest `
            -Method Get `
            -Headers $headers `
            -Uri $uri `
            -OutFile "$PSScriptRoot/attachments/$($item.fileName)"
        $contentBytes = Get-Content "$PSScriptRoot/attachments/$($item.fileName)" -AsByteStream
        $base64 = [Convert]::ToBase64String($contentBytes)
        $body = @"
        {
            "attachmentType": "GeneralAttachment",
            "fileName": "$($item.fileName)",
            "stream": "$base64",
            "comment": ""
        }
"@
        $uri = "$vsts/_apis/test/Runs/$($results.runId)/Results/$($results.resultId)/Attachments?iterationId=1&api-version=5.0"
        Write-Host "Upload test step attachment" -ForegroundColor Magenta
        Invoke-RestMethod `
            -Method Post `
            -ContentType "application/json"`
            -Headers $vstsHeaders `
            -Uri $uri `
            -Body $body
        Remove-Item "$PSScriptRoot/attachments/$($item.fileName)"
    }
}

function setStepsStatuses($suite){
    $uri = "$zephyrApi/stepResult?executionId=$($execution.id)"
    #"$uri"
    $steps = Invoke-RestMethod `
        -Method Get `
        -Headers $headers `
        -ContentType 'application/json' `
        -Uri $uri
    #$steps.Count
    if($steps){
        $i = 2
        $actionResults = @()
        $results = getRunId
        foreach($step in $steps){
            $actionResults += [PSCustomObject]@{
                outcome = getOutcome $step.status
                actionPath = makeHex $i
                iterationId = 1
                stepIdentifier = $i
                errorMessage = if($step.htmlComment.Length -gt 0){$step.comment}
                               else{""}
            }
            addStepAttachments
            $i++
        }
        $iterationDetails = [PSCustomObject]@{
            id = 1
            outcome = getOutcome $execution.executionStatus
            actionResults = $actionResults
        }
        $testResults = [PSCustomObject]@{
            id = $results.resultId
            iterationDetails = @($iterationDetails)
            owner = [PSCustomObject]@{
                displayName = if(checkUser $execution.createdByDisplay){$execution.createdByDisplay}
                              else{$null}
            }
            runBy = [PSCustomObject]@{
                displayName = if(checkUser $execution.executedByDisplay){$execution.executedByDisplay}
                              else{$null}
            }
        }
        $body = @(
            $testResults
        )
        $body = ConvertTo-Json $body -Depth 10
        #"$body"
        $uri = "$vsts/_apis/test/Runs/$($results.runId)/results?api-version=7.1-preview.6"
        Write-Host "Upgrade test steps of test case $($execution.issueKey)" -ForegroundColor DarkMagenta
        Invoke-RestMethod `
            -Method Patch `
            -uri $uri `
            -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) `
            -Headers $vstsHeaders `
            -ContentType 'application/json' | Out-Null
    }
}
