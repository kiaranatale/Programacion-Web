"""Convierte el CSV de comisiones del SGA actual en un seed SQL.

El CSV se baja con sga/scripts/comisiones_a_csv.js (ver sga/ROADMAP.md,
"Cómo bajar las comisiones y horarios"). Uso:

    python3 sga/scripts/csv_a_seed_comisiones.py comisiones_sga.csv > sga/supabase/seed_comisiones.sql

Cada fila es una comisión: nombre, horarios ("Jueves 19:00 - 22:00 Aula
ITBA: 003T #----> SDT Aula externa: Presencial ..."), y cupo con
inscriptos ("3 / 24", "2 / Ilimitado"). Si el CSV trae una columna de
profesores, se descarta: no se cargan datos de personas reales.
"""

import csv
import re
import sys
from datetime import datetime

PERIODOS = {"Primer Cuat.": "1C", "Segundo Cuat.": "2C"}
DIAS = {
    "Lunes": "LUNES", "Martes": "MARTES", "Miércoles": "MIERCOLES", "Jueves": "JUEVES",
    "Viernes": "VIERNES", "Sábado": "SABADO", "Domingo": "DOMINGO",
}
BLOQUE = re.compile(r"(" + "|".join(DIAS) + r") (\d{1,2}:\d{2}) - (\d{1,2}:\d{2})")
AULA = re.compile(r"Aula ITBA: (\S+) #----> (.*?)(?= Aula externa:|$)")
MODALIDAD = re.compile(r"Aula externa: (.*)$")
# Sede del SGA → edificio de seed_aulas.sql (para aulas que no estén cargadas)
EDIFICIOS = {"Sede Distrito Financiero": "SEDE-DM", "Sede Rectorado": "SEDE-RE"}


def sql(texto) -> str:
    if texto is None:
        return "NULL"
    return "'" + str(texto).replace("'", "''") + "'"


def fecha(texto: str) -> str | None:
    texto = (texto or "").strip()
    return datetime.strptime(texto, "%d/%m/%Y").strftime("%Y-%m-%d") if texto else None


def hora(texto: str) -> str:
    h, m = texto.split(":")
    return "23:59" if int(h) >= 24 else f"{int(h):02d}:{m}"


def modalidad(texto: str, aula: str | None) -> str:
    t = texto.lower()
    if "asincr" in t:
        return "VIRTUAL_ASINCRONICO"
    if t.startswith("virtual"):
        return "VIRTUAL_SINCRONICO"
    # Presencial, "Presencial - SDR" y Blended (la parte con aula es presencial)
    return "PRESENCIAL" if aula or not t.startswith("blended") else "VIRTUAL_SINCRONICO"


def horarios(texto: str) -> list[tuple]:
    """'Jueves 19:00 - 22:00 Aula ITBA: 003T #----> SDT Aula externa: Blended Viernes ...'
    → [(dia, desde, hasta, modalidad, aula, sede), ...]"""
    inicios = list(BLOQUE.finditer(texto))
    salida = []
    for i, m in enumerate(inicios):
        resto = texto[m.end():inicios[i + 1].start() if i + 1 < len(inicios) else len(texto)].strip()
        a = AULA.search(resto)
        mo = MODALIDAD.search(resto)
        aula, sede = (a.group(1), a.group(2).strip()) if a else (None, None)
        desde, hasta = hora(m.group(2)), hora(m.group(3))
        if hasta <= desde:
            continue
        salida.append((DIAS[m.group(1)], desde, hasta, modalidad(mo.group(1).strip() if mo else "", aula), aula, sede))
    return salida


def cupo(texto: str) -> tuple[int | None, int | None]:
    """'3 / 24' → (3, 24); '2 / Ilimitado' → (2, None)."""
    m = re.match(r"\s*(\d+)\s*/\s*(\S+)", texto or "")
    if not m:
        return None, None
    maximo = int(m.group(2)) if m.group(2).isdigit() and int(m.group(2)) > 0 else None
    return int(m.group(1)), maximo


