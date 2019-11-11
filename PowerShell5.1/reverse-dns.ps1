function Get-IP {
    Param(
        [pscredential]$credential
    )
    $script = {
        $servers = "gdc-ddc03.prod.main.ntgov","gdc-ddc06.prod.main.ntgov","gdc-ddc01.prod.main.ntgov","crh-ddc01.prod.main.ntgov","gdc-ddc07.prod.main.ntgov","gdc-ddc08.prod.main.ntgov","agr-ddc01.prod.main.ntgov"
        $servers | %{
            resolve-dnsname $_ 
        }| %{ 
            $_.Name
            $_.IP4Address
        } 
    }

    invoke-command drwnt-dc5 -scriptblock $script -Credential $credential
}