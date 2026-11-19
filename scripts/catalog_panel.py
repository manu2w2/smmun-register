"""Servidor de consulta local. Requiere Supabase local y npm run build."""

from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
PORT = 8765
QUERY = """
select jsonb_build_object(
  'representations', coalesce((
    select jsonb_agg(to_jsonb(r) order by r.edition, r.committee, r.representation_name)
    from catalog.representations r
  ), '[]'::jsonb),
  'runs', coalesce((
    select jsonb_agg(to_jsonb(recent) order by started_at desc)
    from (
      (select distinct on (edition) id, edition, mode, status, started_at, finished_at,
        altas, cambios, iguales, ausentes, error_code
       from catalog.sync_runs order by edition, started_at desc)
      union
      (select distinct on (edition) id, edition, mode, status, started_at, finished_at,
        altas, cambios, iguales, ausentes, error_code
       from catalog.sync_runs where mode = 'apply' and status = 'success'
       order by edition, started_at desc)
    ) recent
  ), '[]'::jsonb)
) as catalog;
"""


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.headers.get("Host") != f"127.0.0.1:{PORT}":
            self.send_error(403)
            return
        site = self.headers.get("Sec-Fetch-Site")
        if site and site not in ("same-origin", "none"):
            self.send_error(403)
            return
        if urlsplit(self.path).path == "/api/catalog":
            self.catalog()
            return
        super().do_GET()

    def list_directory(self, path):
        self.send_error(404)
        return None

    def catalog(self):
        environment = {key: value for key, value in os.environ.items()
                       if not key.upper().startswith("SUPABASE_")}
        environment["DO_NOT_TRACK"] = "1"
        command = ["node", str(ROOT / "node_modules/supabase/dist/supabase.js"),
                   "db", "query", "--read-only", "--output", "json", QUERY]
        try:
            result = subprocess.run(command, cwd=ROOT, env=environment, capture_output=True,
                                    text=True, encoding="utf-8", timeout=20, check=True)
            data = json.loads(result.stdout)["rows"][0]["catalog"]
            response = json.dumps(data, ensure_ascii=False).encode("utf-8")
        except (subprocess.SubprocessError, OSError, ValueError, KeyError, IndexError):
            self.send_error(503, "No se pudo consultar Supabase local")
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)

    def log_message(self, format, *args):
        return


def main():
    if not (BUILD / "catalogo" / "index.html").is_file():
        raise SystemExit("Ejecuta npm run build antes de iniciar el panel.")
    handler = partial(Handler, directory=str(BUILD))
    with ThreadingHTTPServer(("127.0.0.1", PORT), handler) as server:
        print(f"Panel local: http://127.0.0.1:{PORT}/catalogo/", flush=True)
        server.serve_forever()


if __name__ == "__main__":
    main()
