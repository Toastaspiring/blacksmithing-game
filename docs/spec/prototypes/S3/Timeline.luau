--!strict
-- S3 prototype: binary timeline codec + validation (buffer, little endian)
local Timeline = {}
Timeline.VERSION = 1
Timeline.HEADER_BYTES = 12
Timeline.FAMILY_CODE = { HoldZone = 1, TimingStrike = 2, PrecisionTrace = 3 }
Timeline.RECORD_BYTES = { HoldZone = 3, TimingStrike = 2, PrecisionTrace = 7 }
Timeline.MAX_RECORDS = { HoldZone = 1024, TimingStrike = 512, PrecisionTrace = 2048 }
Timeline.U_MAX = 3 * 16384
Timeline.V_MAX = 16384

-- records: HoldZone {t, down}; TimingStrike number t; PrecisionTrace {t, u, v, grind}
function Timeline.encode(family: string, durationMs: number, patternHash: number, records: { any }): buffer
	local rb = Timeline.RECORD_BYTES[family]
	local n = #records
	local b = buffer.create(Timeline.HEADER_BYTES + n * rb)
	buffer.writeu8(b, 0, Timeline.VERSION)
	buffer.writeu8(b, 1, Timeline.FAMILY_CODE[family])
	buffer.writeu16(b, 2, n)
	buffer.writeu32(b, 4, durationMs)
	buffer.writeu32(b, 8, patternHash)
	local prev = 0
	local o = Timeline.HEADER_BYTES
	for _, r in records do
		local t = if family == "TimingStrike" then r else r.t
		buffer.writeu16(b, o, t - prev)
		prev = t
		if family == "HoldZone" then
			buffer.writeu8(b, o + 2, if r.down then 1 else 0)
		elseif family == "PrecisionTrace" then
			buffer.writeu16(b, o + 2, r.u)
			buffer.writeu16(b, o + 4, r.v)
			buffer.writeu8(b, o + 6, if r.grind then 1 else 0)
		end
		o += rb
	end
	return b
end

-- returns (records, patternHash) or (nil, errorCode)
function Timeline.decode(b: any, family: string, durationMs: number): (any, any)
	if typeof(b) ~= "buffer" then
		return nil, "NotBuffer"
	end
	local len = buffer.len(b)
	if len < Timeline.HEADER_BYTES then
		return nil, "Short"
	end
	if buffer.readu8(b, 0) ~= Timeline.VERSION then
		return nil, "Version"
	end
	if buffer.readu8(b, 1) ~= Timeline.FAMILY_CODE[family] then
		return nil, "Family"
	end
	local n = buffer.readu16(b, 2)
	local rb = Timeline.RECORD_BYTES[family]
	if n > Timeline.MAX_RECORDS[family] then
		return nil, "TooMany"
	end
	if len ~= Timeline.HEADER_BYTES + n * rb then
		return nil, "Length"
	end
	if buffer.readu32(b, 4) ~= durationMs then
		return nil, "Duration"
	end
	local hash = buffer.readu32(b, 8)
	local out = {}
	local t = 0
	local o = Timeline.HEADER_BYTES
	local expectDown = true
	for i = 1, n do
		local dt = buffer.readu16(b, o)
		if family == "PrecisionTrace" and i > 1 and dt == 0 then
			return nil, "NotIncreasing"
		end
		t += dt
		if t > durationMs then
			return nil, "PastEnd"
		end
		if family == "HoldZone" then
			local k = buffer.readu8(b, o + 2)
			if k > 1 then
				return nil, "BadKind"
			end
			local down = k == 1
			if down ~= expectDown then
				return nil, "NotAlternating"
			end
			expectDown = not expectDown
			out[i] = { t = t, down = down }
		elseif family == "TimingStrike" then
			out[i] = t
		else
			local u, v, f = buffer.readu16(b, o + 2), buffer.readu16(b, o + 4), buffer.readu8(b, o + 6)
			if u > Timeline.U_MAX or v > Timeline.V_MAX then
				return nil, "OutOfPanel"
			end
			if f > 1 then
				return nil, "BadFlags"
			end
			out[i] = { t = t, u = u, v = v, grind = f == 1 }
		end
		o += rb
	end
	return out, hash
end

return Timeline
