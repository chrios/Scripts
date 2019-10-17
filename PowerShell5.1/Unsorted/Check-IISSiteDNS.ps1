$iisSites = Import-Csv -Path C:\Users\scchristopher.frew\Desktop\iisParsed.csv

$iisSites | ForEach-Object {
    $address = (Resolve-DnsName -Name $_.URL -Server 10.55.15.24).IP4Address
    $runningHost = (Resolve-DnsName -Name $address -Type PTR).NameHost
    
    [PSCustomObject]@{
        IP4Address = $address
        URL = $_.URL
        State = $_.State
        RunningHost = $runningHost
    } | Export-csv -Path C:\Users\scchristopher.frew\Desktop\iisDns.csv -Append -NoTypeInformation
}