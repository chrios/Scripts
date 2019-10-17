function Invoke-DeployRODCVirtualMachine {
<#
.SYNOPSIS
    This function will deploy VM's from the RODC template.

.DESCRIPTION
    Before using, ensure you have prepared your .csv file located at \\drwnt-cifs\NEC\christopherFrew\projects\287\data\NewVm.csv. This file will be imported and iterated through. A new VM will deploy for each line in the CSV file on the newVMHost server.

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-06-11
    Version 1.0 - initial build
#>

    #Requires -Modules Vmware.PowerCLI

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter Domain credentials")]
        [PSCredential]$domainCreds,
        [Parameter(Mandatory=$True,HelpMessage="Enter path of CSV file to deploy from")]
        [string]$csvLocation,
        [Parameter(Mandatory=$True,HelpMessage="Enter path of file to log to")]
        [string]$deployLogFile,
        [Parameter(Mandatory=$True,HelpMessage="Enter name of template to deploy")]
        [string]$templateName,
        [Parameter(Mandatory=$True,HelpMessage="Number of servers to deploy")]
        [string]$numOfServers
    )

    Begin{}
    Process{
        # Import CSV of new VMs
        try {
            "[$(Get-Date)] Importing $csvLocation..." | Tee-Object -FilePath $deployLogFile -Append
            $newVMCSV = Import-Csv -Path "$csvLocation"
            "[$(Get-Date)] Imported CSV successfully!" | Tee-Object -FilePath $deployLogFile -Append
        } catch {
            $_ | Tee-Object -FilePath $deployLogFile -Append
            Disconnect-VIServer * -Confirm:$true
            return
        }

        # Connect to vCentre in order to deploy VM
        try {
            "[$(Get-Date)] Connecting to DRWNT-VC2.ntschools.net ..." | Tee-Object -FilePath $deployLogFile -Append
            Connect-VIServer -Server drwnt-vc2.ntschools.net -Credential $domainCreds
            "[$(Get-Date)] Connected successfully!" | Tee-Object -FilePath $deployLogFile -Append
        } catch {
            $_ | Tee-Object -FilePath $deployLogFile -Append
            Disconnect-VIServer * -Confirm:$true
            return
        }

        # get the template we are going to use for New-VM
        try {
            "[$(Get-Date)] Gathering $templateName template..." | Tee-Object -FilePath $deployLogFile -Append
            $template = Get-Template -Name $templateName
            "[$(Get-Date)] Gathered template $templateName successfully!" | Tee-Object -FilePath $deployLogFile -Append
        } catch {
            $_ | Tee-Object -FilePath $deployLogFile -Append
            Disconnect-VIServer * -Confirm:$true
            return
        }

        $newVMCSV | Foreach-Object {
            # Catch already deployed VMs and exit this iteration of the loop
            if ($_.deployed -eq 'True') {
                $currentVM = $_.newVmName
                "[$(Get-Date)] $currentVM already deployed! exiting iteration of loop!" | Tee-Object -FilePath $deployLogFile -Append
                return
            }
            if ($numOfServers -eq 0) {
                return
            } else {
                # Deploy over WAN link (may take a long time)
                try {
                    $newVmName = $_.newVmName
                    $vmHost = $_.newVmHost
                    "[$(Get-Date)] Starting deployment of $newVmName  ..." | Tee-Object -FilePath $deployLogFile -Append
                    New-VM -Name $_.newVmName -Template $template -VMHost $_.newVmHost -Confirm:$false -RunAsync:$true -DiskStorageFormat Thin
                    "[$(Get-Date)] Deployed $newVmName to $vmHost using template $template" | Tee-Object -FilePath $deployLogFile -Append
                    # Now we update the existing CSV parameter
                    $_.deployed = 'True'
                } catch {
                    $_ | Tee-Object -FilePath $deployLogFile -Append
                    Disconnect-VIServer * -Force -Confirm:$false
                    return
                }
                $numOfServers = $numOfServers - 1
            }
        }
        # Now we overwrite the original deployment csv with the updated deployment status
        $newVMCSV | export-csv -Path $csvLocation -NoTypeInformation
        Disconnect-VIServer * -Force -Confirm:$false
    }
    End{}
}

