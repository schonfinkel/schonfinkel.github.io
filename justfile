set dotenv-load

# Define source directory
STATIC_SRC := 'static'
STATIC_JS_SRC := STATIC_SRC / 'js'

D3_VERSION := 'v7'
D3_FILENAME := "d3.min.js"
D3_URL := "https://d3js.org/d3." + D3_VERSION + ".min.js"
D3_PATH := STATIC_JS_SRC / D3_FILENAME

default:
  just --list

# Generate the Markdown files
build: clean
    python fix-html.py
    emacs $(pwd) --batch --load publish.el

# Download D3
d3-download:
    curl -L -o {{ D3_PATH }} {{ D3_URL }}

# Build braph
graph:
    python generate-graph.py

# Removes org backups
remove-org:
    #!/usr/bin/env bash
    find . -iname "#*.org#" | xargs rm -f
    find . -iname "*~undo-tree~" | xargs rm -f
    echo "Finished!"

# Cleans the current environment
clean: remove-org
    rm -rf content
    rm -f .#content.org
    rm -rf public
