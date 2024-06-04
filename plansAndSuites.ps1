#!/usr/bin/pwsh

function queryItems($jiraKey){
    $uri = "$vsts/_apis/wit/wiql?api-version=6.0-preview.2"
    $query = "SELECT [System.Id] FROM WorkItems WHERE [System.WorkItemType] = 'Test Case' AND [Custom.JiraIssueID] = '$jiraKey'"
    $body = @{query = $query}
    $bodyJson = @($body) | ConvertTo-Json
    $workItem = Invoke-RestMethod -Method Post `
        -Headers $vstsHeaders `
        -Uri $uri `
        -ContentType $contentType `
        -Body $bodyJson
    $workItem.workItems[0].id
}

function addTestCases($testSuite){

    $id = queryItems $execution.issueKey
    if($id){
        $testCaseId = $id
    }
    else{
        $uri = "$jiraAPI/issue/$($execution.issueKey)"
        $test = Invoke-RestMethod `
            -Method Get `
            -Headers $headers `
            -ContentType $contentType `
            -Uri $uri
        #get description section
        $description = processDescription $test.fields.description
        getSteps

        #get metadata
        if(Get-Content $PSScriptRoot/vstsSteps.stp){
            $allSteps = ((Get-Content $PSScriptRoot/vstsSteps.stp -Raw) -replace "\n","") -replace '"','\"'
        }
        else{
            $allSteps = $null
        }
        $assignedTo = $test.fields.assignee.displayName
        $tags = $test.fields.labels -join (';')
        $summary = $test.fields.summary -replace '"','\"'
        $priority = $test.fields.priority.name.toLower()
        $status = $test.fields.status.name
        $testSpecification = processDescription $test.fields.customfield_10361
        switch -regex ($test.fields.status.name.toLower()){
            'definition|estimation' {
                $status = 'Design'
            }
            'closed' {
                $status = 'Closed'
            }
            default {
                $status = 'Ready'
            }
        }

        #create work item
        $testCase = createTestCase
        Write-Host "Test case $($testCase.id) is created" -ForegroundColor Green
        
        #add attachments to the work item
        addAttachments
        if(Test-Path "$PSScriptRoot/$($test.id)"){
            Remove-Item "$PSScriptRoot/$($test.id)" -Recurse -Force
        }
        $testCaseId = $testCase.id
    }

    if(toAdd $testCaseId){
        Write-Host "Adding test cases $($execution.issueKey) to the suite $($testSuite.name) with id $($testSuite.name)" -ForegroundColor Green
        $body = '[{{"pointAssignments":[],"workItem":{{"id":{0}}}}}]' -f $testCaseId
        $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/Suites/$($testSuite.id)/TestCase?api-version=7.1-preview.3"
        Invoke-RestMethod -Method Post -Body $body -Uri $uri -Headers $vstsHeaders -ContentType 'application/json' | Out-Null
    }
    else{
        Write-Host "Test case $($execution.issueKey) is already added to the suite $($testSuite.name)" -ForegroundColor Green
    }

    processConfiguration
}

. $PSScriptRoot/prod_functions.ps1

$token = ""
$text = ""
$bytes = [System.Text.Encoding]::UTF8.GetBytes($text)
$encodedText = [Convert]::ToBase64String($bytes)
$headers =  @{Authorization=("Basic {0}" -f $encodedText)}
$contentType = 'application/json'
$pat = ''
$user = ''
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $user, $pat)))
$vstsHeaders = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
$vsts = "https://dev.azure.com/remira/EPAM%20TEST"
$jira = "https://intranet.futura4retail.com/issues"
$jiraAPI = "$jira/rest/api/latest"
$zephyrAPI = "$jira/rest/zapi/latest"
$organizationName = "remira"
$projectName = "EPAM%20TEST"
$vsts = "https://dev.azure.com/$organizationName/$projectName"
$collectionId = "61773c56-881d-47b4-8591-49a4536e6fc7"

