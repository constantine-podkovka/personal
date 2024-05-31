# Count string occurence in all files in a directory.

#$path = "C:\AAAAA\git\ROME-PQ.wiki\"
#$filter = "*.md"
$strFrom = "https://dev.azure.com/aaabedev/"#rome-uat/"#_wiki/"
#$strTo = "https://dev.azure.com/nbsdevops/ROME-PQ/_wiki/"

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
            #$content = $content.Replace( $strFrom , $strTo )
            #Set-Content -LiteralPath $file -Value $content
            #Write-Host "Replaced successfully"
            $mCounter = $mCounter + $match
            $fCounter = $fCounter +1
        }
    }
}

Write-Host "Totaly found" $mCounter "in" $fCounter "files."