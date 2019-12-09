
$computers = "WIN-DETAS5L5U2U","TAMINHS-APP2","MCC-DRW-FS01","SFASDC","ARALUSCH-CV1","DWNHIGH-CLKVID1","dwnhigh-ps1","DWNHIGH-SEC1","LITCHSCH-CV1","LITCHSCH-CV2","LIVINSCH2","MCC-DRW-AP01","MCC-DRW-CV1","MCC-DRW-PS01","MCC-DRW-TS01","NHULUCSC-CV1","PALMEHS-TS1","ROSEBMSVS2","STPAUSCH-FS3","TAMINHS-PS2","WAGAMSCH-LIB1"


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


