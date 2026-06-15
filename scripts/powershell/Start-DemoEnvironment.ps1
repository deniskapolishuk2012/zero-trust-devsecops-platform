<#
.SYNOPSIS
    Stands up the full stack, wires up kubectl, fires the Sprint 7 trigger, and
    prints a screenshot checklist — designed for a "create -> screenshot -> destroy"
    cycle that costs a few dollars instead of leaving the trial running 24/7.

.DESCRIPTION
    Order of operations:
      1. terraform apply (interactive approval unless -AutoApprove)
      2. az aks get-credentials + kubelogin convert (via Get-AksCredentials.ps1)
      3. Apply demo/workload-identity-demo/{namespace,service-account}.yaml
      4. Apply demo/privileged-pod-attempt.yaml (expected to be denied by Kyverno —
         the denial output IS the first screenshot)
      5. Print docs/DEMO_CHECKLIST.md as an ordered to-do list with portal links

    When you're done capturing screenshots, run Stop-DemoEnvironment.ps1 to tear
    everything down. Don't leave this running longer than you need —
    see docs/DEMO_CHECKLIST.md for what each step proves and roughly how long
    Sentinel takes to surface the incident.

.NOTES
    Requires: terraform, az (logged in), kubectl, kubelogin
#>

[CmdletBinding()]
param(
    [switch]$AutoApprove
)

$ErrorActionPreference = "Stop"
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$terraformDir = Join-Path $repoRoot "terraform"

foreach ($tool in @("terraform", "az", "kubectl")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not found on PATH."
    }
}

# --- 1. Apply ---
Write-Host "==> terraform apply (this takes ~20-40 min — AKS + node pools + Helm releases)" -ForegroundColor Cyan
Push-Location $terraformDir
try {
    terraform init -input=false
    if ($AutoApprove) {
        terraform apply -auto-approve
    }
    else {
        terraform apply
    }

    $rgPlatform   = terraform output -raw rg_platform_name
    $clusterName  = terraform output -raw aks_cluster_name
    $clientId     = terraform output -raw workload_identity_client_id
    $acrLogin     = terraform output -raw acr_login_server
    $kvUri        = terraform output -raw key_vault_uri
    $sentinelWsId = terraform output -raw sentinel_workspace_id
}
finally {
    Pop-Location
}

# --- 2. kubectl credentials ---
Write-Host "==> Configuring kubectl for $clusterName" -ForegroundColor Cyan
& (Join-Path $PSScriptRoot "Get-AksCredentials.ps1") -ResourceGroup $rgPlatform -ClusterName $clusterName

# --- 3. Apply the legitimate workload-identity demo resources ---
Write-Host "==> Applying workload-identity demo namespace + ServiceAccount" -ForegroundColor Cyan
kubectl apply -f (Join-Path $repoRoot "demo\workload-identity-demo\namespace.yaml")

$saTemplate = Get-Content (Join-Path $repoRoot "demo\workload-identity-demo\service-account.yaml") -Raw
($saTemplate -replace '\$\{WORKLOAD_IDENTITY_CLIENT_ID\}', $clientId) | kubectl apply -f -

# --- 4. Fire the Sprint 7 trigger ---
Write-Host "==> Applying demo/privileged-pod-attempt.yaml (expect this to be DENIED — that's the point)" -ForegroundColor Cyan
Write-Host "--- Screenshot 1: the denial below ---" -ForegroundColor Yellow
kubectl apply -f (Join-Path $repoRoot "demo\privileged-pod-attempt.yaml")

# --- 5. Print the checklist ---
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Environment is up. Follow docs/DEMO_CHECKLIST.md from here."   -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick reference for this run:"
Write-Host "  Resource group     : $rgPlatform"
Write-Host "  AKS cluster        : $clusterName"
Write-Host "  ACR login server   : $acrLogin"
Write-Host "  Key Vault URI      : $kvUri"
Write-Host "  Sentinel workspace : $sentinelWsId"
Write-Host ""
Get-Content (Join-Path $repoRoot "docs\DEMO_CHECKLIST.md")
Write-Host ""
Write-Host "When you're done: .\Stop-DemoEnvironment.ps1" -ForegroundColor Magenta
