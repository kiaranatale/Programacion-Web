"""Convierte el CSV de "Académica → Cursos" del SGA actual en un seed SQL.

El CSV se baja con el script de consola descripto en sga/ROADMAP.md
("Cómo bajar el listado de cursos"). Uso:

    python3 sga/scripts/csv_a_seed_cursos.py cursos_sga.csv > sga/supabase/seed_cursos.sql

Solo toma código, materia, departamento, período y fechas. La columna
"alumnos" del CSV se descarta: la cantidad sale de las inscripciones.
"""

import csv
import sys
from datetime import datetime

PERIODOS = {"Primer Cuat.": "1C", "Segundo Cuat.": "2C"}
# Departamentos de versiones anteriores de los seeds, que no existen en el SGA
INVENTADOS = ("A confirmar", "Ciencias Básicas", "Informática")


def sql(texto: str) -> str:
    return "'" + texto.replace("'", "''") + "'"


def fecha(texto: str) -> str:
    return datetime.strptime(texto, "%d/%m/%Y").strftime("%Y-%m-%d")


def main(ruta: str) -> None:
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        filas = [f for f in csv.DictReader(f) if f["codigo"].strip()]

    materias = {}
    cursos = set()
    for f in filas:
        codigo = f["codigo"].strip()
        materias.setdefault(codigo, (f["materia"].strip(), f["departamento"].strip()))
        cursos.add((codigo, int(f["anio"]), PERIODOS[f["periodo"].strip()], fecha(f["comienzo"]), fecha(f["fin"])))

    departamentos = sorted({d for _, d in materias.values()})
    periodos = sorted({(a, p) for _, a, p, _, _ in cursos})

    out = sys.stdout.write
    out("-- =====================================================================\n")
    out(f"-- Cursos del SGA actual: {len(cursos)} cursos de {len(materias)} materias\n")
    out(f"-- ({', '.join(f'{p} {a}' for a, p in periodos)}). Generado con\n")
    out("-- sga/scripts/csv_a_seed_cursos.py a partir del listado de cursos.\n")
    out("-- Correr después de seed_plan_a22.sql. Se puede correr más de una vez.\n")
    out("--\n")
    out("-- Las materias nuevas quedan con créditos desconocidos (NULL): el\n")
    out("-- listado de cursos no los trae. Las que ya existían conservan nombre y\n")
    out("-- créditos; solo se completa el departamento si no lo tenían.\n")
    out("-- =====================================================================\n\n")
    out("BEGIN;\n\n")

    out("INSERT INTO sga.departamento (nombre) VALUES\n")
    out(",\n".join(f"    ({sql(d)})" for d in departamentos))
    out("\nON CONFLICT (nombre) DO NOTHING;\n\n")

    out("CREATE TEMP TABLE csv_materia (codigo TEXT, nombre TEXT, departamento TEXT) ON COMMIT DROP;\n")
    out("INSERT INTO csv_materia VALUES\n")
    out(",\n".join(f"    ({sql(c)}, {sql(n)}, {sql(d)})" for c, (n, d) in sorted(materias.items())))
    out(";\n\n")

    out("INSERT INTO sga.materia (codigo, nombre, departamento_id, creditos)\n")
    out("SELECT m.codigo, m.nombre, d.id, NULL\n")
    out("FROM csv_materia m JOIN sga.departamento d ON d.nombre = m.departamento\n")
    out("ON CONFLICT (codigo) DO NOTHING;\n\n")

    out("-- Departamento real para las materias que estaban en uno provisorio\n")
    out("UPDATE sga.materia ma\nSET departamento_id = d.id\n")
    out("FROM csv_materia m, sga.departamento d, sga.departamento actual\n")
    out("WHERE ma.codigo = m.codigo AND d.nombre = m.departamento\n")
    out("  AND actual.id = ma.departamento_id\n")
    out(f"  AND actual.nombre IN ({', '.join(sql(x) for x in INVENTADOS)});\n\n")

    out("DELETE FROM sga.departamento d\n")
    out(f"WHERE d.nombre IN ({', '.join(sql(x) for x in INVENTADOS)})\n")
    out("  AND NOT EXISTS (SELECT 1 FROM sga.materia m WHERE m.departamento_id = d.id);\n\n")

    out("INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)\n")
    out("SELECT m.id, x.anio, x.periodo, x.inicio, x.fin\nFROM (VALUES\n")
    out(",\n".join(
        f"    ({sql(c)}, {a}, {sql(p)}, DATE {sql(i)}, DATE {sql(fi)})"
        for c, a, p, i, fi in sorted(cursos)
    ))
    out("\n) AS x (codigo, anio, periodo, inicio, fin)\n")
    out("JOIN sga.materia m ON m.codigo = x.codigo\n")
    out("ON CONFLICT (materia_id, anio, periodo, fecha_inicio) DO NOTHING;\n\n")
    out("COMMIT;\n\n")

    out("SELECT\n")
    out("    (SELECT count(*) FROM sga.curso) AS cursos,\n")
    out("    (SELECT count(*) FROM sga.materia) AS materias,\n")
    out("    (SELECT count(*) FROM sga.materia m JOIN sga.departamento d ON d.id = m.departamento_id\n")
    out("        WHERE d.nombre = 'A confirmar') AS materias_sin_departamento;\n")


if __name__ == "__main__":
    main(sys.argv[1])
