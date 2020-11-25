#!/bin/bash

# This script updates the CA certificate+key and server certificate+key on a
# daily basis and distributes the CA certificate to client namespaces

set -o nounset
set -o errexit
set -o pipefail

: "${VAULT_NAMESPACE:?Need to set VAULT_NAMESPACE}"

secret_name="${VAULT_SECRET_NAME:-"vault-tls"}"
vault_name="${VAULT_NAME:-"vault"}"
replicas="${VAULT_REPLICAS:-"3"}"
vault_namespaces="${VAULT_CLIENT_NAMESPACES:-""}"
ca_crt="${VAULT_CACERT:-"/etc/tls/ca.crt"}"

output_dir="./pki"
rm -rf "${output_dir}"
mkdir "${output_dir}"

# update_client_namespace copies the CA cert to a configmap in the provided namespace
update_client_namespace() {
  ns=$1
  cert=$2

  echo "Updating configmap in ${ns}"
  kubectl -n "${ns}" create configmap "${secret_name}" \
    --from-file "${cert}" 2>/dev/null \
    || kubectl -n "${ns}" create configmap "${secret_name}" \
        --from-file "${cert}" \
        --dry-run=client -o yaml | kubectl -n "${ns}" replace -f -
}

# update_client_namespaces copies the CA cert into a configmap in every namespace
# in the cluster. The list of namespaces can be constrained by setting a
# space-delimited list in VAULT_CLIENT_NAMESPACES.
update_client_namespaces() {
    cert=$1

    echo "Updating CA in client namespaces"
    while read -r line; do
      ns="${line#*/}"
      if is_client_namespace "${ns}"; then
        update_client_namespace "${ns}" "${cert}"
      fi
    done < <(kubectl get ns -o name)
}

# update_new_client_namespaces watches for new namespaces and copies the ca cert into them as they're
# added
update_new_client_namespaces() {
  cert=$1

  echo "Watching for new namespaces..."
  while true; do
    while read -r line; do
      event=$(awk '{print $1}' <<<"${line}")
      ns=$(awk '{print $2}' <<<"${line}")

      if [[ "${event}" == "ADDED" ]] && is_client_namespace "${ns}" && [[ -f "${cert}" ]]; then
        echo "Event received: ${event} ${ns}"
        update_client_namespace "${ns}" "${cert}"
      fi
    done < <(kubectl get ns --watch-only --output-watch-events --no-headers)

    # Add a brief delay before starting the watch again to avoid hammering the
    # apiserver in the case of issues
    sleep 2
  done
}

# is_client_namespace returns true if the namespace is in the list of client
# namespaces (or the client namespaces list is empty, which implicitly means
# all)
is_client_namespace() {
  ns=$1

  [[ -z $vault_namespaces ]] || [[ $vault_namespaces =~ (^|[[:space:]])"$ns"($|[[:space:]]) ]]
}

# Cleanup child processes
trap "kill 0" EXIT

# Ensure the certificate is copied into all client namespaces, if it exists
if [[ -f "${ca_crt}" ]]; then
  update_client_namespaces "${ca_crt}"
fi

# In a background process, ensure new namespaces receive the certificate
update_new_client_namespaces "${ca_crt}" &

# Main loop
while true; do
    # Sleep if certificate is not expiring soon
    if [[ -f "${ca_crt}" ]]; then
        now_seconds=$(date +%s)
        cert_expiration=$(cfssl certinfo -cert "${ca_crt}" | jq -r '.not_after' | sed -e 's/T/ /g' -e 's/Z$//g')
        expiration_seconds=$(date -d "${cert_expiration}" +%s)
        validity=$((expiration_seconds - now_seconds))
        if [[ ${validity} -gt 7200 ]]; then # 2h
            sleep 1500 # 25 min
            continue
        fi
    fi
    echo "Rotating PKI"
    # CA files
    ca_config='{
    "CN": "'"${VAULT_NAMESPACE}"' CA",
    "key": {
        "algo": "ecdsa",
        "size": 521
    },
    "ca": {
        "expiry": "25h"
    }
    }'

    echo "${ca_config}" > "${output_dir}"/ca-config.json

    cfssl gencert \
    -initca "${output_dir}"/ca-config.json | cfssljson -bare "${output_dir}"/ca

    mv "${output_dir}"/ca.pem "${output_dir}"/ca-cert.pem
    rm "${output_dir}"/ca.csr

    # Vault server files
    server_config='{
    "CN": "'"${vault_name}"'.'"${VAULT_NAMESPACE}"'",
    "key": {
        "algo": "ecdsa",
        "size": 521
    }
    }'
    hosts='
        "localhost",
        "127.0.0.1",
        "'"${vault_name}"'",
        "'"${vault_name}-cluster"'",
        "'"${vault_name}.${VAULT_NAMESPACE}"'",
        "'"${vault_name}-cluster.${VAULT_NAMESPACE}"'"
    '
    for i in $(seq 0 $((replicas - 1))) ; do
        hosts='
            '"${hosts}"',
            "'"${vault_name}-${i}.${vault_name}"'",
            "'"${vault_name}-${i}.${vault_name}-cluster"'",
            "'"${vault_name}-${i}.${vault_name}.${VAULT_NAMESPACE}"'",
            "'"${vault_name}-${i}.${vault_name}-cluster.${VAULT_NAMESPACE}"'"
        '
    done
    server_config=$(echo "${server_config}" | jq '.hosts = ['"${hosts}"']')

    echo "${server_config}" > "${output_dir}"/server-config.json

    cfssl gencert \
        -ca "${output_dir}"/ca-cert.pem \
        -ca-key "${output_dir}"/ca-key.pem \
        "${output_dir}"/server-config.json | cfssljson -bare "${output_dir}"/server

    mv "${output_dir}"/server.pem "${output_dir}"/server-cert.pem
    rm "${output_dir}"/server.csr

    # Rename files and delete CA key
    mv "${output_dir}"/ca-cert.pem "${output_dir}"/ca.crt
    rm "${output_dir}"/ca-key.pem

    mv "${output_dir}"/server-cert.pem "${output_dir}"/tls.crt
    mv "${output_dir}"/server-key.pem "${output_dir}"/tls.key

    # Update secrets
    echo "Updating secret in ${VAULT_NAMESPACE}"
    kubectl -n "${VAULT_NAMESPACE}" create secret \
        generic "${secret_name}" \
        --from-file "${output_dir}"/ca.crt \
        --from-file "${output_dir}"/tls.crt \
        --from-file "${output_dir}"/tls.key \
        --dry-run=client -o yaml | kubectl -n "${VAULT_NAMESPACE}" replace -f -
    exit_code=$?
    if [ "${exit_code}" != "0" ]; then
        echo "Error: failed to update secret in ${VAULT_NAMESPACE}, exiting"
        exit 1
    fi

    # Copy the new ca.crt to the client namespaces
    update_client_namespaces "${output_dir}"/ca.crt

    echo "Rotated successfully on $(date -I'seconds')"
    sleep 1500 # 25 min
done