$uri = "https://intranet.futura4retail.com/issues/rest/zapi/latest/cycle?projectId=10100"
$cycles = Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri $uri

$versions = ($cycles | Get-Member | Where-Object{$_.MemberType -eq 'NoteProperty'}).Name

$cycleIds = ($cycles.'18010' | Get-Member | Where-Object{$_.MemberType -eq 'NoteProperty' -and $_.Name -ne 'recordsCount'}).Name

#https://intranet.futura4retail.com/issues/rest/zapi/latest/cycle/269/folders?projectId=10100&versionId=16755
#https://intranet.futura4retail.com/issues/rest/zapi/latest/execution?cycleId=-1&versionId=17210&projectId=10100
#https://intranet.futura4retail.com/issues/rest/zapi/latest/execution?cycleId=269&folderId=210

#creating test plan

$uri = "$vsts/_apis/testplan/plans?api-version=7.1-preview.1"
$body = @"
{
    "name": "Unreleased",
    "areaPath": "EPAM TEST",
    "iteration": "EPAM TEST",
    "owner": null
}
"@
$plans = Invoke-RestMethod -Method Get -Headers $vstsHeaders -ContentType $contentType -Uri $uri
$plan = $plans.value | Where-Object{$_.name -eq 'Unreleased'}
if($plan){
    Write-Host "Plan 'Unreleased' is already created" -ForegroundColor Cyan
}
else{
    Write-Host "Creating test plan 'Unreleased'"
    $plan = Invoke-RestMethod -Method Post -Headers $vstsHeaders -ContentType $contentType -Uri $uri -Body $body
}
$uri = "$vsts/_apis/testplan/Plans/$($plan.id)/suites?api-version=7.1-preview.1"
$parentSuiteId = (Invoke-RestMethod -Method Get -Headers $vstsHeaders -ContentType $contentType -Uri $uri).value[0].id

