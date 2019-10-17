function Get-ADSites {
    Param(

    )

    # Form a hashmap of hashmaps containing site DN and subnet count
    $siteArray = @{}
    Get-ADReplicationSite -Filter * | ForEach-Object {
        $siteArray.add($_.Name, [ordered]@{
            'SiteDN' = $_.DistinguishedName
            'subnetCount' = 0
        })
    }

    # Iterate through replication subnets and sum to relevant siteDN 
    Get-ADReplicationSubnet -Filter * | ForEach-Object {
        try {
            $siteName = $_.Site.split(',')[0].split('=')[1]
            $siteArray[$siteName]['subnetCount'] += 1
        }
        catch {
            "Error processing site $($_.Site)"
        }
        
    }

    # Iterate through hashmap, printing site if it has no subnets
    $siteArray.Keys | %{
        if ($siteArray[$_]['subnetCount'] -eq 0)
        {
            $siteArray[$_]
        }
    }

}