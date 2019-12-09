Param(
    [pscredential]$Credential,
    [boolean]$Backout
)

if ($Backout -eq $true) {
    # If we are backing out, set things to the way they were before the change
    if (Get-DnsServerZone "cprod.corp.ntgov") {
        "DNS Zone cprod.corp.ntgov already present"
        Invoke-Command DRWNT-DC4 -ScriptBlock { Remove-DnsServerZone "cprod.corp.ntgov" } -Credential $Credential
        Invoke-Command DRWNT-DC4 -ScriptBlock { Add-DnsServerStubZone -MasterServers 155.205.8.161,155.205.7.119 -ReplicationScope "Forest" } -Credential $Credential
    } else {
        "DNS Zone cprod.corp.ntgov not present. Recreating"
        Invoke-Command DRWNT-DC4 -ScriptBlock { Add-DnsServerStubZone -MasterServers 155.205.8.161,155.205.7.119 -ReplicationScope "Forest" } -Credential $Credential
    }

    # this script will be run on all domain controllers
    $scriptBlock = {
        if (Get-DnsServerZone -Name "corp.ntgov") {
            "DNS Zone corp.ntgov already present"
            Set-DnsServerConditionalForwarderZone -Name "corp.ntgov" -MasterServers 150.191.240.2,150.191.250.2
        } else {
            "DNS Zone corp.ntgov not present. Recreating..."
            Add-DnsServerConditionalForwarderZone -Name "corp.ntgov" -MasterServers 150.191.240.2,150.191.250.2
        }
    }
    # Apply change in conditional forwarder zones to all core DCs
    1..9 | ForEach-Object {
        Invoke-Command -ComputerName "DRWNT-DC$_" -ScriptBlock $scriptBlock -Credential $Credential
    }
} else {
    # Lets apply the change..
    # Delete cprod.corp.ntgov stub zone
    Remove-DnsServerZone "cprod.corp.ntgov" -PassThru -Verbose

    # this script will be run on all domain controllers
    $scriptBlock = {
        # Update conditional forwarder for corp.ntgov
        Set-DnsServerConditionalForwarderZone -Name "corp.ntgov" -MasterServers 10.2.35.22,10.2.35.23
        # Add conditional forwarder for cprod.corp.ntgov
        Add-DnsServerConditionalForwarderZone -Name "cprod.corp.ntgov" -MasterServers 10.2.35.20,10.2.35.21
    }

    # Apply change in conditional forwarder zones to all core DCs
    1..9 | ForEach-Object {
        Invoke-Command -ComputerName "DRWNT-DC$_" -ScriptBlock $scriptBlock -Credential $Credential
    }
}
