#!/bin/bash -ue
export PIP_CACHE_DIR=/tmp/pip-cache
    export PYTHONUSERBASE=/tmp/python-user
    pip install --user --quiet networkx
    python - << 'PY'
import networkx as nx, random, sys, pathlib, os

print("Building similarity graph from MASH distances...")

# This is the absolute path to your main input directory
input_dir = "./test_data"

G = nx.Graph()
# Process the mash distance file - files are now relative filenames
for line in open('mash.dist'):
    a, b, d, *_ = line.split()
    if float(d) < 0.01:
        G.add_edge(a, b)

print(f"Graph built with {G.number_of_nodes()} nodes and {G.number_of_edges()} edges")
print(f"Found {nx.number_connected_components(G)} connected components")

# Analyze component sizes for debugging
component_sizes = [len(comp) for comp in nx.connected_components(G)]
component_sizes.sort(reverse=True)
print(f"Component sizes: {component_sizes[:10]}")  # Show top 10 component sizes
print(f"Largest component has {max(component_sizes) if component_sizes else 0} genomes")
print(f"Average component size: {sum(component_sizes)/len(component_sizes) if component_sizes else 0:.1f}")

with open('subset.list','w') as out:
    total_selected = 0
    for i, comp in enumerate(nx.connected_components(G)):
        comp = list(comp)
        # Optimized subsampling for better cluster resolution: take fewer but more diverse representatives
        k = min(100, max(10, int(len(comp) * 0.15)))
        k = min(k, len(comp))
        if k > 0:
            selected = random.sample(comp, k)
            for filename in selected:
                # Create a sample name from the filename
                sample_name = os.path.splitext(filename)[0]
                # Create the full absolute path for PopPUNK to use
                full_path = os.path.join(input_dir, filename)
                out.write(f"{sample_name}\t{full_path}\n")
                total_selected += 1
        print(f"Component {i+1}: {len(comp)} genomes -> selected {k} representatives")

print(f"Total genomes selected for PopPUNK modeling: {total_selected}")
PY
