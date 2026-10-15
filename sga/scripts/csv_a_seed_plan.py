"""Convierte el CSV de un "Detalle de Planes de estudio" del SGA actual en
un seed SQL como seed_plan_bio22.sql.

El CSV se baja pegando scripts/plan_a_csv.js en la consola del navegador
estando en el detalle del plan. Uso:

    python3 sga/scripts/csv_a_seed_plan.py BIO_22.csv --carrera BIO \\
        --desde 2023-03-01 --hasta 2024-02-01 > sga/supabase/seed_plan_bio22.sql

--desde/--hasta son la primera fecha de "Activo desde" y "Activo hasta"
del listado de planes (primer cuatrimestre: marzo, segundo: agosto,
verano: febrero). Las correlativas a materias que no están en el plan ni
en el catálogo quedan afuera (el control del final lo muestra).
"""

import argparse
import csv
import re
import sys

RE_TITULO_BLOQUE = re.compile(r"\s*\(\s*Título otorgado:.*?\)\s*")
RE_TODOS = re.compile(r"Aprobar todos los [ií]tems \(suma (\d+) cr[ée]ditos\)")
RE_JUNTAR = re.compile(r"Juntar (\d+) cr[ée]ditos")
RE_ITEMS = re.compile(r"Aprobar (\d+) [ií]tem\(s\) \(suma (\d+) cr[ée]ditos\)")


def sql(texto: str) -> str:
    return "'" + texto.replace("'", "''") + "'"


def entero(texto: str) -> int:
    return int(texto) if texto.strip() else 0


