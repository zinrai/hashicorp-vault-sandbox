cluster_name = "workload-vault"

# No UI: operators use the CLI, and applications the API.
ui = false

# mlock off, not on: Integrated Storage memory-maps its database, which
# does not mix with mlock. Swap is disabled on the host instead, as
# HashiCorp advises for Raft.
disable_mlock = true

# No enable_unauthenticated_access: generate-root and rekey stay behind a
# token, as Vault 2.x has them. Whoever can start or cancel them without one
# can cancel every attempt, so that no ceremony ever completes
# (CVE-2026-5807). Added for break-glass only, generate-root alone, while
# nobody can log in to start one, and removed again (docs/scenarios.md).

api_addr     = "https://172.29.0.11:8200"
cluster_addr = "https://172.29.0.11:8201"

storage "raft" {
  path    = "/vault/file"
  node_id = "workload-vault-1"
  retry_join {
    leader_api_addr     = "https://172.29.0.10:8200"
    leader_ca_cert_file = "/vault/tls/ca.crt"
  }
  retry_join {
    leader_api_addr     = "https://172.29.0.12:8200"
    leader_ca_cert_file = "/vault/tls/ca.crt"
  }
}

listener "tcp" {
  address         = "172.29.0.11:8200"
  cluster_address = "172.29.0.11:8201"
  tls_cert_file   = "/vault/tls/server.crt"
  tls_key_file    = "/vault/tls/server.key"
  tls_min_version = "tls13"

  # The client's address from the load balancer's PROXY header, not the
  # load balancer's own: the audit log must name who asked. Connections
  # from anywhere else, such as vault-ceremony and the other nodes, carry
  # no header and keep their own address.
  proxy_protocol_behavior         = "allow_authorized"
  proxy_protocol_authorized_addrs = "172.29.0.5"
}

# Transit, not Shamir and not a KMS's own seal type: whichever seal runs
# beside the node (vault-seal-dev, or vault-seal-sakura-kms for SAKURA Cloud
# KMS) answers Vault's transit API, so this stanza is the same for each. A
# Unix socket, not loopback TCP, so that only the vault group can ask for a
# decryption. No key_name here: it comes from VAULT_TRANSIT_SEAL_KEY_NAME,
# dev for the development seal, the KMS key ID for a KMS.
seal "transit" {
  address         = "unix:///vault/seal/kms.sock"
  mount_path      = "transit/"
  disable_renewal = "true"
}
