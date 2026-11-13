#!/usr/bin/env bash
# Execute SUR l'instance EC2 (via: ssh host "bash -s -- <args>" < scripts/deploy.sh)
# Usage: deploy.sh <image> <container-name> <host-port> <infisical-env>
# Prerequis serveur : /etc/php-devops-tp/deploy.env (chmod 600, proprietaire = utilisateur de deploiement)
#   GHCR_USERNAME, GHCR_READ_TOKEN (PAT read:packages), INFISICAL_CLIENT_ID,
#   INFISICAL_CLIENT_SECRET, INFISICAL_PROJECT_ID
set -euo pipefail

IMAGE="${1:?image}"; NAME="${2:?container name}"; PORT="${3:?port}"; INF_ENV="${4:?infisical env}"
ENV_FILE=/etc/php-devops-tp/deploy.env
[ -r "$ENV_FILE" ] || { echo "Fichier $ENV_FILE introuvable"; exit 1; }
# shellcheck disable=SC1090
source "$ENV_FILE"

echo "$GHCR_READ_TOKEN" | docker login ghcr.io -u "$GHCR_USERNAME" --password-stdin
docker pull "$IMAGE"

# Conserver l'ancien conteneur pour pouvoir revenir en arriere
if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  docker rm -f "${NAME}-old" >/dev/null 2>&1 || true
  docker stop "$NAME" >/dev/null && docker rename "$NAME" "${NAME}-old"
fi

docker run -d --name "$NAME" --restart unless-stopped \
  -p "${PORT}:80" \
  --security-opt no-new-privileges:true \
  --memory 256m --cpus 0.5 --pids-limit 200 \
  -e INFISICAL_CLIENT_ID="$INFISICAL_CLIENT_ID" \
  -e INFISICAL_CLIENT_SECRET="$INFISICAL_CLIENT_SECRET" \
  -e INFISICAL_PROJECT_ID="$INFISICAL_PROJECT_ID" \
  -e INFISICAL_ENV="$INF_ENV" \
  "$IMAGE"

# Health check applicatif (l'application renvoie une image PNG)
for i in $(seq 1 15); do
  if curl -fsS -o /dev/null -w '%{content_type}\n' "http://127.0.0.1:${PORT}/" | grep -q 'image/png'; then
    echo "Deploiement OK ($IMAGE)"
    docker rm -f "${NAME}-old" >/dev/null 2>&1 || true
    docker image prune -f >/dev/null
    exit 0
  fi
  sleep 2
done

echo "Health check KO -> rollback"
docker logs --tail 50 "$NAME" || true
docker rm -f "$NAME" >/dev/null 2>&1 || true
if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}-old"; then
  docker rename "${NAME}-old" "$NAME" && docker start "$NAME"
fi
exit 1
