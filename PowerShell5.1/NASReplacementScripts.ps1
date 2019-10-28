
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
#>

# Invoke-UpdateAndExpandDisk
# Invoke-PreSeedFiles
# Create-SMBShares


# At 4:30pm, for each site:
# 
# Invoke-SwapDFSFolderTarget
# Invoke-FinalCopyFiles
# Invoke-PowerDownNAS

function Invoke-UpdateAndExpandDisk {
    Param(
        [string]$siteCode,
        [pscredential]$Credential
    )
    Begin {
        $scriptBlock = {
            Update-HostStorageCache
            $sizeMax = (Get-PartitionSupportedSize -DriveLetter F).SizeMax
            Resize-Partition -DriveLetter F -Size $sizeMax
        }
        $fsName = $siteCode + '-FS1'
    }
    Process {
        Invoke-Command -ComputerName $fsName -Credential $Credential -ScriptBlock $scriptBlock
    }
}

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
        [string]$siteCode
    )
    Begin {
        $script = 'robocopy e:\NASData \\<schoolcode>-fs1\f$\NASdata /S /E /COPY:DATSO /NP /XO /R:0 /W:0 /TEE /LOG:C:\users\admcfrew\robocopy-log.txt'
        $script = $script.replace('<schoolcode>', $siteCode)
    }
    Process {
        return $script
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
        [string]$siteCode
    )
    Begin {
        $script = 'robocopy e:\NASData \\<schoolcode>-fs1\f$\NASdata /S /E /COPY:DATSO /NP /XO /R:0 /W:0 /TEE /LOG:C:\users\admcfrew\robocopy-log-final.txt'
        $script = $script.replace('<schoolcode>', $siteCode)
        
    }
    Process {
        return $script
    }
}

function Invoke-SwapDFSFolderTarget {
    Param(
        [string]$siteCode
    )
    Begin {
    }
    Process {
        New-DfsnFolderTarget -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\NAS\Staff NoBackup" -TargetPath "\\$siteCode-fs1.ntschools.net\Staff NoBackup"
        New-DfsnFolderTarget -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\NAS\Student NoBackup" -TargetPath "\\$siteCode-fs1.ntschools.net\Student NoBackup"
        Remove-DfsnFolderTarget -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\Staff NoBackup" -TargetPath "\\$siteCode-NA1.ntschools.net\Staff NoBackup"
        Remove-DfsnFolderTarget -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\Student NoBackup" -TargetPath "\\$siteCode-NA1.ntschools.net\Student NoBackup"
        Remove-DfsnFolderTarget -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\Staff NoBackup" -TargetPath "\\$siteCode-NA1\Staff NoBackup"
        Remove-DfsnFolderTarget -Path "\\ntschools.net\SchoolsData\$siteCode\Unmanaged Data\Student NoBackup" -TargetPath "\\$siteCode-NA1\Student NoBackup"
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