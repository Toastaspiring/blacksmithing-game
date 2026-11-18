#!/bin/bash
cd "$(dirname "$0")"
seq 0 3 | xargs -P 4 -I{} lune run b_run plausible {} 4 >> out/b_plaus.log 2>&1
echo ALLDONE >> out/b_plaus.log
