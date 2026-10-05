# Operational Scenarios

Each scenario assumes the shell from the [README](../README.md) (`. sandbox/env.sh`), the cluster's directory with its environment (`cd foundation && . ./env`, or the same for `workload`), and an operator logged in. Commands that apply to one cluster only say so.

Generating a root token and rekeying take a Vault token as well as the keys, from the operator's `vault login` in the shell where they run. A holder who is not an operator approves in a shell where an operator has logged in. At any point, `vault-ceremony status --as <name>` shows that person's next step.

## Checking Cluster State

```bash
$ vault-ceremony status                  # seal and HA state, ceremonies in progress
$ vault operator raft autopilot state    # Raft peers and health, as an operator
```

Stop a node only while autopilot shows `Failure Tolerance: 1`.

## Follower Recovery (Foundation)

```bash
$ docker compose stop foundation-1
$ vault operator raft autopilot state
$ docker compose start foundation-1
$ for h in alice bob safe-hq; do vault-ceremony key --as $h | decrypt $h | vault-ceremony unseal --node foundation-1 --as $h; done
```

## Node Restart (Workload)

A restarted node unseals by itself:

```bash
$ docker compose restart workload-1
$ vault-ceremony status
```

## Seal Outage (Workload)

A node does not start while its seal is down, and starts and unseals once the seal is back:

```bash
$ docker compose stop workload-1-seal
$ docker compose restart workload-1
$ vault-ceremony status                  # workload-1 unreachable
$ docker compose logs workload-1         # error parsing Seal configuration
$ docker compose start workload-1-seal
$ vault-ceremony status                  # workload-1 unsealed
```

## Leader Failover (Foundation)

Stop the leader (assume `foundation-0`), wait about 15 seconds for another node to become active, and for the load balancer to send to it, then bring it back:

```bash
$ docker compose stop foundation-0
$ vault-ceremony status
$ vault status                           # through the load balancer, from the new active node
$ docker compose logs foundation-lb      # which node it sends to
$ docker compose start foundation-0
$ for h in alice bob carol; do vault-ceremony key --as $h | decrypt $h | vault-ceremony unseal --node foundation-0 --as $h; done
```

## Rolling Restart (Foundation)

One node at a time, `foundation-0` last, each once autopilot shows `Failure Tolerance: 1` again:

```bash
$ docker compose restart foundation-2
$ for h in alice bob carol; do vault-ceremony key --as $h | decrypt $h | vault-ceremony unseal --node foundation-2 --as $h; done
```

If the node is not listening yet, the unseal reports it as unreachable; run it again.

## Generating a Root Token

The coordinator starts it for alice, three holders approve with the printed nonce (unseal keys in the Foundation Vault, recovery keys in the Workload Vault), and alice decrypts the token:

```bash
$ vault-ceremony generate-root --for alice
$ for h in alice carol safe-dc2; do vault-ceremony key --as $h | decrypt $h | vault-ceremony approve --nonce <nonce> --as $h; done
$ vault-ceremony root-token --as alice | decrypt alice
$ VAULT_TOKEN=<root token> vault token revoke -self
$ rm state/root-token.json
```

## Break-Glass: Nobody Can Log In

