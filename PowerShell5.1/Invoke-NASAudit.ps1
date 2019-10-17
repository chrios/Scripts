# This function was created to audit NAS drives and compare them against Vmware datastores
# it had to handle some interesting edge cases such as consolidated sites and sites with no NAS

function Get-FS1Drives {
    Param(
        [PSCredential]$Credential,
        [string]$ExportPath
    )

    $results = @()
    "[$(Get-Date)] Connecting to VI Server..."
    Connect-VIServer drwnt-vc2.ntschools.net -Credential $Credential
    
    # Iterate through datastores
    Get-Datastore | Sort-Object -Property Name | Foreach-Object {
        $siteNases = @()
        $fsName = $_.Name + '-FS1.ntschools.net'
        $hdCounter, $provisionedSpace, $fsErrorFlag, $naErrorFlag, $datastoreNasSpace = 0

        Vmware.Vimautomation.Core\Get-VM -Datastore $_ -Name *DC1* | Foreach-Object {
            if (Resolve-DnsName $_.Name.replace('-DC1', '-NA1')) {
                $siteNases += $_.Name.replace('-DC1', '-NA1')
            }
        }

        if ($siteNases) {
            "[$(Get-Date)] Checking datastore $($_.Name)..."
        
            # Get hard drives on that datastore
            "[$(Get-Date)] Counting Hard disks"
            Get-HardDisk -Datastore $_ | ForEach-Object {
                $hdCounter += 1
                "[$(Get-Date)] Testing Hard Disk $hdCounter..."
                # Add hard drive size to counter
                $provisionedSpace += $_.CapacityGB
            }
            # Get Free space of <datastore>-FS1 
            try {
                "[$(Get-Date)] Attempting to connect to $fsName..."
                $freeSpaceFonFs1 = Invoke-Command -ComputerName $fsName -ScriptBlock { (Get-PSDrive -PSProvider FileSystem -Name F).Free / 1024 / 1024 / 1024 } -Credential $Credential
                "[$(Get-Date)] Success"
            }
            catch {
                "[$(Get-Date)] Unable to connect to $fsName"
                $freeSpaceFonFs1 = "Unable to connect to $fsName."
            }
            
            # Get Used space of site NASes
            $siteNases | ForEach-Object {
                try {
                    "[$(Get-Date)] Attempting to connect to $_..."
                    $usedSpaceEonNa1 = Invoke-Command -ComputerName $_ -ScriptBlock { (Get-PSDrive -PSProvider FileSystem -Name E).Used / 1024 / 1024 / 1024 } -Credential $Credential
                    "[$(Get-Date)] Success"
                    $datastoreNasSpace += $usedSpaceEonNa1
                }
                catch {
                    "[$(Get-Date)] Unable to connect to $_!"
                    $usedSpaceEonNa1 = "Unable to connect to $_."
                }
            }
            
            "[$(Get-Date)] Adding result to array"
            # Add result to results array
            $results += [PSCustomObject]@{
                'Datastore'                           = $_.Name
                'Provisioned Space on Datastore (GB)' = $provisionedSpace
                'Total Space on Datastore (GB)'       = $_.CapacityGB
                'Available Space on Datastore (GB)'   = $_.CapacityGB - $provisionedSpace
                'Available Space on FS1 F: (GB)'      = $freeSpaceFonFs1
                'Used Space on NA1s E: (GB)'          = $datastoreNasSpace
                'Buffer for future growth (GB)'       = '500'
            }
            # debugging
            $results | Export-Csv -NoTypeInformation $ExportPath
        }
        else {
            "[$(Get-Date)] Skipping datastore $($_.Name), no Site NAS detected!"
        }
    }
    "[$(Get-Date)] Exporting results"
    # Export results to exportFile
    $results | ForEach-Object {
        $_ | Export-Csv -NoTypeInformation $ExportPath -Append
    }

    Disconnect-VIServer * -Confirm:$false
    "[$(Get-Date)] Done!"
}