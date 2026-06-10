$Headers = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept = "application/vnd.github+json"
}

$Branch = $env:CI_COMMIT_REF_NAME

Write-Host "Waiting for CodeQL workflow..."

for($i=1;$i -le 30;$i++)
{
    Write-Host "Attempt $i"

    $Runs = Invoke-RestMethod `
      -Uri "https://api.github.com/repos/$env:GITHUB_OWNER/$env:GITHUB_REPO/actions/workflows/codeql.yml/runs?branch=$Branch&per_page=1" `
      -Headers $Headers

    if($Runs.workflow_runs.Count -eq 0)
    {
        Write-Host "No workflow found yet"

        Start-Sleep 10

        continue
    }

    $Latest = $Runs.workflow_runs[0]

    Write-Host "Status: $($Latest.status)"
    Write-Host "Conclusion: $($Latest.conclusion)"

    if($Latest.status -eq "completed")
    {
        Write-Host "CodeQL completed"

        exit 0
    }

    Start-Sleep 15
}

throw "CodeQL workflow timeout"