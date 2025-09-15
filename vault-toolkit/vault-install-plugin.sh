#!/bin/bash

# This script registers installed vault-plugin-secrets-github plugin.

set -o errexit
set -o pipefail

# Validations and defaults
: "${VAULT_CACERT:?Need to set VAULT_CACERT}"
local_addr="${VAULT_LOCAL_ADDR:-"https://127.0.0.1:8200"}"

# Wait until vault answers the initialization check
until curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" | jq -e '.initialized == true or .initialized == false' >/dev/null 2>&1; do
  echo "vault not ready, sleeping for 3 seconds"
  sleep 3
done

if curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" | jq -e '.initialized == false' >/dev/null 2>&1; then
  echo "vault is not initialized, going to sleep";
  sleep 3
fi

# move plugin binary to plugin directory 
mv /usr/local/bin/vault-plugin-secrets-github /vault/plugins/vault-plugin-secrets-github

echo "sha256sum: $(sha256sum /vault/plugins/vault-plugin-secrets-github)"

sleep 1

# VAULT_TOKEN is required to register plugin binary
until [ -n "$VAULT_TOKEN" ]; do
    echo "VAULT_TOKEN to be set, going to sleep"
    sleep 3
done

# SECRETS_GH_PLUGIN_VERSION and SECRETS_GH_PLUGIN_SHA env value comes from image 
# which is added at build time 
echo "registering secret github plugin version: ${SECRETS_GH_PLUGIN_VERSION} sha256: ${SECRETS_GH_PLUGIN_SHA}"

curl -Ss --fail-with-body --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/plugins/catalog/secret/github" \
  --request POST                            \
  --header "X-Vault-Token: ${VAULT_TOKEN}"  \
  --data '{
    "command": "vault-plugin-secrets-github",
    "sha256": "'"${SECRETS_GH_PLUGIN_SHA}"'",
    "version": "'"${SECRETS_GH_PLUGIN_VERSION}"'"
  }'

echo "pining the new secret github plugin version for the current cluster"

curl -Ss --fail-with-body --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/plugins/pins/secret/github" \
  --request POST                            \
  --header "X-Vault-Token: ${VAULT_TOKEN}"  \
  --data '{"version":"'"${SECRETS_GH_PLUGIN_VERSION}"'"}'
 
echo "reloading secret github plugin"

curl -Ss --fail-with-body --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/plugins/reload/secret/github" \
  --request POST                            \
  --header "X-Vault-Token: ${VAULT_TOKEN}"

sleep inf