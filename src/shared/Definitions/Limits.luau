--!strict
-- Definitions/Limits (SPEC §3.6, §9.8, §16.2; owner S1, geometry values S2): structural and persistence bounds, one
-- frozen table. Bounds are rejected, never clamped (Blueprint/Canonical); the editor clamps visibly first.
-- In the BALANCE Manifest: MIN_DIM, MAX_DIM, EPS_CONTAIN, CONTACT_TOL (they decide validity and measurement); the
-- other limits change no outcome.

local Limits = {
	-- blueprint geometry (§3.1, §3.5, §3.6)
	POS_ABS_MAX = 16, -- stud per component; keeps every part inside S6's ×4 editor stage
	MIN_DIM = 0.02, -- stud; smallest side S2 measures cleanly (E-S2.2); at most 0.05 [Decision to confirm] (Q4)
	MAX_DIM = 6.0, -- stud; > hitbox diagonal 5.28; bounds sample counts
	EPS_CONTAIN = 1e-4, -- stud; float noise on parts flush with the hitbox wall
	CONTACT_TOL = 0.01, -- stud; connectivity distance, chord merging
	MAX_PARTS = 24, -- parts; structural cap = Sword part limit (S2); budgets and S7's render cap use it
	MAX_PART_ID = 65535, -- part ids are integers 1..MAX_PART_ID; the editor's counter starts at max + 1 (§11.5)
	QUAT_NORM_TOL = 1e-9, -- renormalize only above it: idempotent, editor quaternions untouched (C3)
	QUAT_INPUT_TOL = 1e-2, -- reject wire quaternions further from unit (client bug, zero, overflow) (C2)

	-- names (§3.9)
	NAME_MIN_CP = 1, -- code points; no empty names
	NAME_MAX_CP = 32, -- code points; fits a plaque, ≤ 64 bytes with the Latin set
	NAME_MAX_INPUT_BYTES = 256, -- bytes; cheap rejection before parsing

	-- records (§3.3, §9.4)
	MAX_ISSUES_STORED = 8, -- entries of analysis.issues kept per blueprint
	MAX_STEP_FLAGS = 10, -- ≥ the 9 flag kinds (S3's 7, S5's LateSubmit and ScoreMismatch): no flag is dropped

	-- persistence (§9.2, §9.3, §9.8)
	MAX_BLUEPRINTS = 40, -- records; worst profile 43.5 % of the key [Decision to confirm] (Q18)
	MAX_ITEMS = 150, -- records; same budget, scrap frees a slot [Decision to confirm] (Q18)
	MAX_UI_FLAGS = 64, -- entries; bounds uiFlags (worst 2,561 B)
	UI_FLAG_KEY_MAX_BYTES = 32, -- bytes; bounds uiFlags keys
	DATASTORE_VALUE_LIMIT = 4194304, -- characters; Roblox per-key value limit, the budget test targets ≤ 50 %
	KEY_WRITE_BYTES_PER_MIN = 4000000, -- bytes/min; Roblox per-key write throughput, derives the size block
	PROFILE_SIZE_WARN_BYTES = 1000000, -- bytes; DataIssue telemetry for unusually heavy profiles
	PROFILE_SIZE_BLOCK_BYTES = 2000000, -- bytes; refuse new records: 2 writes/min × 2 MB = 4 MB/min
	PROFILE_STORE_NAME = "PlayerData", -- Roblox's recommended store name
	PROFILE_KEY_PREFIX = "User_", -- key = prefix .. UserId, the pattern automated right-to-be-forgotten needs
}

return table.freeze(Limits)
