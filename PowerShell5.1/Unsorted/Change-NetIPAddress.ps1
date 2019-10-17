$configureIPAddress = 'Get-NetIPAddress -IPAddress <newIP> | Remove-NetIPAddress -confirm:$false; New-NetIPAddress -IPAddress <oldIP> -InterfaceAlias Ethernet0; ipconfig /registerdns'

$csv = Import-Csv revertREVERT.csv

$domainCreds = Get-Credential -Message "Domain Creds"

Connect-VIServer -Server drwnt-vc2.ntschools.net -Credential $domainCreds

$csv | %{ 

    "[$(Get-Date)] Processing $($_.Name)..."
    $thisConfigureIPAddress = $configureIPAddress.replace('<oldIP>', $_.IPAddress).replace('<newIP>', $_.newIPAddress)

    "[$(Get-Date)] Starting $($_.oldName)..."
    Start-VM -VM $_.oldName -Confirm:$false | Out-Null

    "[$(Get-Date)] Changing $($_.Name) ip address..."
    Invoke-Command -ComputerName $_.Name -Credential $domainCreds -ScriptBlock ([scriptblock]::Create($thisConfigureIPAddress)) -AsJob
    
    "[$(Get-Date)] Finished processing $($_.Name)."
}

Disconnect-VIServer -Server * -Confirm:$false
