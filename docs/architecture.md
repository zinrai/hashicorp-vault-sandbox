# Architecture

How the parts connect. Addresses, ports and file names are left to the configuration, which says them exactly.

## A Node

Every node is the same, apart from the seal: only Workload nodes have one. The load balancer passes TLS through and adds a PROXY header with the client's address; vault-ceremony reaches each node directly.

```mermaid
flowchart TB
    lb["load balancer"] -->|"TLS"| vault["vault server"]
    holders["vault-ceremony"] -->|"direct"| vault
    config["vault.hcl"] --> vault
    tls["TLS key and certificate"] --> vault
    vault --> data["Raft storage"]
    vault --> logs["audit log"]
    vault <-->|"Raft"| peers["other nodes"]
    vault <-->|"Unix socket"| seal["seal, Workload only"]
```

## A Workload Node Starts

The node cannot start while its seal is down, and unseals by itself once it is up.

```mermaid
sequenceDiagram
    participant N as Workload node
    participant S as Seal
    participant K as Key file or KMS
    N->>S: decrypt the root key (transit API)
    S->>K: decrypt with the key
    K-->>S: root key
    S-->>N: root key
    Note over N: unsealed, rejoins Raft
```

## Holders Unseal a Foundation Node

Each holder in turn, until the threshold is met. The holder decrypts with their own OpenPGP tool and pipes the plaintext into `unseal`: it exists only in the pipe.

```mermaid
sequenceDiagram
    actor H as Holder
    participant C as vault-ceremony
    participant R as Repository (state/)
    participant N as Foundation node
    H->>C: key --as holder
    C->>R: read the holder's key
    C-->>H: encrypted key
    Note over H: decrypts
    H->>C: unseal --as holder
    C->>N: submit the key
    N-->>C: progress
    Note over N: unsealed at the threshold
```

## Generating a Root Token

The same for both clusters: unseal keys in the Foundation Vault, recovery keys in the Workload Vault. Holders approve in a shell where an operator has logged in. Before submitting a key, vault-ceremony checks that the token would go to someone in `pubkeys/`; the token lands in `state/root-token.json`, and the recipient decrypts it with `root-token`.

```mermaid
sequenceDiagram
    actor Co as Coordinator
    actor H as Holders
    participant C as vault-ceremony
    participant V as Vault
    Co->>C: generate-root --for recipient
    C->>V: start, with the public key
    V-->>Co: nonce
    Co-->>H: announce the nonce
    loop until the threshold is met
        H->>C: key | decrypt | approve
        C->>V: check, then submit the key
    end
    V-->>C: root token, encrypted
    Note over C: state/root-token.json
```
