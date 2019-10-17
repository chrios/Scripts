$Colors = @{
    BackgroundColor = "#FF252525"
    FontColor = "#FFFFFFFF"
}

Start-UDDashboard -Port 10001 -Content {
    New-UDDashboard -Title "Windows EOL Monitoring Dashboard" `
    -NavBarColor '#FF1c1c1c' `
    -NavBarFontColor "#FF55b3ff" `
    -BackgroundColor "#FF333333" `
    -FontColor "#FFFFFFF" `
    -Content {
        New-UDRow {
            New-UDColumn -Size 3 {
                New-UDCard -Title 'Deployed VMs' -Endpoint {
                    Import-Csv -Path 'C:\Users\scchristopher.frew\Desktop\287\newVms.csv' | Select-Object -Property deployed | Where-Object {$_.deployed -eq 'TRUE'} | Measure-Object
                }
            }
        }
        New-UDRow {
            New-UDColumn -Size 12 {
                New-UDGrid -Title "Deployed Virtual Machines" `
                @Colors `
                -Headers @("Deployed VM Name", "Deployed VM Host", "Configured", "Deployed") `
                -Properties @("newVmName", "newVmHost", "configured", "deployed") `
                -AutoRefresh `
                -NoPaging `
                -Endpoint {
                    Import-Csv -Path 'C:\Users\scchristopher.frew\Desktop\287\newVms.csv' | Out-UDGridData
                }
            }
        }
    }
}