# HashiCorp Vault Sandbox

A 5-node Vault OSS Raft HA cluster using Docker Compose for learning Vault operations.

## Overview

This project provides a "flight simulator" for Vault operations—bridging the gap between `vault server -dev` and production deployments.

What you can learn:

- Raft integrated storage and HA clustering
- Manual unseal process with Shamir's secret sharing
- Cluster state monitoring with Autopilot
- Failure recovery and leader failover

## Prerequisites

- Docker
- Docker Compose V2

## Quick Start

Start the cluster:

```bash
$ sudo docker compose up -d
```

Initialize Vault and save the unseal keys:

```bash
$ sudo docker compose exec vault-0 vault operator init > init-output.txt
```

Unseal all nodes:

```bash
$ sudo ./unseal.sh --target all
```

Login with the root token:

```bash
sudo docker compose exec vault-0 vault login $(grep "Initial Root Token" init-output.txt | awk '{ print $NF }')
```

## Operational Scenarios

### Checking Cluster State

View Raft peer list:

```bash
$ sudo docker compose exec vault-0 vault operator raft list-peers
```

View detailed Autopilot state including health status and last contact time:

```bash
$ sudo docker compose exec vault-0 vault operator raft autopilot state
```

### Follower Recovery

Stop a follower node:

```bash
$ sudo docker compose down vault-1
```

Observe the cluster state—vault-1 becomes unhealthy:

```bash
$ sudo docker compose exec vault-0 vault operator raft autopilot state
```

Restore the node:

```bash
$ sudo docker compose up -d vault-1
$ sudo ./unseal.sh --target vault-1
```

### Leader Failover

Stop the leader node (assuming vault-0 is leader):

```bash
$ sudo docker compose down vault-0
```

A new leader is elected automatically. Verify from another node:

```bash
$ sudo docker compose exec vault-1 vault operator raft list-peers
```

Restore the former leader:

```bash
$ sudo docker compose up -d vault-0
$ sudo ./unseal.sh --target vault-0
```

The node rejoins as a follower, not reclaiming leadership.

## Notes

This environment is for learning purposes only.

Differences from production:

- TLS is disabled
- Unseal keys are stored in plaintext files
- Single host (no physical HA)

In production, use Auto Unseal with a KMS and enable TLS.

## License

This project is licensed under the [MIT License](./LICENSE).
