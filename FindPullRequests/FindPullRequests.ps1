param(
    [Parameter(Mandatory=$true)]
    [string] $token,
    [Parameter(Mandatory=$true)]
    [string] $collectionUri,
    [Parameter(Mandatory=$true)]
    [string] $teamProjectName,
    [string []] $prStatuses = @('active'),
    [string] $restAPIversion = '5.0'
)

$reportPath = $PSScriptRoot
$reportName = "PullRequestDetails.html"


$User=""

# Base64-encodes the Personal Access Token (PAT) appropriately
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$token)));
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)};

Function Get-TotalWeekDays {

    <#
    https://powershell.org/2012/07/get-total-number-of-week-days/ 

    .Synopsis
    Get total number of week days
    .Description
    Return the number of days between two dates not counting Saturday
    and Sunday.
    .Parameter Start
    The starting date
    .Parameter End
    The ending date
    .Example
    PS C:\> Get-TotalWeekDays -start 7/1/2012 -end 7/31/2012
    22
    .Inputs
    None
    .Outputs
    Integer
    #>

    [cmdletbinding()]

    Param (
    [Parameter(Position=0,Mandatory=$True,HelpMessage="What is the start date?")]
    [ValidateNotNullorEmpty()]
    [DateTime]$StartDate,
    [Parameter(Position=1,Mandatory=$True,HelpMessage="What is the end date?")]
    [ValidateNotNullorEmpty()]
    [DateTime]$EndDate
    )

    Write-Verbose -message "Starting $($myinvocation.mycommand)"
    Write-Verbose -Message "Calculating number of week days between $StartDate and $EndDate"

    #define a counter
    $i=0
    #test every date between start and end to see if it is a weekend
    for ($d=$StartDate;$d -le $EndDate;$d=$d.AddDays(1)){
      if ($d.DayOfWeek -notmatch "Sunday|Saturday") {
        #if the day of the week is not a Saturday or Sunday
        #increment the counter
        $i++    
      }
      else {
        #verify these are weekend days
        Write-Verbose ("{0} is {1}" -f $d,$d.DayOfWeek)
      }
    } #for

    #write the result to the pipeline
    $i

    Write-Verbose "Ending $($myinvocation.mycommand)"

} 

$tabName = "PRsTable"

#Create Table object
$PRsTable = New-Object system.Data.DataTable “$tabName”

#Define Columns
$colPRId = New-Object system.Data.DataColumn PRId,([string])
$colPRUrl = New-Object system.Data.DataColumn PRUrl,([string])
$colAge = New-Object system.Data.DataColumn Age,([int])
$colRepoName = New-Object system.Data.DataColumn RepoName,([string])
$colReviewers = New-Object system.Data.DataColumn Reviewers,([string])
$colTargetBranchName = New-Object system.Data.DataColumn TargetBranchName,([string])
$colSourceBranchName = New-Object system.Data.DataColumn SourceBranchName,([string])
$colCreatedDate = New-Object system.Data.DataColumn CreatedDate,([datetime])
$colCreatedBy = New-Object system.Data.DataColumn CreatedBy ,([string])
$colClosedDate = New-Object system.Data.DataColumn ClosedDate,([string])


#Add the Columns
$PRsTable.columns.add($colPRId)
$PRsTable.columns.add($colPRUrl)
$PRsTable.columns.add($colAge)
$PRsTable.columns.add($colRepoName)
$PRsTable.columns.add($colReviewers)
$PRsTable.columns.add($colTargetBranchName)
$PRsTable.columns.add($colSourceBranchName)
$PRsTable.columns.add($colCreatedDate)
$PRsTable.columns.add($colCreatedBy)
$PRsTable.columns.add($colClosedDate)


$PRsTable.primarykey = $PRsTable.columns[0];


# HTML Report **************>>>>>>
$reportName = "$reportPath\$reportName"

$report = '<!DOCTYPE html><html><head>
<style> 
li {font-family: Arial; font-size: 10pt;}

table {
    border-collapse: collapse;
}

table, th, td {
    border: 1px solid black;
}

th {
    padding-top: 2px;
    padding-bottom: 2px;
    text-align: left;
    background-color: #0073e6;
    color: white;
}

