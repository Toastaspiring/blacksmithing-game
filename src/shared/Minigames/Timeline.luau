--!strict
-- Minigames/Timeline (SPEC §6.7, §10.3, §10.5; owner S3): the timeline wire format. The client encodes its records
-- at the end of a step (Craft.Submit's `timeline`); the server decodes them before the replay. Pure.
--
--   layout     little-endian: a 12-byte header (u8 version, u8 family code, u16 count, u32 durationMs, u32
--              patternHash), then `count` records, each u16 dtMs from the previous record (t_0 = 0) and the family's
--              fields: HoldZone u8 kind (1 = down), TimingStrike none, PrecisionTrace u16 uQ, u16 vQ, u8 flags (bit0
--              grind); the wire constants are Definitions/MinigameFamilies' (§16.12)
--   decode     total on any value, first failure wins (§6.7): NotBuffer, Short (< 12 B), Version, Family, TooMany
--              (count > MAX_RECORDS, or more bytes than the family's cap 12 + MAX_RECORDS · RECORD_BYTES, §10.3),
--              Length (≠ 12 + count · RECORD_BYTES), Duration (≠ the spec's); then per record, in order:
--              NotIncreasing (a trace dt of 0 after the first), PastEnd (t > durationMs), BadKind (kind > 1),
--              NotAlternating (kinds alternate from down), OutOfPanel (uQ > U_MAX, vQ > V_MAX), BadFlags (flags > 1).
--              Success returns (records, patternHash); comparing the hash is the judge's step (§10.5)
--   encode     for honest records (Input, Bots, tests): it errors on anything decode would refuse, so an encoded
--              timeline always decodes to the same records (§6.6: an unmodified client never sends a timeline decode
--              rejects; a Recorder bug stops the submit instead of costing the player a strike)
--   capBytes   a family's cap in bytes (§10.3), decode's TooMany bound: judge refuses an oversize buffer in O(1),
--              so Submit relies on it and calls no Timeline function (§6.2's facade)
--
-- Records: HoldZone {t, down}; TimingStrike the press time t itself; PrecisionTrace {t, u, v, grind} with u, v in
-- 1/PT_FIXED_POINT panel units. U_MAX = PT_PANEL_ASPECT · PT_FIXED_POINT and V_MAX = PT_FIXED_POINT come from
-- PrecisionTrace, the panel's owner. The size checks come before the record loop, which reads only inside the buffer,
-- so an oversize buffer is refused in O(1). Each family is one codec in CODECS: a Phase 2 family adds a codec, its
-- Definitions row with the wire constants, its family module, an Input rule and a Bots policy (§15).

local MinigameFamilies = require("../Definitions/MinigameFamilies")
local DT = require("../Definitions/Types")
local PrecisionTrace = require("./PrecisionTrace")
local Types = require("./Types")

type InvalidReason = Types.InvalidReason
type HoldRecord = Types.HoldRecord
type TraceRecord = Types.TraceRecord

-- one family's records on the wire: whether times strictly increase (NotIncreasing); a record's time; encode's checks
-- of its fields (nil when decode accepts them) and their writing after the dt; decode's reading of them (the record,
-- or the reason it is refused)
type Codec = {
	increasing: boolean,
	time: (r: any) -> number,
	check: (r: any, i: number) -> string?,
	write: (b: buffer, o: number, r: any) -> (),
	read: (b: buffer, o: number, t: number, i: number) -> (any, InvalidReason?),
}

local VERSION = MinigameFamilies.TIMELINE_FORMAT_VERSION
local HEADER = MinigameFamilies.TIMELINE_HEADER_BYTES
local FAMILY_CODE = MinigameFamilies.FAMILY_CODE
local RECORD_BYTES = MinigameFamilies.RECORD_BYTES
local MAX_RECORDS = MinigameFamilies.MAX_RECORDS
local U_MAX = PrecisionTrace.PT_PANEL_ASPECT * PrecisionTrace.PT_FIXED_POINT -- 49152: u ≤ 3 panel heights
local V_MAX = PrecisionTrace.PT_FIXED_POINT -- 16384
local U16_MAX = 65535
local U32 = 4294967296

-- typed, so luau-lsp keeps the literal types (M1's lesson)
local NOT_BUFFER: InvalidReason = "NotBuffer"
local SHORT: InvalidReason = "Short"
local VERSION_REASON: InvalidReason = "Version"
local FAMILY: InvalidReason = "Family"
local TOO_MANY: InvalidReason = "TooMany"
local LENGTH: InvalidReason = "Length"
local DURATION: InvalidReason = "Duration"
local NOT_INCREASING: InvalidReason = "NotIncreasing"
local PAST_END: InvalidReason = "PastEnd"
local BAD_KIND: InvalidReason = "BadKind"
local NOT_ALTERNATING: InvalidReason = "NotAlternating"
local OUT_OF_PANEL: InvalidReason = "OutOfPanel"
local BAD_FLAGS: InvalidReason = "BadFlags"

local function isInt(v: any, lo: number, hi: number): boolean
	return type(v) == "number" and v >= lo and v <= hi and math.floor(v) == v
end

-- HoldZone's kinds alternate from down: record i is a down exactly when i is odd
local function oddIndex(i: number): boolean
	return bit32.band(i, 1) == 1
end

local CODECS: { [DT.FamilyId]: Codec } = table.freeze({
	HoldZone = table.freeze({
		increasing = false,
		time = function(r: HoldRecord): number
			return r.t
		end,
		check = function(r: HoldRecord, i: number): string?
			if type(r.down) ~= "boolean" then
				return "down must be a boolean"
			elseif r.down ~= oddIndex(i) then
				return "kinds must alternate from a down"
			end
			return nil
		end,
		write = function(b: buffer, o: number, r: HoldRecord)
			buffer.writeu8(b, o, if r.down then 1 else 0)
		end,
		read = function(b: buffer, o: number, t: number, i: number): (any, InvalidReason?)
			local kind = buffer.readu8(b, o)
			if kind > 1 then
				return nil, BAD_KIND
			end
			local down = kind == 1
			if down ~= oddIndex(i) then
				return nil, NOT_ALTERNATING
			end
			return { t = t, down = down }, nil
		end,
	}),
	TimingStrike = table.freeze({
		increasing = false,
		time = function(t: number): number
			return t
		end,
		check = function(_t: number, _i: number): string?
			return nil
		end,
		write = function(_b: buffer, _o: number, _t: number) end,
		read = function(_b: buffer, _o: number, t: number, _i: number): (any, InvalidReason?)
			return t, nil
		end,
	}),
	PrecisionTrace = table.freeze({
		increasing = true,
		time = function(r: TraceRecord): number
			return r.t
		end,
		check = function(r: TraceRecord, _i: number): string?
			if not isInt(r.u, 0, U_MAX) or not isInt(r.v, 0, V_MAX) then
				return "u and v must be integers in [0, U_MAX] × [0, V_MAX]"
			elseif type(r.grind) ~= "boolean" then
				return "grind must be a boolean"
			end
			return nil
		end,
		write = function(b: buffer, o: number, r: TraceRecord)
			buffer.writeu16(b, o, r.u)
			buffer.writeu16(b, o + 2, r.v)
			buffer.writeu8(b, o + 4, if r.grind then 1 else 0)
		end,
		read = function(b: buffer, o: number, t: number, _i: number): (any, InvalidReason?)
			local u, v, flags = buffer.readu16(b, o), buffer.readu16(b, o + 2), buffer.readu8(b, o + 4)
			if u > U_MAX or v > V_MAX then
				return nil, OUT_OF_PANEL
			elseif flags > 1 then
				return nil, BAD_FLAGS
			end
			return { t = t, u = u, v = v, grind = flags == 1 }, nil
		end,
	}),
})

local function codecOf(family: DT.FamilyId, fn: string): Codec
	local codec = CODECS[family]
	if codec == nil then
		error(string.format("Timeline.%s: %s has no timeline codec", fn, tostring(family)), 3)
	end
	return codec
end

local Timeline = {
	U_MAX = U_MAX,
	V_MAX = V_MAX,
}

function Timeline.capBytes(family: DT.FamilyId): number
	codecOf(family, "capBytes")
	return HEADER + MAX_RECORDS[family] * RECORD_BYTES[family]
end

function Timeline.encode(family: DT.FamilyId, durationMs: number, patternHash: number, records: { any }): buffer
	local codec = codecOf(family, "encode")
	if not isInt(durationMs, 0, U32 - 1) or not isInt(patternHash, 0, U32 - 1) then
		error(string.format("Timeline.encode: durationMs and patternHash must be u32 integers, got %s and %s",
			tostring(durationMs), tostring(patternHash)), 2)
	end
	local n = #records
	if n > MAX_RECORDS[family] then
		error(string.format("Timeline.encode: %d %s records, more than MAX_RECORDS %d", n, family,
			MAX_RECORDS[family]), 2)
	end
	local rb = RECORD_BYTES[family]
	local b = buffer.create(HEADER + n * rb)
	buffer.writeu8(b, 0, VERSION)
	buffer.writeu8(b, 1, FAMILY_CODE[family])
	buffer.writeu16(b, 2, n)
	buffer.writeu32(b, 4, durationMs)
	buffer.writeu32(b, 8, patternHash)
	local prev = 0
	local o = HEADER
	for i, r in ipairs(records) do
		local t = codec.time(r)
		local dt = if type(t) == "number" then t - prev else nil
		local problem: string? = nil
		if dt == nil or not isInt(dt, 0, U16_MAX) then
			problem = "times must be integers, non-decreasing, at most 65535 ms apart"
		elseif codec.increasing and i > 1 and dt == 0 then
			problem = "times must increase"
		elseif t > durationMs then
			problem = "past durationMs " .. durationMs
		else
			problem = codec.check(r, i)
		end
		if problem then
			error(string.format("Timeline.encode: %s record %d (t = %s): %s", family, i, tostring(t), problem), 2)
		end
		buffer.writeu16(b, o, dt :: number)
		codec.write(b, o + 2, r)
		prev = t
		o += rb
	end
	return b
end

function Timeline.decode(b: unknown, family: DT.FamilyId, durationMs: number): ({ any }?, number | InvalidReason)
	if typeof(b) ~= "buffer" then
		return nil, NOT_BUFFER
	end
	local buf = b :: buffer
	local len = buffer.len(buf)
	if len < HEADER then
		return nil, SHORT
	end
	if buffer.readu8(buf, 0) ~= VERSION then
		return nil, VERSION_REASON
	end
	local code, codec = FAMILY_CODE[family], CODECS[family]
	if code == nil or codec == nil or buffer.readu8(buf, 1) ~= code then
		return nil, FAMILY
	end
	local rb = RECORD_BYTES[family]
	local n = buffer.readu16(buf, 2)
	if n > MAX_RECORDS[family] or len > HEADER + MAX_RECORDS[family] * rb then
		return nil, TOO_MANY
	end
	if len ~= HEADER + n * rb then
		return nil, LENGTH
	end
	if buffer.readu32(buf, 4) ~= durationMs then
		return nil, DURATION
	end
	local hash = buffer.readu32(buf, 8)
	local out = table.create(n)
	local t = 0
	local o = HEADER
	for i = 1, n do
		local dt = buffer.readu16(buf, o)
		if i > 1 and dt == 0 and codec.increasing then
			return nil, NOT_INCREASING
		end
		t += dt
		if t > durationMs then
			return nil, PAST_END
		end
		local r, reason: InvalidReason? = codec.read(buf, o + 2, t, i)
		if reason ~= nil then
			return nil, reason :: InvalidReason
		end
		out[i] = r
		o += rb
	end
	return out, hash
end

return table.freeze(Timeline)
