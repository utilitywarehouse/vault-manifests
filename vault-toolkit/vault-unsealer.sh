#!/bin/sh

# This script unseals the local vault instance with the ${UNSEAL_KEY}

set -e

vault_addr="${VAULT_ADDR:-"https://127.0.0.1:8200"}";

# Sleep if no unseal key provided
if [ -z "${UNSEAL_KEY}" ]; then
  echo "No unseal key provided, going to sleep";
  while true; do sleep 86400; done
fi

# Wait for vault api and sleep if not initialized
until [ "${initialized}" = "true" -o "${initialized}" = "false" ]; do
  initialized=$(curl -Ss -f --cacert "${VAULT_CACERT}" "${vault_addr}/v1/sys/init" | jq '.initialized');
  echo 'leader not ready, sleeping for 3 seconds';
  sleep 3;
done;

if [ "${initialized}" = "false" ];then
  echo "vault is not initialized, going to sleep";
  while true; do sleep 86400; done
fi

# Unseal and sleep
echo 'Attempting to unseal vault'
curl -Ss -f --cacert "${VAULT_CACERT}" "${vault_addr}/v1/sys/unseal" \
  -XPUT -d '{"key":"'"${UNSEAL_KEY}"'"}' \
  | jq .sealed \
  | grep -q "^false$";
echo "vault unsealed, going to sleep";
while true; do sleep 86400; done
