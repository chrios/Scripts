$2008csv = import-csv -Path 'c:\users\scchristopher.frew\Desktop\checking\2008\Book2.csv'

$2008csv | %{ 
    echo "Testing ..." $_.CN
    if (test-connection $_.CN -count 1) {
        $PING = 'TRUE'
    } else {
        $PING = ''
    } 

    [PSCustomObject]@{
        PING = $PING
        CN = $_.CN
    } | export-csv -Append -Path  C:\users\scchristopher.frew\Desktop\checking\2008\output.csv -NoTypeInformation

    sleep 1
}