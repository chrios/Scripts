$list = import-csv -Path C:\Users\scchristopher.frew\Desktop\iis.csv
$parse = '(?<URL>(?<=SITE\s\")\w+\.\w+\.\w+(?=\")|(?<=SITE\s\")\w+\.\w+\.\w+\.\w+(?=\")).+state:(?<State>\w+)'

$list | %{
    if ($_ -match $parse) {
        [PSCustomObject]@{
            URL = $matches.URL
            State = $matches.state
        } | export-csv -Path C:\Users\scchristopher.frew\Desktop\iisParsed.csv -NoTypeInformation -Append
    }
}