# =====================================================
# GITHUB SECURITY VALIDATION SCRIPT
# =====================================================

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$githubToken = $env:GITHUB_TOKEN
$repoOwner   = $env:GITHUB_OWNER
$repoName    = $env:GITHUB_REPO

Write-Host ""
Write-Host "GitHub Owner: $repoOwner"
Write-Host "GitHub Repo: $repoName"
Write-Host "GitHub Token Exists: $($githubToken -ne $null)"

# =====================================================
# HEADERS
# =====================================================

$headers = @{
    Authorization = "Bearer $githubToken"
    Accept        = "application/vnd.github+json"
    "User-Agent"  = "AzureDevOpsPipeline"
}

Write-Host ""
Write-Host "======================================"
Write-Host "GITHUB SECURITY VALIDATION"
Write-Host "======================================"

# =====================================================
# LATEST CODEQL WORKFLOW RUN
# =====================================================

$branchName = $env:CI_COMMIT_REF_NAME

Write-Host ""
Write-Host "Current Branch:"
Write-Host $branchName

$workflowUri = "https://api.github.com/repos/$repoOwner/$repoName/actions/workflows/codeql.yml/runs?branch=$branchName&per_page=1"

Write-Host ""
Write-Host "Latest Workflow URI:"
Write-Host $workflowUri