def main() -> None:
    args = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    args.add_argument("csv")
    args.add_argument("--carrera", required=True, help="código de la carrera (BIO, K, S, ...)")
    args.add_argument("--desde", required=True, help="vigencia desde, AAAA-MM-DD")
    args.add_argument("--hasta", help="vigencia hasta, AAAA-MM-DD")
    a = args.parse_args()

    with open(a.csv, encoding="utf-8-sig", newline="") as f:
        filas = list(csv.DictReader(f))
    if not filas:
        sys.exit("El CSV está vacío.")
    plan = filas[0]["plan"]

    # Bloques en el orden del SGA, con su requisito (tipo, créditos, ítems)
    bloques: dict[str, tuple[str, int, int | None]] = {}
    for f in filas:
        if f["tipo"] == "TITULO":
            continue
        nombre = RE_TITULO_BLOQUE.sub(" ", f["bloque"]).strip()
        f["bloque"] = nombre
        if nombre in bloques:
            continue
        if m := RE_TODOS.search(f["requisito_bloque"]):
            bloques[nombre] = ("APROBAR_TODOS", int(m.group(1)), None)
        elif m := RE_JUNTAR.search(f["requisito_bloque"]):
            bloques[nombre] = ("JUNTAR_CREDITOS", int(m.group(1)), None)
        elif m := RE_ITEMS.search(f["requisito_bloque"]):
            bloques[nombre] = ("APROBAR_ITEMS", int(m.group(2)), int(m.group(1)))
        else:
            sys.exit(f"Requisito desconocido en el bloque {nombre}: {f['requisito_bloque']}")

    materias = [f for f in filas if f["tipo"] == "MATERIA"]
    huecos = [f for f in filas if f["tipo"] == "HUECO"]
    titulos = [f for f in filas if f["tipo"] == "TITULO"]
    for h in huecos:
        if h["nombre"] not in bloques:
            sys.exit(f"El hueco {h['nombre']} no coincide con ningún bloque de electivas.")
    total = sum(c for r, c, _ in bloques.values() if r == "APROBAR_TODOS")
    hasta = f"DATE '{a.hasta}'" if a.hasta else "NULL"

    out = []
    w = out.append
    w("-- =====================================================================")
    w(f"-- Plan {plan}, generado con scripts/csv_a_seed_plan.py desde el")
    w('-- "Detalle de Planes de estudio" del SGA actual. Correr DESPUÉS de')
    w("-- seed.sql (como seed_plan_a22.sql).")
    w("--")
    w("-- Los departamentos de cada materia no figuran en el detalle del plan:")
    w('-- las materias nuevas quedan en "A confirmar" hasta tener ese dato.')
    w("--")
    w("-- Se puede correr más de una vez.")
    w("-- =====================================================================")
    w("")
    w("BEGIN;")
    w("")
    w("INSERT INTO sga.departamento (nombre) VALUES ('A confirmar')")
    w("ON CONFLICT (nombre) DO NOTHING;")
    w("")
    w("INSERT INTO sga.plan_estudio (carrera_id, codigo, version, creditos_totales, vigencia_desde, vigencia_hasta)")
    w(f"SELECT id, {sql(plan)}, 1, {total}, DATE '{a.desde}', {hasta}")
    w(f"FROM sga.carrera WHERE codigo = {sql(a.carrera)}")
    w("ON CONFLICT (carrera_id, codigo) DO NOTHING;")
    w("")
    w("CREATE TEMP TABLE nuevo_plan ON COMMIT DROP AS")
    w("SELECT p.id FROM sga.plan_estudio p")
    w("JOIN sga.carrera c ON c.id = p.carrera_id")
    w(f"WHERE c.codigo = {sql(a.carrera)} AND p.codigo = {sql(plan)};")
    w("")
    w("INSERT INTO sga.plan_bloque (plan_id, nombre, requisito, creditos, items, orden)")
    w("SELECT p.id, b.nombre, b.requisito::sga.requisito_bloque, b.creditos, b.items, b.orden")
    w("FROM nuevo_plan p")
    w("CROSS JOIN (VALUES")
    w(",\n".join(f"    ({sql(n)}, '{r}', {c}, {it if it else 'NULL::INTEGER'}, {i})" for i, (n, (r, c, it)) in enumerate(bloques.items(), 1)))
    w(") AS b (nombre, requisito, creditos, items, orden)")
    w("ON CONFLICT (plan_id, nombre) DO NOTHING;")
    w("")
    w("-- bloque, código, nombre, créditos, créditos requeridos, año, cuatrimestre,")
    w("-- correlativas (códigos separados por espacio)")
    w("CREATE TEMP TABLE nuevo_materias (")
    w("    bloque TEXT, codigo TEXT, nombre TEXT, creditos INT, requeridos INT,")
    w("    anio SMALLINT, cuatri SMALLINT, correlativas TEXT")
    w(") ON COMMIT DROP;")
    w("")
    w("INSERT INTO nuevo_materias VALUES")
    w(",\n".join(
        f"    ({sql(m['bloque'])}, {sql(m['codigo'])}, {sql(m['nombre'])}, {entero(m['creditos'])}, "
        f"{entero(m['creditos_requeridos'])}, {m['anio'] or 'NULL'}, {m['cuatrimestre'] or 'NULL'}, {sql(m['correlativas'])})"
        for m in materias) + ";")
    w("")
    w("-- Materias (las que ya existían conservan su nombre y departamento)")
    w("INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)")
    w("SELECT DISTINCT ON (m.codigo) m.codigo, m.nombre, d.id, m.creditos")
    w("FROM nuevo_materias m")
    w("JOIN sga.departamento d ON d.nombre = 'A confirmar'")
    w("ON CONFLICT (codigo) DO NOTHING;")
    w("")
    w("-- Ubicación de cada materia en el plan")
    w("INSERT INTO sga.plan_materia (plan_id, materia_id, bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos_requeridos)")
    w("SELECT p.id, ma.id, b.id, m.anio, m.cuatri, m.requeridos")
    w("FROM nuevo_materias m")
    w("CROSS JOIN nuevo_plan p")
    w("JOIN sga.materia ma ON ma.codigo = m.codigo")
    w("JOIN sga.plan_bloque b ON b.plan_id = p.id AND b.nombre = m.bloque")
    w("ON CONFLICT (plan_id, materia_id) DO UPDATE")
    w("SET bloque_id = EXCLUDED.bloque_id,")
    w("    anio_sugerido = EXCLUDED.anio_sugerido,")
    w("    cuatrimestre_sugerido = EXCLUDED.cuatrimestre_sugerido,")
    w("    creditos_requeridos = EXCLUDED.creditos_requeridos;")
    if huecos:
        w("")
        w("-- Huecos de electivas en la grilla del plan")
        w("INSERT INTO sga.plan_hueco_electiva (bloque_id, anio_sugerido, cuatrimestre_sugerido, creditos)")
        w("SELECT b.id, h.anio, h.cuatri, h.creditos")
        w("FROM nuevo_plan p")
        w("JOIN sga.plan_bloque b ON b.plan_id = p.id")
        w("JOIN (VALUES")
        w(",\n".join(f"    ({sql(h['nombre'])}, {h['anio'] or 'NULL::SMALLINT'}, {h['cuatrimestre'] or 'NULL::SMALLINT'}, {entero(h['creditos'])})" for h in huecos))
        w(") AS h (bloque, anio, cuatri, creditos) ON h.bloque = b.nombre")
        w("ON CONFLICT (bloque_id, anio_sugerido, cuatrimestre_sugerido) DO NOTHING;")
    w("")
    w("-- Correlativas del plan (para cursar, con la correlativa regular)")
    w("INSERT INTO sga.correlativa (plan_id, materia_id, materia_requerida_id, tipo_requisito, estado_requerido)")
    w("SELECT p.id, ma.id, req.id, 'PARA_CURSAR', 'REGULAR'")
    w("FROM nuevo_materias m")
    w("CROSS JOIN nuevo_plan p")
    w("CROSS JOIN LATERAL unnest(string_to_array(nullif(m.correlativas, ''), ' ')) AS c (codigo)")
    w("JOIN sga.materia ma  ON ma.codigo = m.codigo")
    w("JOIN sga.materia req ON req.codigo = c.codigo")
    w("ON CONFLICT (plan_id, materia_id, materia_requerida_id, tipo_requisito) DO NOTHING;")
    if titulos:
        w("")
        w("INSERT INTO sga.plan_titulo (plan_id, tipo, nombre, requisito)")
        w("SELECT p.id, t.tipo, t.nombre, t.requisito")
        w("FROM nuevo_plan p")
        w("CROSS JOIN (VALUES")
        w(",\n".join(f"    ({sql(t['bloque'])}, {sql(t['nombre'])}, {sql(t['requisito_bloque'])})" for t in titulos))
        w(") AS t (tipo, nombre, requisito)")
        w("ON CONFLICT (plan_id, nombre) DO NOTHING;")
    w("")
    w("COMMIT;")
    w("")
    esperadas = sum(len(m["correlativas"].split()) for m in materias)
    w(f"-- Control: {len(materias)} materias, {total} créditos en los bloques obligatorios")
    w(f"-- (materias + huecos) y {esperadas} correlativas según el SGA.")
    w("SELECT")
    w(f"    (SELECT count(*) FROM sga.plan_materia pm JOIN sga.plan_estudio p ON p.id = pm.plan_id WHERE p.codigo = {sql(plan)}) AS materias,")
    w("    (SELECT coalesce(sum(m.creditos), 0) FROM sga.plan_materia pm")
    w("        JOIN sga.plan_estudio p ON p.id = pm.plan_id")
    w("        JOIN sga.plan_bloque b ON b.id = pm.bloque_id")
    w("        JOIN sga.materia m ON m.id = pm.materia_id")
    w(f"        WHERE p.codigo = {sql(plan)} AND b.requisito = 'APROBAR_TODOS')")
    w("    + (SELECT coalesce(sum(h.creditos), 0) FROM sga.plan_hueco_electiva h")
    w("        JOIN sga.plan_bloque b ON b.id = h.bloque_id")
    w("        JOIN sga.plan_estudio p ON p.id = b.plan_id")
    w(f"        WHERE p.codigo = {sql(plan)}) AS creditos_plan,")
    w(f"    (SELECT count(*) FROM sga.correlativa c JOIN sga.plan_estudio p ON p.id = c.plan_id WHERE p.codigo = {sql(plan)}) AS correlativas;")
    print("\n".join(out))


if __name__ == "__main__":
    main()
