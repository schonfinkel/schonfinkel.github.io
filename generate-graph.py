import fileinput
import itertools
import json
import os
import pathlib
import sqlite3
import sys

import networkx as nx
import networkx.algorithms.link_analysis.pagerank_alg as pag
import networkx.algorithms.community as com
from networkx.drawing.nx_pydot import read_dot
from networkx.readwrite import json_graph

# Number of predicted missing links
N_MISSING = 10  
# Number of nodes in the final graph 
MAX_NODES = 500

ROOT_PATH = pathlib.Path(__file__).parent.resolve()
NOTES_PATH = pathlib.Path(ROOT_PATH / "notes" / "org-roam.db").resolve()

def to_rellink(inp: str) -> str:
    return pathlib.Path(inp).stem

def build_graph() -> nx.DiGraph:
    """Build a graph from the org-roam database."""
    graph = nx.DiGraph()
    conn = sqlite3.connect(NOTES_PATH)

    # Query all nodes first
    nodes = conn.execute("SELECT file, id, title FROM nodes WHERE level = 0;")
    # A double JOIN to get all nodes that are connected by a link
    links = conn.execute("SELECT n1.id, nodes.id FROM ((nodes AS n1) "
                         "JOIN links ON n1.id = links.source) "
                         "JOIN (nodes AS n2) ON links.dest = nodes.id "
                         "WHERE links.type = '\"id\"';")
    # Populate the graph
    graph.add_nodes_from((n[1], {
        "label": n[2].strip("\""),
        "tooltip": n[2].strip("\""),
        "lnk": to_rellink(n[0]).lower(),
        "id": n[1].strip("\"")
    }) for n in  nodes)
    graph.add_edges_from(n for n in links if n[0] in graph.nodes and n[1] in graph.nodes)
    conn.close()
    return graph

def compute_centrality(dot_graph: nx.DiGraph) -> None:
    """Add a `centrality` attribute to each node with its PageRank score.
    """
    simp_graph = nx.Graph(dot_graph)
    central = pag.pagerank(simp_graph)
    min_cent = min(central.values())
    central = {i: central[i] - min_cent for i in central}
    max_cent = max(central.values())
    central = {i: central[i] / max_cent for i in central}
    nx.set_node_attributes(dot_graph, central, "centrality")
    sorted_cent = sorted(dot_graph, key=lambda x: dot_graph.nodes[x]["centrality"])
    for n in sorted_cent[:-MAX_NODES]:
        dot_graph.remove_node(n)


def compute_communities(dot_graph: nx.DiGraph, n_com: int) -> None:
    """Add a `communityLabel` attribute to each node according to their
    computed community.
    """
    simp_graph = nx.Graph(dot_graph)
    communities = com.girvan_newman(simp_graph)
    labels = [tuple(sorted(c) for c in unities) for unities in
              itertools.islice(communities, n_com - 1, n_com)][0]
    label_dict = {l_key: i for i in range(len(labels)) for l_key in labels[i]}
    nx.set_node_attributes(dot_graph, label_dict, "communityLabel")


def add_missing_links(dot_graph: nx.DiGraph, n_missing: int) -> None:
    """Add some missing links to the graph by using top ranking inexisting
    links by ressource allocation index.
    """
    simp_graph = nx.Graph(dot_graph)
    preds = nx.ra_index_soundarajan_hopcroft(simp_graph, community="communityLabel")
    new = sorted(preds, key=lambda x: -x[2])[:n_missing]
    for link in new:
        sys.stderr.write(f"Predicted edge {link[0]} {link[1]}\n")
        dot_graph.add_edge(link[0], link[1], predicted=link[2])

def update_html(graph_data: nx.DiGraph) -> None:
    JS_GRAPH = json_graph.node_link_data(graph_data)
    JSON_GRAPH = json.dumps(JS_GRAPH)
    pathlib.Path("./static/graph.json").write_text(JSON_GRAPH)
    filepath = pathlib.Path("./static/html/graph.html").resolve()
    for line in fileinput.input([filepath], inplace=True):
        if line.strip().startswith("var graph_data ="):
            line = f"var graph_data = {JSON_GRAPH}\n"
        sys.stdout.write(line)

if __name__ == "__main__":
    sys.stderr.write("Reading graph...")
    DOT_GRAPH = build_graph()
    compute_centrality(DOT_GRAPH)
    number_of_communities = nx.number_weakly_connected_components(DOT_GRAPH)
    compute_communities(DOT_GRAPH, number_of_communities)
    add_missing_links(DOT_GRAPH, N_MISSING)
    update_html(DOT_GRAPH)
    sys.stderr.write("Done...")
