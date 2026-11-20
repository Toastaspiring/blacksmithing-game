--!strict
-- tests/lib/Cheats.luau — the minigame cheat inputs of §14.8 (SPEC §14.2, §14.3, E-S8.5): Exact, Fast, Flood,
-- Malformed, Replay, Forged, and the structured garbage of T-MG-08. Requires nothing in src/ (§14.2: specs pass
-- modules in): Cheats.new({ Timeline, MinigameFamilies, Minigames?, Bots? }) returns the builders. The decode-level
-- ones need only the wire codec and its constants, so they exist before the facade and the bots; flood's judge-cap
-- timeline needs the facade (Minigames.recordCap), and exact needs Bots. Randomness from the caller's TestRng only.
--
--   reasons(family)                   the decode reasons a timeline of the family can have, in §6.7's order
--   malformed(spec, reason)           values that each decode to exactly that reason, every one but NotBuffer planted
--                                     in the bytes of an honest timeline (M7's S-E2E-10 takes the first)
--   flood(spec)                       { overCount = MAX_RECORDS + 1 records, overLength = more bytes than the family's
--                                     cap with a count within it (M4's D8), overCap = a valid trace with one record
--                                     more than the judge accepts (L6; nil for a family whose cap is decode's) }
--   replay(spec, records, otherSpec)  { first, again = the same bytes in another buffer (S5 answers a duplicate),
--                                     stale = that old timeline sent on another step: its duration rewritten to
--                                     otherSpec's so decode passes, leaving the hash to refuse it (HashMismatch) }
--   garbageBuffers(rng, spec, records, n)   n buffers: random bytes after the spec's header, lengths 0 to the cap + 16,
--                                     honest timelines with 1–3 byte flips, truncated or extended, random counts with
--                                     matching lengths (T-MG-08)
--   fast(spec, records, earlyTolMs)   { timeline, sendAtMs = countdownMs + durationMs − earlyTolMs − 1 }: an honest
--                                     timeline sent before the early bound (§7.8; S5's EARLY_TOL_MS passed in)
--   forged(args)                      Submit arguments with an extra key, and with another session id (M7's Guard)
--   exact(spec, pattern)              Bots.play's "Exact" records: TimingStrike at the exact targets, unquantized;
--                                     HoldZone's exact-state controller; a trace on the pacer every 20 ms

local TestRng = require("./TestRng")

export type Modules = { Timeline: any, MinigameFamilies: any, Minigames: any?, Bots: any? }
export type Cheats = {
	reasons: (family: string) -> { string },
	malformed: (spec: any, reason: string) -> { any },
	flood: (spec: any) -> { overCount: buffer, overLength: buffer, overCap: buffer? },
	replay: (spec: any, records: { any }, otherSpec: any) -> { first: buffer, again: buffer, stale: buffer },
	garbageBuffers: (rng: TestRng.TestRng, spec: any, records: { any }, n: number) -> { buffer },
	fast: (spec: any, records: { any }, earlyTolMs: number) -> { timeline: buffer, sendAtMs: number },
	forged: (args: { [string]: any }) -> { extraKey: { [string]: any }, otherSession: { [string]: any } },
	exact: (spec: any, pattern: any) -> { any },
}

-- §6.7's decode reasons, in its order, and the families each can occur in (nil: every family)
local REASONS: { { name: string, families: { string }? } } = {
	{ name = "NotBuffer" },
	{ name = "Short" },
	{ name = "Version" },
	{ name = "Family" },
	{ name = "TooMany" },
	{ name = "Length" },
	{ name = "Duration" },
	{ name = "NotIncreasing", families = { "PrecisionTrace" } },
	{ name = "PastEnd" },
	{ name = "BadKind", families = { "HoldZone" } },
	{ name = "NotAlternating", families = { "HoldZone" } },
	{ name = "OutOfPanel", families = { "PrecisionTrace" } },
	{ name = "BadFlags", families = { "PrecisionTrace" } },
}

local HEADER = 12

local Cheats = {}

function Cheats.new(m: Modules): Cheats
	local MF = m.MinigameFamilies
	local Timeline = m.Timeline
	assert(MF ~= nil and Timeline ~= nil, "Cheats.new needs Timeline and MinigameFamilies")

	local function encode(spec: any, records: { any }): buffer
		return Timeline.encode(spec.family, spec.durationMs, spec.patternHash, records)
	end

	local function copyOf(b: buffer): buffer
		local out = buffer.create(buffer.len(b))
		buffer.copy(out, 0, b)
		return out
	end

	-- three or four honest records near GO, so a fault can be planted in record 1, 2 or the last
	local function honest(spec: any): { any }
		assert(spec.durationMs >= 400, "Cheats: a step of at least 400 ms")
		if spec.family == "HoldZone" then
			return {
				{ t = 0, down = true },
				{ t = 100, down = false },
				{ t = 200, down = true },
				{ t = 300, down = false },
			}
		elseif spec.family == "TimingStrike" then
			return { 100, 200, 300 }
		end
		return {
			{ t = 0, u = 8192, v = 8192, grind = true },
			{ t = 20, u = 8300, v = 8192, grind = true },
			{ t = 40, u = 8400, v = 8100, grind = false },
		}
	end

	-- the byte offset of record i's first byte (its dt)
	local function at(spec: any, i: number): number
		return HEADER + (i - 1) * MF.RECORD_BYTES[spec.family]
	end

	local function otherCode(family: string): number
		local own = MF.FAMILY_CODE[family]
		for _, f in { "HoldZone", "TimingStrike", "PrecisionTrace" } do
			if MF.FAMILY_CODE[f] ~= own then
				return MF.FAMILY_CODE[f]
			end
		end
		error("Cheats: no other family code")
	end

	-- a header for `count` records and `bytes` bytes in all, the records' bytes zero
	local function sized(spec: any, count: number, bytes: number): buffer
		local b = buffer.create(bytes)
		buffer.writeu8(b, 0, MF.TIMELINE_FORMAT_VERSION)
		buffer.writeu8(b, 1, MF.FAMILY_CODE[spec.family])
		buffer.writeu16(b, 2, count)
		buffer.writeu32(b, 4, spec.durationMs)
		buffer.writeu32(b, 8, spec.patternHash)
		return b
	end

	local api = {}

	function api.reasons(family: string): { string }
		local out: { string } = {}
		for _, r in REASONS do
			if r.families == nil or table.find(r.families, family) ~= nil then
				table.insert(out, r.name)
			end
		end
		return out
	end

	function api.malformed(spec: any, reason: string): { any }
		local family = spec.family
		assert(table.find(api.reasons(family), reason) ~= nil, "Cheats.malformed: no " .. reason .. " for " .. family)
		local records = honest(spec)
		local function planted(plant: (b: buffer) -> buffer?): buffer
			local b = encode(spec, records)
			return plant(b) or b
		end
		if reason == "NotBuffer" then
			return { "abc", {}, 12, true, buffer.tostring(encode(spec, records)) }
		elseif reason == "Short" then
			return {
				buffer.create(0),
				planted(function(b: buffer): buffer?
					local short = buffer.create(HEADER - 1)
					buffer.copy(short, 0, b, 0, HEADER - 1)
					return short
				end),
			}
		elseif reason == "Version" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, 0, MF.TIMELINE_FORMAT_VERSION + 1)
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, 0, 0)
					return nil
				end),
			}
		elseif reason == "Family" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, 1, otherCode(family))
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, 1, 0)
					return nil
				end),
			}
		elseif reason == "TooMany" then
			local n = MF.MAX_RECORDS[family] + 1
			return { sized(spec, n, HEADER + n * MF.RECORD_BYTES[family]), sized(spec, 65535, HEADER) }
		elseif reason == "Length" then
			local n = #records
			return {
				planted(function(b: buffer): buffer?
					local long = buffer.create(buffer.len(b) + 1)
					buffer.copy(long, 0, b)
					return long
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu16(b, 2, n + 1)
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu16(b, 2, n - 1)
					return nil
				end),
			}
		elseif reason == "Duration" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu32(b, 4, spec.durationMs + 1)
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu32(b, 4, spec.durationMs - 1)
					return nil
				end),
			}
		elseif reason == "NotIncreasing" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu16(b, at(spec, 2), 0)
					return nil
				end),
			}
		elseif reason == "PastEnd" then
			local n = #records
			local prev = records[n - 1]
			local prevT = if n == 1 then 0 elseif type(prev) == "number" then prev else prev.t
			return {
				planted(function(b: buffer): buffer?
					-- the last record one ms past the end; a dt stays within u16 for any duration ≤ 65535 + prevT
					buffer.writeu16(b, at(spec, n), spec.durationMs + 1 - prevT)
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu16(b, at(spec, 1), 65535)
					for i = 2, n do
						buffer.writeu16(b, at(spec, i), 65535)
					end
					return nil
				end),
			}
		elseif reason == "BadKind" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, at(spec, 1) + 2, 2)
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, at(spec, 2) + 2, 255)
					return nil
				end),
			}
		elseif reason == "NotAlternating" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, at(spec, 2) + 2, 1) -- two downs
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu8(b, at(spec, 1) + 2, 0) -- an up first
					return nil
				end),
			}
		elseif reason == "OutOfPanel" then
			return {
				planted(function(b: buffer): buffer?
					buffer.writeu16(b, at(spec, 1) + 2, Timeline.U_MAX + 1)
					return nil
				end),
				planted(function(b: buffer): buffer?
					buffer.writeu16(b, at(spec, 2) + 4, Timeline.V_MAX + 1)
					return nil
				end),
			}
		end
		-- BadFlags
		return {
			planted(function(b: buffer): buffer?
				buffer.writeu8(b, at(spec, 2) + 6, 2)
				return nil
			end),
			planted(function(b: buffer): buffer?
				buffer.writeu8(b, at(spec, 3) + 6, 255)
				return nil
			end),
		}
	end

	function api.flood(spec: any): { overCount: buffer, overLength: buffer, overCap: buffer? }
		local family = spec.family
		local rb, max = MF.RECORD_BYTES[family], MF.MAX_RECORDS[family]
		local overCap: buffer? = nil
		if m.Minigames ~= nil then
			local cap = m.Minigames.recordCap(spec)
			if cap < max then
				-- cap + 1 valid trace samples, 1 ms apart from GO
				local records: { any } = {}
				for i = 1, cap + 1 do
					records[i] = { t = i - 1, u = 8192, v = 8192, grind = true }
				end
				overCap = encode(spec, records)
			end
		end
		return {
			overCount = sized(spec, max + 1, HEADER + (max + 1) * rb),
			overLength = sized(spec, max, HEADER + max * rb + 1),
			overCap = overCap,
		}
	end

	function api.replay(spec: any, records: { any }, otherSpec: any): { first: buffer, again: buffer, stale: buffer }
		local first = encode(spec, records)
		local stale = copyOf(first)
		buffer.writeu32(stale, 4, otherSpec.durationMs)
		return { first = first, again = copyOf(first), stale = stale }
	end

	function api.garbageBuffers(rng: TestRng.TestRng, spec: any, records: { any }, n: number): { buffer }
		local family = spec.family
		local rb = MF.RECORD_BYTES[family]
		local cap = HEADER + MF.MAX_RECORDS[family] * rb
		local base = encode(spec, records)
		local out: { buffer } = {}
		for i = 1, n do
			local kind = rng:int(1, 5)
			local b: buffer
			if kind == 1 then -- random bytes after a valid header and a random count, any length up to the cap + 16
				local len = rng:int(0, cap + 16)
				local from = 0
				if len >= HEADER then
					b = sized(spec, rng:int(0, 65535), len)
					from = HEADER
				else
					b = buffer.create(len)
				end
				for o = from, len - 1 do
					buffer.writeu8(b, o, rng:int(0, 255))
				end
			elseif kind == 2 then -- the honest timeline with 1–3 byte flips
				b = copyOf(base)
				for _ = 1, rng:int(1, 3) do
					local o = rng:int(0, buffer.len(b) - 1)
					if rng:int(1, 2) == 1 then
						buffer.writeu8(b, o, rng:int(0, 255))
					else
						buffer.writeu8(b, o, bit32.bxor(buffer.readu8(b, o), bit32.lshift(1, rng:int(0, 7))))
					end
				end
			elseif kind == 3 then -- truncated
				b = buffer.create(rng:int(0, buffer.len(base) - 1))
				buffer.copy(b, 0, base, 0, buffer.len(b))
			elseif kind == 4 then -- extended by 1 to 16 random bytes
				b = buffer.create(buffer.len(base) + rng:int(1, 16))
				buffer.copy(b, 0, base)
				for o = buffer.len(base), buffer.len(b) - 1 do
					buffer.writeu8(b, o, rng:int(0, 255))
				end
			else -- a random count with its matching length: random records reach the per-record checks
				local count = rng:int(0, math.min(64, MF.MAX_RECORDS[family]))
				b = sized(spec, count, HEADER + count * rb)
				for o = HEADER, buffer.len(b) - 1 do
					-- small dts, so some records stay within the step
					buffer.writeu8(b, o, if rng:int(1, 3) == 1 then rng:int(0, 255) else rng:int(0, 3))
				end
			end
			out[i] = b
		end
		return out
	end

	function api.fast(spec: any, records: { any }, earlyTolMs: number): { timeline: buffer, sendAtMs: number }
		return { timeline = encode(spec, records), sendAtMs = spec.countdownMs + spec.durationMs - earlyTolMs - 1 }
	end

	function api.forged(args: { [string]: any }): { extraKey: { [string]: any }, otherSession: { [string]: any } }
		local extra, other = table.clone(args), table.clone(args)
		extra.extraKey = true
		local id = tostring(args.sessionId or "")
		local first = string.sub(id, 1, 1)
		other.sessionId = (if first == "0" then "1" else "0") .. string.sub(id, 2)
		return { extraKey = extra, otherSession = other }
	end

	function api.exact(spec: any, pattern: any): { any }
		if m.Bots == nil then
			error("Cheats.exact needs Bots: Cheats.new({ ..., Bots = Bots })", 2)
		end
		return m.Bots.play(spec, pattern, "Exact", 0)
	end

	return api :: any
end

return Cheats
