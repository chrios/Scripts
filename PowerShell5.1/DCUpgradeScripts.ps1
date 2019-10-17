###### PROCESS ######
#
# 1. create Sites.csv file as list of sites to updates
# 2. Run Invoke-PullVmsFromCsv to generate vms.csv, manually check for errors
# 3. Check dcdiag in core:
#       - Invoke-DcDiagOnCoreDc
# 4. Check replication status of DC2 objects. 
#       - Invoke-CheckRepAdminFromCsv
#       - Fix errors
# 5. Stop VMS
#       - Invoke-StopVmsFromCsv
# 6. Delete DC1 VMs
#       - Invoke-DeleteVMsFromCsv
# 7. Rename the DC2 VMs to DC1
#       - Invoke-RenameVmsFromCsv
# 8. Delete the DC1 objects from ADUC and ADSS.
# 9. Replicate the core DCs
#       - Invoke-ReplicationInCore
# 10. Replicate the changes out to the branch DCs in ADSS. 
#       - Right click NTDS Settings - replicate configuration
# 11. For each VM in list:
#       - Invoke-AddDC1Name
#       - Invoke-MakeNamePrimary
#       - Restart-Computer
#       - Invoke-RemoveAltName
#
#####################

# Run dcdiag /q on all CHANDC domain controllers
# Params: $domainCreds
function Invoke-DcDiagOnCoreDC {
    Param(
        [pscredential]$domainCreds
    )
    $vms = 'drwnt-dc1', 'drwnt-dc2', 'drwnt-dc3', 'drwnt-dc4', 'drwnt-dc5', 'drwnt-dc6', 'drwnt-dc9'
    $vms | ForEach-Object {
        "Checking $($_)..."
        invoke-command -ScriptBlock { dcdiag /q } -ComputerName $_ -Credential $domainCreds
    }
}

# change ips from .56 or whatever to .55
# Params: $domainCreds, $serverName
function Invoke-ChangeIPAddress {
    Param(
        [pscredential]$domainCreds,
        [string]$serverName
    )
    $ip = (Resolve-DnsName -Name $serverName).IPAddress
    $newIP = $ip -replace "\.5.$", ".55"
    $scriptText = "Get-NetIPAddress $ip | Remove-NetIPAddress -confirm:$<false> ; New-NetIPAddress $newIP -PrefixLength 20 -InterfaceIndex 6" 
    $scriptText = $scriptText.replace('<false>', 'false')
    $scriptBlock = [ScriptBlock]::Create($scriptText)
    Invoke-Command -ComputerName $serverName -Credential $domainCreds -ScriptBlock $scriptBlock
}

# add DC1 as alternate name
# Params: $domainCreds, $siteCode
function Invoke-AddDC1Name {
    Param(
        [PSCredential]$domainCreds,
        [string]$siteCode
    )

    $name = $siteCode + '-DC2'
    $newName = $siteCode + '-DC1'

    $scriptText = "netdom computername $($name).ntschools.net /add:$newName.ntschools.net /userd:ntschools\$($domainCreds.Username) /passwordd:$($domainCreds.GetNetworkCredential().Password)"
    $scriptBlock = [ScriptBlock]::Create($scriptText)
    invoke-command -ComputerName $name -scriptblock $scriptBlock -Credential $domainCreds
}

# set DC1 as primary
# Params: $domainCreds, $siteCode
function Invoke-MakeNamePrimary {
    Param(
        [PSCredential]$domainCreds,
        [string]$siteCode
    )

    $name = $siteCode + '-DC2'
    $newName = $siteCode + '-DC1'

    $scriptText = "netdom computername $($name).ntschools.net /makeprimary:$newName.ntschools.net /userd:ntschools\$($domainCreds.Username) /passwordd:$($domainCreds.GetNetworkCredential().Password)"
    $scriptBlock = [ScriptBlock]::Create($scriptText)
    invoke-command -ComputerName $name -scriptblock $scriptBlock -Credential $domainCreds
}

# remove DC2 as alternate
# Params: $domainCreds, $siteCode
function Invoke-RemoveAltName {
    Param(
        [PSCredential]$domainCreds,
        [string]$siteCode
    )

    $altName = $siteCode + '-DC2'
    $name = $siteCode + '-DC1'

    $scriptText = "netdom computername $name.ntschools.net /remove:$altName.ntschools.net /userd:ntschools\$($domainCreds.Username) /passwordd:$($domainCreds.GetNetworkCredential().Password)"
    $scriptBlock = [ScriptBlock]::Create($scriptText)
    invoke-command -ComputerName $name -scriptblock $scriptBlock -Credential $domainCreds
}

# Run syncall on all CHANDC domain controllers (replicate intrasite, push replication)
# Params: $domainCreds
function Invoke-ReplicationInCore {
    Param(
        [PSCredential]$domainCreds
    )
    $vms = 'drwnt-dc1', 'drwnt-dc2', 'drwnt-dc3', 'drwnt-dc4', 'drwnt-dc5', 'drwnt-dc6', 'drwnt-dc9'
    $vms | ForEach-Object { invoke-command -ScriptBlock { repadmin /syncall /d } -ComputerName $_ -Credential $domainCreds -AsJob }
}

# Run syncall on CHANDC DC's with /e option (replicate intersite, push replication)
# Params: $domainCreds
function Invoke-ReplicationInterSite {
    Param(
        [pscredential]$domainCreds
    )
    $vms = 'drwnt-dc1', 'drwnt-dc2', 'drwnt-dc3', 'drwnt-dc4', 'drwnt-dc5', 'drwnt-dc6', 'drwnt-dc9'
    $vms | ForEach-Object { invoke-command -ScriptBlock { repadmin /syncall /deP } -ComputerName $_ -Credential $domainCreds -AsJob }
}

