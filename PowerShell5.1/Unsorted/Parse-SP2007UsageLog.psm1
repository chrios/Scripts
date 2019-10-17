function Parse-SP2007Log {

    Param(
        [Parameter(Mandatory=$true)][String[]]$LogFolder,
        [Parameter(Mandatory=$true)][String]$OutputFile
    )
    $dayFolders = Get-ChildItem $LogFolder
    $parseLog = '(?<AccessTime>\d\d:\d\d:\d\d).(?<URL>htt(p|ps):\/\/\w+.\w+.\w+.+?(?=ntschools))(?<UserName>\w+\\\w+\.\w+)'

    $sw = New-Object System.IO.StreamWriter $OutputFile


    $dayFolders | ForEach-Object {
        $currentDayFolder = $_
        $date = $currentDayFolder.Name

        Get-ChildItem $currentDayFolder.FullName | ForEach-Object {
            $currentLogFile = $_
            $log = get-content $currentLogFile.FullName
            $multiLine = $log -split "`r`n"

            $multiLine | ForEach-Object {
                $currentLogFileLine = $_

                if ($currentLogFileLine -match $parseLog) {
                    "Logging $date..."
                    $logLine = $date+','+$matches.AccessTime+','+$matches.Username+','+$matches.URL

                    $sw.WriteLine($logLine)
                }
            }
        }
    }
    $sw.Close()
}
