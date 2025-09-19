#!/bin/bash

# This script registers vault-plugin-secrets-github plugin.

set -o nounset
set -o errexit
set -o pipefail

# Validations and defaults
: "${VAULT_CACERT:?Need to set VAULT_CACERT}"
local_addr="${VAULT_LOCAL_ADDR:-"https://127.0.0.1:8200"}"

# Wait until vault is ready for registration
until curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" | jq -e '.initialized == true or .initialized == false' >/dev/null 2>&1; do
  echo "vault not ready, sleeping for 3 seconds"
  sleep 3
done

until curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" | jq -e '.initialized == true' >/dev/null 2>&1; do
  echo "vault is not initialized, going to sleep";
  sleep 3
done

until curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/seal-status" | jq -e '.sealed == false' >/dev/null 2>&1; do
  echo "sealed vault detected, going to sleep";
  sleep 3
done

# move plugin binary to plugin directory 
mv /usr/local/bin/vault-plugin-secrets-github /vault/plugins/vault-plugin-secrets-github
echo "sha256sum: $(sha256sum /vault/plugins/vault-plugin-secrets-github)"

# SEC_GITHUB_PLUGIN_VERSION and SEC_GITHUB_PLUGIN_SHA env value are set in image at build time
echo "registering secret github plugin version: ${SEC_GITHUB_PLUGIN_VERSION} sha256: ${SEC_GITHUB_PLUGIN_SHA}"

curl -Ss --fail-with-body --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/plugins/catalog/secret/github" \
  --request POST                            \
  --header "X-Vault-Token: ${VAULT_TOKEN}"  \
  --data '{
    "command": "vault-plugin-secrets-github",
    "sha256": "'"${SEC_GITHUB_PLUGIN_SHA}"'",
    "version": "'"${SEC_GITHUB_PLUGIN_VERSION}"'"
  }'

echo "pinning the new secret github plugin version for the current cluster"

curl -Ss --fail-with-body --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/plugins/pins/secret/github" \
  --request POST                            \
  --header "X-Vault-Token: ${VAULT_TOKEN}"  \
  --data '{"version":"'"${SEC_GITHUB_PLUGIN_VERSION}"'"}'

sleep inf
