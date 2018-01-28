$VerbosePreference = 'continue'

function Set-InputDataForCSV{
param 
(
	[Parameter(Mandatory=$true)]
	[String] $InputFile,
    [Parameter(Mandatory=$false)]
	[string] $Delimiter=',',
    [Parameter(Mandatory=$false)]
	[string] $OutputPath
)

    if(!$OutputPath){
        $OutputPath = $PSScriptRoot
    }

    if(!(Test-Path $InputFile)){
        Write-Verbose "Error in input file $InputFile"       
    }
    else{
        #read from file
        [xml]$inputData = Get-Content $InputFile
        #export xml as csv
        $inputData.inputdata.ChildNodes | Export-Csv "$OutputPath\output.csv" -NoTypeInformation -Delimiter:$Delimiter -Encoding:UTF8
        return $true
    }
}

function Get-InputDataFromCSV{
param 
(
	[Parameter(Mandatory=$true)]
	[String] $InputFile,
    [Parameter(Mandatory=$false)]
	[string] $Delimiter=','
)
    
    $data = @()

    if(Test-Path $InputFile){
        $content = @{}     
        Import-Csv $InputFile -Delimiter $Delimiter | `
             ForEach-Object {
                $content.Add($_.Email,$_.Time)
            }

        $data += $content
        return $data
        
    }
    else{
        return $false
    }

}

function Send-MyEmail{
Param (
        [Parameter(Mandatory=$true)]
        [String]$SMTPServer,
        [Parameter(Mandatory=$true)]
        [String]$SMTPUsername,
        [Parameter(Mandatory=$true)]
        [Object]$SMTPPassword,
        [Parameter(Mandatory=$true)]
        [String]$MailBody,
        [Parameter(Mandatory=$true)]
        [String]$MailTo
    )

    $SMTPPort = 587
    $EmailCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SMTPUsername,$SMTPPassword
    $MailFrom = "frommail@domain.com"
    $MailSubject = "Scheduled mail"

    Send-MailMessage -SmtpServer $SMTPServer -From $MailFrom -To $MailTo -Subject $MailSubject -Body $MailBody -Port $SMTPPort -Credential $EmailCredential -UseSsl

}
<#
function Get-DetailsFromDB{
param([Parameter(Mandatory=$false)]
        [String]$targetServerName = 'localhost',
        [Parameter(Mandatory=$false)]
        [String]$sqlcommand
        )
try{
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $sqlConnection.ConnectionString = "Server=$targetServerName;Database=master;Trusted_Connection=True;"
    $sqlConnection.open()
	$command = New-Object System.Data.SqlClient.SqlCommand
	$command.CommandType = 1
	$command.Connection = $sqlConnection
    $sqlCommand="SELECT * FROM DEMO.DATA;"
	Write-Verbose "$sqlCommand"
    $command.CommandText = $sqlCommand
	$Reader = $command.ExecuteReader()
    while ($Reader.Read()) {
         $Reader.GetValue($1)
    }
    
}
catch{
	throw $_
	}
finally{
	if ($sqlConnection.State -eq 'Open'){ 
			Write-Verbose "Closing SQL connection"
			$sqlConnection.Close() 
		}
    if (!($Reader.IsClosed)){ 
			    Write-Verbose "Closing data reader"
			    $Reader.Close() 
		    }
	}

}#>

$input = 'D:\resonate solutions\Technical test\input.xml'
$output = 'D:\resonate solutions\Technical test'
$smtpServer = ''

$result = Set-InputDataForCSV -InputFile $input -Delimiter '`' -OutputPath $output

if($result){
    $mailDeliveryDetails = Get-InputDataFromCSV -InputFile "$output\output.csv" -Delimiter '`'
    $smtpServer =  Read-Host -Prompt 'enter the smtp server'
    $smtpUsername = Read-Host -Prompt 'enter the username'
    $smtpPassword = Read-Host -Prompt 'enter the password' -AsSecureString 
    $servername = 'localhost'
    $query = ";WITH CTE AS
            (
            SELECT ID,NUMBER, ROW_NUMBER() OVER (ORDER BY ID) AS ROW FROM DEMO.DATA
            )
            SELECT A.ID,A.NUMBER,B.NUMBER + A.NUMBER AS 'RESULT' FROM CTE A
	            LEFT JOIN CTE B ON A.ROW+1 = B.ROW
            ORDER BY A.ID"
    $messageBody =  Invoke-Sqlcmd -ServerInstance $servername -Database 'master' -Query $query |Select-Object ID,NUMBER, RESULT| ConvertTo-Html | Out-String

    foreach($mailTo in $mailDeliveryDetails.Keys){
    Send-MyEmail -SMTPServer $smtpServer -SMTPUsername  $smtpUsername -SMTPPassword $smtpPassword -MailBody $messageBody -MailTo $mailTo}
    
}