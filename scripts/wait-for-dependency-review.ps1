$Headers = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept        = "application/vnd.github+json"
}

$Branch = $env:CI_COMMIT_REF_NAME

Write-Host "Waiting for Dependency Review"

for ($i = 1; $i -le 30; $i++) {

    $uri = "https://api.github.com/repos/$env:GITHUB_OWNER/$env:GITHUB_REPO/actions/workflows/dependency-review.yml/runs?branch=$Branch&per_page=1"

    $Runs = Invoke-RestMethod -Uri $uri -Headers $Headers

    if ($Runs.workflow_runs.Count -eq 0) {
        Start-Sleep -Seconds 10
        continue
    }

    $Latest = $Runs.workflow_runs[0]

    Write-Host "Status: $($Latest.status)"
    Write-Host "Conclusion: $($Latest.conclusion)"

    if ($Latest.status -eq "completed") {
        if ($Latest.conclusion -eq "success") {
            exit 0
        }

        throw "Dependency Review Failed"
    }

    Start-Sleep -Seconds 15
}

throw "Dependency Review Timeout"
``