param(
    [string]$DateString = (Get-Date -Format "yyyy-MMM"),
    [string]$OutputFile = "" 
)

$productsFile = "./products.txt"

if ($DateString -notmatch "^\d{4}-[A-Za-z]{3}$") {
    Write-Host "Ensure that -DateString is in the format of YYYY-MMM (e.g. 2026-Mar)."
    exit(1)
}

try {
    Import-Module MsrcSecurityUpdates -ErrorAction Stop
    Write-Host "Importing list of products from $($productsFile)..."
    $products = Import-Csv $productsFile -ErrorAction Stop
} 
catch [System.IO.FileNotFoundException] {
    if ($_.FullyQualifiedErrorId -match "Modules_ModuleNotFound") {
        Write-Host "ERROR: Unable to import the MsrcSecurityUpdates module: $($_.Exception)" -ForegroundColor Red
        Write-Host "Ensure that the MsrcSecurityUpdates module is installed before running this script."
        Write-Host "Installation instructions: https://www.powershellgallery.com/packages/MsrcSecurityUpdates"
        Write-Host "Microsoft Github Repo: https://github.com/microsoft/MSRC-Microsoft-Security-Updates-API/tree/main"
        exit(1)
    } 
    elseif ($_.FullyQualifiedErrorId -match "FileOpenFailure") {
        Write-Host "ERROR: Unable to find products.txt in the local folder: $($_.Exception)" -ForegroundColor Red
        Write-Host "Please run UpdateProducts.ps1 to start."
        exit(1)
    }
}
catch {
    Write-Host "ERROR: Unhandled exception caught: $($_.Exception)" -ForegroundColor Red
    Write-Host "$($_.CategoryInfo)"
    Write-Host "$($_.FullyQualifiedErrorId)"
    exit(1)
}

if ($products.Count -lt 1) {
    Write-Host "ERROR: products.txt is empty." -ForegroundColor Red
    Write-Host "Please run UpdateProducts.ps1 to start."
    exit(1)
}

# get list of updates for the current month
#$DateString = "2026-Mar"
$remediations = @()

try {
    Write-Host "Getting list of updates for $($DateString)...`n"
    $cvrf = Get-MsrcCvrfDocument -ID $DateString
} 
catch [System.IO.InvalidDataException] {
    Write-Host "ERROR: Unable to get updates: $($_.Exception)" -ForegroundColor Red
    exit(1)
}
catch [System.Management.Automation.ParameterBindingException] {
    Write-Host "ERROR: No updates available for $($DateString)" -ForegroundColor Red
    exit(1)
}
catch {
    Write-Host "ERROR: Unhandled exception caught: $($_.Exception)" -ForegroundColor Red
    Write-Host "$($_.CategoryInfo)"
    Write-Host "$($_.FullyQualifiedErrorId)"
    exit(1)
}

foreach ($product in $products) {
    #Write-Host "Getting security updates for $($product.Description)..."

    # initialise hashtable for each product
    $remediation = [PSCustomObject]@{
        Product         = $product.Description
        LatestVersion   = ""
        Link            = ""
        RestartRequired = "" 
    }

    # extract relevant remediations
    $r = @($cvrf.Vulnerability.Remediations | 
        Where-Object {
            ($product.ProductId -in $_.ProductID) -and 
            $_.SubType -eq "Security Update"
        })

    # consolidate latest remediations for all relevant products if they exist
    if ($r.Count -gt 0) {
        # sort all remediations by FixedBuild and get the latest
        try {
            $r = $r | Sort-Object { [version]$_.FixedBuild } -ErrorAction Stop -Descending

            $remediation.LatestVersion = $r[0].FixedBuild
            $remediation.Link = $r[0].URL
            $remediation.RestartRequired = $r[0].RestartRequired.Value
        }
        # if FixedBuild cannot be casted to version type
        catch [System.InvalidCastException] {
            # if it's a URL
            if ($r.FixedBuild -match "^https:") {
                $remediation.LatestVersion = "N/A - See Link"
                $remediation.Link = $r[0].FixedBuild
                $remediation.RestartRequired = $r[0].RestartRequired.Value
            }
            # if there are multiple versions separated by "and" or ","
            elseif ($r.FixedBuild -match ".*(,.*)?\sand\s.*") {
                # sort by text string instead
                $r = $r | Sort-Object { $_.FixedBuild } -ErrorAction Stop -Descending

                $remediation.LatestVersion = $r[0].FixedBuild
                $remediation.Link = $r[0].URL
                $remediation.RestartRequired = $r[0].RestartRequired.Value
            }
            else {
                Write-Host "ERROR: Unhandled exception caught: $($_.Exception)" -ForegroundColor Red
                Write-Host "$($_.CategoryInfo)"
                Write-Host "$($_.FullyQualifiedErrorId)"
            }
        }
    }
    # no remediations found
    else {
        $remediation.LatestVersion = "N/A"
        $remediation.Link = "No security updates for $($DateString)"
        $remediation.RestartRequired = "N/A" 
    }

    # replace all blank links for Microsoft Edge
    # there may be other uncaught edge cases here
    if ($product.ProductId -eq "11655" -and $remediation.Link -eq "") {
        $remediation.Link = "https://docs.microsoft.com/en-us/DeployEdge/microsoft-edge-relnotes-security"
    }

    $remediations += $remediation
}

# print list of updates
$documentTitle = $cvrf.DocumentTitle.Value
Write-Host ("=" * ($documentTitle.Length + 6))
Write-Host "== $($cvrf.DocumentTitle.Value) =="
Write-Host ("=" * ($documentTitle.Length + 6))
$remediations | Sort-Object -Property Product | Format-Table -AutoSize -Wrap 

# output to file
if ($OutputFile -ne "") {
    Write-Host "Exporting all security updates to $($OutputFile)..."
    try {
        $($remediations | Sort-Object -Property Product | Select-Object Product, LatestVersion, Link, RestartRequired) | Export-Csv -Path "$OutputFile" -Delimiter "," -NoTypeInformation
        Write-Host "Security updates exported to $($OutputFile)."
    }
    catch {
        Write-Host "ERROR: Failed to export file: $($_.Exception)" -ForegroundColor Red
        Write-Host "$($_.CategoryInfo)"
        Write-Host "$($_.FullyQualifiedErrorId)"
    }
}
