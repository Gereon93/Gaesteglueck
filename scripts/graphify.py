import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
GRAPHIFY_PACKAGE = "graphifyy==0.9.71"
REMOTE_RENDERER = '''<script src="https://unpkg.com/vis-network@9.1.6/standalone/umd/vis-network.min.js"
        integrity="sha384-Ux6phic9PEHJ38YtrijhkzyJ8yQlH8i/+buBR8s3mAZOJrP1gwyvAcIYl3GWtpX1"
        crossorigin="anonymous"></script>'''
LOCAL_RENDERER = '<script src="vendor/vis-network-9.1.6.min.js"></script>'


def main():
    if len(sys.argv) == 1:
        raise SystemExit("Aufruf: python3 scripts/graphify.py <Graphify-Befehl> [Argumente]")
    try:
        result = subprocess.run(
            ["uv", "tool", "run", "--python", "3.12", "--from", GRAPHIFY_PACKAGE,
             "graphify", *sys.argv[1:]],
            cwd=ROOT,
            check=False,
        )
    except FileNotFoundError:
        raise SystemExit("uv fehlt. Installation: https://docs.astral.sh/uv/getting-started/installation/")
    if result.returncode:
        raise SystemExit(result.returncode)
    html_path = ROOT / "graphify-out" / "graph.html"
    if html_path.exists():
        html = html_path.read_text(encoding="utf-8")
        if REMOTE_RENDERER in html:
            html_path.write_text(html.replace(REMOTE_RENDERER, LOCAL_RENDERER), encoding="utf-8")


if __name__ == "__main__":
    main()
