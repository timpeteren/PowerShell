# Get SAS token

Connect-AzAccount
Get-AzSubscription
 
$subscriptionId = "yourSubscriptionId"
$storageAccountRG = "demo-azcopy-rg"
$storageAccountName = "tomsaccount"
$storageContainerName = "images"
$localPath = "C:\temp\images"
 
Select-AzSubscription -SubscriptionId $SubscriptionId
 
$storageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $storageAccountRG -AccountName $storageAccountName).Value[0]
 
$destinationContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
 
$containerSASURI = New-AzStorageContainerSASToken -Context $destinationContext -ExpiryTime(get-date).AddSeconds(3600) -FullUri -Name $storageContainerName -Permission rw
 
azcopy copy $localPath $containerSASURI --recursive