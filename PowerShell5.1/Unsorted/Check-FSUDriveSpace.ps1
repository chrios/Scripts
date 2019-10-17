 $csv = Import-Csv -Path C:\TEMP\nas.csv
 
 $csv | ForEach-Object { 
    $computerName = $_.Name.Split('-')[0] + '-FS1'
    "Testing $computerName..."
    Get-Date
    $disk = Get-WmiObject Win32_LogicalDisk -ComputerName $computerName -Filter "DeviceID='f:'" | Select-Object Size,FreeSpace
    [PSCustomObject]@{
        Name = [string]$_.Name
        Size = [string]$disk.Size / 1GB
        FreeSpace = [string]$disk.FreeSpace / 1GB
    } | Export-Csv -Path C:\TEMP\Output.csv -Append -NoTypeInformation
}