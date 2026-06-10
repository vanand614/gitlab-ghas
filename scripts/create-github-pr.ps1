$Headers = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept        = "application/vnd.github+json"
}

$Body = @{
    title = "GitLab MR - $env:CI_COMMIT_REF_NAME"
    head  = $env:CI_COMMIT_REF_NAME
    base  = "main"
    body  = "Automatically created from GitLab Merge Request"
} | ConvertTo-Json

$Uri = "https://api.github.com/repos/$env:GITHUB_OWNER/$env:GITHUB_REPO/pulls"

try {
    $Response = Invoke-RestMethod `
        -Uri $Uri `
        -Method Post `
        -Headers $Headers `
        -Body $Body `
        -ContentType "application/json"

    Write-Host "PR Created:"
    Write-Host $Response.html_url

    New-Item -ItemType Directory -Path reports -Force

    $Response.number | Out-File reports/pr-number.txt
}

catch {
    Write-Host "Pull Request may already exist"

    Write-Host $_.Exception.Message
}