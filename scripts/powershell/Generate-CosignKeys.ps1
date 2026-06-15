<#
.SYNOPSIS
    Generates a Cosign key pair for signing container images (Sprint 3 / 4).

.DESCRIPTION
    The private key + password are stored as GitHub Actions secrets
    (COSIGN_PRIVATE_KEY, COSIGN_PASSWORD) and never committed. The public key
    is what feeds Terraform's `cosign_public_key` variable, which Kyverno's
    verify-image-signatures ClusterPolicy (modules/kyverno) checks against —
    only images signed with the matching private key are allowed to run.

.NOTES
    Requires the `cosign` CLI: https://docs.sigstore.dev/cosign/system_config/installation/
    Run once per environment. Re-running overwrites local cosign.key / cosign.pub —
    back them up (or rather, the secrets they're stored in) before rotating.
#>

[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot "..\..\.cosign")
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command cosign -ErrorAction SilentlyContinue)) {
    throw "cosign CLI not found. Install it first: https://docs.sigstore.dev/cosign/system_config/installation/"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
Push-Location $OutputDirectory
try {
    if (Test-Path "cosign.key") {
        Write-Warning "cosign.key already exists in $OutputDirectory — refusing to overwrite. Remove it manually to rotate."
        return
    }

    Write-Host "Generating Cosign key pair (you'll be prompted for a password — store it as the COSIGN_PASSWORD secret)..." -ForegroundColor Cyan
    cosign generate-key-pair

    Write-Host ""
    Write-Host "Done. Next steps:" -ForegroundColor Green
    Write-Host "  1. gh secret set COSIGN_PRIVATE_KEY < `"$OutputDirectory\cosign.key`""
    Write-Host "  2. gh secret set COSIGN_PASSWORD              # paste the password you just chose"
    Write-Host "  3. Copy cosign.pub into terraform.tfvars as cosign_public_key, e.g.:"
    Write-Host "       cosign_public_key = <<-EOT"
    Write-Host "       $(Get-Content "$OutputDirectory\cosign.pub" -Raw)"
    Write-Host "       EOT"
    Write-Host ""
    Write-Warning "Do NOT commit cosign.key. Add '.cosign/' to .gitignore (already done if you used this script's default output dir)."
}
finally {
    Pop-Location
}
