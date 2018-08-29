
param(
    [Parameter(Mandatory=$true)]
    [string] $token,
    [Parameter(Mandatory=$true)]
    [string] $collectionUri,
    [Parameter(Mandatory=$true)]
    [string] $teamProjectName,
    [string] $repoName = '*'
)


$User=""

# Base64-encodes the Personal Access Token (PAT) appropriately
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $User,$token)));
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)};


$reportName = 'RepoBuildDefs.html'

$report = '<!DOCTYPE html><html><head>
<style> 
li {font-family: Arial; font-size: 10pt;} 
</style>
</head><body>'

$report = $report + '<h2><u><center>' + 'Repo Build Definitions' + '</center></u></h2>'
$report = $report + '<h4><u><center>' + 'for ' + $collectionUri + '\ ' + $teamProjectName + '</center></u></h4><ul>'
$report | Out-File -Force $reportName
$report = '';

# Verifying build defnitions for tfvc regardless of repo name
$Uri = $collectionUri + '/' + $teamProjectName +'/_apis/build/definitions?repositoryType=TfsVersionControl&repositoryId=$/&includeAllProperties=true&api-version=4.1'
$tfvcBuidDefs = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

$report = $report + '<li> <a target="_blank" href="' + $collectionUri + '/' + $teamProjectName  + '/_versioncontrol" >' +  'TFVC Repo $/' + $teamProjectName + '</a><ul>' 
if ($tfvcBuidDefs.count -le 0)
{
    # Could be tfvc repo not found or no build found for tfvc repo
    $report = $report + '<li style="color:red" > No build defnitions found or TFVC Repo does not exist.</li>'
}
else
{
    foreach($buildDef in $tfvcBuidDefs.value) # print all build defs
    {
        $buildUrl = $collectionUri + '/' + $teamProjectName + '/_build?definitionId=' + $buildDef.id
        $report = $report + '<li style="color:green" > <a target="_blank" href="' + $buildUrl + '" >' +  $buildDef.name + '</a> Default Branch to Build: '+ $buildDef.repository.defaultBranch + '</li>'
    }
}

$report = $report + '</ul></li></br>'     
$report | Out-File -Append -Force $reportName
$report = '';
#************TFVC  Done**************

#************** Git Repos **************

$Uri = $collectionUri + '/' + $teamProjectName +'/_apis/git/repositories?api-version=4.1'
$gitRepos = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

# Filter git reposs for given name
$gitReposFiltered = $gitRepos.value.Where({$_.Name -like $repoName})

if ($gitReposFiltered.count -ge 1)
{
    #------Sorting Git repos by name ----
    [HashTable] $reposHT = @{}

    foreach($gitRepo in  $gitReposFiltered)
    {
       $reposHT.Add($gitRepo.Name,($gitRepo.id,$gitRepo.remoteUrl)) # adding repos to a hashtable allowing to sorting
    }

    $sortedRepos = $reposHT.GetEnumerator()| sort -Property Key
     
    #------Searching for builds in sorted Git repos ----
    foreach($sortedRepo in $sortedRepos)
    {
        $report = $report + '<li> <a target="_blank" href="' + $sortedRepo.value[1] + '" >' +  $sortedRepo.key + '</a><ul>' 

        $Uri = $collectionUri + '/' + $teamProjectName +'/_apis/build/definitions?repositoryType=TfsGit&repositoryId=' +$sortedRepo.value[0] + '&includeAllProperties=true&api-version=4.1'
        $buildDefs = Invoke-RestMethod -Method Get -ContentType application/json -Uri $Uri -Headers $header

        if ($buildDefs.count -le 0) # No build defs
        {
            $report = $report + '<li style="color:red" > No build defnitions found.</li>'
        }
        else # found build defs
        {
            foreach($buildDef in $buildDefs.value)
            {
                $buildUrl = $collectionUri + '/' + $teamProjectName + '/_build?definitionId=' + $buildDef.id
                $report = $report + '<li style="color:green" > <a target="_blank" href="' + $buildUrl + '" >' +  $buildDef.name + '</a> Default Branch to Build: '+ $buildDef.repository.defaultBranch + '</li>'
            }
        }

        $report = $report + '</ul></li></br>'     
        $report | Out-File -Append -Force $reportName
        $report = '';
    }
}

$report = $report + '</ul></body></html>'     
$report | Out-File -Append -Force $reportName
$report = '';