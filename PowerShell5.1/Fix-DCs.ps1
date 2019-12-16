Param(
    [pscredential]$Credential,
    [string[]]$dcs
)



$script = {
    cd 'C:\Program Files\Microsoft Monitoring Agent\Agent\'
    .\HSLockdown.exe /A "NT AUTHORITY\SYSTEM"
    Get-Service HealthService | Restart-Service
}

$dcs | ForEach-Object {
    "Fixing $($_)..."
    try {
        $scriptout = Invoke-Command -Credential $Credential -ScriptBlock $script -ComputerName $_
    } catch {
        "Failed fixing $_"
    }
    
}