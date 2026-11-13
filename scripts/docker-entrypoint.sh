#!/usr/bin/env bash
# Injecte les secrets Infisical dans l'environnement du process Apache/PHP.
# Si les identifiants Infisical sont absents (dev local), on lance la commande telle quelle.
set -euo pipefail

if [ -n "${INFISICAL_CLIENT_ID:-}" ] && [ -n "${INFISICAL_CLIENT_SECRET:-}" ]; then
  INFISICAL_TOKEN="$(infisical login --method=universal-auth \
      --client-id="$INFISICAL_CLIENT_ID" \
      --client-secret="$INFISICAL_CLIENT_SECRET" \
      --silent --plain)"
  export INFISICAL_TOKEN
  unset INFISICAL_CLIENT_SECRET
  exec infisical run --projectId "${INFISICAL_PROJECT_ID:?INFISICAL_PROJECT_ID manquant}" \
       --env "${INFISICAL_ENV:-prod}" -- "$@"
fi

exec "$@"
