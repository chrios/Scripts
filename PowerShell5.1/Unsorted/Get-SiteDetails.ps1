
function Get-SiteIPInformation
{
    Param(
        [Parameter(Mandatory=$True,HelpMessage="Enter site code.")]$SiteCode
    )
    $fsName = $SiteCode + "-FS1"
    $oldName = $SiteCode + "-DC1"

    # Get newVmName
    $newVmName = ($SiteCode + "-DC2").ToUpper()

    # Get newVmHost
    $newVmHost = ($SiteCode + "-VS1").toLower()

    # Get newVmIpAddress
    # This takes the IP address of the current (DC1) for the site and increments it by 1
    $newVmIpAddress = ''
    (([System.Net.Dns]::GetHostAddresses($oldName).GetAddressBytes()[0..2]) + ([string]([int]([System.Net.Dns]::GetHostAddresses($oldName).GetAddressBytes()[3]) + 1)))|%{ $newVmIpAddress += [string]$_ + "." }
    $newVmIpAddress = $newVmIpAddress.Substring(0,$newVmIpAddress.length-1)

    # Get newVmIpv4Prefix
    # This get the current netmask from the DHCP scope of the site and converts it to CIDR notation
    $newVmIpv4Prefix = 0
    (((Get-DhcpServerv4Scope -ComputerName $fsName).SubnetMask).IPAddressToString).Split('.')|%{ (([convert]::ToString($_,2)).toCharArray())|%{ if($_ -eq '1') { $newVmIpv4Prefix += 1 } } }

    # Get newVmGateway
    # This gets the router option from the site DHCP scope
    $newVmGateway = [string]((Get-DhcpServerv4OptionValue -ComputerName $fsName -ScopeId (Get-DhcpServerv4Scope -ComputerName $fsName).ScopeId ) | ? {$_.Name -eq "Router"}).Value

    # Get newVmDnsAddress
    # This gets the DNS server option from the site DHCP scope
    $newVmDnsAddress = [string]((Get-DhcpServerv4OptionValue -ComputerName $fsName -ScopeId (Get-DhcpServerv4Scope -ComputerName $fsName).ScopeId ) | ? {$_.Name -eq "DNS Servers"}).Value

    [PSCustomObject]@{
        newVmName = $newVmName
        newVmHost = $newVmHost
        newVmIpAddress = $newVmIpAddress
        newVmIpv4Prefix = $newVmIpv4Prefix
        newVmGateway = $newVmGateway
        newVmDnsAddress = $newVmDnsAddress
    } | export-csv -Path \\drwnt-cifs\nec\christopherFrew\projects\287\data\vmIp.csv -NoTypeInformation -Append
}