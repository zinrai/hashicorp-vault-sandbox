# Node Contract

What every node provides. Here `docker-compose.yaml` provides it; on hosts, configuration management provides the same.

| | Sandbox | Hosts |
|---|---|---|
| Vault | Image `hashicorp/vault:2.1.1` | Package `vault` 2.1.1 |
| `/vault/config` | `<cluster>/config/<node>/`, read-only bind mount | The same `vault.hcl`; `root:vault`, 0640 |
| `/vault/tls` | `<cluster>/tls/<node>/` from `certs`, as `<cluster>/certs/` declares it, read-only bind mount | A TLS certificate from your offline CA for the node's IP and the load balancer's, and the CA certificate; the key `root:vault` 0640 |
| `/vault/file`, `/vault/logs` | Volumes | Directories owned by `vault`, 0750 |
| Process | `vault server -config=/vault/config` | systemd unit running the same command |
| Address | IP from `ceremony.yaml`, one bridge network per cluster | IP from `ceremony.yaml` |
| Reachability | The Docker host | 8200 from the load balancer and from holder machines (vault-ceremony talks to each node), 8201 between nodes |
| Swap | — | Disabled |
| Configuration reload | `docker compose kill -s HUP <node>` | `systemctl reload vault`, sending `SIGHUP` |
| Audit log | In the volume | Rotated with `SIGHUP`, and shipped off-cluster by a second audit device |
| Time | Host clock | NTP |

Each cluster also has a load balancer, which applications and the `vault` CLI use:

| | Sandbox | Hosts |
|---|---|---|
| HAProxy | Image `haproxy:3.2`, `<cluster>-lb` | Package `haproxy`, on its own host or pair of hosts |
| Address | The `bind` address in `<cluster>/haproxy.cfg` | The same, also in every node certificate |
| Configuration | `<cluster>/haproxy.cfg` and the CA certificate, read-only bind mounts | The same `haproxy.cfg` and CA certificate |
| Reachability | The Docker host | 8200 from applications and operator machines |

Workload nodes also provide:

| | Sandbox | Hosts |
|---|---|---|
| Seal | `vault-seal-dev`, or `vault-seal-sakura-kms` (`WORKLOAD_SEAL`), in a container beside the node | systemd unit running a seal backed by a KMS, such as `vault-seal-sakura-kms`, as a member of the `vault` group; never `vault-seal-dev`, whose key is a file on the host |
| `/vault/seal/kms.sock` | tmpfs volume shared with the node | Directory owned by `vault`, 0750 |
| The seal's key or credentials | `workload/seal-key/` from `dev-seal`, or `workload/seal.env` with the KMS credentials from the Foundation Vault | The KMS credentials, from the Foundation Vault, given to the seal unit only |
| `VAULT_TRANSIT_SEAL_KEY_NAME` | `dev`, or the KMS key ID from `.env` | The KMS key ID, in the environment of the vault unit |
| Reachability of the seal | The KMS API, if any | The KMS API |
| Reachability of what secrets engines and auth methods name | Containers on the `workload` network, by name | The databases, OIDC providers and other services they name |
