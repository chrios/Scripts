# This will help in checking for repadmin errors
# The default repadmin /showrepl * /errorsonly is pretty verbose...
# Wrote this to shorten it.

function Check-RepAdminFromADSites {

    Param(
        [PSCredential]$domainCreds
    )
    $sites = Get-ADReplicationSite -Filter * 

    $sites | ForEach-Object { 
        $DC1 = $_.Name + '-DC1'
        "Checking $DC1..."
        $output = Invoke-CheckRepadmin -domainCreds $domainCreds -serverName $DC1
        if ($output -like '*failed*') {
            "============"
            "$DC1 error!"
            $output
        }
    }
}


function Invoke-CheckRepadmin {
    Param(
        [PSCredential]$domainCreds,
        [string]$serverName
    )
    Invoke-Command -ComputerName $serverName -Credential $domainCreds -ScriptBlock {repadmin /showrepl}
}