function Invoke-ConfigureRODCVirtualMachine {
<#
.SYNOPSIS
    This function will configure deployed RODC vms.

.DESCRIPTION
    This script will use the deployedVms.csv file and will install AD DS and configure as a domain controller each VM in the file with Invoke-VMScript as a RODC. It will then update the deployedVms.csv file 'configured' field to true.

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-05-16
    Version 1.0 - initial build
#>

    #Requires -Modules Vmware.PowerCLI

    Param(
        [Parameter(Mandatory=$True,HelpMessage="Credentials to access the DCs")]
        [PSCredential]$domainCreds,
        [Parameter(Mandatory=$True,HelpMessage="Root credentials for the ESXi host")]
        [PSCredential]$vmHostCredential,
        [Parameter(Mandatory=$true,HelpMessage="Local admin credentials of the newly deployed server")]
        [PSCredential]$localCreds,
        [Parameter(Mandatory=$True,HelpMessage="The DSRM password you want to assign to the new domain controller")]
        [string]$DSRMPassword,
        [Parameter(Mandatory=$True,HelpMessage="Location of the file to log to")]
        [string]$logFileLocation,
        [Parameter(Mandatory=$True,HelpMessage="Location of the CSV file to configure from")]
        [string]$csvFileLocation,
        [Parameter(Mandatory=$True,HelpMessage="The number of servers you want to configure in this batch")]
        [string]$numOfServers
    )
    Begin{}
    Process{

        # Import CSV of new VMs
        try {
            "[$(Get-Date)] Importing $csvFileLocation..." | Tee-Object -FilePath $logFileLocation -Append
            $newVMCSV = Import-Csv -Path $csvFileLocation
            "[$(Get-Date)] Imported CSV successfully!" | Tee-Object -FilePath $logFileLocation -Append
        } catch {
            $_ | Tee-Object -FilePath $logFileLocation -Append
            exit
        }

        # Now we will define boilerplate code templates. Everything in <> we will replace with our variables before passing the script to Invoke-VMScript.
        # Exiting from script with number sets scriptOutput.ExitCode . We will test for the following:
        # 1 means item already configured. Continue with script.
        # 2 means error configuring. Log error, set configuration parameter to FALSE, continue with script.
        # 0 means item was configured. Set configuration parameter to TRUE, continue with script.

        # This will set the IP address of the server.
        # Variables: newVmIpAddress, newVmGateway, newVmIpv4Prefix
        $configureNetAdapter = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
# Check if already configured
if ((Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias Ethernet0).IPAddress -eq <newVmIpAddress>) {
    exit 0
}

# Try to configure static IP address
try {
    Get-NetAdapter | New-NetIPAddress -IPAddress <newVmIpAddress> -DefaultGateway <newVmGateway> -AddressFamily IPv4 -PrefixLength <newVmIpv4Prefix>
} catch {
    exit 2
}

exit 0
'@
        # Configures the servers DNS server addresses and suffix search list
        # Variables: newVmDnsAddress
        $configureDnsServers = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
# Check DNS Servers
if (((Get-DnsClientServerAddress -InterfaceAlias Wi-Fi -AddressFamily IPv4).ServerAddresses -join ',') -eq '<newVmDnsAddress') {
    exit 0
}

# Try to configure Dns Server addreses
try {
    Set-DnsClientServerAddress -InterfaceAlias Ethernet0 -ServerAddresses <newVmDnsAddress>
} catch {
    exit 2
}

exit 0
'@
        # Sets the computer name
        # Variables: newVmName
        $configureServerName = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
if ($env:COMPUTERNAME -eq '<newVmName>') {
    exit 0
}

# Set computer name
try {
    Rename-Computer -NewName <newVmName> -Force
} catch {
    exit 2
}

exit 0
'@
        # Joins the machine to the domain
        # Variables: plainTextDomainPassword, plainTextDomainUserName, newVmName, siteName
        $configureServerDomainJoin = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    exit 0
}

# Join machine to domain
try {
    # Convert plaintext password to secure string
    $secPassword = ConvertTo-SecureString "<plainTextDomainPassword>" -AsPlainText -Force
    # Create new PSCredential object
    $domainCredentials = New-Object System.Management.Automation.PSCredential("<plainTextDomainUserName>", $secPassword)
    Add-Computer -DomainName ntschools.net -Credential $domainCredentials -NewName <newVmName> -Force -Server <siteName>-DC1.ntschools.net
} catch {
    exit 2    
}

# Set restart job and exit script
Restart-computer -Force
exit 0
'@

        # Check if machine is in domain
        $checkServerDomainJoin = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    exit 0
} else {
    exit 2
}
'@
        # Installs AD-Domain-Services role
        $configureInstallADDS = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
# check if feature is installed
if ((Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    exit 0
}

# Install feature if not installed
try {
    Install-WindowsFeature AD-Domain-Services
} catch {
    exit 2
}

exit 0
'@
        # Configures machine as RODC
        # Variables: plainTextDomainPassword, plainTextDomainUserName, DSRMPassword, siteName
        $configureInstallRODC = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 2) {
    exit 0
}

