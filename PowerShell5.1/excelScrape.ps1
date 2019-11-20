$excel = New-Object -ComObject Excel.Application
$workBook = $excel.Workbooks.Open('C:\Users\scchristopher.frew\Desktop\With Analysis-BSOD tickets.xlsx')
$ws = $workBook.Worksheets | Where-Object { $_.Name -eq 'BSOD Tickets' }

$rowMax = ($ws.UsedRange.Rows).count
$resultsArray = @()

for ($row = 2; $row -le $rowMax; $row++) {
    $resultsArray += [PSCustomObject]@{
        'TicketNumber'    = $ws.cells.item($row, 1).value2
        'Title'           = $ws.cells.item($row, 2).value2
        'Description'     = $ws.cells.item($row, 3).value2
        'SerialNumber'    = $ws.cells.item($row, 4).value2
        'NumberOfLaptops' = $ws.cells.item($row, 5).value2
        'TypeOfBSOD'      = $ws.cells.item($row, 6).value2
        'Make'            = $ws.cells.item($row, 7).value2
        'Model'           = $ws.cells.item($row, 8).value2
        # 'OpenTime' = $ws.cells.item($row, 9).value2
        'Contact'         = $ws.cells.item($row, 10).value2
        'Location'        = $ws.cells.item($row, 11).value2
    }
}

$resultsArray | % {
    if ($_ -match 'dell') {
        $_.Make = 'Dell'
    }
    if ($_ -match '7390') {
        $_.Model = '7390'
    }
    $_
}