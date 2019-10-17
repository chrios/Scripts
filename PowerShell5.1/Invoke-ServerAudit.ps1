# These functions will search AD for servers that are 2008 / 2003, and can sort them into the required CSV, or alternatively, add a category tag.
function Get-2008Servers {
    $timeStamp = (Get-Date -Format dd/MM/yy).ToString()
    Remove-Item '.\2008-NAS.csv' -ErrorAction SilentlyContinue
    Remove-Item '.\2008-Unmanaged.csv' -ErrorAction SilentlyContinue
    Remove-Item '.\2008-Other.csv' -ErrorAction SilentlyContinue
    Remove-Item '.\2008-SharePoint.csv' -ErrorAction SilentlyContinue
    Get-ADComputer -Filter 'OperatingSystem -like "*2008*"' -Properties Description, DistinguishedName, CanonicalName, OperatingSystem, Enabled `
    | Select-Object -Property DNSHostName, Description, OperatingSystem, CanonicalName, Enabled `
    | Sort-Object -Property CanonicalName `
    | ForEach-Object {
        $currentServer = $_
        if ( $currentServer.CanonicalName -like '*-NA1') {
            $currentServer | Export-Csv -NoTypeInformation -Append -Path '.\2008-NAS.csv'
            # $currentServer | Add-Member -MemberType NoteProperty -Name Category -Value 'NAS' -PassThru | Export-Csv -NoTypeInformation -Append -Path '.\2008.csv'
        }
        elseif ($currentServer.CanonicalName -like '*Unmanaged*') {
            $currentServer | Export-CSv -NoTypeInformation -Append -Path '.\2008-Unmanaged.csv'
            # $currentServer | Add-Member -MemberType NoteProperty -Name Category -Value 'Unmanaged' -PassThru | Export-Csv -NoTypeInformation -Append -Path '.\2008.csv'
        }
        elseif ($currentServer.Description -like '*SharePoint*') {
            $currentServer | Export-Csv -NoTypeInformation -Append -Path '.\2008-SharePoint.csv'
            # $currentServer | Add-Member -MemberType NoteProperty -Name Category -Value 'SharePoint' -PassThru | Export-Csv -NoTypeInformation -Append -Path '.\2008.csv'
        }
        else {
            $currentServer | Export-Csv -NoTypeInformation -Append -Path '.\2008-Other.csv'
            # $currentServer | Add-Member -MemberType NoteProperty -Name Category -Value 'Other' -PassThru | Export-Csv -NoTypeInformation -Append -Path '.\2008.csv'
        }
    }
}

function Get-2003Servers {
    Remove-Item '.\2003.csv' -ErrorAction SilentlyContinue
    Get-ADComputer -Filter 'OperatingSystem -like "*2003*"' -Properties Description, DistinguishedName, CanonicalName, OperatingSystem, Enabled `
    | Select-Object -Property DNSHostName, Description, OperatingSystem, CanonicalName, Enabled `
    | Export-Csv -NoTypeInformation -Path '.\2003.csv'
}