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
| Seal | `vault-seal-sakura-kms` in a container beside the node, as the `vault` user | systemd unit running `vault-seal-sakura-kms` as a member of the `vault` group |
| `/vault/seal/kms.sock` | tmpfs volume shared with the node | Directory owned by `vault`, 0750 |
| KMS credentials | `workload/seal.env`, from the Foundation Vault | Environment file of the seal unit, 0600, from the Foundation Vault |
| `VAULT_TRANSIT_SEAL_KEY_NAME` | `workload/vault.env` | Environment of the vault unit |
| Reachability of the seal | The KMS API | The KMS API |
| Reachability of what secrets engines and auth methods name | Containers on the `workload` network, by name | The databases, OIDC providers and other services they name |
