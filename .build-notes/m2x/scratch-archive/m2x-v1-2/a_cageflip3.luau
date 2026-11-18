--!nocheck
-- the same sword without the Ball, and with it
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local L = require("./lib")
local parts = serde.decode("json", fs.readFile("out/cageflip_sword.json"))
local without = {}
for i, p in ipairs(parts) do if i ~= 5 then table.insert(without, p) end end
L.renumber(without)
local r = L.run(L.copyParts(without), { measureInvalid = false })
print("without the Ball: valid " .. tostring(r.validation.ok) .. " " .. L.codes(r) .. "; " .. L.dline(L.emu(L.copyParts(without))))
print("with the Ball:    " .. L.dline(L.emu(L.renumber(L.copyParts(parts)))))
