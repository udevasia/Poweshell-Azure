
Import-MOdule Azure

$VerbosePreference = 'continue'

function GetCredentialForADUser
{
    Write-Verbose "Getting the credential for the user"
    if($Cred -eq $null)
    {
        $PSCredential = Get-Credential
        return $PSCredential 
    }
    else
    {
        return $Cred
    }
}


function Get-CredentialsForSubscription {
[CmdletBinding()]
param 
(
	[Parameter(Position=0,Mandatory=$true)]
	[string] $VMName,
    [Parameter(Position=1,Mandatory=$true)]
	[string] $Location,
    [Parameter(Position=2,Mandatory=$true)]
	[string] $ADDomain,
    [Parameter(Position=3,Mandatory=$true)]
	[string] $Subscriptionname 

)

    $Subscriptionid = Get-AzureRmSubscription -SubscriptionName $Subscriptionname
    Write-Verbose "Get the AD credential for the subscription $Subscriptionname"

    $cred = GetCredentialForADUser 
    

}