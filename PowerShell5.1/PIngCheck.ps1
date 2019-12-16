
[CmdletBinding()]
param (
    [Parameter()]
    [string[]]
    $computers
)


$computers | Foreach-Object { 
    $operatingSystem = (Get-ADComputer $_ -Properties OperatingSystem).OperatingSystem
    if (Test-Connection $_ -Count 1 -Quiet ) {
        [PSCustomObject]@{
            Name = $_
            Ping = 'TRUE'
            OperatingSystem = $operatingSystem
        } | export-csv pingout.csv -Append -NoTypeInformation
    } else {
        [PSCustomObject]@{
            Name = $_
            Ping = 'FALSE'
            OperatingSystem = $operatingSystem
        } | export-csv pingout.csv -Append -NoTypeInformation
    }
}