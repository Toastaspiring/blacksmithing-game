#!/bin/bash
# mkvar.sh <name> <python patch file or -> : var_<name> = the repo's src, tests, S2 v2 and worst_designs, Cover patched
set -e
R="/c/Users/louis/Documents/RANDOM/ROBLOX/Blacksmithing Game"
D="var_$1"
rm -rf "$D"
mkdir -p "$D/docs/spec/prototypes/S2/cover"
cp -r "$R/src" "$R/tests" "$D/"
cp -r "$R/docs/spec/prototypes/S2/v2" "$D/docs/spec/prototypes/S2/"
cp "$R/docs/spec/prototypes/S2/cover/worst_designs.luau" "$D/docs/spec/prototypes/S2/cover/"
if [ "$2" != "-" ]; then python "$2" "$D/src/shared/Physics/Cover.luau"; fi
echo "variant ready: $D"
