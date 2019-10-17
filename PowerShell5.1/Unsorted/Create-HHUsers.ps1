import-csv -Path C:\Users\scchristopher.frew\Desktop\azureADUsers.csv | % {
    $userPasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $userPasswordProfile.Password = $_.password

    $userParams = @{
        UserPrincipalName = $_.userPrincipalName
        DisplayName = $_.displayName
        AccountEnabled = $_.enabled
        PasswordProfile = $userPasswordProfile
    }
    
    if ($_.mailNickName) {$userParams.MailNickName = $_.mailNickName}
    if ($_.givenName) {$userParams.GivenName = $_.givenName}
    if ($_.surname) {$userParams.Surname = $_.surname}
    if ($_.city) {$userParams.City = $_.city}
    if ($_.country) {$userParams.Country = $_.country}
    if ($_.jobTitle) {$userParams.JobTitle = $_.jobTitle}
    if ($_.postalCode) {$userParams.PostalCode = $_.postalCode}
    if ($_.state) {$userParams.state = $_.State}
    if ($_.streetAddress) {$userParams.StreetAddress = $_.streetAddress}
    if ($_.telephoneNumber) {$userParams.TelephoneNumber = $_.telephoneNumber}

    #New-AzureADUser @userParams

    $userParams
    echo "-----------------------"
    echo ""

}