

function Invoke-SwapNetIPAddress
{
    <#
.SYNOPSIS
    This function will swap the IP addresses between two VM's using Invoke-VMScript

.DESCRIPTION
    Give this function two parameters, the names of the two VMs. It will then remove the IP addresses from both computers, and then add them back but swapping the two addresses between the servers.

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-06-11
    Version 1.0 - initial build
#>

    #Requires -Modules Vmware.PowerCLI

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter VM1 name")]
        [string]$VM1,
        [Parameter(Mandatory=$True,HelpMessage="Enter VM2 name")]
        [string]$VM2,
        [Parameter(Mandatory=$True,HelpMessage="Log file that script logs to.")]
        [string]$logFile,
        [Parameter(Mandatory=$True,HelpMessage="Root credentials for VM host.")]
        [PSCredential]$vmHostCredential,
        [Parameter(Mandatory=$True,HelpMessage="Admin credentials for VM1 and VM2.")]
        [PSCredential]$guestCredential
        
    )
    Begin{}
    Process{
        # Lets get these pesky addresses first
        try {
            $resolvedName = Resolve-DnsName -Name $VM1
            $VM1Address = $resolvedName.IPAddress
            $resolvedName = Resolve-DnsName -Name $VM2
            $VM2Address = $resolvedName.IPAddress
        } catch {
            $datetime = Get-Date
            $_ | Tee-Object -FilePath $logFile -Append
            "[$datetime] Error! Unable to resolve address!" | Tee-Object -FilePath $logFile -Append
            exit
        }

        # Calculate the VS name
        $VMHost = $VM1.Split('-')[0] + '-VS1'

        # We have to connect directly to the ESX server otherwise Invoke-VMScript does not work :/
        try {
            $datetime = Get-Date
            "[$datetime] Attempting to connect to $VMHost" | Tee-Object -FilePath $logFile -Append
            Connect-VIServer -Server $VMHost -Credential $vmHostCredential -Force
            $datetime = Get-Date
            "[$datetime] Successfully connected to $VMHost" | Tee-Object -FilePath $logFile -Append
        } catch {
            $_ | Tee-Object -FilePath $logFile -Append
            Disconnect-VIServer * -Confirm:$true
            exit
        }

        # Logging
        $datetime = Get-Date
        "[$datetime] Assigning $VM1Address to $VM2 Address, assigning $VM2Address to $VM1!" | Tee-Object c:\temp\address.log -Append

        # boilerplate code block to swap IP addresses
        $replaceNetIPScript = @'
$interfaceIndex = (Get-NetIPAddress -InterfaceAlias Ethernet0 -AddressFamily IPv4).interfaceIndex
$interfacePrefix = (Get-NetIPAddress -InterfaceAlias Ethernet0 -AddressFamily IPv4).PrefixLength
Remove-NetIPAddress -InterfaceIndex $interfaceIndex
New-NetIPAddress -InterfaceIndex $interfaceIndex -IPv4Address <otherAddress> -PrefixLength $interfacePrefix

ipconfig /flushdns
ipconfig /registerdns
dcdiag /DnsRecordRegistration
dcdiag /fix
'@

        # Run replaceNetIPScript against VM1
        try {
            $datetime = Get-Date
            "[$datetime] Assigning $VM2Address to $VM1" | Tee-Object -FilePath $logFile -Append
            $thisVmReplaceNetIPScript = $replaceNetIPScript.Replace('<otherAddress>', $VM2Address)
            Invoke-VMScript -ScriptText $thisVmReplaceNetIPScript -VM $VM1 -GuestCredential $guestCredential -ScriptType PowerShell
            $datetime = Get-Date
            "[$datetime] $VM2Address assigned to $VM1!" | Tee-Object -FilePath $logFile -Append
        } catch {
            $_ | Tee-Object -FilePath $logFile -Append
            "Warning! Failed assigning address!! Manually check server!!" | Tee-Object -FilePath $logFile -Append
            exit
        }

        # Run replaceNetIPScript against VM2
        try {
            $datetime = Get-Date
            "[$datetime] Assigning $VM1Address to $VM2" | Tee-Object -FilePath $logFile -Append
            $thisVmReplaceNetIPScript = $replaceNetIPScript.Replace('<otherAddress>', $VM1Address)
            Invoke-VMScript -ScriptText $thisVmReplaceNetIPScript -VM $VM2 -GuestCredential $guestCredential -ScriptType PowerShell
            $datetime = Get-Date
            "[$datetime] $VM1Address assigned to $VM2!" | Tee-Object -FilePath $logFile -Append
        } catch {
            $_ | Tee-Object -FilePath $logFile -Append
            "Warning! Failed assigning address!! Manually check server!!" | Tee-Object -FilePath $logFile -Append
            exit
        }

        # Success
        "Successfully swapped IP Addresses between $VM1 and $VM2" | Tee-Object -FilePath $logFile -Append
    }
    End{}
}




