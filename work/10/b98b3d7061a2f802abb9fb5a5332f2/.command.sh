#!/bin/bash -ue
echo "Computing pairwise distances for all genomes..."
mash dist -p 16 mash.msh mash.msh > mash.dist
echo "Distance computation completed. Generated $(wc -l < mash.dist) pairwise comparisons."
