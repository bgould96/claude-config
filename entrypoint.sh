#!/bin/bash
set -euo pipefail

# --- UID/GID mapping ---
# Match container user to host file ownership so files aren't created as root.
HOST_UID=$(stat -c '%u' /workspace)
HOST_GID=$(stat -c '%g' /workspace)

if [ "$HOST_UID" -eq 0 ]; then
    # Workspace owned by root — just run as root
    RUN_AS_ROOT=1
else
    RUN_AS_ROOT=0
    groupadd -g "$HOST_GID" -o agent 2>/dev/null || true
    useradd -u "$HOST_UID" -g "$HOST_GID" -o -m -s /bin/bash agent 2>/dev/null || true
fi

# --- Project-specific apt packages ---
if [ -f /workspace/agent.deps ]; then
    DEPS=$(grep -v '^\s*#' /workspace/agent.deps | grep -v '^\s*$' | tr '\n' ' ')
    if [ -n "$DEPS" ]; then
        echo "Installing apt packages from agent.deps: $DEPS"
        apt-get update -qq
        # shellcheck disable=SC2086
        apt-get install -y --no-install-recommends -qq $DEPS
        rm -rf /var/lib/apt/lists/*
    fi
fi

# --- Python dependencies ---
if [ -f /workspace/requirements.txt ]; then
    echo "Installing Python dependencies..."
    pip3 install -q -r /workspace/requirements.txt
fi

# --- Node dependencies ---
if [ -f /workspace/package.json ] && [ ! -d /workspace/node_modules ]; then
    echo "Installing Node dependencies..."
    if [ "$RUN_AS_ROOT" -eq 1 ]; then
        npm install --prefix /workspace
    else
        gosu agent npm install --prefix /workspace
    fi
fi

# --- Git config ---
git config --global --add safe.directory /workspace
git config --global user.name "${GIT_USER_NAME:-Claude Code Agent}"
git config --global user.email "${GIT_USER_EMAIL:-claude-agent@noreply.github.com}"

# --- GH CLI auth ---
# Map GH_API_KEY to GH_TOKEN if GH_TOKEN isn't already set (gh CLI auto-detects GH_TOKEN)
if [ -z "${GH_TOKEN:-}" ] && [ -n "${GH_API_KEY:-}" ]; then
    export GH_TOKEN="$GH_API_KEY"
fi

# --- Build claude args ---
CLAUDE_ARGS=()
if [ "${SKIP_PERMISSIONS:-}" = "1" ]; then
    CLAUDE_ARGS+=("--dangerously-skip-permissions")
fi

# Append any args passed to the container
if [ $# -gt 0 ]; then
    CLAUDE_ARGS+=("$@")
fi

# --- Launch ---
if [ "$RUN_AS_ROOT" -eq 1 ]; then
    exec claude ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}
else
    exec gosu agent claude ${CLAUDE_ARGS[@]+"${CLAUDE_ARGS[@]}"}
fi
