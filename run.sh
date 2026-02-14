#!/bin/bash
set -euo pipefail

# --- Resolve paths ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# --- Validate prerequisites ---
if ! command -v docker &>/dev/null; then
    echo "Error: docker is not installed or not in PATH" >&2
    exit 1
fi

if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "Error: .env file not found in $PROJECT_DIR" >&2
    echo "Create one with at least ANTHROPIC_API_KEY=sk-ant-..." >&2
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
    echo "Error: Dockerfile not found in $SCRIPT_DIR" >&2
    exit 1
fi

# --- Parse --skip-perms flag ---
SKIP_PERMISSIONS="${SKIP_PERMISSIONS:-0}"
ARGS=()
for arg in "$@"; do
    if [ "$arg" = "--skip-perms" ]; then
        SKIP_PERMISSIONS=1
    else
        ARGS+=("$arg")
    fi
done

# --- Image caching (hash-based) ---
hash_files() {
    if command -v sha256sum &>/dev/null; then
        cat "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/entrypoint.sh" | sha256sum | cut -c1-12
    else
        cat "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/entrypoint.sh" | shasum -a 256 | cut -c1-12
    fi
}

IMAGE_HASH=$(hash_files)
IMAGE_TAG="claude-code:${IMAGE_HASH}"

if docker image inspect "$IMAGE_TAG" &>/dev/null; then
    echo "Image exists, skipping build ($IMAGE_TAG)"
else
    echo "Building image ($IMAGE_TAG)..."
    docker build -t "$IMAGE_TAG" "$SCRIPT_DIR"
fi

# --- TTY detection ---
DOCKER_FLAGS=()
if [ -t 0 ] && [ -t 1 ]; then
    DOCKER_FLAGS+=("-it")
fi

# --- Container name ---
CONTAINER_NAME="claude-${PROJECT_NAME}-$$"

# --- Dep cache volumes ---
PIP_CACHE_VOL="claude-pip-cache-${PROJECT_NAME}"
NPM_CACHE_VOL="claude-npm-cache-${PROJECT_NAME}"

# --- Optional port exposure ---
PORT_FLAGS=()
CONTAINER_PORT=$(grep -E '^CONTAINER_PORT=' "$PROJECT_DIR/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || true)
if [ -n "$CONTAINER_PORT" ]; then
    PORT_FLAGS+=("-p" "${CONTAINER_PORT}:${CONTAINER_PORT}")
fi

# --- Run ---
# Use ${arr[@]+"${arr[@]}"} pattern for empty-array safety with set -u on bash < 4.4
exec docker run --rm \
    ${DOCKER_FLAGS[@]+"${DOCKER_FLAGS[@]}"} \
    --name "$CONTAINER_NAME" \
    --env-file "$PROJECT_DIR/.env" \
    -e "SKIP_PERMISSIONS=${SKIP_PERMISSIONS}" \
    --add-host=host.docker.internal:host-gateway \
    --security-opt=no-new-privileges \
    --cap-drop=ALL \
    --cap-add=CHOWN \
    --cap-add=SETUID \
    --cap-add=SETGID \
    --cap-add=DAC_OVERRIDE \
    -v "$PROJECT_DIR:/workspace" \
    -v "${PIP_CACHE_VOL}:/root/.cache/pip" \
    -v "${NPM_CACHE_VOL}:/root/.npm" \
    ${PORT_FLAGS[@]+"${PORT_FLAGS[@]}"} \
    "$IMAGE_TAG" \
    ${ARGS[@]+"${ARGS[@]}"}
