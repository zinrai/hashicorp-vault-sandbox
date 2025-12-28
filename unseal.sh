#!/bin/bash

set -e

KEYS_FILE="keys.txt"
INIT_OUTPUT="init-output.txt"

usage() {
    echo "Usage: $0 --target <all|vault-0|vault-1|vault-2|vault-3|vault-4>"
    echo ""
    echo "Examples:"
    echo "  $0 --target all      # Unseal all nodes"
    echo "  $0 --target vault-0  # Unseal vault-0 only"
    exit 1
}

# 引数チェック
if [ "$1" != "--target" ] || [ -z "$2" ]; then
    usage
fi

TARGET="$2"

# キーファイル確認・生成
if [ ! -f "$INIT_OUTPUT" ]; then
    echo "Error: Neither $KEYS_FILE nor $INIT_OUTPUT found."
    echo "Run: docker compose exec vault-0 vault operator init > $INIT_OUTPUT"
    exit 1
fi
grep "Unseal Key" "$INIT_OUTPUT" | awk '{ print $NF }' > "$KEYS_FILE"

unseal_node() {
    local node=$1
    echo "Unsealing $node..."
    
    # 配列に読み込む
    mapfile -t selected_keys < <(shuf -n 3 "$KEYS_FILE")
    
    # 3つのキーでunseal
    for key in "${selected_keys[@]}"; do
        docker compose exec -T "$node" vault operator unseal "$key"
    done
    
    echo "✓ $node unsealed"
}

# ターゲットに応じて実行
case "$TARGET" in
    all)
        for node in vault-{0..4}; do
            unseal_node "$node"
        done
        ;;
    vault-[0-4])
        unseal_node "$TARGET"
        ;;
    *)
        echo "Error: Invalid target '$TARGET'"
        usage
        ;;
esac
