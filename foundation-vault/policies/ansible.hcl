# Read-only, not read-write: the Foundation Vault holds nothing that
# rebuild automation should write.

path "secret/data/platform/*" {
  capabilities = ["read"]
}

path "secret/metadata/platform/*" {
  capabilities = ["list"]
}
