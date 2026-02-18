#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

DEFAULT_MIHOMO_TAG="$(grep -Eo '\bv[0-9]+\.[0-9]+\.[0-9]+\b' README.md 2>/dev/null | head -n1 || true)"
if [[ -z "$DEFAULT_MIHOMO_TAG" ]]; then
  DEFAULT_MIHOMO_TAG="main"
fi

IMAGE_NAME="${IMAGE_NAME:-mikrotik-mihomo-fakeip:smoke}"
MIHOMO_TAG="${MIHOMO_TAG:-$DEFAULT_MIHOMO_TAG}"
BUILDTIME="${BUILDTIME:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
AMD64VERSION="${AMD64VERSION:-v1}"
WITH_GVISOR="${WITH_GVISOR:-0}"
CONTAINER_NAME="mihomo-smoke-$(date +%s)-$RANDOM"

cleanup() {
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "[smoke] Building image: $IMAGE_NAME"
echo "[smoke] Using TAG=$MIHOMO_TAG WITH_GVISOR=$WITH_GVISOR AMD64VERSION=$AMD64VERSION"

docker build \
  --build-arg TAG="$MIHOMO_TAG" \
  --build-arg WITH_GVISOR="$WITH_GVISOR" \
  --build-arg BUILDTIME="$BUILDTIME" \
  --build-arg AMD64VERSION="$AMD64VERSION" \
  -t "$IMAGE_NAME" \
  .

echo "[smoke] Starting container: $CONTAINER_NAME"
docker run -d --name "$CONTAINER_NAME" --privileged --rm=false "$IMAGE_NAME" >/dev/null

echo "[smoke] Waiting for /root/.config/mihomo/config.yaml"
for _ in {1..10}; do
  if docker exec "$CONTAINER_NAME" test -s /root/.config/mihomo/config.yaml; then
    echo "[smoke] config.yaml found"
    echo "[smoke] First 40 lines of config.yaml:"
    docker exec "$CONTAINER_NAME" sh -lc 'sed -n "1,40p" /root/.config/mihomo/config.yaml'
    echo "[smoke] Smoke test passed"
    exit 0
  fi
  sleep 0.5
done

echo "[smoke] ERROR: config.yaml was not created" >&2
echo "[smoke] Container logs:" >&2
docker logs "$CONTAINER_NAME" >&2 || true
exit 1
