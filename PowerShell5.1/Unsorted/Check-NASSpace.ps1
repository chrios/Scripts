$csv = Import-Csv c:\temp\NAS.csv

 
 $csv | ForEach-Object { 
    $computer = $_.CN
    "Testing $computer..."

    $disk = Get-WmiObject Win32_LogicalDisk -ComputerName $_.CN -Filter "DeviceID='e:'" | Select-Object Size,FreeSpace
    [PSCustomObject]@{
        Name = [string]$_.CN
        Size = [string]$disk.Size / 1GB
        FreeSpace = [string]$disk.FreeSpace / 1GB
    } | Export-Csv -Path C:\TEMP\Output.csv -Append -NoTypeInformation
}