<#
.SYNOPSIS
    Fetches AKS credentials and converts the kubeconfig for Azure RBAC / kubelogin.

.DESCRIPTION
    The cluster is created with `local_account_disabled = true` (modules/aks) — there
    is no static admin kubeconfig to download. Every `kubectl` session authenticates
    as *you*, through Entra ID, scoped by whatever Azure RBAC role your account (or
    one of var.aks_admin_group_object_ids) holds on the cluster. This script wraps
    the two-step `az aks get-credentials` + `kubelogin convert-kubeconfig` dance so
    you don't have to remember the flags every time the trial subscription resets.

.NOTES
    Requires: az CLI (logged in: az login), kubectl, kubelogin
    Install kubelogin if missing:  az aks install-cli
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$ClusterName
)

$ErrorActionPreference = "Stop"

foreach ($tool in @("az", "kubectl", "kubelogin")) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "$tool not found on PATH. Install it before running this script (kubelogin: 'az aks install-cli')."
    }
}

Write-Host "Fetching credentials for $ClusterName in $ResourceGroup..." -ForegroundColor Cyan
az aks get-credentials --resource-group $ResourceGroup --name $ClusterName --overwrite-existing

Write-Host "Converting kubeconfig to use kubelogin (interactive Entra ID login on first use)..." -ForegroundColor Cyan
kubelogin convert-kubeconfig -l azurecli

Write-Host ""
Write-Host "Ready. Try:  kubectl get nodes" -ForegroundColor Green
Write-Host "If you get 'Forbidden', your account isn't in var.aks_admin_group_object_ids — add its Entra group's object ID and re-apply."
