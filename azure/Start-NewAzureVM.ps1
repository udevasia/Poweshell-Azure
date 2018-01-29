#Get Azure Rm VM Images Infos
function Get-AzureRmVMImageInfos(){
	param
    (
      [Parameter(Mandatory=$true)]
      [string]$RmProfilePath,
      [Parameter(Mandatory=$true)]
	  [string]$LocationName,
      [Parameter(Mandatory=$false)]
      [string]$PublisherName = 'Microsoft',
      [Parameter(Mandatory=$false)]
      [string]$OfferName = 'windows'
    )
    Select-AzureRmProfile -Path $RmProfilePath -ErrorAction Stop
    $Location = Get-AzureRmLocation | Where-Object {$_.Location -eq $LocationName}
	If(-not($Location)) { Throw "The location does not exist." }
    $PublisherName = '*'+$PublisherName+'*'
    $OfferName='*'+$OfferName+'*'
    $lstPublishers = Get-AzureRMVMImagePublisher -Location $LocationName | Where-object { $_.PublisherName -like $PublisherName }
    ForEach ($pub in $lstPublishers) {
       #Get the offers
       $lstOffers = Get-AzureRMVMImageOffer -Location $LocationName -PublisherName $pub.PublisherName  | Where-object { $_.Offer -like $OfferName }
       ForEach ($off in $lstOffers) {
         Get-AzureRMVMImageSku -Location $LocationName -PublisherName $pub.PublisherName -Offer $off.Offer | Format-Table -Auto
	   }
    }
}

#Check location 
function Check-AzureRmLocation(){
    param
    (
	  [Parameter(Mandatory=$true)]
	  [string]$LocationName
    )
     Write-Verbose "Check location $LocationName"
     $Location = Get-AzureRmLocation | Where-Object {$_.Location -eq $LocationName}
	 If(-not($Location)) {
       Write-Verbose "The location" $LocationName "does not exist."
       return $false
     }
     Else{
       return $true
     }
}

#Check resource group, if not, created it.
function Check-AzureRmResourceGroup(){
     param
    (
	  [Parameter(Mandatory=$true)]
      [string]$ResourceGroupName,
	  [Parameter(Mandatory=$true)]
	  [string]$LocationName
    )
     Write-Verbose "Check resource group $ResourceGroupName, if not, created it." -ForegroundColor Green
     Try
     {
         $ResourceGroup = Get-AzureRmResourceGroup -Name $ResourceGroupName -Location $LocationName -ErrorAction Stop
	     If(-not($ResourceGroup)) {
             Write-Verbose "Creating resource group" $ResourceGroupName "..."
             New-AzureRmResourceGroup -Name $ResourceGroupName -Location $LocationName  -ErrorAction Stop
             return $true
         }
         Else{
             return $true
         }
    }
    Catch
    {
        Write-Verbose -ForegroundColor Red "Create resource group" $LocationName "failed." $_.Exception.Message
        return $false
    }
}

#Auto generate network interface.
function AutoGenerate-AzureRmNetworkInterface(){
     param
    (
      [Parameter(Mandatory=$true)]
      [string] $ResourceGroupName,
      [Parameter(Mandatory=$true)]
	  [string] $LocationName,
      [Parameter(Mandatory=$true)]
      [string] $VMName
    )
   
    Try
    {
          $RandomNum = Get-Random -minimum 100 -maximum 999
          $SubnetName = "subnetdefault"+$RandomNum
          $VnetName = $ResourceGroupName+"-vnet"+$RandomNum
          $IpName = $VMName+"-ip"+$RandomNum
          $NicName = $VMName+"-ni"+$RandomNum

          Write-Verbose "Auto generate network interface $NicName" 
          $Subnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix 10.0.0.0/24 -ErrorAction Stop
               
          $Vnet = New-AzureRmVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -Location $LocationName -AddressPrefix 10.0.0.0/16 -Subnet $Subnet -ErrorAction Stop        
         
          $Pip = New-AzureRmPublicIpAddress -Name $IpName -ResourceGroupName $ResourceGroupName -Location $LocationName -AllocationMethod Dynamic -ErrorAction Stop       
          
          $Nic = New-AzureRmNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $Pip.Id -ErrorAction Stop

          return $Nic.Id
    }
    Catch
    {
          Write-Verbose "Auto generate network interface" $_.Exception.Message
          return $false
    }
}

