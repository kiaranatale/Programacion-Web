#!/usr/bin/env bash
# Deja lista una Supabase local (`supabase start`, que ya aplicó las
# migraciones) para los tests E2E de app/e2e:
#   1. Corre los seeds (scripts/seeds.sh).
#   2. Crea en Auth los usuarios demo (clave demo1234); el trigger de
#      persona los vincula por mail.
#   3. Escribe app/.env.e2e con la URL y las claves para la app y los tests.
# Uso, desde la raíz del repo y con Docker andando:
#   cd sga && npx supabase start && bash scripts/e2e_preparar.sh
# NO apuntarlo al proyecto de Supabase: usa solo la instancia local.
set -euo pipefail

cd "$(dirname "$0")/.."
SUPABASE=${SUPABASE_CLI:-npx -y supabase@2}

eval "$($SUPABASE status -o env | grep -E '^(DB_URL|API_URL|PUBLISHABLE_KEY|SERVICE_ROLE_KEY)=')"
case "$API_URL" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "La API no es local ($API_URL): no se corre." >&2; exit 1 ;;
esac

source scripts/seeds.sh
echo "== Seeds"
for s in "${SEEDS[@]}"; do
  psql "$DB_URL" -X -q -v ON_ERROR_STOP=1 -f "supabase/$s.sql" > /dev/null
done

echo "== Usuarios demo"
for mail in alumno.demo@itba.edu.ar docente.demo@itba.edu.ar admin.demo@itba.edu.ar; do
  codigo=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$API_URL/auth/v1/admin/users" \
    -H "apikey: $SERVICE_ROLE_KEY" -H "Authorization: Bearer $SERVICE_ROLE_KEY" \
    -H "content-type: application/json" \
    -d "{\"email\":\"$mail\",\"password\":\"demo1234\",\"email_confirm\":true}")
  # 422 = ya existía (se corrió antes)
  case "$codigo" in 200|201|422) echo "   $mail ($codigo)" ;; *) echo "No se pudo crear $mail ($codigo)" >&2; exit 1 ;; esac
done

cat > app/.env.e2e <<EOF
NEXT_PUBLIC_SUPABASE_URL=$API_URL
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=$PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY=$SERVICE_ROLE_KEY
EOF
echo "== Listo: app/.env.e2e"