try
{
    $workflowResponse = Invoke-RestMethod `
        -Uri $workflowUri `
        -Headers $headers `
        -Method GET

    $latestWorkflowRun = $workflowResponse.workflow_runs[0]

    $latestWorkflowSha = $latestWorkflowRun.head_sha

    Write-Host ""
    Write-Host "Workflow Branch:"
    Write-Host $branchName

    Write-Host ""
    Write-Host "Latest Workflow Commit:"
    Write-Host $latestWorkflowSha
}
catch
{
    Write-Host ""
    Write-Host "Unable to retrieve latest workflow run"

    exit 1
}

# =====================================================
# CODEQL ALERTS
# =====================================================
 
$codeqlUri = "https://api.github.com/repos/$repoOwner/$repoName/code-scanning/alerts"
 
Write-Host ""
Write-Host "CodeQL URI:"
Write-Host $codeqlUri
 
try
{
    Write-Host ""
    Write-Host "Checking CodeQL Alerts..."
 
    $response = Invoke-WebRequest `
        -Uri $codeqlUri `
        -Headers $headers `
        -Method GET `
        -UseBasicParsing
 
    Write-Host ""
    Write-Host "HTTP Status:"
    Write-Host $response.StatusCode
 
    Write-Host ""
    Write-Host "===== RAW CODEQL RESPONSE ====="
    Write-Host $response.Content
    Write-Host "==============================="
 
    $codeqlAlerts = $response.Content | ConvertFrom-Json
 
    Write-Host ""
    Write-Host "Object Type:"
    Write-Host $codeqlAlerts.GetType().FullName
 
    foreach ($alert in @($codeqlAlerts))
    {
        Write-Host ""
        Write-Host "Alert State : $($alert.state)"
 
        if ($alert.rule)
        {
            Write-Host "Alert Rule  : $($alert.rule.id)"
        }
    }
 
    $openCodeQLAlerts = @(
    $codeqlAlerts | Where-Object {

        $_.state -eq "open" -and
        $_.most_recent_instance.commit_sha -eq $latestWorkflowSha

    }
    )
 
    $openCount = $openCodeQLAlerts.Count
 
    Write-Host ""
    Write-Host "Latest Workflow SHA:"
    Write-Host $latestWorkflowSha

    Write-Host "Open CodeQL Alerts Matching Latest Scan: $openCount"
}
catch
{
    if ($_.Exception.Response.StatusCode.value__ -eq 404)
    {
        Write-Host ""
        Write-Host "No CodeQL alerts found."
 
        $openCount = 0
    }
    else
    {
        Write-Host ""
        Write-Host "CODEQL API ERROR"
 
        Write-Host $_.Exception.Message
 
        exit 1
    }
}
# =====================================================
# DEPENDABOT ALERTS
# =====================================================

$dependabotUri = "https://api.github.com/repos/$repoOwner/$repoName/dependabot/alerts"

Write-Host ""
Write-Host "Dependabot URI:"
Write-Host $dependabotUri

try
{
Write-Host ""
Write-Host "Checking Dependabot Alerts..."

$response = Invoke-WebRequest `
    -Uri $dependabotUri `
    -Headers $headers `
    -Method GET `
    -UseBasicParsing

$dependabotAlerts = $response.Content | ConvertFrom-Json

Write-Host ""
Write-Host "===== DEPENDABOT ALERTS ====="

foreach($alert in @($dependabotAlerts))
{
    Write-Host ""
    Write-Host "Package : $($alert.dependency.package.name)"
    Write-Host "Severity: $($alert.security_advisory.severity)"
    Write-Host "State   : $($alert.state)"
}

# ONLY OPEN ALERTS

$openDependabotAlerts = @(
    $dependabotAlerts | Where-Object {
        $_.state -eq "open"
    }
)

$highAlerts = @(
    $dependabotAlerts | Where-Object {
        $_.state -eq "open" -and
        $_.security_advisory.severity -eq "high"
    }
)

$criticalAlerts = @(
    $dependabotAlerts | Where-Object {
        $_.state -eq "open" -and
        $_.security_advisory.severity -eq "critical"
    }
)

$highOrCriticalAlerts = @(
    $dependabotAlerts | Where-Object {
        $_.state -eq "open" -and (
            $_.security_advisory.severity -eq "high" -or
            $_.security_advisory.severity -eq "critical"
        )
    }
)

Write-Host ""
Write-Host "Open Dependabot Alerts: $($openDependabotAlerts.Count)"

Write-Host ""
Write-Host "High Dependabot Alerts: $($highAlerts.Count)"

Write-Host ""
Write-Host "Critical Dependabot Alerts: $($criticalAlerts.Count)"

Write-Host ""
Write-Host "High/Critical Dependabot Alerts: $($highOrCriticalAlerts.Count)"

}
catch
{
if ($_.Exception.Response.StatusCode.value__ -eq 404)
{
Write-Host ""
Write-Host "No Dependabot alerts found."

    $openDependabotAlerts = @()
    $highAlerts = @()
    $criticalAlerts = @()
    $highOrCriticalAlerts = @()
}
else
{
    Write-Host ""
    Write-Host "DEPENDABOT API ERROR"

    Write-Host $_.Exception.Message

    exit 1
}

}

# =====================================================
# REPORT GENERATION
# =====================================================

New-Item -ItemType Directory -Path reports -Force | Out-Null

$HtmlReport = @"
<html>
<head>
<title>GitHub Security Report</title>

<style>
body {
    font-family: Arial;
    margin: 20px;
}

table {
    border-collapse: collapse;
    width: 100%;
}

th {
    background-color: #4472C4;
    color: white;
    padding: 8px;
    border: 1px solid black;
}

td {
    padding: 8px;
    border: 1px solid black;
}

.high {
    background-color: #FFCCCC;
}

.critical {
    background-color: #FF6666;
}
</style>

</head>

<body>

<h1>GitHub Security Report</h1>

<h2>Summary</h2>

<ul>
<li>Open CodeQL Alerts: $OpenCodeQLAlerts</li>
<li>Open Dependabot Alerts: $OpenDependabotAlerts</li>
<li>High/Critical Dependabot Alerts: $HighCriticalDependabotAlerts</li>
</ul>

<h2>CodeQL Alerts</h2>

<table>

<tr>
<th>Rule</th>
<th>Severity</th>
<th>State</th>
<th>Branch</th>
<th>Commit SHA</th>
<th>Message</th>
<th>File</th>
<th>Alert URL</th>
</tr>
"@

foreach ($Alert in $CodeQLAlerts)
{
    $RuleId = $Alert.rule.id
    $Severity = $Alert.rule.security_severity_level
    $State = $Alert.state

    $Branch = $Alert.most_recent_instance.ref
    $CommitSha = $Alert.most_recent_instance.commit_sha

    $Message = $Alert.most_recent_instance.message.text

    $FilePath = $Alert.most_recent_instance.location.path

    $AlertUrl = $Alert.html_url

    $HtmlReport += @"
<tr>
<td>$RuleId</td>
<td>$Severity</td>
<td>$State</td>
<td>$Branch</td>
<td>$CommitSha</td>
<td>$Message</td>
<td>$FilePath</td>
<td><a href='$AlertUrl'>View Alert</a></td>
</tr>
"@
}

$HtmlReport += @"

</table>

<br/>

<h2>Dependabot Alerts</h2>

<table>

<tr>
<th>Package</th>
<th>Severity</th>
<th>State</th>
<th>Alert URL</th>
</tr>
"@

foreach ($Alert in $DependabotAlerts)
{
    $Package = $Alert.dependency.package.name
    $Severity = $Alert.security_advisory.severity
    $State = $Alert.state
    $AlertUrl = $Alert.html_url

    $HtmlReport += @"
<tr>
<td>$Package</td>
<td>$Severity</td>
<td>$State</td>
<td><a href='$AlertUrl'>View Alert</a></td>
</tr>
"@
}

$HtmlReport += @"

</table>

</body>
</html>
"@

$HtmlReport | Out-File `
    -FilePath "reports/security-report.html" `
    -Encoding utf8

Write-Host "======================================"
Write-Host "REPORT GENERATED"
Write-Host "======================================"
Write-Host "reports/security-report.html"
# =====================================================
# SECURITY GATE
# =====================================================

$securityFailure = $false

Write-Host ""
Write-Host "======================================"
Write-Host "SECURITY GATE EVALUATION"
Write-Host "======================================"

Write-Host "Current Branch: $branchName"
Write-Host "Latest Workflow SHA: $latestWorkflowSha"

Write-Host ""
Write-Host "CodeQL Alerts Matching Latest Scan: $openCount"

Write-Host ""
Write-Host "Open Dependabot Alerts: $($dependabotAlerts.Count)"

Write-Host "High/Critical Dependabot Alerts: $($highOrCriticalAlerts.Count)"

# -----------------------------------------------------
# CODEQL VALIDATION
# -----------------------------------------------------

if ($openCount -gt 0)
{
    Write-Host ""
    Write-Host "======================================"
    Write-Host "CODEQL SECURITY FAILURE"
    Write-Host "======================================"

    $securityFailure = $true
}
else
{
    Write-Host ""
    Write-Host "No CodeQL alerts found for current branch"
}

# -----------------------------------------------------
# DEPENDABOT VALIDATION
# -----------------------------------------------------

if ($highOrCriticalAlerts.Count -gt 0)
{
    Write-Host ""
    Write-Host "======================================"
    Write-Host "DEPENDABOT SECURITY FAILURE"
    Write-Host "======================================"

    foreach($alert in $highOrCriticalAlerts)
    {
        Write-Host ""
        Write-Host "Package : $($alert.dependency.package.name)"
        Write-Host "Severity: $($alert.security_advisory.severity)"
        Write-Host "State   : $($alert.state)"

        if($alert.html_url)
        {
            Write-Host "Alert   : $($alert.html_url)"
        }
    }

    $securityFailure = $true
}
else
{
    Write-Host ""
    Write-Host "No High/Critical Dependabot alerts found"
}

# -----------------------------------------------------
# FINAL DECISION
# -----------------------------------------------------

if ($securityFailure)
{
    Write-Host ""
    Write-Host "======================================"
    Write-Host "SECURITY GATE FAILED"
    Write-Host "======================================"

    exit 1
}

Write-Host ""
Write-Host "======================================"
Write-Host "SECURITY VALIDATION PASSED"
Write-Host "======================================"

exit 0