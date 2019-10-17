# Get start time/date of script
$startTime = Get-Date -Format "dd-MM-yyyy_HH:mm"

# Edit these variables to suit (Used for robocopy)
$Source = "C:\temp\Folder B"
$Destination = "C:\temp\Folder A"

# This is used for the log files and credential file
$fileBase = "C:\manage"

# Email support - edit to correct email.
# Be sure to save the file "credential.xml" with the following on the client machine:
# Get-Credential | Export-Clixml credential.xml
# And place credential.xml in the "$fileBase" directory above.
$toAddress = "support@oneitservices.com.au"
$fromAddress = "client@domain.com"
$smtpServer = "smtp.office365.com"

# These are the log files and credential file declarations. You shouldn't edit these.
$logLocation = "$fileBase\$($startTime)-log.txt"
$credFile = "$fileBase\credential.xml"
$errorLog = "$fileBase\error.log"

# Import credential
try {
    $credential = Import-Clixml -Path $credFile
}
catch {
    "[$(Get-Date)] Error! No credential! Email will not work" | Tee-Object -Append -FilePath $errorLog
}

# Define robocopy errors
function returnRobocopyError($errorLevel) {
    switch ($errorLevel) {
        0 { return "No errors occurred, and no copying was done. The source and destination directory trees are completely synchronized."; Break }
        1 { return "One or more files were copied successfully (that is, new files have arrived)."; Break }
        2 { return "Some Extra files or directories were detected. No files were copied. Examine the output log for details."; Break }
        3 { return "Some files were copied. Additional files were present. No failure was encountered."; Break }
        4 { return "Some Mismatched files or directories were detected. Examine the output log. Housekeeping might be required."; Break }
        5 { return "Some files were copied. Some files were mismatched. No failure was encountered."; Break }
        6 { return "Additional files and mismatched files exist. No files were copied and no failures were encountered. This means that the files already exist in the destination directory"; Break }
        7 { return "Files were copied, a file mismatch was present, and additional files were present."; Break }
        8 { return "Some files or directories could not be copied (copy errors occurred and the retry limit was exceeded). Check these errors further."; Break }
        16 { return "Serious error. Robocopy did not copy any files. Either a usage error or an error due to insufficient access privileges on the source or destination directories."; Break }
        default { return "Unknown error code." }
    }
}

# Start Robocopy
robocopy $Source $destination . /XO /TEE /E /R:0 /W:0 /NP /LOG:$logLocation

# Send email
Send-MailMessage -Attachments $logLocation -From $fromAddress -To $toAddress -Subject "$startTime - Robocopy output - $LASTEXITCODE" -Body returnRobocopyError($LASTEXITCODE) -SmtpServer $smtpServer -Port 587 -UseSsl:$true -Credential $credential