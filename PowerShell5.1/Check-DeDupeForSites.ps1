function Check-DedupeForSites {
    Param(
        [pscredential]$Credential
    )
    $siteCodes = "ALAWASCH","ALEKACEC","ALYANAS","AMPILSCH","ARLPAHS","BAKEWSCH","BATCHAS","BORROSCH","CASUAHS","CASUASCH","DURACSCH","GIRRASCH","GRAYSCH","GUNBACEC","HOWARSCH","HUMPTSCH","JILKMSCH","JINGISCH","KALKACEC","KARAMSCH","KATHESOA","LAJAMCEC","LARAPSCH","LEANYSCH","MACFASCH","MALAKSCH","MANUNSCH","MILLNSCH","MINYESCH","MOULDSCH","NHULUHS","NIGHTHS","NIGHTSCH","PIGEOSCH","ROBINSCH","SADADSCH","TENNASCH","WANGUSCH","WARRUSCH","WUGULSCH","WULAGSCH","YIRRKHLC","DRIVESCH","MILYASCH"
    $dedupeSavings = 0
    $dedupedServerCounter = 0
    $siteCodes | ForEach-Object {
        $FS1Name = $_+'-FS1'
        $Dedupe = Invoke-Command -ComputerName $FS1Name -Credential $Credential -ScriptBlock {Get-DedupStatus -Volume F:}
        $Dedupe.PSComputerName
        $Dedupe.SavingsRate
        "-------"
        $dedupeSavings += $Dedupe.SavingsRate
        $dedupedServerCounter += 1
    }
    $averageDedupeSavingsRate = $dedupeSavings / $dedupedServerCounter
    "----------- SUMMARY -----------"
    "Number of deduped servers: $dedupedServerCounter"
    "Average Dedupe rate: $averageDedupeSavingsRate"
}
