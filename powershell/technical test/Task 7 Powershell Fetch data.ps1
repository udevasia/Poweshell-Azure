$VerbosePreference = 'continue'

$scores =0

#Fetch data from https://resonatetest.azurewebsites.net/data 
$httpOuput = Invoke-RestMethod https://resonatetest.azurewebsites.net/data

#Display average of all scores
$httpOuput |%{write verbose " --------------------------------------" $_`
        $scores += $_.score
    }
$AverageScore = [decimal]($scores) / [decimal]($httpOuput.Length)

Write-Verbose "Average of all scores is: $AverageScore"


#Displays results for id: 54,57,77,98 and prompts to add new JSON object named CallBackFeedback. Prompt the user for the value of this new field.
[PSCustomObject]$filteredData=''
[PSCustomObject]$newFilteredData=''
foreach($data in $httpOuput){

    if($data.id -in @('54','57','77','98')){             
       $filteredData += $data
       $userIP = Read-Host -Prompt "enter value for 'CallBackFeedback' "
       Add-Member -InputObject $data -MemberType NoteProperty -Name "CallBackFeedback" -Value $userIP
       $newFilteredData += $data
    }
}

 Write-Verbose "result for ids  '54','57','77','98'" 
 $filteredData
Write-Verbose "Output after adding new node"
$newFilteredData