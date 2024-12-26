import fileinput
import os
import pathlib
import sys

PROJECT_ROOT_PATH = pathlib.Path(__file__).parent.absolute()
PROJECT_OUT_PATH = (PROJECT_ROOT_PATH / pathlib.Path("public")).absolute()

def update_html() -> None:
    URL = os.environ.get("OUT_URL", PROJECT_OUT_PATH)
    filepath = pathlib.Path("./static/html/graph.html").resolve()
    for line in fileinput.input([filepath], inplace=True):
        if line.strip().startswith("var url ="):
            line = f"var url = \"{URL}\"\n"
        sys.stdout.write(line)

if __name__ == "__main__":
    sys.stderr.write("Fixing html...")
    update_html()
    sys.stderr.write("Done...")
