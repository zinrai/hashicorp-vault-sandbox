# Sourced, not run: it sets up the calling shell, in the sandbox's root.
#
# The sandbox's own commands on PATH beside the release binaries, not
# called by path: they stand in for what people and machines do, in any
# cluster directory.

export PATH="$PWD/bin:$PWD/sandbox/bin:$PATH"
# Pinned, not looked up: docker compose then works from either cluster's
# directory, as one project.
export COMPOSE_FILE="$PWD/docker-compose.yaml"
# Exported, not left to docker-compose.yaml's default of 1000: the vault
# containers read node keys through the group of whoever made them.
HOST_GID=$(id -g)
export HOST_GID
