#!/usr/bin/env bash
# Arma la base desde cero en un Postgres común y corre los tests SQL:
#   1. Lo mínimo de Supabase (tests/sql/supabase_stub.sql).
#   2. Todas las migraciones, en orden.
#   3. Los seeds, dos veces (tienen que poder volver a correrse).
#   4. Todos los tests de tests/sql.
# Usa las variables estándar de psql (PGHOST, PGPORT, PGUSER, PGPASSWORD,
# PGDATABASE). Lo corre GitHub Actions en cada push; localmente:
#   PGHOST=localhost PGUSER=postgres PGDATABASE=sga_test bash sga/scripts/probar_base.sh
# NO apuntarlo al proyecto de Supabase.
set -euo pipefail

cd "$(dirname "$0")/.."
PSQL=(psql -X -q -v ON_ERROR_STOP=1)

echo "== Supabase mínimo"
"${PSQL[@]}" -f tests/sql/supabase_stub.sql

echo "== Migraciones"
for f in supabase/migrations/*.sql; do
  echo "   $(basename "$f")"
  "${PSQL[@]}" -f "$f"
done

# Mismo orden que en el README
SEEDS=(seed seed_plan_a22 seed_plan_bio22 seed_plan_aer25 seed_plan_c23 seed_plan_e11 seed_cursos seed_aulas seed_usuarios seed_legajo_demo seed_hoy seed_mensajes
       seed_autoridades_encuestas seed_facturas seed_docencia seed_finales seed_cursadas seed_eventos seed_proyectos seed_tramites seed_intercambios)
for vuelta in 1 2; do
  echo "== Seeds (vuelta $vuelta)"
  for s in "${SEEDS[@]}"; do
    "${PSQL[@]}" -f "supabase/$s.sql" > /dev/null
  done
done

echo "== Tests"
fallas=0
for t in tests/sql/*_test.sql; do
  if salida=$("${PSQL[@]}" -f "$t" 2>&1 > /dev/null); then
    echo "   OK    $(basename "$t")"
  else
    echo "   FALLA $(basename "$t")"
    echo "$salida" | grep -E "ERROR|psql:" | head -5 | sed 's/^/         /'
    fallas=$((fallas + 1))
  fi
done

if [ "$fallas" -gt 0 ]; then
  echo "$fallas test(s) fallaron"
  exit 1
fi
echo "Todos los tests pasaron"
