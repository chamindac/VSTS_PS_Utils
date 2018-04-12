
param(
    [Parameter(Mandatory=$true)]
    [string] $token,
    [Parameter(Mandatory=$true)]
    [string] $fromDate,
    [Parameter(Mandatory=$true)]
    [string] $collectionUri
)




$User=""

# Base64-encodes the Personal Access Token (PAT) appropriately
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$token)));
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)};


$reportName = 'ActiveTeamProjects.html'

$report = '<!DOCTYPE html><html><head>
<style> 
li {font-family: Arial; font-size: 10pt;} 
</style>
</head><body>'

$report = $report + '<h2><u><center>' + 'Active Team Project List' + '</center></u></h2>'
$report = $report + '<h4><u><center>' + 'for ' + $collectionUri + ' from ' + $fromDate + '</center></u></h4><ul>'
$report | Out-File -Force $reportName
$report = '';



$top=100;
$skip=0;

while($true)
{

    
    $Uri = $collectionUri + '/_apis/projects?$top='+ $top + '&$skip='+ $skip + '&api-version=1.0'

    $projects = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

    $skip+=$top;

    if($projects.count -le 0)
        {
            break;
        }
	
	foreach($project in $projects.value) {
        $project

        $sourceControlPath = ("$/" + $project.name)

        # TFVC
        # Get Changesets
        $Uri = $collectionUri + '/_apis/tfvc/changesets?$top=1&orderby=id%20desc&searchCriteria.itemPath=' + $sourceControlPath + '&searchCriteria.fromDate=' + $fromDate + '&api-version=1.0'

        $changesHistory = $null;

        try{

            $changesHistory = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

            if ($changesHistory.count -ge 1)
            {

                $changesHistoryitem = $changesHistory.value.Item(0);

            
                $report = $report + '<li> <a target="_blank" href="' + $collectionUri +  '/'+ $project.Name + '" >' +  $project.Name + '</a> --> <a target="_blank" href="' + $collectionUri +  '/'+ $project.Name + '/_versionControl/changesets" >' +  $changesHistoryitem.changesetId + '</a> '+ $changesHistoryitem.createdDate + ' ' + $changesHistoryitem.checkedInBy.displayName +' -- ' + $changesHistoryitem.comment + '--</li>'     
                $report | Out-File -Append -Force $reportName
                $report = '';
            }
        }
        catch{
            Write-Warning $_.ErrorDetails.Message
        }

        #Git

        $Uri = $collectionUri + '/' + $project.name +'/_apis/git/repositories?api-version=1.0'
        $gitRepos = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

         if ($gitRepos.count -ge 1)
         {
            foreach($gitRepo in  $gitRepos.value)
            {
                #find commits
                $Uri = $gitRepo.url + '/commits?$top=1&fromDate=' + $fromDate + '&api-version=1.0'
                $commits = $null;

                $commits = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

                if($commits.count -ge 1)
                {
                    $commitItem = $commits.value.Item(0);

            
                    $report = $report + '<li> <a target="_blank" href="' + $collectionUri +  '/'+ $project.Name + '" >' +  $project.Name + '</a> --> <a target="_blank" href="' + $commitItem.remoteUrl + '" >' +  $commitItem.commitId + '</a> '+ $commitItem.committer.date + ' ' + $commitItem.committer.name +' -- ' + $commitItem.comment + '--</li>'     
                    $report | Out-File -Append -Force $reportName
                    $report = '';
                }

            }
         }

    }

}

$report = $report + '</ul></body></html>'     
$report | Out-File -Append -Force $reportName
$report = '';
	
	