# Generate csv of Domain Controller VMs from list of sites
# Params: $csvPath, $domainCreds, $exportPath
function Invoke-PullVmsFromCsv {
    Param(
        [string]$csvPath,
        [PSCredential]$domainCreds,
        [string]$exportPath

    )
    $csv = Import-Csv $csvPath

    Connect-VIServer drwnt-vc2.ntschools.net -credential $domainCreds

    $csv | Foreach-Object { 
        Get-vm -name "$($_.Site)-DC*" | Foreach-Object { 
            $vmGuest = Get-VMGuest -VM $_ 
            $thisvm = [PSCustomObject]@{
                name   = $_.Name
                os     = $vmGuest.OSFullName
                ip     = $vmGuest.IPAddress[0]
                vmhost = $_.VMHost
            }
            $thisvm
            $thisvm | export-csv -Path $exportPath -Append -NoTypeInformation
        }
    }

    Disconnect-VIServer * -Confirm:$false
}

# Stop DC1 vms from csv file
# Params: $csvPath, $domainCreds
function Invoke-StopVmsFromCsv {
    Param(
        [string]$csvPath,
        [pscredential]$domainCreds
    )
    $csv = Import-Csv $csvPath

    Connect-VIServer drwnt-vc2.ntschools.net -credential $domainCreds

    $csv | Foreach-Object { 
        if ($_.name -like '*DC1*') {
            "Stopping $($_.name)..."
            Stop-VM -VM $_.name -Confirm:$false
        }
    }

    Disconnect-VIServer * -Confirm:$false
}

# Delete DC1 vms from disk from csv file, will ask for confirmation lol
# Params: $csvPath, $domainCreds
function Invoke-DeleteVMsFromCsv {
    Param(
        [pscredential]$domainCreds,
        [string]$csvPath
    )
    $csv = Import-Csv $csvPath

    Connect-VIServer drwnt-vc2.ntschools.net -credential $domainCreds

    $csv | ForEach-Object {
        if ($_.name -like '*DC1*') {
            "Deleting $($_.name)..."
            Remove-VM -DeletePermanently -VM $_.name
        }
    }
    Disconnect-VIServer * -Confirm:$false
}

# Renames the DC2 vm object to DC1
# Params: $csvPath, $domainCreds
function Invoke-RenameVmsFromCsv {
    Param(
        [pscredential]$domainCreds,
        [string]$csvPath
    )
    $csv = Import-Csv $csvPath

    Connect-VIServer drwnt-vc2.ntschools.net -credential $domainCreds

    $csv | ForEach-Object {
        if ($_.name -like '*DC2*') {
            $newName = $_.name.replace('DC2', 'DC1')
            "Renaming $($_.name) to $newName.."
            $vm = Get-VM $_.name
            Set-VM -VM $vm -Name $newName
        }
    }

    Disconnect-VIServer * -Confirm:$false
}

# Check repadmin on remote server
# Params: $domainCreds, $serverName
function Invoke-CheckRepadmin {
    Param(
        [PSCredential]$domainCreds,
        [string]$serverName
    )
    Invoke-Command -ComputerName $serverName -Credential $domainCreds -ScriptBlock {repadmin /showrepl}
}

# Check repadmin on remote servers from CSV file, output if there are failed
# Params: $csvPath $domainCreds
function Invoke-CheckRepAdminFromCsv {
    Param(
        [string]$csvPath,
        [PSCredential]$domainCreds
    )
    $csv = Import-Csv -Path $csvPath
    $csv | ForEach-Object { 
        if ($_.os -like '*2016*') { 
            "Checking $($_.name)..."
            $output = Invoke-CheckRepadmin -domainCreds $domainCreds -serverName $_.name 
            if ($output -like '*failed*') {
                $output
            } else {
                "$($_.name) tested OK!"
            }
        }
    }
}

function Invoke-CheckRepAdminFromSites {
    Param(
        [string]$csvPath,
        [PSCredential]$domainCreds
    )
    $csv = Import-Csv -Path $csvPath
    $csv | ForEach-Object { 
        $DC1 = $_.Site+'-DC1'
        "Checking $DC1..."
        $output = Invoke-CheckRepadmin -domainCreds $domainCreds -serverName $DC1
        if ($output -like '*failed*') {
            "============"
            "$DC1 error!"
            $output
        }
    }
}

function Invoke-AddDC1NameFromSites {
    Param(
        [string]$sitesCsvPath,
        [PSCredential]$domainCreds
    )
    $csv = Import-Csv -Path $sitesCsvPath
    $csv | Foreach-Object {
        "Processing site $($_.Site)..."
        Invoke-AddDC1Name -siteCode $_.Site -domainCreds $domainCreds
    }

}

function Invoke-MakeNamePrimaryFromSites {
    Param(
        [string]$sitesCsvPath,
        [PSCredential]$domainCreds
    )
    $csv = Import-Csv -Path $sitesCsvPath
    $csv | Foreach-Object {
        "Processing site $($_.Site)..."
        Invoke-MakeNamePrimary -siteCode $_.Site -domainCreds $domainCreds
    }

}

function Invoke-CheckRepAdminFromAD {
    Param(
        [PSCredential]$domainCreds
    )
    $dcs = Get-ADComputer -SearchBase "OU=Domain Controllers,DC=ntschools,DC=net" -Filter *
    $dcs | Foreach-Object {
        "Checking $($_.Name)..."
        $output = Invoke-CheckRepadmin -domainCreds $domainCreds -serverName $_.Name
        $output
    }
}