# Set Headers and Tokens

$ContentType = "application/json"

$SourceOrganisation = ""
$SourceProject = ""
$SourcePersonalAccessToken = ""
$SourceToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($SourcePersonalAccessToken)"))
$SourceHeader = $AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + $SourceToken;accept=$ContentType}

$TargetOrganisation = ""
$TargetProject = ""
$TargetPersonalAccessToken = ""
$TargetToken = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($TargetPersonalAccessToken)"))
$TargetHeader = $AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + $TargetToken;accept=$ContentType}


# QUERY TESTPOINTS

#https://nbsdevops.visualstudio.com/AAA%20Rome/_testPlans/execute?planId=22437&suiteId=22561

$planId=22437
$suiteId=22440
$uri = "https://dev.azure.com/$SourceOrganisation/$SourceProject/_apis/test/Plans/$($planId)/Suites/$($suiteId)/points?api-version=7.1"
$points = Invoke-RestMethod -Method Get -Headers $SourceHeader -ContentType $ContentType -Uri $uri

#$points.value[].id
#$points.value[].outcome
#$points.value[].lastResultDetails.dateCompleted


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

function setTestsStatuses($testSuite){
    $uri = "$vsts/_apis/test/Plans/$($plan.id)/Suites/$($testSuite.id)/points?api-version=7.1"
    $points = Invoke-RestMethod -Method Get -Headers $vstsHeaders -ContentType 'application/json' -Uri $uri
    foreach($point in $points.value){
        $thisExecution = $executions.executions | Where-Object{$_.issueKey -eq $(returnJiraIssueId $point.testCase.id) -and $(cutName $_.comment).Replace(' ','').Replace('Windows10','') -eq $point.configuration.name.Replace(' ','').Replace('"','\"').Replace('Windows10','')}
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
        $uri = "$vsts/_apis/testplan/Plans/$($plan.id)/Suites/$($testSuite.id)/TestPoint?api-version=7.1"
        Write-Host "Set test $($point.testCase.id) execution status to $outcome" -ForegroundColor DarkMagenta
        Invoke-RestMethod -Method Patch -Headers $vstsHeaders -Uri $uri -Body $body -ContentType 'application/json' | Out-Null
    }
}