function Invoke-DecommissionDomainController
{
    <#
.SYNOPSIS
    This function will decommission a domain controller

.DESCRIPTION
    This function will ensure that a vm is powered on, will uninstall active directory domain services from it, and power the VM off.

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-06-13
    Version 1.1 - added error handling
#>

    #Requires -Modules Vmware.PowerCLI

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter DC name")]
        [string]$DCName
    )
    Begin{}
    Process{
        # Calculate the VS name
        $VMHost = $DCName.Split('-')[0] + '-VS1'

        # Get credentials for the ESX host and for the guest OS
        $vmHostCredential = Get-Credential -Message "Enter the root credentials for $VMHost"
        $guestCredential = Get-Credential -Message "Enter the admin credentials for $VM1 and $VM2"
        $localAdministratorPassword = Read-Host "Enter the local administrator password for DC"

        # Boilerplate code for AD Domain Controller uninstall script
        $removeADDS = @'
$localAdminPass = ConvertTo-SecureString -AsPlainText -Force -String '<DSRMPassword>'
Uninstall-ADDSDomainController -Confirm:$false -LocalAdministratorPassword $localAdminPass
'@
        # Insert DSRM Password into uninstall script
        $removeADDS = $removeADDS.Replace('<DSRMPassword>', $localAdministratorPassword)

        # We have to connect directly to the ESX server otherwise Invoke-VMScript does not work :/
        try {
            $datetime = Get-Date
            "[$datetime] Attempting to connect to $VMHost" | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
            Connect-VIServer -Server $VMHost -Credential $vmHostCredential -Force
            $datetime = Get-Date
            "[$datetime] Successfully connected to $VMHost" | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
        } catch {
            $_ | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
            Disconnect-VIServer * -Confirm:$false
            exit
        }

        # Get VM
        try {
            $vm = Get-VM -Server $VMHost -Name $DCName
            "[$datetime] Gathered VM $DCName" | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
        } catch {
            $_ | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
            Disconnect-VIServer * -Confirm:$false
            exit
        }

        # Check if VM is powered off, if it is, power it on
        if ($vm.PowerState -eq 'PoweredOff') {
            Start-VM -Server $VMHost -VM $DCName
            Wait-Tools $DCName
        }

        # Run demote script against DCName
        try {
            $datetime = Get-Date
            "[$datetime] Demoting $DCName from Domain Controller role..." | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
            Invoke-VMScript -ScriptType PowerShell -VM $DCName -GuestCredential $guestCredential -ScriptText $removeADDS
        } catch {
            $_ | Tee-Object -FilePath 'C:\temp\decommission.log' -Append
            Disconnect-VIServer * -Confirm:$false
            exit
        }

        # Disconnect from ESX host, log success
        Disconnect-VIServer * -Confirm:$false
        $datetime = Get-Date
        "[$datetime] Successfully decommissioned $DCName on $VMHost" | Tee-Object -FilePath 'c:\temp\decommission.log' -Append
    }
    End{}
}


function Get-SiteIPInformation
{
    <#
.SYNOPSIS
    This function will calculate IP values from the inputted site code (from DHCP and DNS) and append to a spreadsheet

.DESCRIPTION
    This script will get the following variables from the DHCP scode and from DNS:
    newVmName
        Generated from the input parameter (SiteCode)
    newVmHost
        Calculated from the input parameter (SiteCode)
    newVmIpAddress
        Takes the site DC1 IP address and increments by 1
    newVmIpv4Prefix
        Calculated from the site DHCP scope
    newVmGateway
        Taken from the site DHCP scope
    newVmDnsAddress
        Taken from the site DHCP scope


.NOTES
    Author: Christopher Frew
    Last Edit: 2019-05-21
    Version 1.0 - initial build
#>

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter site code.")]
        [string]$SiteCode,
        [Parameter(Mandatory=$True,HelpMessage="CSV file that script saves output to")]
        [string]$outputFile
    )
    Begin{}
    Process{
        $fsName = $SiteCode + "-FS1"
        $oldName = $SiteCode + "-DC1"

        # Get newVmName
        $newVmName = ($SiteCode + "-DC2").ToUpper()

        # Get newVmHost
        $newVmHost = ($SiteCode + "-VS1").toLower()

        # Get newVmIpAddress
        # This takes the IP address of the current (DC1) for the site and increments it by 51 to put it in an unused area of the addressing standard
        $newVmIpAddress = ''
        (([System.Net.Dns]::GetHostAddresses($oldName).GetAddressBytes()[0..2]) + ([string]([int]([System.Net.Dns]::GetHostAddresses($oldName).GetAddressBytes()[3]) + 51)))| Foreach-Object { $newVmIpAddress += [string]$_ + "." }
        $newVmIpAddress = $newVmIpAddress.Substring(0,$newVmIpAddress.length-1)

        # Get newVmIpv4Prefix
        # This get the current netmask from the DHCP scope of the site and converts it to CIDR notation
        $newVmIpv4Prefix = 0
        (((Get-DhcpServerv4Scope -ComputerName $fsName).SubnetMask).IPAddressToString).Split('.')| Foreach-Object { (([convert]::ToString($_,2)).toCharArray())| Foreach-Object { if($_ -eq '1') { $newVmIpv4Prefix += 1 } } }

        # Get newVmGateway
        # This gets the router option from the site DHCP scope
        $newVmGateway = [string]((Get-DhcpServerv4OptionValue -ComputerName $fsName -ScopeId (Get-DhcpServerv4Scope -ComputerName $fsName).ScopeId ) | Where-Object {$_.Name -eq "Router"}).Value

        # Get newVmDnsAddress
        # This gets the DNS server option from the site DHCP scope
        $newVmDnsAddress = [string]((Get-DhcpServerv4OptionValue -ComputerName $fsName -ScopeId (Get-DhcpServerv4Scope -ComputerName $fsName).ScopeId ) | Where-Object {$_.Name -eq "DNS Servers"}).Value

        [PSCustomObject]@{
            newVmName = $newVmName
            newVmHost = $newVmHost
            newVmIpAddress = $newVmIpAddress
            newVmIpv4Prefix = $newVmIpv4Prefix
            newVmGateway = $newVmGateway
            newVmDnsAddress = $newVmDnsAddress
            newVmSiteCode = $SiteCode
        } | export-csv -Path $outputFile -NoTypeInformation -Append
    }
    End{}
}