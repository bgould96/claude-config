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
short_sha256() {
    if command -v sha256sum &>/dev/null; then
        sha256sum | cut -c1-12
    else
        shasum -a 256 | cut -c1-12
    fi
}

IMAGE_HASH=$(cat "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR/entrypoint.sh" | short_sha256)
IMAGE_TAG="claude-code:${IMAGE_HASH}"

if docker image inspect "$IMAGE_TAG" &>/dev/null; then
    echo "Image exists, skipping build ($IMAGE_TAG)"
else
    echo "Building image ($IMAGE_TAG)..."
    docker build -t "$IMAGE_TAG" "$SCRIPT_DIR"
fi

# --- Project image layer (caches apt + pip deps) ---
DEPS_FILES=()
for f in "$PROJECT_DIR/agent.deps" "$PROJECT_DIR/requirements.txt"; do
    [ -f "$f" ] && DEPS_FILES+=("$f")
done

if [ ${#DEPS_FILES[@]} -gt 0 ]; then
    DEPS_HASH=$(cat "${DEPS_FILES[@]}" | short_sha256)
    PROJECT_TAG="claude-code-project:${IMAGE_HASH}-${DEPS_HASH}"

    if docker image inspect "$PROJECT_TAG" &>/dev/null; then
        echo "Project image exists, skipping deps build ($PROJECT_TAG)"
    else
        echo "Building project image ($PROJECT_TAG)..."
        TMPDIR_BUILD=$(mktemp -d)
        trap 'rm -rf "$TMPDIR_BUILD"' EXIT

        # Copy deps files into build context
        DOCKERFILE_BODY="FROM $IMAGE_TAG"
        for f in "${DEPS_FILES[@]}"; do
            cp "$f" "$TMPDIR_BUILD/"
        done

        if [ -f "$PROJECT_DIR/agent.deps" ]; then
            DOCKERFILE_BODY="${DOCKERFILE_BODY}
COPY agent.deps .
RUN apt-get update -qq && grep -v '^\s*#' agent.deps | grep -v '^\s*\$' | xargs -r apt-get install -y --no-install-recommends -qq -- && rm -rf /var/lib/apt/lists/*"
        fi

        if [ -f "$PROJECT_DIR/requirements.txt" ]; then
            DOCKERFILE_BODY="${DOCKERFILE_BODY}
COPY requirements.txt .
RUN pip3 install -q -r requirements.txt"
        fi

        DOCKERFILE_BODY="${DOCKERFILE_BODY}
RUN touch /opt/.deps-preinstalled"

        printf '%s\n' "$DOCKERFILE_BODY" > "$TMPDIR_BUILD/Dockerfile"
        docker build -t "$PROJECT_TAG" "$TMPDIR_BUILD"
    fi
    RUN_IMAGE="$PROJECT_TAG"
else
    RUN_IMAGE="$IMAGE_TAG"
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
CLAUDE_DATA_VOL="claude-data-${PROJECT_NAME}"

# --- Optional port exposure ---
PORT_FLAGS=()
CONTAINER_PORT=$(grep -E '^CONTAINER_PORT=' "$PROJECT_DIR/.env" 2>/dev/null | cut -d'=' -f2- | tr -d '"' | tr -d "'" | tr -d '\r' || true)
if [ -n "$CONTAINER_PORT" ]; then
    PORT_FLAGS+=("-p" "${CONTAINER_PORT}:${CONTAINER_PORT}")
fi

# --- Host credentials (authenticate once, use everywhere) ---
CLAUDE_CREDENTIALS="${CLAUDE_CREDENTIALS:-$HOME/.claude/.credentials.json}"
CLAUDE_AUTH_FLAGS=()
if [ -f "$CLAUDE_CREDENTIALS" ]; then
    CLAUDE_AUTH_FLAGS+=("-v" "${CLAUDE_CREDENTIALS}:/opt/claude-auth/.credentials.json:ro")
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
    -v "$PROJECT_DIR:/workspace" \
    -v "${PIP_CACHE_VOL}:/opt/pip-cache" \
    -v "${NPM_CACHE_VOL}:/opt/npm-cache" \
    -v "${CLAUDE_DATA_VOL}:/opt/claude-data" \
    ${PORT_FLAGS[@]+"${PORT_FLAGS[@]}"} \
    ${CLAUDE_AUTH_FLAGS[@]+"${CLAUDE_AUTH_FLAGS[@]}"} \
    "$RUN_IMAGE" \
    ${ARGS[@]+"${ARGS[@]}"}
