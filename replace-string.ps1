# Replace string occurence in all files in a directory.

#$path = "C:\AAAAA\git\ROME-PQ.wiki\"
#$filter = "*.md"
$strFrom = "https://dev.azure.com/aaabedev/rome-uat/_wiki/"
$strTo = "https://dev.azure.com/nbsdevops/ROME-PQ/_wiki/"

Write-Host "Getting files..."
$files = Get-ChildItem *.md -Recurse
Write-Host "Totaly found" $files.count "files"
$mCounter = 0
$fCounter = 0

foreach ( $file in $files )
{
    $content = Get-Content -LiteralPath $file
    if ( $content.Length -gt 0 )
    {
        $match = ( $content | Select-String -pattern $strFrom -List ).count
        if ( $match -gt 0 )
        {
            Write-Host "Matching string found" $match "time(s) in the following file:`n" $file
            $newcontent = $content.Replace( $strFrom , $strTo )
            Set-Content -LiteralPath $file -Value $newcontent
            Write-Host "Replaced successfully"
            $mCounter = $mCounter + $match
            $fCounter = $fCounter +1
        }
    }
}

Write-Host "Totaly replaced" $mCounter "in" $fCounter "files."



#(Get-ChildItem *.md -Recurse | Get-Content | Select-String -pattern "https://dev.azure.com/aaabedev/rome-uat/_queries" -List).count


#Get-ChildItem *.md -Recurse | ForEach-Object { (Get-Content $_).Replace('https://dev.azure.com/aaabedev/rome-uat/_wiki/' , 'https://dev.azure.com/nbsdevops/ROME-PQ/_wiki/') | Set-Content $_ }

#Get-ChildItem *.md -Recurse | ForEach-Object { Get-Content $_ }