# GetMSRCSecurityUpdates
## Description
This PowerShell script extracts the latest security updates available for specified products from the Microsoft Security Response Centre (MSRC) based on a list of products. 

This script comes in two parts: 
1. The main script - MSRCSecurityUpdates.ps1
2. The product updater - UpdateProducts.ps1

## Pre-Requisites
This script requires at least PowerShell 5.1 and the [MsrcSecurityUpdates PowerShell Module](https://github.com/microsoft/MSRC-Microsoft-Security-Updates-API) from Microsoft to function. 

While this script has only been tested on PowerShell 5.1, it should be able to work on later versions of PowerShell.

## Usage Instructions
For first time usage, run UpdateProducts.ps1 to begin. This will populate the list within products.txt to be used in the main script. To remove products, delete each line manually from products.txt.

Once the products.txt has been setup, run MSRCSecurityUpdates.ps1 to get the list of security updates for each product in product.txt from the MSRC API. 

To specify the month, use the -DateString parameter with the month format in YYYY-MMM (e.g. 2026-May).

To specify an output file, use the -OutputFile parameter with the path to the output file.
