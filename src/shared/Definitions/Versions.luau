--!strict
-- Definitions/Versions (SPEC §9.6, §16.1; owner S1). Positive integers (Validate D7).
--   DATA_VERSION      Profile.Data layout: +1 with a migration for every structural change (a record field added,
--                     renamed, removed or retyped; an id format change; any schema bump)
--   BLUEPRINT_SCHEMA  blueprint format of records, drafts and snapshots; the same migration upgrades records and
--                     snapshots; the wire accepts only the current value
--   BALANCE_VERSION   +1 with any outcome-affecting data (Definitions/Manifest) or code change: items recompute
--                     lazily, analyses go stale; S8's T-BAL-01 refuses changed Manifest data under an unchanged value

local Versions = {
	DATA_VERSION = 1,
	BLUEPRINT_SCHEMA = 1,
	BALANCE_VERSION = 1,
}

return table.freeze(Versions)