try {
    # Convert plaintext password to secure string
    $secPassword = ConvertTo-SecureString "<plainTextDomainPassword>" -AsPlainText -Force
    # Create new PSCredential object
    $domainCredentials = New-Object System.Management.Automation.PSCredential("<plainTextDomainUserName>", $secPassword)
    # Create DSRM Password
    $safeModePassword = ConvertTo-SecureString -String "<DSRMPassword>" -AsPlainText -Force

    # Promote to domain controller
    Install-ADDSDomainController -Credential $domainCredentials `
        -DomainName ntschools.net `
        -InstallDNS:$true `
        -ReadOnlyReplica:$true `
        -Force:$true `
        -SiteName '<siteName>'`
        -SafeModeAdministratorPassword $safeModePassword `
        -Confirm:$false `
        -Verbose `
        -CriticalReplicationOnly:$true `
        -ReplicationSourceDC '<siteName>-DC1.ntschools.net'
} catch {
    exit 2
}

exit 0
'@
        # This script will check if machine is a RODC
        $checkInstallRODC = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
if ((Get-CimInstance -ClassName Win32_OperatingSystem).ProductType -eq 2) {
    exit 0
} else {
    exit 2
}
'@
        # This script will perform some post install configuration tasks 
        $configureDNSGlobalBlockList = @'
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -Confirm:$False
if ((Get-DnsServerGlobalQueryBlocklist).Enable -eq $false) {
    exit 0
}
# Configure DNS global block list to allow WPAD and ISATAP
try {
    Set-DnsServerGlobalQueryBlockList -Enable:$false -Verbose
} catch {
    exit 2
}

