function Parse-SP2007Log {

    Param(
        [Parameter(Mandatory=$true)][String[]]$LogFolder,
        [Parameter(Mandatory=$true)][String[]]$OutputFile
    )
    $dayFolders = Get-ChildItem $LogFolder
    $parseLog = '(?<AccessTime>\d\d:\d\d:\d\d)\s(?<URL>htt(p|ps):\/\/\w+.\w+.\w+.+?(?=ntschools))(?<UserName>\w+\\\w+\.\w+)'

    $dayFolders | ForEach-Object {
        $date = $_.Name
        Get-ChildItem | ForEach-Object {
        
            $log = get-content $_.Name
            $multiLine = $log -split "`r`n"
            $multiLine | ForEach-Object {
                if ($_ -match $parseLog) {
                    [PSCustomObject]@{
                        Date = $date
                        AccessTime = $matches.AccessTime
                        UserName = $matches.UserName
                        URL = $matches.URL
                    } | export-csv -Path $OutputFile -Append -NoTypeInformation
                }
            }
        }
    }

}
