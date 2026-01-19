import fileinput
import itertools
import json
import os
import pathlib
import sqlite3
import sys
import colorsys

import networkx as nx
import networkx.algorithms.link_analysis.pagerank_alg as pag
import networkx.algorithms.community as com
from networkx.readwrite import json_graph

# Number of predicted missing links
N_MISSING = 7
# Number of nodes in the final graph 
MAX_NODES = 500

ROOT_PATH = pathlib.Path(__file__).parent.resolve()
NOTES_PATH = pathlib.Path(ROOT_PATH / "notes" / "org-roam.db").resolve()

def to_rellink(inp: str) -> str:
    return pathlib.Path(inp).stem

def build_graph() -> nx.DiGraph:
    """Build a graph from the org-roam database."""
    graph = nx.DiGraph()
    if not NOTES_PATH.exists():
        sys.stderr.write(f"Error: Database not found at {NOTES_PATH}\n")
        return graph

    conn = sqlite3.connect(NOTES_PATH)
    # Query all nodes first
    nodes = conn.execute("SELECT file, id, title FROM nodes WHERE level = 0;")
    
    graph.add_nodes_from((n[1], {
        "label": n[2].strip("\""),
        "tooltip": n[2].strip("\""),
        "lnk": to_rellink(n[0]).lower(),
        "id": n[1].strip("\"")
    }) for n in nodes)

    # Fetch links: join nodes to links and back to nodes for validation
    links = conn.execute("SELECT n1.id, n2.id FROM nodes AS n1 "
                         "JOIN links ON n1.id = links.source "
                         "JOIN nodes AS n2 ON links.dest = n2.id "
                         "WHERE links.type = '\"id\"';")
    
    graph.add_edges_from(n for n in links if n[0] in graph.nodes and n[1] in graph.nodes)
    conn.close()
    return graph

def compute_centrality(dot_graph: nx.DiGraph) -> None:
    """Add a `centrality` attribute to each node with its PageRank score."""
    if not dot_graph.nodes:
        return
    simp_graph = nx.Graph(dot_graph)
    central = pag.pagerank(simp_graph)
    
    min_cent = min(central.values())
    max_cent = max(central.values())
    
    if max_cent - min_cent > 0:
        central = {i: (central[i] - min_cent) / (max_cent - min_cent) for i in central}
    
    nx.set_node_attributes(dot_graph, central, "centrality")
    
    sorted_cent = sorted(dot_graph, key=lambda x: dot_graph.nodes[x]["centrality"])
    for n in sorted_cent[:-MAX_NODES]:
        dot_graph.remove_node(n)

def compute_communities(dot_graph: nx.DiGraph, n_com: int) -> None:
    """Add a `communityLabel` attribute to each node."""
    if not dot_graph.nodes:
        return
    simp_graph = nx.Graph(dot_graph)
    communities = com.girvan_newman(simp_graph)
    
    try:
        labels = [tuple(sorted(c) for c in unities) for unities in
                  itertools.islice(communities, n_com - 1, n_com)][0]
        label_dict = {l_key: i for i in range(len(labels)) for l_key in labels[i]}
        nx.set_node_attributes(dot_graph, label_dict, "communityLabel")
    except (IndexError, StopIteration):
        # Fallback if no communities can be found
        nx.set_node_attributes(dot_graph, {n: 0 for n in dot_graph.nodes}, "communityLabel")

def assign_node_colors(dot_graph: nx.DiGraph) -> None:
    """Generates deterministic color palette based on community count."""
    communities = {data.get("communityLabel") for _, data in dot_graph.nodes(data=True) 
                   if data.get("communityLabel") is not None}
    
    num_communities = len(communities)
    if num_communities == 0:
        return

    sorted_communities = sorted(list(communities))
    palette = {}

    for i, comm_id in enumerate(sorted_communities):
        # Calculate hue (0 to 1) for full spectrum coverage
        hue = i / num_communities
        # 0.5 lightness is middle-bright; 0.7 saturation is vibrant
        rgb = colorsys.hls_to_rgb(hue, 0.5, 0.7)
        hex_color = '#%02x%02x%02x' % tuple(int(x * 255) for x in rgb)
        palette[comm_id] = hex_color

    node_colors = {node: palette.get(data.get("communityLabel"), "#808080") 
                   for node, data in dot_graph.nodes(data=True)}
    nx.set_node_attributes(dot_graph, node_colors, "color")

def add_missing_links(dot_graph: nx.DiGraph, n_missing: int) -> None:
    """Add missing links using Resource Allocation Index."""
    if not dot_graph.nodes:
        return
    simp_graph = nx.Graph(dot_graph)
    # This requires 'communityLabel' to be set on all nodes
    preds = nx.ra_index_soundarajan_hopcroft(simp_graph, community="communityLabel")
    new = sorted(preds, key=lambda x: -x[2])[:n_missing]
    for link in new:
        dot_graph.add_edge(link[0], link[1], predicted=link[2])

def update_html(graph_data: nx.DiGraph) -> None:
    """Export graph to JSON and inject into HTML, with NetworkX 3.6 compatibility."""
    # EXPLICIT: set edges="links" to maintain compatibility with your current HTML/JS setup
    JS_GRAPH = json_graph.node_link_data(graph_data, edges="links")
    JSON_GRAPH = json.dumps(JS_GRAPH)
    
    static_dir = pathlib.Path("./static")
    static_dir.mkdir(exist_ok=True)
    (static_dir / "graph.json").write_text(JSON_GRAPH)
    
    filepath = pathlib.Path("./static/html/graph.html").resolve()
    if filepath.exists():
        for line in fileinput.input([str(filepath)], inplace=True):
            if line.strip().startswith("var graph_data ="):
                line = f"var graph_data = {JSON_GRAPH}\n"
            sys.stdout.write(line)

if __name__ == "__main__":
    sys.stderr.write("Building and coloring graph...")
    DOT_GRAPH = build_graph()
    
    if len(DOT_GRAPH.nodes) > 0:
        compute_centrality(DOT_GRAPH)
        
        # Use weak components as the initial community count
        num_clusters = nx.number_weakly_connected_components(DOT_GRAPH)
        compute_communities(DOT_GRAPH, max(1, num_clusters))
        
        assign_node_colors(DOT_GRAPH)
        add_missing_links(DOT_GRAPH, N_MISSING)
        update_html(DOT_GRAPH)
        sys.stderr.write(" Done.\n")
    else:
        sys.stderr.write(" Done (Graph empty).\n")
