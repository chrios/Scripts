# This function will output a list of the site links and the replication frequency

function Get-ReplicationDelay {
    Param(
        [string]$FilePath
    )

    $sites = @()
    Import-Module ActiveDirectory
    Get-ADReplicationSiteLink -Filter * | Foreach-Object {

        $currentSite = [ordered]@{
            'Replication Frequency (min)' = $_.ReplicationFrequencyinMinutes
        }

        $siteNumber = 0

        $_.SitesIncluded | ForEach-Object {
            $site = $_.split(',')[0].split('=')[1]
            $siteName = "Site$siteNumber"
            $currentSite.Add($siteName, $site)         
            $siteNumber += 1
        }

        [PSCustomObject]$currentSite | Export-Csv -Path $FilePath -NoTypeInformation -Append

        $sites += $currentSite
        $currentSite = ''

    }

    $sites

}