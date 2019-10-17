$URI = "https://directory.ntschools.net/"

$HTML = Invoke-WebRequest -Uri $URI

$urls = ($HTML.ParsedHtml.getElementsByTagName("a") | where { $_.className -eq 'AZBody' }).href

foreach ($url in $urls) {

    start-sleep -s 1.5
    
    $schoolName = $url.Replace('about:SchoolProfile.aspx?name=', '')
    $formattedUrl = $url.Replace('about:', 'https://directory.ntschools.net/')

    $schoolHtml = Invoke-WebRequest -Uri $formattedUrl
    $schoolBandwidth = ($schoolHtml.ParsedHtml.getElementsByTagName("td") | where {$_.getAttributeNode('class').Value -eq 'ProfileHeading'} | where { $_.innerHTML -like '*Mbps*' }).innerHTML

    echo $schoolName
    echo $formattedUrl
    echo $schoolBandwidth
    echo ''
    
    [PSCustomObject]@{
        schoolName = $schoolName
        url = $formattedUrl
        bandwidth = $schoolBandwidth
     } | Export-Csv -Path c:\manage\bandwidth.csv -Append

}