#Create a Windows VM using Resource Manager
function New-AzureVMByRM(){
     param
    (
      [Parameter(Mandatory=$true)]
      [string] $RmProfilePath,
      [Parameter(Mandatory=$true)]
      [string] $ResourceGroupName,
      [Parameter(Mandatory=$true)]
	  [string] $LocationName,
      [Parameter(Mandatory=$true)]
      [string] $VMName,
      [Parameter(Mandatory=$false)]
      [string] $VMSizeName ="Standard_DS1",
      [Parameter(Mandatory=$false)]
      [string] $PublisherName = 'MicrosoftVisualStudio',
      [Parameter(Mandatory=$false)]
      [string] $OfferName = 'Windows',
      [Parameter(Mandatory=$false)]
      [string] $SkusName = '10-Enterprise-N',
      [Parameter(Mandatory=$true)]
      [PSCrecdential] $PsCred
    )
   
    Try
    {     
       Write-Verbose "Login Azure by profile" -ForegroundColor Green   
       Select-AzureRmProfile -Path $RmProfilePath -ErrorAction Stop

       #2. Check location
       if(Check-AzureRmLocation -LocationName $LocationName){
          #3. Check resource group, if not, created it.
          if(Check-AzureRmResourceGroup -LocationName $LocationName -ResourceGroupName $ResourceGroupName){
             #4. Check VM images  
             Write-Verbose "Check VM images $SkusName"   
             If(Get-AzureRMVMImageSku -Location $LocationName -PublisherName $PublisherName -Offer $OfferName -ErrorAction Stop | Where-Object {$_.Skus -eq $SkusName}){
                 #5. Check VM
                 If(Get-AzureRmVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction Ignore){
                     Write-Verbose "VM $VMName has already exist."
                 }
                 else{
                    #6. Check VM Size
                    Write-Verbose "check VM Size $VMSizeName" 
                    If(Get-AzureRmVMSize -Location $LocationName | Where-Object {$_.Name -eq $VMSizeName})
                    {
                       #7. Create a storage account                     
                        #8. Create a network interface
                        $Nid = AutoGenerate-AzureRmNetworkInterface -Location $LocationName -ResourceGroupName $ResourceGroupName -VMName $VMName
                        If($Nid){
                            Write-Verbose "Creating VM $VMName ..." -ForegroundColor Green 
							
                            #11.Choose virtual machine size, set computername and credential
                            $VM = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSizeName -ErrorAction Stop
                            $VM = Set-AzureRmVMOperatingSystem -VM $VM -Windows -ComputerName $VMName -Credential $Cred -ProvisionVMAgent -EnableAutoUpdate -ErrorAction Stop
                           
                            #12.Choose source image
                            $VM = Set-AzureRmVMSourceImage -VM $VM -PublisherName $PublisherName -Offer $OfferName -Skus $SkusName -Version "latest" -ErrorAction Stop
                           
                            #13.Add the network interface to the configuration.
                            $VM = Add-AzureRmVMNetworkInterface -VM $VM -Id $Nid -ErrorAction Stop
                           
                            #14.Add storage that the virtual hard disk will use. 
                            <#$BlobPath = "vhds/"+$SkusName+"Disk.vhd"
                            $OSDiskUri = $BlobURL + $BlobPath
                            $DiskName = "windowsvmosdisk"
                            $VM = Set-AzureRmVMOSDisk -VM $VM -Name $DiskName -VhdUri $OSDiskUri -CreateOption fromImage -ErrorAction Stop#>

                            #15. Create a virtual machine
                            New-AzureRmVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VM -ErrorAction Stop
                            Write-Verbose "Successfully created a virtual machine $VMName" -ForegroundColor Green  
                        }
                    }
                    Else
                    {
                       Write-Verbose -ForegroundColor Red "VM Size $VMSizeName does nott exist."
                    }
                    
                 }
             }
              Else{
                 Write-Verbose -ForegroundColor Red "VM images does not exist."
             }
          }
       }
      
    }
    Catch
    {
          Write-Verbose "Create a virtual machine $VMName failed" $_.Exception.Message
          return $false
    }
}

$Global:Verbosepreference = 'continue'
# Variables for common values
$resourceGroup = "myResourceGroup"
$location = "australiaeast"
$vmName = "myVM"

$AZureModuleExists = Get-Module -ListAvailable | where{$_.Name -eq 'AzureRM'}
if(!($AZureModuleExists))
{
	Install-Module AzureRM -AllowClobber -Force
}
	
if(!(Get-Module -Name AzureRM))
{
    Write-Verbose 'Importing Azure RM module...'
	Import-Module AzureRM
}
$ProfilePath = "D:\git\Profile.json"
Save-AzureRmProfile -Profile (Add-AzureRmAccount) -Path $ProfilePath

function GetUserCredential
{
    Write-Verbose "Getting the credential for the user"
    if(!($Cred))
    {
        $Cred = Get-Credential
        return $Cred 
    }
    else
    {
        return $Cred
    }
}

New-AzureVMByRM  -ResourceGroupName $resourceGroup -LocationName $location -VMName $vmName -RmProfilePath $ProfilePath -PsCred (GetUserCredential)
