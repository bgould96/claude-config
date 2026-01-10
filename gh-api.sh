#!/bin/bash
# GH API wrapper that loads credentials from project .env

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_ROOT/.env"

# Load .env if it exists
if [ -f "$ENV_FILE" ]; then
    # Export only GH_API_KEY, safely
    export GH_TOKEN=$(grep -E '^GH_API_KEY=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
fi

# Validate token exists
if [ -z "$GH_TOKEN" ]; then
    echo "Error: GH_API_KEY not found in $ENV_FILE" >&2
    exit 1
fi

# Pass all arguments to gh
exec gh "$@"
