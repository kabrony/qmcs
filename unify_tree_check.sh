#!/usr/bin/env bash
#
# unify_tree_check.sh
#
# 1) cd into ~/qmcs
# 2) Show a tree listing
# 3) Then do an ls -la
#

cd ~/qmcs
echo "=== tree of ~/qmcs ==="
tree

echo ""
echo "=== ls -la of ~/qmcs ==="
ls -la