exit 0
'@

        # Text processing. Instead of putting credentials in plain text in the script, we insert them into the scripts here.
        #
        # We need to pass through credentials to the invoke-vmscript block, but we can't pass anything but the script text.
        # To achieve this, we will extract the data from the $domainCreds variable in plain text
        $plainTextDomainPassword = $domainCreds.GetNetworkCredential().Password
        $plainTextDomainUserName = $domainCreds.UserName

        # Insert credentials into domain join script boilerplate
        $configureServerDomainJoin = $configureServerDomainJoin.replace("<plainTextDomainPassword>", $plainTextDomainPassword)
        $configureServerDomainJoin = $configureServerDomainJoin.replace("<plainTextDomainUserName>", $plainTextDomainUserName)

        # Insert credentials into RODC installation script boilerplate
        $configureInstallRODC = $configureInstallRODC.replace("<plainTextDomainPassword>", $plainTextDomainPassword)
        $configureInstallRODC = $configureInstallRODC.replace("<plainTextDomainUserName>", $plainTextDomainUserName)
        $configureInstallRODC = $configureInstallRODC.replace("<DSRMPassword>", $DSRMPassword)

        # Start main configuration loop
        $newVMCSV | Foreach-Object {
            if ($numOfServers -eq 0) {
                return
            } else {
                # For use in logging
                $newVmHost = $_.newVmHost
                $newVmName = $_.newVmName
                "[$(Get-Date)] Configuring $newVmName..." | Tee-Object -FilePath $logFileLocation -Append

                # Skip this loop iteration if the VM is marked as configured already
                if ($_.configured -eq 'True') {return}

                # Skip this loop iteration if the VM is not marked as deployed
                if ($_.deployed -ne 'True') {return}

                # Insert variables into thisConfigureNetAdapter script
                $thisConfigureNetAdapter = $configureNetAdapter.replace("<newVmIpAddress>", $_.newVmIpAddress)
                $thisConfigureNetAdapter = $thisConfigureNetAdapter.replace("<newVmGateway>", $_.newVmGateway)
                $thisConfigureNetAdapter = $thisConfigureNetAdapter.replace("<newVmIpv4Prefix>", $_.newVmIpv4Prefix)

                # Insert variables into thisConfigureDnsServers script
                $thisConfigureDnsServers = $configureDnsServers.replace("<newVmDnsAddress>", $_.newVmDnsAddress)

                # Insert variables into thisConfigureServerName script
                $thisConfigureServerName = $configureServerName.replace("<newVmName>", $_.newVmName)
                
                # Insert variables into thisConfigureServerDomainJoin script
                $thisConfigureServerDomainJoin = $configureServerDomainJoin.replace("<newVmName>", $_.newVmName)
                $thisConfigureServerDomainJoin = $thisConfigureServerDomainJoin.replace("<siteName>", $_.newVmSite)

                # Add the site name into thisConfigureInstallRODC script
                $thisConfigureInstallRODC = $configureInstallRODC.replace('<siteName>', $_.newVmSite)

                # We have to connect directly to the ESX server otherwise Invoke-VMScript does not work :/
                try {
                    "[$(Get-Date)] Attempting to connect to $newVmHost" | Tee-Object -FilePath $logFileLocation -Append
                    Connect-VIServer -Server $_.newVmHost -Credential $vmHostCredential
                } catch {
                    $_ | Tee-Object -FilePath $logFileLocation -Append
                    Disconnect-VIServer * -Confirm:$true
                    return
                }

                # Ensure that the VM has 8gb of RAM and 2 vCPU's
                "[$(Get-Date)] Checking memory and CPU of $newVMName..." | Tee-Object -FilePath $logFileLocation -Append
                $VM = Get-VM -Name $_.newVmName 
                if ($VM.MemoryGB -ne '8' -and $VM.PowerState -ne 'PoweredOn') {
                    "[$(Get-Date)] Setting VM Memory to 8gb..." | Tee-Object -FilePath $logFileLocation -Append
                    Set-VM -MemoryGB 8 -VM $VM -confirm:$false | Out-Null
                } else { "[$(Get-Date)] VM Memory already set to 8gb." | Tee-Object -FilePath $logFileLocation -Append }
                if ($VM.NumCpu -ne '2' -and $VM.PowerState -ne 'PoweredOn') {
                    "[$(Get-Date)] Setting VM vCPU to 2..." | Tee-Object -FilePath $logFileLocation -Append
                    Set-VM -NumCpu 2 -VM $VM -confirm:$false | Out-Null
                } else { " [$(Get-Date)] VM vCpu already set to 2." | Tee-Object -FilePath $logFileLocation -Append }

                # Start VM if it is stopped
                "[$(Get-Date)] Checking power state of $newVmName..." | Tee-Object -FilePath $logFileLocation -Append
                if ((Get-VM -Name $_.newVmName).PowerState -ne 'PoweredOn') {
                    try {
                        "[$(Get-Date)] Starting $newVmName..." | Tee-Object -FilePath $logFileLocation -Append
                        Start-VM -VM $_.newVmName -Confirm:$false | Out-Null
                        Wait-Tools -VM $_.newVmName | Out-Null
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -Append
                        Disconnect-VIServer * -Confirm:$true
                        return
                    }
                } else { "[$(Get-Date)] $newVmName is powered on!" | Tee-Object -FilePath $logFileLocation -Append }


                if ($_.NetAdapterConfigured -ne '0') {
                    "[$(Get-Date)] Checking network of $newVmName..." | Tee-Object -FilePath $logFileLocation -Append
                    $NetworkAdapater = Get-NetworkAdapter -VM $VM
                    if (($NetworkAdapater).NetworkName -ne $_.newVmSite) {
                        "[$(Get-Date)] Attaching VM network adapter to correct network..." | Tee-Object -FilePath $logFileLocation -Append
                        Set-NetworkAdapter -NetworkAdapter $NetworkAdapater -NetworkName $_.newVmSite -Connected:$true -Confirm:$false | Out-Null
                    } else { "[$(Get-Date)] VM Adapter already configured." | Tee-Object -FilePath $logFileLocation -Append }
                }

                # Wait for tools
                Wait-Tools -VM $_.newVmName | Out-Null
                Start-Sleep -Seconds 5

                if ($_.NetAdapterConfigured -ne '0') {
                    # Verify IP address settings
                    $testIP = Test-NetConnection $_.newVmIpAddress
                    if ($testIP.PingSucceeded -eq $true -and $_.NetAdapterConfigured -ne 0) {
                        "[$(Get-Date)] Duplicate IP detected. Change VM ip address." | Tee-Object -FilePath $logFileLocation -Append
                        $_.NetAdapterConfigured = 'Duplicate IP detected. Change VM ip address.'
                        return
                    } else { "[$(Get-Date)] new Vm IP address verified" | Tee-Object -FilePath $logFileLocation -Append }
                    $testGateway = Test-NetConnection $_.newVmGateway
                    if ($testGateway.PingSucceeded -ne $true -and $_.NetAdapterConfigured -ne 0) {
                        "[$(Get-Date)] new Vm Gateway address - cannot ping. Check network settings." | Tee-Object -FilePath $logFileLocation -Append
                        $_.NetAdapterConfigured = 'new Vm Gateway address - cannot ping. Check network settings.'
                        return
                    } else { "[$(Get-Date)] new VM Gateway address verified" | Tee-Object -FilePath $logFileLocation -Append }
                }

                # Run thisConfigureNetAdapter
                if ($_.NetAdapterConfigured -ne '0') {
                    try {
                        "[$(Get-Date)] Attempting to configure $newVmName IP address..." | Tee-Object -FilePath $logFileLocation -append
                        $scriptOutputNetAdapter = Invoke-VMScript -ScriptText $thisConfigureNetAdapter -VM $_.newVmName -GuestCredential $localCreds -ToolsWaitSecs 300
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -Append
                    }
                } else { "[$(Get-Date)] $newVmName IP Address already configured." | Tee-Object -FilePath $logFileLocation -Append }

                # Wait for tools
                Wait-Tools -VM $_.newVmName | Out-Null
                Start-Sleep -Seconds 5

                # Run thisConfigureDnsServers
                if ($_.DnsServersConfigured -ne '0') {
                    try {
                        "[$(Get-Date)] Attempting to configure $newVmName DNS servers..." | Tee-Object -FilePath $logFileLocation -append
                        $scriptOutputDnsServers = Invoke-VMScript -ScriptText $thisConfigureDnsServers -VM $_.newVmName -GuestCredential $localCreds -ToolsWaitSecs 300
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -append
                    }
                } else { "[$(Get-Date)] $newVmName DNS Servers already configured." | Tee-Object -FilePath $logFileLocation -Append }

                # Wait for tools
                Wait-Tools -VM $_.newVmName | Out-Null
                Start-Sleep -Seconds 5

                # Run thisConfigureServerName
                if ($_.ServerNameConfigured -ne '0') {
                    try {
                        "[$(Get-Date)] Attempting to configure $newVmName server name..." | Tee-Object -FilePath $logFileLocation -append
                        $scriptOutputServerName = Invoke-VMScript -ScriptText $thisConfigureServerName -VM $_.newVmName -GuestCredential $localCreds -ToolsWaitSecs 300
                        Wait-Tools -VM $_.newVmName | Out-Null
                        Start-Sleep -Seconds 5
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -append
                    }
                } else { "[$(Get-Date)] $newVmName server name already configured." | Tee-Object -FilePath $logFileLocation -Append }

                # Run thisConfigureServerDomainJoin
                if ($_.DomainJoinConfigured -ne '0') {
                    try {
                        "[$(Get-Date)] Attempting to join $newVmName to the domain..." | Tee-Object -FilePath $logFileLocation -append
                        Invoke-VMScript -ScriptText $thisConfigureServerDomainJoin -VM $_.newVmName -GuestCredential $localCreds -ToolsWaitSecs 300 | Out-Null
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -append
                    }
                    try {
                        "[$(Get-Date)] Checking if domain join was successful..." | Tee-Object -FilePath $logFileLocation -append
                        Wait-Tools -VM $_.newVmName | Out-Null
                        Start-Sleep -Seconds 10
                        $scriptOutputServerDomainJoin = Invoke-VMScript -ScriptText $checkServerDomainJoin -VM $_.newVmName -GuestCredential $domainCreds -ToolsWaitSecs 300
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -append
                    }
                } else { "[$(Get-Date)] $newVmName already joined to the domain." | Tee-Object -FilePath $logFileLocation -Append }

                # Run configureInstallADDS
                if ($_.ADDSInstalled -ne '0') {
                    try {
                        "[$(Get-Date)] Installing AD-Domain-Services role on $newVmName ..." | Tee-Object -FilePath $logFileLocation -append
                        $scriptOutputInstallADDS = Invoke-VMScript -ScriptText $configureInstallADDS -VM $_.newVmName -GuestCredential $domainCreds -ToolsWaitSecs 300
                        # Wait for tools
                        Wait-Tools -VM $_.newVmName | Out-Null
                        Start-Sleep -Seconds 5
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -append
                    }
                } else { "[$(Get-Date)] AD-Domain-Services already installed on $newVmName." | Tee-Object -FilePath $logFileLocation -Append }

                # Run configureInstallRODC to configure server as read-only replica domain controller
                # This can take a while (hours)
                if ($_.RODCInstalled -ne '0') {
                    try {
                        "[$(Get-Date)] Configuring $newVmName as a read-only replica domain controller ..." | Tee-Object -FilePath $logFileLocation -append
                        Invoke-VMScript -ScriptText $thisConfigureInstallRODC -VM $_.newVmName -GuestCredential $domainCreds -ToolsWaitSecs 300 | Out-Null
                        # Wait for reboot
                        Wait-Tools -VM $_.newVmName | Out-Null
                        Start-Sleep -Seconds 10
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -Append
                    }
                } else { "[$(Get-Date)] $newVMName already configured as RODC. Skipping installation.." | Tee-Object -FilePath $logFileLocation -Append }
                
                if ($_.RODCInstalled -ne '0') {
                    try {
                        "[$(Get-Date)] Checking that $newVmName is a read-only replica domain controller..." | Tee-Object -FilePath $logFileLocation -Append
                        $scriptOutputInstallRODC = Invoke-VMScript -ScriptText $checkInstallRODC -VM $_.newVmName -GuestCredential $domainCreds -ToolsWaitSecs 300
                        # Wait for tools
                        Wait-Tools -VM $_.newVmName | Out-Null
                        Start-Sleep -Seconds 5
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -Append
                    }
                } else { "[$(Get-Date)] $newVMName already configured as RODC. Skipping checking..." | Tee-Object -FilePath $logFileLocation -Append }

                # Configure DNS global block list by running configureDNSGlobalBlockList
                if ($_.DNSGlobalBlocklistConfigured -ne '0') {
                    try {
                        "[$(Get-Date)] Configuring DNS GLobal blocklist on $newVmName ..." | Tee-Object -FilePath $logFileLocation -append
                        $scriptOutputDNSGlobalBlockList = Invoke-VMScript -ScriptText $configureDNSGlobalBlockList -VM $_.newVmName -GuestCredential $domainCreds -ToolsWaitSecs 300
                    } catch {
                        $_ | Tee-Object -FilePath $logFileLocation -append
                    }
                } else { "[$(Get-Date)] DNS Global Query Blocklist already configured on $newVmName." | Tee-Object -FilePath $logFileLocation -Append }

                # Disconnect from the site VS1 server
                "[$(Get-Date)] Disconnecting from VI Server." | Tee-Object -FilePath $logFileLocation -Append
                Disconnect-VIServer * -Confirm:$false

                # Update configuration parameters
                # 2 means error configuring. Set configuration parameter to FALSE
                # 0 means item is configured. Set configuration parameter to TRUE
                # IP Address
                $_.NetAdapterConfigured = $scriptOutputNetAdapter.ExitCode
                # DNS Servers
                $_.DnsServersConfigured = $scriptOutputDnsServers.ExitCode
                # Server Name
                $_.ServerNameConfigured = $scriptOutputServerName.ExitCode
                # Domain Join
                $_.DomainJoinConfigured = $scriptOutputServerDomainJoin.ExitCode
                # AD-Domain-Services installed
                $_.ADDSInstalled = $scriptOutputInstallADDS.ExitCode
                # RODC installed
                $_.RODCInstalled = $scriptOutputInstallRODC.ExitCode
                # DNS GLobal blocklist disabled
                $_.DNSGlobalBlocklistConfigured = $scriptOutputDNSGlobalBlockList.ExitCode

                # Set final configuration flag if all prerequisites met
                if ([int]([int]$_.NetAdapterConfigured + [int]$_.DnsServersConfigured + [int]$_.ServerNameConfigured + [int]$_.DomainJoinConfigured + [int]$_.ADDSInstalled + [int]$_.RODCInstalled + [int]$_.DNSGlobalBlocklistConfigured) -eq 0) {
                    $_.configured = $true
                }
                "[$(Get-Date)] Proceeding to next server." | Tee-Object -FilePath $logFileLocation -Append
                $numOfServers = $numOfServers - 1
            }
        }

        "[$(Get-Date)] Number of servers reached. Updating CSV file." | Tee-Object -FilePath $logFileLocation -Append
        # Update CSV with information on configured VMs
        $newVMCSV | export-csv -Path $csvFileLocation -NoTypeInformation
        "[$(Get-Date)] Terminating script." | Tee-Object -FilePath $logFileLocation -Append


    }
    End{}
}

