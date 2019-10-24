
# In the morning, for each site:
#
# Check-NASSpace
# Create-NewNASFolder
<#
Verify that required space exists on Datastore before proceeding.
Expand F: volume on FS1 by amount required for E:\ drive files:
- Browse to DRWNT-VC2.ntschools.net
- Locate site FS1 server.
- Right Click, Edit Settings
- Change size of 1024GB disk, increasing by required space
- Run diskmgmt.msc as admin
- Connect to FS1
- Right click on expanded drive, click 'Extend Volume'
- Proceed through wizard until finish
#>
# Invoke-PreSeedFiles
# Create-SMBShares


# At 4:30pm, for each site:
# 
# Invoke-FinalCopyFiles
# Invoke-SwapDFSFolderTarget
# Invoke-PowerDownNAS

function Check-NASSpace {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $nasName = $siteCode + '-NA1'
        $scriptBlock = { Get-PSDrive -PSProvider FileSystem -Name E }
    }
    Process {
        Invoke-Command -ComputerName $nasName -Credential $Credential -ScriptBlock $scriptBlock
    }
}

function Create-NewNASFolder {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $fsName = $siteCode + '-FS1'
        $scriptBlock = { New-Item -Path F:\ -Name NASData -ItemType Directory }
    }
    Process {
        Invoke-Command -ComputerName $fsName -Credential $Credential -ScriptBlock $scriptBlock
    }
}

function Invoke-PreSeedFiles {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $script = 'robocopy e:\NASData \\<schoolcode>-fs1\f$\NASdata /TEE /S /E /COPY:DATSO /NP /XO /R:0 /W:0 /LOG:C:\admin\robocopy-log.txt'
        $script = $script.replace('<schoolcode>', $siteCode)
        $scriptBlock = [Scriptblock]::Create($script)
        $nasName = $siteCode + '-NA1'
    }
    Process {
        Invoke-Command -ComputerName $nasName -Credential $Credential -ScriptBlock $scriptBlock
    }
}

function Create-SMBShares {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $fsName = $siteCode+'-FS1'
        $scriptBlock = {
            New-SmbShare -Path 'F:\NASData\Student NoBackup' -Description 'Share to replace Site NAS - Student NoBackup' -FullAccess 'Everyone' -Name 'Student NoBackup'
            New-SmbShare -Path 'F:\NASData\Staff NoBackup' -Description 'Share to replace Site NAS - Staff NoBackup' -FullAccess 'Everyone' -Name 'Staff NoBackup'
        }
    }
    Process {
        Invoke-Command -ComputerName $fsName -Credential $Credential -ScriptBlock $scriptBlock
    }
}

function Invoke-FinalCopyFiles {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $script = 'robocopy e:\NASData \\<schoolcode>-fs1\f$\NASdata /TEE /S /E /COPY:DATSO /NP /XO /R:0 /W:0 /LOG:C:\admin\robocopy-log-final.txt'
        $script = $script.replace('<schoolcode>', $siteCode)
        $scriptBlock = [Scriptblock]::Create($script)
        $nasName = $siteCode + '-NA1'
    }
    Process {
        Invoke-Command -ComputerName $nasName -Credential $Credential -ScriptBlock $scriptBlock
    }
}

function Invoke-SwapDFSFolderTarget {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
    }
    Process {
        Set-DfsnFolderTarget  -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\NAS\Staff NoBackup" -TargetPath "\\$siteCode-FS1.ntschools.net\Staff NoBackup"
        Set-DfsnFolderTarget  -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\NAS\Student NoBackup" -TargetPath "\\$siteCode-FS1.ntschools.net\Student NoBackup"
    }
}

function Invoke-PowerDownNAS {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $nasName = "$siteCode-NA1"
    }
    Process {
        Stop-Computer -ComputerName $nasName -Credential $Credential
    }
}

# At 4:30pm