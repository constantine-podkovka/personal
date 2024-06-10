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

$Uri = "https://dev.azure.com/$SourceOrganisation/_apis/projects?api-version=7.1"
$SourceProjects = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader

$Uri = "https://dev.azure.com/$TargetOrganisation/_apis/projects?api-version=7.1"
$TargetProjects = Invoke-RestMethod -Method GET -Uri $uri -Headers $TargetHeader

$WITypes = "Bug","Epic","Feature","Impediment","Issue","Query","Test Case","Test Plan","Test Suite"

foreach ($project in $TargetProjects.value) {
    Write-Host "Getting fields in" $project.name "..."
    $projectID = $project.id
    $Uri = "https://dev.azure.com/$TargetOrganisation/$projectid/_apis/wit/fields?api-version=7.1"
    $Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $TargetHeader
    Write-Host "Got" $Fields.count "fields."
    foreach ($field in $fields.value){
        if ($field.referenceName -eq 'Custom.AutomatedID'){
            Write-Host "Custom.AutomatedID is used in" $project.name
        }
    }

}


$Uri = "https://dev.azure.com/$SourceOrganisation/$SourceProject/_apis/wit/workitemtypes/bug?api-version=7.1-preview.2"
$TargetWITypes = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader






$Uri = "https://dev.azure.com/$SourceOrganisation/_apis/wit/fields?api-version=7.1"
$Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader

$Uri = "https://dev.azure.com/$SourceOrganisation/_apis/wit/fields/Custom.AutomatedID?api-version=7.1"
$Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $SourceHeader

$Uri = "https://dev.azure.com/$TargetOrganisation/_apis/wit/fields/Custom.AutomatedID?api-version=7.1"
$Fields = Invoke-RestMethod -Method GET -Uri $uri -Headers $TargetHeader
