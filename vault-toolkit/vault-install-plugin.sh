#!/bin/bash

# This script registers installed vault-plugin-secrets-github plugin.

set -o nounset
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

# move plugin binary to plugin directory 
mv /usr/local/bin/vault-plugin-secrets-github /vault/plugins/vault-plugin-secrets-github

sleep inf

# add plugin to the catalog
curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}v1/sys/plugins/catalog/secret/github" \
  --request POST                            \
  --data '{
    "command": "vault-plugin-secrets-github",
    "sha256": "'"${SECRETS_GH_PLUGIN_SHA}"'",
    "version": "'"${SECRETS_GH_PLUGIN_VERSION}"'"
  }'