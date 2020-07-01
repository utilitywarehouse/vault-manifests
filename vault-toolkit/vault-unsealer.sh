#!/bin/bash

# This script unseals the local vault instance with the ${UNSEAL_KEY}

set -o nounset
set -o errexit
set -o pipefail

vault_addr="${VAULT_ADDR:-https://127.0.0.1:8200}";
UNSEAL_KEY="${UNSEAL_KEY:-}"

# Sleep if no unseal key provided
if [ -z "${UNSEAL_KEY}" ]; then
  echo "No unseal key provided, going to sleep";
  while true; do sleep 86400; done
fi

# Wait until vault answers the initialization check
until curl -Ss -f --cacert "${VAULT_CACERT}" "${vault_addr}/v1/sys/init" | jq -e '.initialized == true or .initialized == false' >/dev/null 2>&1; do
  echo "vault not ready, sleeping for 3 seconds"
  sleep 3
done

if curl -Ss -f --cacert "${VAULT_CACERT}" "${vault_addr}/v1/sys/init" | jq -e '.initialized == false' >/dev/null 2>&1; then
  echo "vault is not initialized, going to sleep";
  while true; do sleep 86400; done
fi

# Unseal and sleep
echo 'Attempting to unseal vault'
curl -Ss -f --cacert "${VAULT_CACERT}" "${vault_addr}/v1/sys/unseal" \
  -XPUT -d '{"key":"'"${UNSEAL_KEY}"'"}' \
  | jq -e -r '."sealed" == false'
echo "vault unsealed, going to sleep";
while true; do sleep 86400; done
