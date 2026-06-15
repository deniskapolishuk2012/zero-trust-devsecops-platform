"""Minimal demo workload for the Zero Trust platform.

Exists to prove the pod-identity chain end to end: it never sees a connection
string or API key. `DefaultAzureCredential` picks up the projected ServiceAccount
token (mounted by the Azure Workload Identity webhook), exchanges it for an Entra
ID token via the federated credential in modules/workload-identity, and that
token carries exactly one permission: Key Vault Secrets User (read-only) on the
one vault this namespace is scoped to.
"""
import os

from azure.identity import DefaultAzureCredential
from azure.keyvault.secrets import SecretClient
from flask import Flask, jsonify

app = Flask(__name__)

VAULT_URI = os.environ.get("AZURE_KEY_VAULT_URI")
SECRET_NAME = os.environ.get("AZURE_KEY_VAULT_SECRET_NAME", "demo-secret")

_credential = DefaultAzureCredential()
_client = SecretClient(vault_url=VAULT_URI, credential=_credential) if VAULT_URI else None


@app.get("/healthz")
def healthz():
    return jsonify(status="ok"), 200


@app.get("/")
def read_secret():
    if _client is None:
        return jsonify(error="AZURE_KEY_VAULT_URI is not set"), 500

    try:
        secret = _client.get_secret(SECRET_NAME)
    except Exception as exc:  # surfaced to the caller for the demo; not a generic catch-and-hide
        return jsonify(error=f"could not read secret '{SECRET_NAME}': {exc}"), 502

    return jsonify(
        secret_name=secret.name,
        secret_version=secret.properties.version,
        # Never echo the value in a real service — this demo only proves *access*, not the value
        retrieved="yes",
    ), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
