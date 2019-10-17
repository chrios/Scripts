# Helper functions
# These are an implementation of the WDS PowerShell module through Invoke-VMScript
# I had to run these on Windows Server 2012 machines
# Which does not have the WDS PowerShell Module....
function Get-RidOfHeader {
    Param(
        [String]$InputText
    )

    return $InputText.Split("`n`r") | Where-Object {$_} | Select-Object -Skip 0
}

function Invoke-RunVMScript {
    Param(
        [String]$RemoteCommand,
        [PSCredential]$DomainCredential,
        [String]$ServerName
    )

    Connect-ViServer drwnt-vc2.ntschools.net -Credential $DomainCredential | Out-Null
    $scriptBlock = [ScriptBlock]::Create($RemoteCommand)
    $scriptOutput = $(Invoke-VMScript -ScriptText $scriptBlock -VM $ServerName -GuestCredential $DomainCredential -WarningAction SilentlyContinue).ScriptOutput
    Disconnect-VIServer drwnt-vc2.ntschools.net -confirm:$false
    #"=================="
    #"Raw Output"
    #$scriptOutput
    #$parsedOutput = Get-RidOfHeader -InputText $scriptOutput 
    #"=================="
    #"Parsed Output"
    #$parsedOutput
    return $scriptOutput
}

# WDS Functions
function Get-WDSImageGroups {

    Param(
        [String]$ServerName,
        [PSCredential]$DomainCredential
    )
    
    $outputText = Invoke-RunVMScript `
        -DomainCredential $DomainCredential `
        -ServerName $ServerName `
        -RemoteCommand '$imageGroups = $(wdsutil /Get-AllImageGroups | findstr "Name:") ; $parsedImageGroups = $imageGroups.replace("Name: ", "") ; $parsedImageGroups' `

    return $outputText
}

function Get-WDSBootImages {
    
    Param(
        [String]$ServerName,
        [PSCredential]$DomainCredential
    )

    $outputText = Invoke-RunVMScript `
        -DomainCredential $DomainCredential `
        -ServerName $ServerName `
        -RemoteCommand '$bootImages = $(wdsutil /Get-AllImages /Show:Boot | findstr /C:"Image name:") ; $parsedBootImages = $bootImages.replace("Image name: ", "") ; $parsedBootImages'

    return $outputText.split("`r`n") | Select-Object -Skip 30
}