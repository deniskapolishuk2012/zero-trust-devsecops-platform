<#
.SYNOPSIS
    Tears down everything created by Start-DemoEnvironment.ps1.

.DESCRIPTION
    Runs `terraform destroy` from the terraform/ directory. Interactive approval
    by default — pass -AutoApprove only if you're sure you've finished taking
    screenshots (see docs/DEMO_CHECKLIST.md).

    A few resources bill by the calendar day regardless of how long they ran
    (ACR Premium, Defender), so destroying promptly doesn't get those dollars
    back for *today*, but it stops everything else (AKS nodes, Load Balancer,
    Log Analytics ingestion) from continuing to accrue.
#>

[CmdletBinding()]
param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$terraformDir = Join-Path $repoRoot "terraform"

if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    throw "terraform not found on PATH."
}

Push-Location $terraformDir
try {
    Write-Host "==> terraform destroy" -ForegroundColor Cyan
    if ($AutoApprove) {
        terraform destroy -auto-approve
    }
    else {
        terraform destroy
    }
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done. Double-check in the portal that rg-platform-ztp and rg-security-ztp are gone" -ForegroundColor Green
Write-Host "(the CanNotDelete locks on those RGs are removed by Terraform as part of destroy," -ForegroundColor Green
Write-Host "but if destroy was interrupted partway through, the locks may need manual removal)." -ForegroundColor Green
