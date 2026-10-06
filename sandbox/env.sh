# Sourced, not run: it sets up the calling shell, in the sandbox's root.

export PATH="$PWD/bin:$PATH"
# One keyring for both clusters, not one each: the same people hold keys
# to both.
export PGP_PERSONAS_KEYRING="$PWD/sandbox/keyring"
# Pinned, not looked up: docker compose then works from either cluster's
# directory, as one project.
export COMPOSE_FILE="$PWD/docker-compose.yaml"
# Exported, not left to docker-compose.yaml's default of 1000: the vault
# containers read node keys through the group of whoever made them.
HOST_GID=$(id -g)
export HOST_GID
