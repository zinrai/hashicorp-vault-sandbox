# Vault Configuration for 5-node Raft HA Cluster
# This configuration is shared across all nodes; uniqueness is injected via environment variables

# Enable UI
ui = true

# Disable mlock - appropriate for containerized environments with IPC_LOCK capability
# In production, this should be carefully considered based on security requirements
disable_mlock = true

# Storage: Raft Integrated Storage
storage "raft" {
  path = "/vault/file"

  # Retry join configuration - peer list
  # Each node will attempt to join the cluster by connecting to these addresses
  # This ensures nodes can discover each other regardless of startup order
  retry_join {
    leader_api_addr = "http://vault-0:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-1:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-2:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-3:8200"
  }
  retry_join {
    leader_api_addr = "http://vault-4:8200"
  }
}

# Listener: TCP with TLS disabled
# Note: TLS is disabled for learning/development purposes
# In production, TLS should be enabled with proper certificates
listener "tcp" {
  address         = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable     = true
}