def main(ruta: str) -> None:
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        filas = list(csv.DictReader(f))

    comisiones = {}  # (codigo, anio, periodo, inicio, nombre) → datos; la última fila gana
    salteadas = []
    for f in filas:
        nombres = [n.strip() for n in f["encabezado"].split("|")]
        celdas = [c.strip() for c in f["celdas"].split(" | ")]
        if len(celdas) != len(nombres) or f["periodo"].strip() not in PERIODOS:
            salteadas.append(f"{f['codigo']} ({f['celdas'][:40]})")
            continue
        fila = dict(zip(nombres, celdas))
        nombre = fila.get("Comisión", "").strip()
        if not nombre:
            continue
        periodo = PERIODOS[f["periodo"].strip()]
        anio = int(f["anio"])
        inicio, fin = fecha(f.get("comienzo", "")), fecha(f.get("fin", ""))
        inscriptos, maximo = cupo(fila.get("Cupo", ""))
        comisiones[(f["codigo"].strip(), anio, periodo, inicio, nombre)] = {
            "fin": fin, "cupo": maximo, "inscriptos": inscriptos, "horarios": horarios(fila.get("Horarios", "")),
        }

    periodos = sorted({(a, p) for _, a, p, _, _ in comisiones})
    n_horarios = sum(len(c["horarios"]) for c in comisiones.values())
    materias = {k[0] for k in comisiones}

    out = sys.stdout.write
    out("-- =====================================================================\n")
    out(f"-- Comisiones del SGA actual: {len(comisiones)} comisiones de {len(materias)} materias,\n")
    out(f"-- {n_horarios} bloques de horario ({', '.join(f'{p} {a}' for a, p in periodos)}).\n")
    out("-- Generado con sga/scripts/csv_a_seed_comisiones.py. Correr después de\n")
    out("-- seed_cursos.sql y seed_aulas.sql. Se puede correr más de una vez:\n")
    out("-- actualiza cupo e inscriptos y reemplaza los horarios de esas comisiones.\n")
    out("-- No incluye profesores (datos de personas reales).\n")
    if salteadas:
        out(f"-- Filas sin interpretar ({len(salteadas)}): {', '.join(salteadas[:20])}\n")
    out("-- =====================================================================\n\n")
    out("BEGIN;\n\n")

    out("CREATE TEMP TABLE csv_comision (codigo TEXT, anio INTEGER, periodo TEXT, inicio DATE, fin DATE,\n")
    out("    nombre TEXT, cupo INTEGER, inscriptos INTEGER) ON COMMIT DROP;\n")
    out("INSERT INTO csv_comision VALUES\n")
    out(",\n".join(
        f"    ({sql(c)}, {a}, {sql(p)}, {sql(i)}, {sql(d['fin'])}, {sql(n)}, {d['cupo'] or 'NULL'}, "
        f"{'NULL' if d['inscriptos'] is None else d['inscriptos']})"
        for (c, a, p, i, n), d in sorted(comisiones.items(), key=lambda x: tuple(str(v) for v in x[0]))))
    out(";\n\n")

    out("CREATE TEMP TABLE csv_horario (codigo TEXT, anio INTEGER, periodo TEXT, inicio DATE, comision TEXT,\n")
    out("    dia sga.dia_semana, desde TIME, hasta TIME, modalidad sga.modalidad_horario, aula TEXT, sede TEXT) ON COMMIT DROP;\n")
    bloques = [
        f"    ({sql(c)}, {a}, {sql(p)}, {sql(i)}, {sql(n)}, {sql(dia)}, {sql(de)}, {sql(ha)}, {sql(mo)}, {sql(au)}, {sql(se)})"
        for (c, a, p, i, n), d in sorted(comisiones.items(), key=lambda x: tuple(str(v) for v in x[0]))
        for dia, de, ha, mo, au, se in d["horarios"]
    ]
    if bloques:
        out("INSERT INTO csv_horario VALUES\n" + ",\n".join(bloques) + ";\n\n")

    out("""-- Curso de cada comisión: el de esa fecha de inicio o, sin fecha, el
-- primero del período. Los que no existen se crean (sin fechas en el CSV:
-- 1C del 01/03 al 15/07, 2C del 26/07 al 31/12).
INSERT INTO sga.curso (materia_id, anio, periodo, fecha_inicio, fecha_fin)
SELECT DISTINCT m.id, x.anio, x.periodo,
    COALESCE(x.inicio, make_date(x.anio, 1, 1) + (CASE x.periodo WHEN '1C' THEN '%s' ELSE '%s' END)::INTERVAL),
    COALESCE(x.fin, make_date(x.anio, 1, 1) + (CASE x.periodo WHEN '1C' THEN '%s' ELSE '%s' END)::INTERVAL)
FROM csv_comision x
JOIN sga.materia m ON m.codigo = x.codigo
WHERE NOT EXISTS (
    SELECT 1 FROM sga.curso c
    WHERE c.materia_id = m.id AND c.anio = x.anio AND c.periodo = x.periodo
      AND (x.inicio IS NULL OR c.fecha_inicio = x.inicio))
ON CONFLICT (materia_id, anio, periodo, fecha_inicio) DO NOTHING;

CREATE TEMP TABLE csv_curso ON COMMIT DROP AS
SELECT DISTINCT ON (x.codigo, x.anio, x.periodo, x.inicio, x.nombre)
    x.*, c.id AS curso_id
FROM csv_comision x
JOIN sga.materia m ON m.codigo = x.codigo
JOIN sga.curso c ON c.materia_id = m.id AND c.anio = x.anio AND c.periodo = x.periodo
    AND (x.inicio IS NULL OR c.fecha_inicio = x.inicio)
ORDER BY x.codigo, x.anio, x.periodo, x.inicio, x.nombre, c.fecha_inicio, c.id;

INSERT INTO sga.comision (curso_id, nombre, cupo, inscriptos_sga)
SELECT curso_id, nombre, cupo, inscriptos FROM csv_curso
ON CONFLICT (curso_id, nombre) DO UPDATE
SET cupo = EXCLUDED.cupo, inscriptos_sga = EXCLUDED.inscriptos_sga;

-- Aulas que no están en seed_aulas.sql, en el edificio de su sede
INSERT INTO sga.aula (edificio_id, codigo, capacidad)
SELECT DISTINCT ON (h.aula) e.id, h.aula, NULL::INTEGER
FROM csv_horario h
JOIN sga.edificio e ON e.codigo = CASE h.sede %s ELSE 'SIN-EDIF' END
WHERE h.aula IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sga.aula a WHERE a.codigo = h.aula)
ORDER BY h.aula
ON CONFLICT (edificio_id, codigo) DO NOTHING;

-- Horarios: se reemplazan los de las comisiones del CSV
DELETE FROM sga.horario_comision hc
USING csv_curso x JOIN sga.comision co ON co.curso_id = x.curso_id AND co.nombre = x.nombre
WHERE hc.comision_id = co.id;

INSERT INTO sga.horario_comision (comision_id, dia_semana, hora_inicio, hora_fin, aula_id, modalidad)
SELECT co.id, h.dia, h.desde, h.hasta,
    (SELECT a.id FROM sga.aula a WHERE a.codigo = h.aula ORDER BY a.id LIMIT 1), h.modalidad
FROM csv_horario h
JOIN csv_curso x ON x.codigo = h.codigo AND x.anio = h.anio AND x.periodo = h.periodo
    AND x.inicio IS NOT DISTINCT FROM h.inicio AND x.nombre = h.comision
JOIN sga.comision co ON co.curso_id = x.curso_id AND co.nombre = x.nombre;

COMMIT;

SELECT
    %d AS comisiones_csv,
    (SELECT count(*) FROM sga.comision WHERE inscriptos_sga IS NOT NULL) AS comisiones_cargadas,
    (SELECT count(*) FROM sga.horario_comision hc JOIN sga.comision co ON co.id = hc.comision_id
        WHERE co.inscriptos_sga IS NOT NULL) AS horarios_cargados;
""" % (
        "2 months", "6 months 25 days", "6 months 14 days", "11 months 30 days",
        " ".join(f"WHEN {sql(s)} THEN {sql(e)}" for s, e in EDIFICIOS.items()),
        len(comisiones),
    ))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