function Invoke-CreateCSVtemplate
{
    <#
.SYNOPSIS
    This function exports a template csv file to use with the module

.DESCRIPTION
    Exports the following columns:
    newVmName,newVmHost,newVmIpAddress,newVmIpv4Prefix,newVmGateway,newVmDnsAddress,newVmSite,deployed,configured,NetAdapterConfigured,DnsServersConfigured,ServerNameConfigured,DomainJoinConfigured,DebugACLConfigured,ADDSInstalled,RODCInstalled,DNSGlobalBlocklistConfigured

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-07-10
    Version 1.0
#>

    Param(
        [Parameter(Mandatory=$true,HelpMessage="The file path to export the csv to")]
        [string]$FilePath
    )

    Begin{}
    Process{
        'newVmName,newVmHost,newVmIpAddress,newVmIpv4Prefix,newVmGateway,newVmDnsAddress,newVmSite,deployed,configured,NetAdapterConfigured,DnsServersConfigured,ServerNameConfigured,DomainJoinConfigured,DebugACLConfigured,ADDSInstalled,RODCInstalled,DNSGlobalBlocklistConfigured' | Out-File -Encoding ascii $FilePath
    }
    End{}
}

function Invoke-ConfigureIPAddresses
{
    <#
.SYNOPSIS
    This function powers down the old domain controller, then configures the new domain controller with the old DC's IP address.

.DESCRIPTION
    Becuase the version of PowerShell installed on the current domain controllers is so old, the approach has been modified. Instead of swapping the IP addresses, the script will now transfer the current address to the new DC.

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-07-08
    Version 1.0
#>

    Param(
        [Parameter(Mandatory=$True,HelpMessage="The old DC name")]
        [string]$OldDCName,
        [Parameter(Mandatory=$True,HelpMessage="The new DC Name")]
        [string]$NewDCName,
        [Parameter(Mandatory=$True,HelpMessage="Credentials to access the DCs")]
        [PSCredential]$Credentials,
        [Parameter(Mandatory=$True,HelpMessage="Credentials to access the VM Host")]
        [PSCredential]$vmHostCredential,
        [Parameter(Mandatory=$True,HelpMessage="Log file path (CSV File)")]
        [string]$logFile
    )

    Begin{}
    Process{
        Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$False

        # Calculate vm Host name
        $newVmHost = $OldDCName.ToUpper().split('-')[0]+'-VS1'

        # We have to connect directly to the ESX server otherwise Invoke-VMScript does not work :/
        try {
            "[$(Get-Date)] Attempting to connect to $newVmHost" | Tee-Object -FilePath $logFile -Append
            Connect-VIServer -Server $newVmHost -Credential $vmHostCredential
            "[$(Get-Date)] Successfully connected to $newVmHost" | Tee-Object -FilePath $logFile -Append
        } catch {
            $_ | Tee-Object -FilePath $logFile -Append
            Disconnect-VIServer * -Confirm:$true
            break
        }

        # Prepare IP setting script
        $setIP = @'
$interfaceIndex = (Get-NetIPAddress -InterfaceAlias Ethernet0 -AddressFamily IPv4).interfaceIndex
$interfacePrefix = (Get-NetIPAddress -InterfaceAlias Ethernet0 -AddressFamily IPv4).PrefixLength
Remove-NetIPAddress -InterfaceIndex $interfaceIndex -AddressFamily IPv4 -Confirm:$false
New-NetIPAddress -InterfaceIndex $interfaceIndex -IPv4Address <otherAddress> -PrefixLength $interfacePrefix
Restart-computer -Force

ipconfig /flushdns
ipconfig /registerdns
dcdiag /DnsRecordRegistration
dcdiag /fix
'@

        # Get IP Address of oldDC
        try {
            $resolvedName = Resolve-DnsName -Name $oldDCName
            $oldDCAddress = $resolvedName.IPAddress
            "[$(Get-Date)] Resolved $oldDCName to $oldDCAddress." | Tee-Object -filepath $logFile -Append
        } catch {
            "ERROR Unable to resolve $oldDCName!" | Tee-Object -filepath $logFile -Append
            $_ | Tee-Object -FilePath $logFile -Append
            Disconnect-VIServer * -Confirm:$true
            break
        }

        # Replace with variables
        $thisSetIP = $setIP.Replace('<otherAddress>', $oldDCAddress)

        # Power down old DC
        Stop-VM -VM $oldDCName -Confirm:$true

        # Run setIP against new DC
        try {
            Invoke-VMScript -ScriptText $thisSetIP -VM $NewDCName -GuestCredential $Credentials -ScriptType PowerShell
            "[$(Get-Date)] Set $oldDCAddress on $NewDCName" | Tee-Object -filepath $logFile -append
        } catch {
            "ERROR Unable to set $oldDCADdress on $NewDCName!" | Tee-Object -filepath $logFile -Append
            $_ | Tee-Object -FilePath $logFile -Append
            Disconnect-VIServer * -Confirm:$true
            break
        }
    }
    End{}
}

