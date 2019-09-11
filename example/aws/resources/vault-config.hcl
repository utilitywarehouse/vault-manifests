listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_key_file    = "/etc/tls/tls.key"
  tls_cert_file   = "/etc/tls/tls.crt"
}

storage "raft" {
  path    = "/vault/storage"
  node_id = "${HOSTNAME}"
}

seal "awskms" {
  region     = "eu-west-1"
  kms_key_id = "000000000000000000000000000000000000"
}

api_addr      = "https://${HOSTNAME}.vault.example-ns:8200"
cluster_addr  = "https://${HOSTNAME}.vault.example-ns:8201"
disable_mlock = true