tr:nth-child(even){background-color: #f2f2f2;}
tr:hover {background-color: #ddd;}


</style>
</head><body>'

$report = $report + '<h2><u><center>' + 'Pull Request Details' + '</center></u></h2>'
$report = $report + '<h4><u><center>' + 'for ' + $collectionUri + $teamProjectName + '</center></u></h4><ul>'
$report | Out-File -Force $reportName
$report = '';
# HTML Report ****************<<<<<<

foreach($prStatus in $prStatuses)
{
    Write-Host '----------------------------------'
    Write-Host ('Processing {0} PRs...' -f $prStatus)
    Write-Host '----------------------------------'
    $prStateCriteria = '&searchCriteria.status=' + $prStatus

    $top=100;
    $skip=0;
    $PRsTable.Clear();
    
    # HTML Report **************>>>>>>
    $report = $report + '<li><strong>' + $prStatus + ' - Pull Requests </strong></br><table><tr><th>PR Id</th><th>Age (Days)</th><th>Repo</th><th>Reviewers</th><th>Target Baranch</th><th>Source Baranch</th><th>Created Date</th><th>Created By</th><th>Closed Date</th></tr>'
    # HTML Report ****************<<<<<<

    while($true)
    {
        $Uri = $collectionUri + '/' + $teamProjectName + '/_apis/git/pullrequests?$top='+ $top + '&$skip='+ $skip + $prStateCriteria + '&api-version=' + $restAPIversion
        $PRs = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

        $skip+=$top;
        
        if($PRs.count -le 0)
        {
            if ($PRsTable.Rows.Count -gt 0)
            {
                $sortedPRs = ($PRsTable |sort Age -Descending | Select-Object PRId, PRUrl, Age, RepoName, Reviewers, TargetBranchName, SourceBranchName, CreatedDate, CreatedBy, ClosedDate)

                foreach($sortedPR in $sortedPRs)
                {
                    # HTML Report **************>>>>>>
                    $report = $report + '<tr><td><a target="_blank" href="' + $sortedPR.PRUrl + '" >' +  $sortedPR.PRId + '</a></td><td>' + $sortedPR.Age + '</td><td>' + $sortedPR.RepoName + '</td><td>' + $sortedPR.Reviewers + '</td><td>' + $sortedPR.TargetBranchName + '</td><td>' + $sortedPR.SourceBranchName + '</td><td>' + $sortedPR.CreatedDate + '</td><td>' + $sortedPR.CreatedBy + '</td><td>' + $sortedPR.ClosedDate + '</td></tr>'
                    # HTML Report ****************<<<<<<
                }

            }

            break;
        }

        # Processing each PR

        foreach($PR in $PRs.value)
        {
            Write-Host ('Processing PR {0} ...' -f $PR.pullRequestId)

            $prReviewers='<ul>';

            foreach($reviewer in $PR.reviewers)
            {
                $reviewStatus='';
                switch ($reviewer.vote) 
                {
                   10  {$reviewStatus= "Approved"; break}
                   5   {$reviewStatus= "Approved with suggestions"; break}
                   -5  {$reviewStatus= "Waiting for the author"; break}
                   -10 {$reviewStatus= "Rejected"; break}
                   0   {$reviewStatus= "Pending"; break}
                   default {$reviewStatus= "Pending"; break}
                }
                $prReviewers = $prReviewers + '<li>' + $reviewer.displayName + ' - ' + $reviewStatus +'</li>';
            }
            $prReviewers = $prReviewers + '</ul>';

            $closedDate = '';
            if ($PR.closedDate -ne $null)
            {
                $closedDate = ([datetime] $PR.closedDate).ToString('M/dd/yyyy HH:mm:ss');
            }

            #Create a row
            $row = $PRsTable.NewRow()

            #Enter data in the row
                        
            $row.PRId = $PR.pullRequestId;
            $row.PRUrl = $collectionUri + '/' + $teamProjectName +'/_git/' + $PR.repository.name + '/pullrequest/' + $PR.pullRequestId;
            $row.Age = (Get-TotalWeekDays -StartDate $PR.creationDate -EndDate ([System.DateTime]::UtcNow))
            $row.RepoName = $PR.repository.name;
            $row.Reviewers = $prReviewers;
            $row.TargetBranchName = ($PR.targetRefName -replace 'refs/heads/','' );
            $row.SourceBranchName = ($PR.sourceRefName -replace 'refs/heads/','' );
            $row.CreatedDate = ([datetime] $PR.creationDate).ToString('M/dd/yyyy HH:mm:ss') 
            $row.CreatedBy = $PR.createdBy.displayName;
            $row.ClosedDate = $closedDate
            
            #Add the row to the table
            $PRsTable.Rows.Add($row);
        }

    }

    # HTML Report **************>>>>>>
    $report = $report + '</table></li></br></br>'
    $report | Out-File -Append -Force $reportName
    $report = '';
    # HTML Report ****************<<<<<<
}


# HTML Report **************>>>>>>
$report = $report + '</ul></body></html>'     
$report | Out-File -Append -Force $reportName
$report = '';
# HTML Report ****************<<<<<<
