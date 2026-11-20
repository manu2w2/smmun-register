"""Importación manual del catálogo a Supabase local."""

import argparse
import csv
import json
import os
from pathlib import Path
import re
import subprocess
from tempfile import TemporaryDirectory
from unicodedata import normalize


HEADERS = ("comite", "nombre_delegacion", "tipo_delegacion", "permite_codelegacion")
BOOLEAN_VALUES = {"si": True, "sí": True, "true": True, "no": False, "false": False}


def read_catalog(path):
    rows = []
    with path.open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.reader(stream, strict=True)
        headers = next(reader, [])
        if len(headers) != len(HEADERS) or set(headers) != set(HEADERS):
            raise ValueError(f"Encabezados esperados: {', '.join(HEADERS)}")
        columns = [headers.index(name) for name in HEADERS]
        while True:
            line = reader.line_num + 1
            try:
                record = next(reader)
            except StopIteration:
                break
            except csv.Error as error:
                raise ValueError(f"Línea {line}: CSV inválido ({error})") from error
            record = [normalize("NFC", value.strip()) for value in record]
            if not any(record):
                continue
            if len(record) != len(HEADERS) or not all(record):
                raise ValueError(f"Línea {line}: se requieren cuatro campos completos")
            if any("\0" in value for value in record):
                raise ValueError(f"Línea {line}: contiene un carácter nulo")
            committee, name, kind, co_delegation = [record[index] for index in columns]
            if co_delegation.lower() not in BOOLEAN_VALUES:
                raise ValueError(f"Línea {line}: permite_codelegacion debe ser SI/NO o TRUE/FALSE")
            rows.append({
                "source_line": line,
                "committee": committee,
                "representation_name": name,
                "representation_type": kind,
                "allows_co_delegation": BOOLEAN_VALUES[co_delegation.lower()],
            })
    if not rows:
        raise ValueError("El CSV no contiene representaciones")
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--edition", required=True, help="Identificador de edición, por ejemplo prueba")
    parser.add_argument("--csv", required=True, type=Path, help="Archivo CSV UTF-8 separado por comas")
    parser.add_argument("--apply", action="store_true", help="Guarda el lote. Por defecto muestra una vista previa")
    parser.add_argument("--allow-missing", action="store_true", help="Aplica después de revisar las filas ausentes")
    args = parser.parse_args()

    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,63}", args.edition):
        parser.error("--edition admite hasta 64 caracteres: letras minúsculas ASCII, números y guiones")
    if args.allow_missing and not args.apply:
        parser.error("--allow-missing requiere --apply")
    npm_cli = os.getenv("npm_execpath")
    if not npm_cli:
        parser.error("Ejecuta este comando con npm run catalog:import")

    try:
        rows = read_catalog(args.csv)
    except (OSError, ValueError, csv.Error) as error:
        parser.error(str(error))

    # El lote se codifica como hex para transportar texto arbitrario como un literal SQL.
    payload = json.dumps(rows, ensure_ascii=False).encode("utf-8").hex()
    query = (
        "select catalog.import_representations("
        f"'{args.edition}', convert_from(decode('{payload}', 'hex'), 'UTF8')::jsonb,"
        f"{str(args.apply).lower()}, {str(args.allow_missing).lower()}) as importacion;"
    )
    with TemporaryDirectory(prefix="smmun-catalog-") as directory:
        sql_file = Path(directory) / "catalog.sql"
        sql_file.write_text(query, encoding="utf-8")
        command = [
            "node", npm_cli, "exec", "--no", "--", "supabase", "db", "query",
            "--file", str(sql_file), "--output", "json",
        ]
        if not args.apply:
            command.append("--read-only")
        return subprocess.run(command, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