function Invoke-RenameDomainController
{
<#
.SYNOPSIS
    This function powers down the old domain controller, then configures the new domain controller with the old DC's IP address, then finally renames the newdomain controller to the old domain controller.

.DESCRIPTION
    This script uses a combination of Invoke-Command and Vmware.PowerCLI to perform the following:
    1. Turns off old domain controller
    2. Waits until user has confirmed that they have cleaned up the old domain controller metadata
    3. Changes the IP address of the new domain controller to the IP address that the old domain controller had; uses ipconfig to register the DNS record update
    4. Changes the name of the new domain controller to the name of the old domain controller using netdom as per https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2008-R2-and-2008/cc816601%28v=ws.10%29

    It will perform this on the domain controllers given in a CSV file 

.NOTES
    Author: Christopher Frew
    Last Edit: 2019-08-20
    Version 1.0
#>
    Param(
        [Parameter(Mandatory=$True,HelpMessage="Credentials to access the DCs")]
        [PSCredential]$domainCreds,
        [Parameter(Mandatory=$True,HelpMessage="CSV file path")]
        [string]$csvPath,
        [Parameter(Mandatory=$True,HelpMessage="Location of the file to log to")]
        [string]$logFileLocation

    )
    Begin{}
    Process{
        $configureIPAddress = 'Get-NetIPAddress -IPAddress <oldIP> | Remove-NetIPAddress -confirm:$false; New-NetIPAddress -IPAddress <newIP> -InterfaceAlias Ethernet0; ipconfig /registerdns'
        $csv = Import-Csv -Path $csvPath

        Connect-VIServer -Server drwnt-vc2.ntschools.net -Credential $domainCreds

        $ProgressPreference = 'SilentlyContinue'

        $csv | ForEach-Object { 

            "[$(Get-Date)] Processing $($_.Name)..." | Tee-Object -FilePath $logFileLocation -Append

            $thisConfigureIPAddress = $configureIPAddress.replace('<oldIP>', $_.IPAddress).replace('<newIP>', $_.newIPAddress)
            $renameCommand = "netdom computername $($_.Name).ntschools.net /add:$($_.oldName).ntschools.net /userd:<username> /passwordd:<password>".replace('<username>',$domainCreds.UserName).replace('<password>', $domainCreds.GetNetworkCredential().Password)
            $makePrimaryCommand = "netdom computername $($_.Name).ntschools.net /makeprimary:$($_.oldName).ntschools.net /userd:<domain>\<username> /passwordd:<password>".replace('<username>',$domainCreds.UserName).replace('<password>', $domainCreds.GetNetworkCredential().Password)
            $removeComand = "netdom computername $($_.OldName).ntschools.net /remove:$($_.Name).ntschools.net /userd:<domain>\<username> /passwordd:<password>".replace('<username>',$domainCreds.UserName).replace('<password>', $domainCreds.GetNetworkCredential().Password)

            "[$(Get-Date)] Stopping $($_.oldName)..." | Tee-Object -FilePath $logFileLocation -Append
            Stop-VM -VM $_.oldName -Confirm:$false | Out-Null

            "[$(Get-Date)] Delete $($_.oldName) from Active Directory Users and Computers and Active Directory Sites and Services before pressing any key to continue.." | Tee-Object -FilePath $logFileLocation -Append
            Write-Host "Press any key to continue ..."
            $x = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

            "[$(Get-Date)] Changing $($_.Name) ip address..." | Tee-Object -FilePath $logFileLocation -Append
            Invoke-Command -ComputerName $_.Name -Credential $domainCreds -ScriptBlock ([scriptblock]::Create($thisConfigureIPAddress))

            "[$(Get-Date)] Adding name of $($_.Name) to $($_.oldName)..." | Tee-Object -FilePath $logFileLocation -Append
            Invoke-Command -ComputerName $_.Name -Credential $domainCreds -ScriptBlock ([scriptblock]::Create($renameCommand))

            "[$(Get-Date)] Making $($_.oldName) primary name of server..." | Tee-Object -FilePath $logFileLocation -Append
            Invoke-Command -ComputerName $_.Name -Credential $domainCreds -ScriptBlock ([scriptblock]::Create($makePrimaryCommand))
            Restart-Computer -ComputerName $_.Name -Credential $domainCreds -Confirm:$false -Force
            
            "[$(Get-Date)] Waiting for restart of $($_.oldName) to finish..." | Tee-Object -FilePath $logFileLocation -Append
            while ((test-netconnection $_.Name -InformationLevel Quiet) -ne $true) { sleep 10 } 
            
            "[$(Get-Date)] Waiting for services on $($_.oldName) to start..." | Tee-Object -FilePath $logFileLocation -Append
            sleep 60
            
            "[$(Get-Date)] Registering DNS records for $($_.oldName)..." | Tee-Object -FilePath $logFileLocation -Append
            Invoke-VMScript -VM $_.Name -GuestCredential $domainCreds -ScriptText { ipconfig /registerdns }

            "[$(Get-Date)] Waiting for machine to respond to $($_.oldName)..." | Tee-Object -FilePath $logFileLocation -Append
            while ((test-netconnection $_.oldName -InformationLevel Quiet) -ne $true) { sleep 10 } 

            "[$(Get-Date)] Removing $($_.Name) from $($_.oldName)..." | Tee-Object -FilePath $logFileLocation -Append
            Invoke-Command -ComputerName $_.oldName -Credential $domainCreds -ScriptBlock ([scriptblock]::Create($removeComand))

            "[$(Get-Date)] Finished processing $($_.oldName)." | Tee-Object -FilePath $logFileLocation -Append
        }

        Disconnect-VIServer -Server $_.VMHost -Confirm:$false 

    }
    End{}

}