# Remove all work items in Azure DevOps project

$Organisation = ""
$Project = ""
$PersonalAccessToken = ""
$ContentType = "application/json"

$Token = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(":$($PersonalAccessToken)"))
$Header = $AzureDevOpsAuthenicationHeader = @{Authorization = 'Basic ' + $Token;accept=$ContentType}

# QUERY WI

$Uri = "https://dev.azure.com/$Organisation/$Project/_apis/wit/wiql?api-version=7.1"
$query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$Project' AND [System.WorkItemType] NOT IN ('Test Case', 'Test Suite', 'Test Plan', 'Shared Steps', 'Shared Parameter', 'Feedback Request') ORDER BY [System.ChangedDate] desc"
$body = @{query = $query} | ConvertTo-Json
$workItems = Invoke-RestMethod -Method POST -Uri $Uri -Headers $Header -ContentType $ContentType -Body $body

#$workItem.workItems[].id
#$workItem.workItems[].url

#COUNT WI

$count = $workItems.workItems.id.Count

#DELETE WI

$progress = 0
foreach ($workItemId in $workItems.workItems.id)
{
    $Uri = "https://dev.azure.com/$Organisation/$Project/_apis/wit/workitems/$($workItemId)?destroy=true&api-version=7.1"
    $DeletedWorkItem = Invoke-RestMethod -Method DELETE -Uri $uri -Headers $Header
    $progress = $progress + 1
    if ($progress -match '^\d+[0,5]$' ) { Write-Host $progress "/" $count }
}



# QUERY TEST CASES

$Uri = "https://dev.azure.com/$Organisation/$Project/_apis/wit/wiql?api-version=7.1"
$query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$Project' AND [System.WorkItemType] = 'Test Case' ORDER BY [System.ChangedDate] desc"
$body = @{query = $query} | ConvertTo-Json
$workItems = Invoke-RestMethod -Method POST -Uri $Uri -Headers $Header -ContentType $ContentType -Body $body

#COUNT TEST CASES

$count = $workItems.workItems.id.Count

#DELETE TEST CASES

$progress = 0
foreach ($workItemId in $workItems.workItems.id)
{
    $Uri = "https://dev.azure.com/$Organisation/$Project/_apis/test/testcases/$($workItemId)?api-version=7.1"
    $DeletedWorkItem = Invoke-RestMethod -Method DELETE -Uri $uri -Headers $Header
    $progress = $progress + 1
    if ($progress -match '^\d+[0,5]$' ) { Write-Host $progress "/" $count }
}



# QUERY TEST PLANS

$Uri = "https://dev.azure.com/$Organisation/$Project/_apis/wit/wiql?api-version=7.1"
$query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$Project' AND [System.WorkItemType] = 'Test Plan' ORDER BY [System.ChangedDate] desc"
$body = @{query = $query} | ConvertTo-Json
$workItems = Invoke-RestMethod -Method POST -Uri $Uri -Headers $Header -ContentType $ContentType -Body $body

#COUNT TEST PLANS

$count = $workItems.workItems.id.Count

#DELETE TEST PLANS

$progress = 0
foreach ($workItemId in $workItems.workItems.id)
{
    $Uri = "https://dev.azure.com/$Organisation/$Project/_apis/testplan/plans/$($workItemId)?api-version=7.1"
    $DeletedWorkItem = Invoke-RestMethod -Method DELETE -Uri $uri -Headers $Header
    $progress = $progress + 1
    if ($progress -match '^\d+[0,5]$' ) { Write-Host $progress "/" $count }
}