--!nocheck
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local Worst = require("../repo/docs/spec/prototypes/S2/cover/worst_designs")
fs.writeFile("out/cluster.json", serde.encode("json", Worst.valid[1].parts))
fs.writeFile("out/tc41.json", serde.encode("json", Worst.valid[2].parts))