foreach($cycleId in $cycleIds){
    if($cycleId -eq '-1'){
        # Create version test suite
        $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/suites?api-version=7.1-preview.1"
        $body = @"
        {
            "suiteType": "staticTestSuite",
            "name": "$(replaceUmlaut $cycles.'18010'.$cycleid.versionName)",
            "parentSuite": {
              "id": $parentSuiteId
            },
            "inheritDefaultConfigurations": true
        }
"@
        $suites = Invoke-RestMethod -Method Get -Headers $vstsHeaders -ContentType $contentType -Uri $uri
        $versionSuite = $suites.value | Where-Object{$_.name -eq "$(replaceUmlaut $cycles.'18010'.$cycleid.versionName)" -and $_.parentSuite.id -eq $parentSuiteId}
        if($versionSuite){
            Write-Host "Test suite $($versionSuite.name) with id $($versionSuite.id) is already created" -ForegroundColor Cyan
        }
        else{
            Write-Host "Creating test suite $(replaceUmlaut $cycles.'18010'.$cycleid.versionName)"
            $versionSuite = Invoke-RestMethod -Method Post -Headers $vstsHeaders -ContentType $contentType -Uri $uri -Body $body
            Write-Host "Test suite $(replaceUmlaut $cycles.'18010'.$cycleid.versionName) is created with ID $($versionSuite.id)"
        }
        if($cycles.'18010'.$cycleId.totalCycleExecutions -gt 0){
            $uri = "https://intranet.futura4retail.com/issues/rest/zapi/latest/execution?cycleId=$cycleId&versionId=18010&projectId=10100"
            $executions = Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri $uri
            foreach($execution in $executions.executions){
               Write-Host "Adding test cases $($execution.issueKey)" -ForegroundColor Green
               addTestCases $versionSuite
            }
            Write-Host "Setting test status" -ForegroundColor DarkGreen
            setTestsStatuses $versionSuite
            foreach($execution in $executions.executions){
                setStepsStatuses $versionSuite
            }
        }
    }
    else{
        $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/suites?api-version=7.1-preview.1"
        $body = @"
        {
            "suiteType": "staticTestSuite",
            "name": "$(replaceUmlaut $cycles.'18010'.$cycleId.name)",
            "parentSuite": {
                "id": $($versionSuite.id)
            },
            "inheritDefaultConfigurations": true
        }
"@
        $suites = Invoke-RestMethod -Method Get -Headers $vstsHeaders -ContentType $contentType -Uri $uri
        $suite = $suites.value | Where-Object{$_.name -eq "$(replaceUmlaut $cycles.'18010'.$cycleId.name)" -and $_.parentSuite.id -eq $($versionSuite.id)}
        if($suite){
            Write-Host "Test suite $($suite.name) with id $($suite.id) is already created" -ForegroundColor Cyan
        }
        else{
            Write-Host "Creating test suite $(replaceUmlaut $cycles.'18010'.$cycleId.name)"
            $suite = Invoke-RestMethod -Method Post -Headers $vstsHeaders -ContentType $contentType -Uri $uri -Body $body
            Write-Host "Test suite $($suite.name) is created with ID $($suite.id)"
        }
        if($cycles.'18010'.$cycleId.totalCycleExecutions -gt 0){
            $uri = "https://intranet.futura4retail.com/issues/rest/zapi/latest/execution?cycleId=$cycleId&versionId=18010&projectId=10100"
            $executions = Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri $uri
            foreach($execution in $executions.executions){
               Write-Host "Adding test cases $($execution.issueKey)" -ForegroundColor Green
               addTestCases $suite
            }
            Write-Host "Setting test status" -ForegroundColor DarkGreen
            setTestsStatuses $suite
            foreach($execution in $executions.executions){
                setStepsStatuses $suite
            }
        }
        if($cycles.'18010'.$cycleId.totalFolders -gt 0){
            $uri = "https://intranet.futura4retail.com/issues/rest/zapi/latest/cycle/$cycleId/folders?projectId=10100&versionId=18010"
            $folders = Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri $uri
            foreach($folder in $folders){
                $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/suites?api-version=7.1-preview.1"
                $body = @"
                {
                    "suiteType": "staticTestSuite",
                    "name": "$(replaceUmlaut $folder.folderName)",
                    "parentSuite": {
                        "id": $($suite.id)
                    },
                    "inheritDefaultConfigurations": true
                }
"@
                $suites = Invoke-RestMethod -Method Get -Headers $vstsHeaders -ContentType $contentType -Uri $uri
                $folderSuite = $suites.value | Where-Object{$_.name -eq "$(replaceUmlaut $folder.folderName)" -and $_.parentSuite.id -eq $($suite.id)}
                if($folderSuite){
                    Write-Host "Test suite $($folderSuite.name) with id $($folderSuite.id) is already created" -ForegroundColor Cyan
                }
                else{
                    Write-Host "Creating test suite $(replaceUmlaut $folder.folderName)"
                    $folderSuite = Invoke-RestMethod -Method Post -Headers $vstsHeaders -ContentType $contentType -Uri $uri -Body $body
                    Write-Host "Test suite $($folderSuite.name) is created with ID $($folderSuite.id)"
                }
                $uri = "https://intranet.futura4retail.com/issues/rest/zapi/latest/execution?cycleId=$cycleId&folderId=$($folder.folderId)"
                $executions = Invoke-RestMethod -Method Get -Headers $headers -ContentType $contentType -Uri $uri
                foreach($execution in $executions.executions){
                   Write-Host "Adding test case $($execution.issueKey)" -ForegroundColor Green
                   addTestCases $folderSuite
                }
                Write-Host "Setting test status" -ForegroundColor DarkGreen
                setTestsStatuses $folderSuite
                foreach($execution in $executions.executions){
                    setStepsStatuses $folderSuite
                }
            }
        }
    }
}
