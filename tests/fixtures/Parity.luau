--!strict
-- tests/fixtures/Parity.luau — what S-PAR-02 digests besides its Gen.validSword designs (SPEC §14.10, E-S8.6): every
-- fixture of the repo, in one fixed order. tests/Physics/Parity.spec writes the Lune digest from this list and
-- tests/studio/e2e/S-PAR-02.luau computes it in the Studio Server and Client data models, so the order and the names are
-- part of the digest: append, never reorder.
--
--   F1–F5 (Blueprints), C01–C15 (Calibration), every Adversarial variant, the X fixtures (Regression), P1–P5 and the
--   specks (Cost), then WorstDesigns' valid and TooComplex designs, named as Cost.TPERF's cores ("Worst valid k",
--   "TooComplex k").
--
-- A fixture here cannot require src/ (SPEC §1.3 L1), so an Adversarial variant comes as its draft: both runners hand it
-- to Blueprint/Canonical.draft and drop it when Canonical refuses it (43 of the 149 pass today; those are A01–A28's
-- canonical drafts, A25–A27 among them, valid or not). Every other entry is a canonical core, analysed as it is.

local Adversarial = require("./Adversarial")
local Blueprints = require("./Blueprints")
local Build = require("./Build")
local Calibration = require("./Calibration")
local Cost = require("./Cost")
local Regression = require("./Regression")
local WorstDesigns = require("./WorstDesigns")

-- core: analysed as it is; draft: an Adversarial variant's raw draft (a fresh table on every call), canonicalized first.
export type Entry = { name: string, core: Build.Core?, draft: (() -> any)? }

local LIST: { Entry } = {}

for _, id in Blueprints.order do
	table.insert(LIST, { name = id, core = Blueprints.get(id).core })
end
for _, f in Calibration.list do
	table.insert(LIST, { name = f.id, core = f.core })
end
for _, v in Adversarial.variants do
	table.insert(LIST, { name = v.key, draft = v.draft })
end
for _, set in { Regression.list, Cost.list } do
	for _, f in set do
		table.insert(LIST, { name = f.id, core = f.core })
	end
end
for k, d in WorstDesigns.valid do
	table.insert(LIST, { name = "Worst valid " .. k, core = Build.core("Worst valid " .. k, d.parts) })
end
for k, d in WorstDesigns.tooComplex do
	table.insert(LIST, { name = "TooComplex " .. k, core = Build.core("TooComplex " .. k, d.parts) })
end

local Parity = {
	list = LIST, -- the entries, in digest order
}

Build.freeze(LIST)
return table.freeze(Parity)
