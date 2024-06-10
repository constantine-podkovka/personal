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


$workItemId = '29874'

$Uri = "https://dev.azure.com/$SourceOrganisation/$SourceProject/_apis/wit/wiql?api-version=7.1"
$query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$SourceProject' AND [System.Id] = '$workItemId' AND [System.WorkItemType] = 'Test Case' ORDER BY [System.ChangedDate] desc"
$body = @{query = $query} | ConvertTo-Json
$workItems = Invoke-RestMethod -Method POST -Uri $Uri -Headers $SourceHeader -ContentType $ContentType -Body $body

$Uri = $workItems.workItems.url + "?api-version=7.1"
$WorkItem = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader
$SourceData = $WorkItem.fields.'Custom.AutomatedID'


$workItemId = '76495'

$Uri = "https://dev.azure.com/$TargetOrganisation/$TargetProject/_apis/wit/wiql?api-version=7.1"
$query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$TargetProject' AND [System.Id] = '$workItemId' AND [System.WorkItemType] = 'Test Case' ORDER BY [System.ChangedDate] desc"
$body = @{query = $query} | ConvertTo-Json
$workItems = Invoke-RestMethod -Method POST -Uri $Uri -Headers $TargetHeader -ContentType $ContentType -Body $body


$Uri = $workItems.workItems.url + "?api-version=7.1"
$WorkItem = Invoke-RestMethod -Method GET -Uri $uri -Headers $TargetHeader
$TargetData = $WorkItem.fields.'Custom.AutomatedID'


$Uri = "https://dev.azure.com/$SourceOrganisation/_apis/wit/fields?api-version=7.1"
$Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader

$Uri = "https://dev.azure.com/$SourceOrganisation/_apis/wit/fields/Custom.AutomatedID?api-version=7.1"
$Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader

$Uri = "https://dev.azure.com/$TargetOrganisation/_apis/wit/fields/Custom.AutomatedID?api-version=7.1"
$Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $TargetHeader
