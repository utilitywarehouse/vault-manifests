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

output_dir="./pki"
rm -rf "${output_dir}"
mkdir "${output_dir}"

# update_client_namespaces copies ca.crt into a configmap in every namespace in
# the cluster. The list of namespaces can be constrained by setting a
# space-delimited list in VAULT_CLIENT_NAMESPACES.
#
# This function is ran when the certificate is rotated and subsequently every 25
# minutes to ensure new namespaces receive the certificate after a reasonable
# amount of time.
update_client_namespaces() {
    vault_namespaces="${VAULT_CLIENT_NAMESPACES:-""}"

    if [[ -z "${vault_namespaces}" ]]; then
        vault_namespaces=$(kubectl get ns -o name \
          | sed 's|namespace/||g' \
          | xargs
        )
    fi

    echo "Updating CA in client namespaces"
    for n in $vault_namespaces; do
        echo "Updating configmap in ${n}"
        kubectl -n "${n}" create configmap "${secret_name}" \
            --from-file /etc/tls/ca.crt 2>/dev/null \
            || kubectl -n "${n}" create configmap "${secret_name}" \
                --from-file /etc/tls/ca.crt \
                --dry-run=client -o yaml | kubectl -n "${n}" replace -f -
    done
}

# Main loop
while true; do
    # Sleep if certificate is not expiring soon
    if [[ -f /etc/tls/ca.crt ]]; then
        now_seconds=$(date +%s)
        cert_expiration=$(cfssl certinfo -cert /etc/tls/ca.crt | jq -r '.not_after' | sed -e 's/T/ /g' -e 's/Z$//g')
        expiration_seconds=$(date -d "${cert_expiration}" +%s)
        validity=$((expiration_seconds - now_seconds))
        if [[ ${validity} -gt 7200 ]]; then # 2h
            update_client_namespaces
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
    update_client_namespaces

    echo "Rotated successfully on $(date -I'seconds')"
    sleep 1500 # 25 min
done
