Param(
    [string[]]$ServerList,
    [pscredential]$Credential
)

$script = {
    cd 'C:\Program Files\Microsoft Monitoring Agent\Agent\'
    .\HSLockdown.exe /A "NT AUTHORITY\SYSTEM"
    Get-Service HealthService | Restart-Service
}

$ServerList | ForEach-Object {
    Invoke-Command -Credential $Credential -ScriptBlock $script -ComputerName $_
}