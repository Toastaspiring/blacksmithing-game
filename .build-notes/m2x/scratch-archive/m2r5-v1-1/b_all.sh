#!/bin/bash
cd "$(dirname "$0")"
for f in comb wall bead curvedGrip fuller pinRivet oddPoke tiltPlate ballRivet thinPart sunkRod chamfer; do
  seq 0 9 | xargs -P 10 -I{} lune run b_run $f {} 10 >> out/b_all.log 2>&1
  echo "done $f $(date +%T)" >> out/b_all.log
done
echo ALLDONE >> out/b_all.log
