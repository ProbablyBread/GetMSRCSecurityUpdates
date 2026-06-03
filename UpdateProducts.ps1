try {
    Import-Module MsrcSecurityUpdates -ErrorAction Stop
}
catch {
    Write-Host "Ensure that the MsrcSecurityUpdates module is installed before running this script."
    Write-Host "Installation instructions: https://www.powershellgallery.com/packages/MsrcSecurityUpdates"
    Write-Host "Microsoft Github Repo: https://github.com/microsoft/MSRC-Microsoft-Security-Updates-API/tree/main"
    exit(1)
}

# do not stop on ctrl+c entry to avoid breaking the end of the script
[console]::TreatControlCAsInput = $true

$months = 6
$productsFile = ".\products.txt"

if (-not($null = Get-Item $productsFile)) {
    New-Item -Type File $productsFile | Out-Null
    Add-Content -Path $productsFile -Value "`"ProductId`",`"Description`"" 
}

# index all products over the last six months
# count from 1 to 6 (i.e. last month to six months before)
$products = @()
for ($i = 1; $i -le $months; $i++) {
    $idString = "{0:yyyy-MMM}" -f (Get-Date).AddMonths( - $($i))

    Write-Host "Indexing products for $($idString)..."
    # ignore AZ Linux, Android, or Surface products
    $products += (Get-MsrcCvrfDocument -ID $idString).ProductTree.FullProductName | Where-Object { $_.Value -notmatch "^azl\d.*|^cbl\d.*|.*Linux.*|.*Surface.*|.*Android.*" }
}

# get unique products
$products = $products | Sort-Object -Unique ProductID

# loop to add product IDs to list
do {
    $userInput = Read-Host "`nEnter a search string for a product (enter `"exit`" to quit)"
    
    # check for exit
    if ($userInput -match "[Ee][Xx][Ii][Tt]") {
        break
    }

    $userInput = $userInput.Replace(" ", ".*") # replace all spaces with wildcards

    # treat as array
    $list = @($products | Select-Object -Property ProductId, Value | Where-Object -Property Value -Match "$($userInput)")

    if ($list.Count -gt 0) {
        # print list
        $list | Format-Table -AutoSize
        $addInput = Read-Host "`nEnter a product ID to add to the list (blank to cancel)"

        if ($($addInput) -in $($products.ProductId)) {
            $selection = $list | Where-Object -Property ProductId -eq $addInput
            Write-Host "Adding $($selection.ProductId) - $($selection.Value) to product list."
            Add-Content -Path $productsFile -Value "$($selection.ProductId.Trim()),$($selection.Value.Trim())"
        }
        elseif ([string]::IsNullOrWhiteSpace($addInput)) {
            Write-Host "Returning to search."
        }
        else {
            Write-Host "Product ID not found. Returning to search."
        }
    }
    else {
        Write-Host "No products found. Returning to search.`n"
    }

} while ($true)

# final cleanup of products.txt to remove duplicates
$productsList = Import-Csv -Path $productsFile -Delimiter ","
$productsList | Sort-Object -Property ProductId -Unique | Export-Csv -Path $productsFile -NoTypeInformation