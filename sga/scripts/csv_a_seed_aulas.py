"""Convierte el CSV de "Administración → Ocupación de Aulas" del SGA actual
en un seed SQL con las aulas reales y su ocupación semanal de referencia.

El CSV se baja con el script de consola descripto en sga/ROADMAP.md
("Cómo bajar la ocupación de aulas"). Uso:

    python3 sga/scripts/csv_a_seed_aulas.py ocupacion_aulas_sga.csv 2026-07-26 2026-12-31 \\
        > sga/supabase/seed_aulas.sql

Los dos últimos argumentos son el período en que vale la ocupación (el
cuatrimestre de la semana bajada).
"""

import csv
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta

DIAS = ["LUNES", "MARTES", "MIERCOLES", "JUEVES", "VIERNES", "SABADO", "DOMINGO"]
COLORES = {"#99ccff": "CURSO", "#79d279": "EVENTO", "#ff4d4d": "SUPERPOSICION"}
# Edificio según la letra final del código (como figura en los horarios del
# SGA: "701F → Sede Distrito Financiero", "110R → Sede Rectorado")
EDIFICIOS = {
    "F": ("SEDE-DM", "Sede Distrito Financiero"),
    "R": ("SEDE-RE", "Sede Rectorado"),
}
SIN_EDIFICIO = ("SIN-EDIF", "Sin edificio asignado")


def sql(texto):
    return "NULL" if texto is None else "'" + str(texto).replace("'", "''") + "'"


def separar(nombre):
    """'001R (48)' -> ('001R', 48); capacidad 0 o ausente -> None."""
    m = re.match(r"^(.*?)\s*\((\d+)\)$", nombre.strip())
    if not m:
        return nombre.strip(), None
    capacidad = int(m.group(2))
    return m.group(1).strip(), capacidad or None


def edificio(codigo):
    m = re.match(r"^\d+([A-Z])$", codigo)
    return EDIFICIOS.get(m.group(1), SIN_EDIFICIO) if m else SIN_EDIFICIO


def main(ruta, desde, hasta):
    with open(ruta, encoding="utf-8-sig", newline="") as f:
        filas = list(csv.DictReader(f))

    aulas = {}
    ocupadas = defaultdict(list)  # (aula, dia) -> [(minuto, tipo)]
    fechas = set()
    for f in filas:
        codigo, capacidad = separar(f["aula"])
        aulas[codigo] = capacidad
        color = f["marca"].split("|")[-1].strip().lower()
        if color not in COLORES:
            continue
        fecha = datetime.strptime(f["fecha"], "%d/%m/%Y")
        fechas.add(fecha)
        h, m = map(int, f["desde"].split(":"))
        ocupadas[(codigo, DIAS[fecha.weekday()])].append((h * 60 + m, COLORES[color]))

    # Une medias horas consecutivas del mismo tipo en un bloque
    bloques = []
    for (codigo, dia), franjas in sorted(ocupadas.items()):
        franjas.sort()
        inicio, fin, tipo = franjas[0][0], franjas[0][0] + 30, franjas[0][1]
        for minuto, t in franjas[1:]:
            if minuto == fin and t == tipo:
                fin += 30
            else:
                bloques.append((codigo, dia, inicio, fin, tipo))
                inicio, fin, tipo = minuto, minuto + 30, t
        bloques.append((codigo, dia, inicio, fin, tipo))

    semana = min(fechas).strftime("%d/%m/%Y") if fechas else "?"
    fuente = f"semana del {semana}"
    hora = lambda m: f"{m // 60:02d}:{m % 60:02d}"
    edificios = sorted({edificio(c) for c in aulas})

    out = sys.stdout.write
    out("-- =====================================================================\n")
    out(f"-- Aulas del SGA actual ({len(aulas)}) y su ocupación de referencia de la\n")
    out(f"-- {fuente} ({len(bloques)} bloques), vigente del {desde} al {hasta}.\n")
    out("-- Generado con sga/scripts/csv_a_seed_aulas.py. Correr después de\n")
    out("-- seed.sql. Se puede correr más de una vez.\n")
    out("--\n")
    out("-- Edificio según la letra final del código (F: Sede Distrito Financiero,\n")
    out("-- R: Sede Rectorado); el resto queda en \"Sin edificio asignado\".\n")
    out("-- Capacidad 0 o ausente en el SGA queda como NULL (sin dato).\n")
    out("-- =====================================================================\n\n")
    out("BEGIN;\n\n")

    out("INSERT INTO sga.edificio (codigo, nombre) VALUES\n")
    out(",\n".join(f"    ({sql(c)}, {sql(n)})" for c, n in edificios))
    out("\nON CONFLICT (codigo) DO NOTHING;\n\n")

    out("INSERT INTO sga.aula (edificio_id, codigo, capacidad)\n")
    out("SELECT e.id, x.codigo, x.capacidad\nFROM (VALUES\n")
    out(",\n".join(
        f"    ({sql(edificio(c)[0])}, {sql(c)}, {cap if cap else 'NULL'}::INTEGER)"
        for c, cap in sorted(aulas.items())
    ))
    out("\n) AS x (edificio, codigo, capacidad)\n")
    out("JOIN sga.edificio e ON e.codigo = x.edificio\n")
    out("ON CONFLICT (edificio_id, codigo) DO UPDATE SET capacidad = EXCLUDED.capacidad;\n\n")

    out("INSERT INTO sga.aula_ocupacion_referencia\n")
    out("    (aula_id, dia_semana, hora_inicio, hora_fin, tipo, vigencia_desde, vigencia_hasta, fuente)\n")
    out("SELECT a.id, x.dia::sga.dia_semana, x.inicio::TIME, x.fin::TIME, x.tipo,\n")
    out(f"       DATE {sql(desde)}, DATE {sql(hasta)}, {sql(fuente)}\nFROM (VALUES\n")
    out(",\n".join(
        f"    ({sql(edificio(c)[0])}, {sql(c)}, {sql(d)}, {sql(hora(i))}, {sql(hora(fi))}, {sql(t)})"
        for c, d, i, fi, t in bloques
    ))
    out("\n) AS x (edificio, aula, dia, inicio, fin, tipo)\n")
    out("JOIN sga.edificio e ON e.codigo = x.edificio\n")
    out("JOIN sga.aula a ON a.edificio_id = e.id AND a.codigo = x.aula\n")
    out("ON CONFLICT (aula_id, dia_semana, hora_inicio, vigencia_desde) DO NOTHING;\n\n")
    out("COMMIT;\n\n")
    out("SELECT\n")
    out("    (SELECT count(*) FROM sga.aula) AS aulas,\n")
    out("    (SELECT count(*) FROM sga.aula_ocupacion_referencia) AS bloques_de_referencia;\n")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
