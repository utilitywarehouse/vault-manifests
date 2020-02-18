#!/bin/sh

# This script runs on the first replica in the cluster, initializing each replica and joining
# them together into a raft cluster.

# Only run the initializer in the first replica
replica="${HOSTNAME: -1}";
if [ "${replica}" != "0" ];then
  echo "this replica is not responsible for initialization, going to sleep";
  while true; do sleep 86400; done
fi

# Validations and defaults
: ${VAULT_CACERT:?"Need to set VAULT_CACERT"};
vault_name="${VAULT_ADDR:-"vault"}";
leader_addr="https://${vault_name}-0.${vault_name}-cluster:8200";
replicas="${VAULT_REPLICAS:-"3"}";

# Wait until vault answers the initialization check
until [ "${initialized}" = "true" -o "${initialized}" = "false" ]; do
  initialized=$(curl -s --cacert "${VAULT_CACERT}" "${leader_addr}/v1/sys/init" | jq '.initialized');
  echo 'leader not ready, sleeping for 3 seconds';
  sleep 3;
done;

if [ "${initialized}" = "true" ];then
  echo "vault is already initialized, going to sleep";
  while true; do sleep 86400; done
fi

# Initialize vault and update secret
init=$(curl -s --cacert "${VAULT_CACERT}" "${leader_addr}/v1/sys/init" \
  -XPUT -d '{"secret_shares":1,"secret_threshold": 1}');
token=$(echo "${init}" | jq -r '.root_token');
unseal_key=$(echo "${init}" | jq -r '.keys[0]');
kubectl patch secret vault -p '{"stringData":{"unseal-key":"'"${unseal_key}"'","root-token":"'"${token}"'"}}'
echo "vault initialized"

# Unseal leader
curl -s --cacert "${VAULT_CACERT}" "${leader_addr}/v1/sys/unseal" -XPUT -d '{"key":"'"${unseal_key}"'"}'
echo "leader unsealed"

# Wait for replicas api and join and unseal them
join_replica()
{
  replica_number="$1";
  replica_name="${vault_name}-${replica_number}";
  replica_addr="https://${replica_name}.${vault_name}-cluster:8200";
  until curl -s --cacert "${VAULT_CACERT}" "${replica_addr}/v1/sys/init"; do
    echo "${replica_name} not ready, sleeping for 3 seconds";
    sleep 3;
  done;

  leader_ca_cert=$(awk 'NF {printf "%s\\n",$0;}' "${VAULT_CACERT}")
  curl -s --cacert "${VAULT_CACERT}" "${replica_addr}/v1/sys/storage/raft/join" -XPUT \
    -d '{
      "leader_api_addr":"'"${leader_addr}"'",
      "leader_ca_cert":"'"${leader_ca_cert}"'"
    }'
  curl -s --cacert "${VAULT_CACERT}" "${replica_addr}/v1/sys/unseal" -XPUT -d '{"key":"'"${unseal_key}"'"}'
  echo "${replica_name} joined and initialized"
}
for i in $(seq $(($replicas - 1))) ; do
  join_replica $i;
done
