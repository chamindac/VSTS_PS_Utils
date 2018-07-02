Param(
[Parameter(Mandatory=$true)]
[string] $resourceGroupName,
[Parameter(Mandatory=$true)]
[string] $location,
[Parameter(Mandatory=$true)]
[string] $appServicePlan,
[Parameter(Mandatory=$true)]
[string] $pricingTier,
[Parameter(Mandatory=$true)]
[string] $webAppName
)

#******************************
# Creating resource group if not exisiting

Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorVariable resourceGroupNotFound -ErrorAction SilentlyContinue

if ($resourceGroupNotFound)
{
    Write-Host $resourceGroupNotFound

    Write-Host 'Creating resource group' $resourceGroupName
    New-AzureRmResourceGroup -Name $resourceGroupName -Location $location -Verbose
}
else
{
    Write-Host 'Resource group ' $resourceGroupName ' found'
}

#******************************
# Creating app service plan if not exisiting

$appsvcplan = Get-AzureRmAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlan 

if (!$appsvcplan)
{
    Write-Host 'App service plan ' $appServicePlan ' not foiund'

    Write-Host 'Creating resource group' $appServicePlan 'in' $resourceGroupName 'pricing tier: ' $pricingTier
    New-AzureRmAppServicePlan -Name $appServicePlan -Location $location -ResourceGroupName $resourceGroupName -Tier $pricingTier
}
else
{
    #---Updating pricing tier -------
    Write-Host 'App serrvice plan found and updating pricing tier to ' $pricingTier
    Set-AzureRmAppServicePlan -ResourceGroupName $resourceGroupName -Name $appServicePlan -Tier $pricingTier
}

#******************************
# Creating web appe if not exisiting

Get-AzureRmWebApp -ResourceGroupName $resourceGroupName  -Name $webAppName -ErrorVariable webAppNotFound -ErrorAction SilentlyContinue

if ($webAppNotFound)
{
    Write-Host $webAppNotFound

    Write-Host 'Creating web app ' $webAppName

    New-AzureRmWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -Location $location -AppServicePlan $appServicePlan    
}
else
{
    #---Updating app service plan -------
    Write-Host 'Web App Found updating app service plan to ' $appServicePlan  

    Set-AzureRmWebApp -ResourceGroupName $resourceGroupName -Name $webAppName -AppServicePlan $appServicePlan  
}


