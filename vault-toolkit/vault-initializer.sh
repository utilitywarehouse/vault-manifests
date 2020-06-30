#!/bin/sh

# This script initializes the local vault.

set -e

# Validations and defaults
: ${VAULT_CACERT:?"Need to set VAULT_CACERT"}
local_addr="${VAULT_LOCAL_ADDR:-"https://127.0.0.1:8200"}"
vault_addr="${VAULT_ADDR:-"https://vault:8200"}"

# Wait until vault answers the initialization check
until curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" | jq -e '.initialized == true or .initialized == false' >/dev/null 2>&1; do
  echo "vault not ready, sleeping for 3 seconds"
  sleep 3
done

if curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" | jq -e '.initialized == true' >/dev/null 2>&1; then
  echo "vault is already initialized, going to sleep"
  while true; do sleep 86400; done
fi

# If there's no current leader and this is the first replica then initialize
# the cluster, otherwise join the current leader
leader_addr=$(curl -Ss -f --cacert "${VAULT_CACERT}" "${vault_addr}/v1/sys/leader" | jq -r '.leader_address')
if [ -z "${leader_addr}" ]; then
  if [ "${HOSTNAME: -1}" = "0" ]; then
    # Initialize vault and update secret
    init=$(curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/init" \
      -XPUT -d '{"secret_shares":1,"secret_threshold": 1}')
    token=$(echo "${init}" | jq -r '.root_token')
    unseal_key=$(echo "${init}" | jq -r '.keys[0]')
    kubectl patch secret vault -p '{"stringData":{"unseal-key":"'"${unseal_key}"'","root-token":"'"${token}"'"}}'
    echo "vault initialized"
  else 
    echo "Can't find a leader to join"
    exit 1
  fi
else
  # join the leader
  leader_ca_cert=$(awk 'NF {printf "%s\\n",$0;}' "${VAULT_CACERT}")
  curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/storage/raft/join" -XPUT \
    -d '{
      "leader_api_addr":"'"${leader_addr}"'",
      "leader_ca_cert":"'"${leader_ca_cert}"'",
      "retry":true
    }'
  echo "joined leader: ${leader_addr}"
fi

# Unseal vault
echo "unsealing vault"
if [ -z "${unseal_key}" ]; then
  unseal_key=$(kubectl get secret vault -o jsonpath='{.data.unseal-key}' | base64 -d)
fi
curl -Ss -f --cacert "${VAULT_CACERT}" "${local_addr}/v1/sys/unseal" -XPUT -d '{"key":"'"${unseal_key}"'"}'
echo "vault unsealed"

echo "initialization completed, going to sleep"
while true; do sleep 86400; done