The last resort, for a lockout that several operators and the [denials of the admin policy](#changing-what-admin-cannot) did not prevent. It is not a HashiCorp procedure: `enable_unauthenticated_access` brings back what Vault 2.0 closed for CVE-2026-5807, and that a SIGHUP applies it was checked on Vault 2.1.1 only. Check it again here after upgrading Vault.

Let generate-root run without a token, generate a root token as above, then close it again. A SIGHUP applies the configuration, without a restart or an unseal:

```bash
$ for n in 0 1 2; do echo 'enable_unauthenticated_access = ["generate-root"]' >> config/foundation-$n/vault.hcl; done
$ docker compose kill -s HUP foundation-0 foundation-1 foundation-2
$ vault-ceremony generate-root --for alice
$ for h in alice carol safe-dc2; do vault-ceremony key --as $h | decrypt $h | vault-ceremony approve --nonce <nonce> --as $h; done
$ sed -i '/^enable_unauthenticated_access/d' config/foundation-*/vault.hcl
$ docker compose kill -s HUP foundation-0 foundation-1 foundation-2
$ vault-ceremony root-token --as alice | decrypt alice
```

For the Workload Vault, the same with `workload-[0-2]`. While it is open, anyone who can reach the API can cancel the generation, so close it as soon as the token is out.

## Rekeying When a Holder Leaves

Replace the departing holder in `holders` of `ceremony.yaml` (say carol with dave), then:

```bash
$ keys dave
$ vault-ceremony rekey
$ for h in alice bob carol; do vault-ceremony key --as $h | decrypt $h | vault-ceremony approve --nonce <nonce> --as $h; done
$ for h in alice dave safe-hq; do vault-ceremony key --nonce <verification nonce> --as $h | decrypt $h | vault-ceremony approve --nonce <verification nonce> --as $h; done
```

The last approval of the current holders prints the verification nonce. The new keys take effect when the new holders have approved with them. The old key set moves to `state/archive/`.

## Snapshot and Restore

Take a snapshot, with the key set that belongs to it:

```bash
$ mkdir -p state/snapshots
$ vault operator raft snapshot save state/snapshots/<time>.snap
$ cp state/shares.json state/snapshots/<time>.shares.json
```

Restore into fresh nodes, with only the first one running until it has been restored and restarted. For the Foundation Vault:

```bash
$ docker compose stop foundation-0 foundation-1 foundation-2
$ docker compose rm -f foundation-0 foundation-1 foundation-2
$ docker volume rm $(docker volume ls -q | grep -E '_foundation-[0-2]-(data|audit)$')
$ docker compose up -d foundation-0
$ vault-ceremony restore --snapshot state/snapshots/<time>.snap --shares state/snapshots/<time>.shares.json
$ docker compose restart foundation-0
$ for h in alice bob carol; do vault-ceremony key --as $h | decrypt $h | vault-ceremony unseal --node foundation-0 --as $h; done
$ docker compose up -d foundation-1 foundation-2
$ for h in alice bob carol; do vault-ceremony key --as $h | decrypt $h | vault-ceremony unseal --as $h; done
$ vault login -method=userpass username=alice
```

For the Workload Vault, the same with `--profile workload` and `workload-[0-2]`, without the unseals: the seal unseals every node.

## Rotating the KMS Credentials (Workload, SAKURA Cloud KMS)

Update the credentials in the Foundation Vault, write `workload/seal.env` again as in the [README](../README.md#workload-vault), and restart the seals:

```bash
$ cd ../foundation && . ./env
$ vault kv patch secret/platform/sakura-kms access_token=<new> access_token_secret=<new>
$ docker compose --profile workload up -d --force-recreate workload-0-seal workload-1-seal workload-2-seal
```

## Automation with AppRole (Foundation)

Set up a role for automation, such as Ansible reading the KMS credentials, issue it a single-use secret ID, and log in with it:

```bash
$ vault auth enable approle
$ vault write auth/approle/role/ansible token_policies=ansible \
    token_ttl=10m token_max_ttl=30m secret_id_ttl=10m secret_id_num_uses=1
$ vault read -field=role_id auth/approle/role/ansible/role-id
$ vault write -f -field=secret_id auth/approle/role/ansible/secret-id
$ vault write auth/approle/login role_id=<role_id> secret_id=<secret_id>
```

## Adding an Operator

As an existing operator:

```bash
$ vault write auth/userpass/users/erin password=<initial password>
$ id=$(vault write -field=id identity/entity name=erin policies=admin)
$ vault write identity/entity-alias name=erin canonical_id=$id \
    mount_accessor=$(vault read -field=accessor sys/auth/userpass)
```

## Removing an Operator

Only while at least two other operators can still log in with admin: one person away must not lock everyone out.

```bash
$ vault list auth/userpass/users
$ vault delete auth/userpass/users/erin
$ vault delete identity/entity/name/erin
```

## Changing What Admin Cannot

Audit devices, the userpass auth method and the admin policy take a root token. Generate one (see [Generating a Root Token](#generating-a-root-token)), then, for example:

```bash
$ VAULT_TOKEN=<root token> vault audit enable -path=<path> <type> <options>
$ VAULT_TOKEN=<root token> vault policy write admin policies/admin.hcl
$ VAULT_TOKEN=<root token> vault token revoke -self
```
