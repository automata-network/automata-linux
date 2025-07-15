
#!/usr/bin/env bash
set -euo pipefail

SOURCE_IMAGE="$1"   # e.g., alpine:latest
TARGET_IMAGE="$2"   # e.g., docker.io/yaoxin111/alpine:signed

COSIGN_KEY="$3"
COSIGN_PUB="$4"

REPO_PATH="${TARGET_IMAGE#*/}"          # e.g. yaoxin111/alpine:signed → yaoxin111/alpine:signed
REPO_NAME="${REPO_PATH%%:*}"            # strip tag → yaoxin111/alpine
NAMESPACE="${REPO_NAME%%/*}"            # yaoxin111
REPO_ONLY="${REPO_NAME#*/}"             # alpine

# ───────────────────────────────────────────────────────────────────────────────
# Usage: ./sign-and-verify.sh <source-image> <registry>/<image-name>:<tag>
# Example: ./sign-and-verify.sh alpine:latest docker.io/yaoxin111/alpine:secure
# ───────────────────────────────────────────────────────────────────────────────

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <source-image> <target-image>"
  echo "Example: $0 alpine:latest docker.io/yaoxin111/alpine:signed"
  exit 1
fi

# ───────────────────────────────────────────────────────────────────────────────
# Ensure Docker is installed
# ───────────────────────────────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
  echo "🐳 Docker not found — installing..."

  sudo apt-get update
  sudo apt-get install -y \
    ca-certificates curl gnupg lsb-release

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  
  echo "✅ Docker installed: $(docker --version)"
else
  echo "✅ Docker already installed: $(docker --version)"
fi

# ───────────────────────────────────────────────────────────────────────────────
# Ensure current user is in the docker group
# ───────────────────────────────────────────────────────────────────────────────

# If running non-root and no docker access, re-exec with sudo
if ! groups "$USER" | grep -q '\bdocker\b'; then
  echo "👤 User '$USER' is not in the 'docker' group — adding now..."
  sudo usermod -aG docker "$USER"
  echo "⚠️  You are not yet in the 'docker' group. Re-running with sudo..."
  exec sudo "$0" "$@"
fi

# If still not root or not in docker group, fallback check
if ! docker info &>/dev/null; then
  echo "🚫 Still cannot access Docker. Re-running with sudo..."
  exec sudo "$0" "$@"
fi


# ───────────────────────────────────────────────────────────────────────────────
# Ensure Cosign is installed
# ───────────────────────────────────────────────────────────────────────────────
if ! command -v cosign &>/dev/null; then
  echo "🔍 Cosign not found — installing..."

  COSIGN_LATEST="$(curl -sSf https://api.github.com/repos/sigstore/cosign/releases/latest \
    | grep -Po '"tag_name": *"\K[^"]+')"

  curl -fsSL -o cosign "https://github.com/sigstore/cosign/releases/download/${COSIGN_LATEST}/cosign-linux-amd64"
  chmod +x cosign
  sudo mv cosign /usr/local/bin/

  echo "✅ Cosign ${COSIGN_LATEST} installed."
else
  echo "✅ Cosign already installed: $(cosign version)"
fi

# ───────────────────────────────────────────────────────────────────────────────
# Signing Process
# ───────────────────────────────────────────────────────────────────────────────
echo "1️ Pulling base image: ${SOURCE_IMAGE}"
docker pull "${SOURCE_IMAGE}"

echo "2️ Tagging for registry: ${TARGET_IMAGE}"
docker tag "${SOURCE_IMAGE}" "${TARGET_IMAGE}"

echo "3 Pushing image to registry: ${TARGET_IMAGE}"
if ! docker push "${TARGET_IMAGE}"; then
  echo "❌ Failed to push image: ${TARGET_IMAGE}"
  echo "🚨 This may be due to:"
  echo "  • Missing Docker login (run: sudo docker login)"
  echo "  • Repository '${REPO_NAME}' not existing on Docker Hub"
  echo "👉 Visit https://hub.docker.com/repositories to create it manually."
  exit 1
fi

DIGEST=$(docker inspect --format '{{index .RepoDigests 0}}' "${TARGET_IMAGE}" | cut -d'@' -f2)
PULL_URL="${TARGET_IMAGE%@*}@${DIGEST}"

echo "📦 Image pushed with digest: ${DIGEST}"
echo "🔗 Pull URL: docker pull ${PULL_URL}"

echo "4️⃣ Signing image with Cosign..."
cosign sign --key "${COSIGN_KEY}" "${TARGET_IMAGE}"

echo "5️⃣ Verifying signature..."
cosign verify --key "${COSIGN_PUB}" "${TARGET_IMAGE}"

echo "✅ Done: Image signed and verified."
