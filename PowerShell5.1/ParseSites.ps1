# These scripts will allow you to check if sites that are still on an IIS web server are in fact in production, checking DNS for source of truth...

# Get the output of appcmd list sites from WS51...
function Get-CurrentSitesMigration {
    Param(
        [string]$WebServer,
        [pscredential]$Credential,
        [string]$ExportPath
    )

    $output = Invoke-Command -ComputerName $WebServer -Credential $Credential -ScriptBlock {c:\windows\system32\inetsrv\APPCMD list sites}

    $output | Out-File -FilePath $ExportPath
}
# Parse the output and export a CSV with current status of sites...
function Invoke-ParseSites {
    Param(
        [string]$SitesFilePath,
        [string]$ExportFile
    )
    $sites = Get-Content $SitesFilePath
    $sites | ForEach-Object {
        $url = $_.split(" ")[1].replace('"','')
        if ($ip = (Resolve-DnsName $url -ErrorAction SilentlyContinue ).IPAddress) {
            if ($server = (Resolve-DnsName $ip -Type PTR -ErrorAction SilentlyContinue).NameHost) {
                if ($server.GetType().FullName -eq 'System.String') {
                    $serverName = $server
                } else {
                    $serverName = "IP Address resolves to multiple server names."
                }
                
            } else {
                $serverName = "Unable to resolve IP address to server name."
            }
        } else {
            $ip = "No DNS A record."
            $serverName = "No DNS A record."
        }
        
        [PSCustomObject]@{
            URL = $url
            IP = $ip
            SERVER = $serverName
        } | Export-Csv -NoTypeInformation -Append -Path $ExportFile 
    }
}