#!/bin/sh

set -e

VAULT_TOKEN="${VAULT_TOKEN:?"must be set"}"
VAULT_CACERT="${VAULT_CACERT:-"/etc/tls/ca.crt"}"
VAULT_ADDR="${VAULT_ADDR:-"https://vault:8200"}"
CONFIG_MAP_NAME="${CONFIG_MAP_NAME:-"vault-aws-credentials"}"
AWS_SECRET_BACKEND="${AWS_SECRET_BACKEND:="aws"}"

log()
{
  echo "$(date -I'seconds') ${1}"
}

err()
{
  echo "$(date -I'seconds') ${1}" >&2
}

# init bootstraps the rotation of the IAM user credentials held by vault.
#
# Intended usage:
# $ aws iam create-access-key --user-name <username>
#   <output containing keys>
# $ kubectl --context=<context> -n <namespace> exec -it vault-aws-credentials-rotator-<hash> -- vault-aws-credentials.sh init
#   Access Key ID: <insert key>
#   Secret Access Key: <insert key>
init() {
  # Read access key and secret key from user input
  while [ -z "${access_key_id}" ]; do
    read -p "Access Key ID: " access_key_id
  done
  while [ -z "${secret_access_key}" ]; do
    read -sp "Secret Access Key: " secret_access_key
    echo
  done

  # Retrieve the current config of the aws secrets backend
  aws_config=$(curl -s --cacert "${VAULT_CACERT}" --header "X-Vault-Token: ${VAULT_TOKEN}" \
    "${VAULT_ADDR}/v1/${AWS_SECRET_BACKEND}/config/root" \
    | jq -r .data
  )

  # Merge the new access key and secret key into the current config
  new_aws_config=$(jq -n \
    --argjson data "${aws_config}" \
    --arg a "${access_key_id}" \
    --arg s "${secret_access_key}" \
    '$data + {access_key: $a,secret_key: $s}'
  )

  # Update the secrets backend with the new config
  log "updating the AWS secrets backend config"
  curl -sSf --cacert "${VAULT_CACERT}" --header "X-Vault-Token: ${VAULT_TOKEN}" \
    -XPOST \
    -d "${new_aws_config}" \
    "${VAULT_ADDR}/v1/${AWS_SECRET_BACKEND}/config/root"

  # Rotate the credentials so that only vault knows the secret key
  log "rotating the root credentials"
  curl -sSf --cacert "${VAULT_CACERT}" --header "X-Vault-Token: ${VAULT_TOKEN}" \
    -XPOST \
    "${VAULT_ADDR}/v1/${AWS_SECRET_BACKEND}/config/rotate-root"

  # Save the time of this rotation to a configmap
  log "updating the date of the last rotation in the configmap"
  kubectl patch configmap "${CONFIG_MAP_NAME}" -p '{"data":{"last_rotated_date":"'"$(date +%s)"'"}}'
}

# rotator rotates the root credentials used by the vault AWS secret backend
rotator() {
  CREDENTIALS_TTL="${CREDENTIALS_TTL:="86400"}"
  while true; do
    # get the last time the credentials were rotated
    last_rotated_date=$(kubectl get configmap "${CONFIG_MAP_NAME}" -o jsonpath={.data.last_rotated_date})
    if [ -z "${last_rotated_date}" ]; then
      err "error: can't find the last rotation time in the config map ${CONFIG_MAP_NAME}"
      sleep 30
    else
      # if the credentials are older than the ttl, rotate them
      credentials_age=$(($(date +%s) - ${last_rotated_date}))
      if [ "${credentials_age}" -ge "${CREDENTIALS_TTL}" ]; then
        log "rotating the root credentials"
        curl -sSf --cacert "${VAULT_CACERT}" --header "X-Vault-Token: ${VAULT_TOKEN}" \
          -XPOST \
          "${VAULT_ADDR}/v1/${AWS_SECRET_BACKEND}/config/rotate-root"

        log "updating the date of the last rotation in the configmap"
        kubectl patch configmap "${CONFIG_MAP_NAME}" -p '{"data":{"last_rotated_date":"'"$(date +%s)"'"}}'
        credentials_age=0
      fi
      # sleep until the ttl is up
      sleep $((CREDENTIALS_TTL-credentials_age))
    fi
  done
}


case "$1" in
  "init")
    init
    ;;
  "rotator")
    rotator
    ;;
  *)
    err "error: ${1} is not a valid argument"
    ;;
esac