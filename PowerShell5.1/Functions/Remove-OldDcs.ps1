# This script fixed branch DCs that had not replicated the new core dcs 
# they could not replicate as the core dc objects had been replaced however they still had the old objects in their local db
# it forces replication of the old objects (deleting them) and the new objects (creating them)
# then forces replication of the Configuration partition
function Remove-OldDcs {
    $rodcs = get-adcomputer -searchbase 'ou=domain controllers,dc=ntschools,dc=net' -filter 'DnsHostName -notlike "*DRWNT*"'
    $ra = @()
    $script = {
        repadmin /add CN=Schema,CN=Configuration,DC=ntschools,DC=net (hostname) drwnt-dc12.ntschools.net /readonly /selsecrets

        Start-Sleep -Seconds 20

        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=12456c93-881a-4db3-b565-3fc5409ec095>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=c7334d3d-37b5-4cae-8ee8-3a3a7ced634c>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=af018f8a-2a8f-4d80-a9f7-b690ddf2e9d4>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=c1cb93f1-cb98-457c-a494-7d9a1c0c27c1>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=909da108-4e7a-4794-805b-81099804875f>"

        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=6d406282-455d-475f-a220-59c712c60b71>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=d7cee747-9b4f-4a47-b880-0108eecd61cf>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=6aaf8604-3b48-4f40-80e2-65aad2ff8347>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=19faf120-407c-47e7-bb8f-84764ebfe703>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=5bda3963-b0f5-40ef-925c-950ce7d1e9a0>"
        repadmin /replsingleobj (hostname) drwnt-dc12 "<GUID=07db66ca-6ced-4af7-9238-7dd3b11ff9e0>"
        
        repadmin /add CN=Configuration,DC=ntschools,DC=net (hostname) drwnt-dc12.ntschools.net /readonly /selsecrets
    }

    $rodcs | ForEach-Object {
        "Invoking on $($_.DnsHostName)..."
        $scriptOut = Invoke-Command -ScriptBlock $script -ComputerName $_.DnsHostName -Credential $cred
        $ra += $scriptOut
    }
}


<#
repadmin /replsingleobj batchas-dc1 drwnt-dc12 "<GUID=>"

bad: 
DRWNT-DC9 - c7334d3d-37b5-4cae-8ee8-3a3a7ced634c
DRWNT-DC6 - af018f8a-2a8f-4d80-a9f7-b690ddf2e9d4
DRWNT-DC4 - 12456c93-881a-4db3-b565-3fc5409ec095
DRWNT-DC5 - c1cb93f1-cb98-457c-a494-7d9a1c0c27c1
DRWNT-DC3 - 909da108-4e7a-4794-805b-81099804875f

good:
DRWNT-DC9 - 6d406282-455d-475f-a220-59c712c60b71
DRWNT-DC6 - d7cee747-9b4f-4a47-b880-0108eecd61cf
DRWNT-DC5 - 6aaf8604-3b48-4f40-80e2-65aad2ff8347
DRWNT-DC3 - 19faf120-407c-47e7-bb8f-84764ebfe703
DRWNT-DC2 - 5bda3963-b0f5-40ef-925c-950ce7d1e9a0
DRWNT-DC1 - 07db66ca-6ced-4af7-9238-7dd3b11ff9e0
#>