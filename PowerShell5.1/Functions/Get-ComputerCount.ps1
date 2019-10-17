# Author: Christopher Frew
# Creation Date: 10/09/2019
#
# This function will audit your environment and report on operating system versions (numbers of)
# Needs modification to work outside of the environment it was design of
# Last Modified: 18/09/2019 Christopher Frew
# - Added function call and email message
# - Example use: Get-ComputerCount -ExportPath 'c:\temp\computerAudit.csv' -LastLoginDateCutoff 90 -TempCsvPath 'c:\temp\temp.csv' -OUSearchBase 'dc=contoso,dc=com'

function Get-ComputerCount {
    Param(
        [String]$ExportPath,
        [int]$LastLoginDateCutoff,
        [String]$TempCsvPath,
        [string]$OUSearchBase
    )

    Remove-Item $ExportPath -ErrorAction SilentlyContinue

    # Modify this variable to set the cutoff date for LastLoginDate in the report. 
    $CutoffDate = (Get-Date).AddDays(-$LastLoginDateCutoff)

    # Search AD for all the school computers
    Get-ADComputer -SearchBase $OUSearchBase -Properties OperatingSystem, OperatingSystemVersion, LastLogonDate, CanonicalName -Filter 'LastLogonDate -gt $CutoffDate' `
        | Select-Object -Property OperatingSystem, OperatingSystemVersion, LastLogonDate, CanonicalName `
        | Foreach-Object { $_.CanonicalName = $_.CanonicalName.split('/')[2]; $_ } `
        | Export-Csv -NoTypeInformation -Path $TempCsvPath
    
    # "Processing Results..."
    $csv = Import-Csv $TempCsvPath

    # This hash table will contain the hash tables
    $schools = @{ }

    # Lets iterate through the rows in the CSV
    $csv | ForEach-Object {
        # For clarity
        $SchoolName = $_.CanonicalName
        $OperatingSystem = $_.OperatingSystem
        $OperatingSystemVersion = $_.OperatingSystemVersion

        # Check and add new hash table if required
        if ($schools.Contains($SchoolName) -eq $false) {
            $schools[$SchoolName] = @{
                'Site Name'                  = $SchoolName
                'Windows 7'                  = 0
                'Windows 10 - Total at Site' = 0
                'Windows 10 - 1507'          = 0
                'Windows 10 - 1511'          = 0
                'Windows 10 - 1607'          = 0
                'Windows 10 - 1703'          = 0
                'Windows 10 - 1709'          = 0
                'Windows 10 - 1803'          = 0
                'Windows 10 - 1809'          = 0
                'Windows 10 - 1903'          = 0
                'Windows 10 - Other'         = 0
                'Windows 8'                  = 0
                'Windows 8.1'                = 0
                'MacOS'                      = 0
                'Total Computers at Site'    = 0
            }
        }

        # Add count to hash table key for OS
        if ($OperatingSystem -like '*7*') {
            $schools[$SchoolName]['Windows 7'] += 1
        }
        elseif ($OperatingSystem -like '*8.1*') {
            $schools[$SchoolName]['Windows 8.1'] += 1
        }
        elseif ($OperatingSystem -like '*8*') {
            $schools[$SchoolName]['Windows 8'] += 1
        }
        elseif ($OperatingSystem -like '*10*') {
            $schools[$SchoolName]['Windows 10 - Total at Site'] += 1
            # Check the build of windows 10, increment relevant counter
            if ($OperatingSystemVersion -eq '10.0 (10240)') {
                $schools[$SchoolName]['Windows 10 - 1507'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (10586)') {
                $schools[$SchoolName]['Windows 10 - 1511'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (14393)') {
                $schools[$SchoolName]['Windows 10 - 1607'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (15063)') {
                $schools[$SchoolName]['Windows 10 - 1703'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (16299)') {
                $schools[$SchoolName]['Windows 10 - 1709'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (17134)') {
                $schools[$SchoolName]['Windows 10 - 1803'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (17763)') {
                $schools[$SchoolName]['Windows 10 - 1809'] += 1
            }
            elseif ($OperatingSystemVersion -eq '10.0 (18362)') {
                $schools[$SchoolName]['Windows 10 - 1903'] += 1
            }
            else {
                $schools[$SchoolName]['Windows 10 - Other'] += 1
            }
        }
        elseif ($OperatingSystem -like '*Mac*') {
            $schools[$SchoolName]['MacOS'] += 1
        }

        # Increment total count for school
        $schools[$SchoolName]['Total Computers at Site'] += 1
    }
    # Iterate through the keys of the schools hashmap
    $schools.Keys | Foreach-Object {
        # Typecast the containing hashmap to PSCustomObject and export to CSV
        [PSCustomObject]$schools.Item($_) | Export-Csv -Path $ExportPath -Append -NoTypeInformation
    }

    Remove-Item $TempCsvPath

}