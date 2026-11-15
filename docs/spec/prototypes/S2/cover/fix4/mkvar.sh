#!/bin/bash
# mkvar.sh <name> <src root> [python patch]: var_<name> = <src root>'s src, tests, S2 v2 and worst_designs, then the patch
set -e
D="var_$1"
S="$2"
rm -rf "$D"
mkdir -p "$D/docs/spec/prototypes/S2/cover"
cp -r "$S/src" "$S/tests" "$D/"
cp -r "$S/docs/spec/prototypes/S2/v2" "$D/docs/spec/prototypes/S2/"
cp "$S/docs/spec/prototypes/S2/cover/worst_designs.luau" "$D/docs/spec/prototypes/S2/cover/"
if [ -n "$3" ]; then python "$3" "$D"; fi
echo "variant ready: $D"
