--!strict
-- Prototype of src/shared/Net/RateLimit.luau (pure: injected clock, integer ms).
-- Token bucket: `capacity` tokens, refilled continuously at `refillPerSec`.

export type BucketSpec = { capacity: number, refillPerSec: number }
export type Bucket = { tokens: number, lastMs: number, spec: BucketSpec }

local RateLimit = {}

function RateLimit.newBucket(spec: BucketSpec, nowMs: number): Bucket
	return { tokens = spec.capacity, lastMs = nowMs, spec = spec }
end

-- Returns true and consumes `cost` tokens if available; false otherwise.
-- A clock that goes backwards is ignored (os.clock is monotonic on Roblox).
function RateLimit.take(b: Bucket, nowMs: number, cost: number?): boolean
	local c = cost or 1
	local dt = nowMs - b.lastMs
	if dt > 0 then
		b.tokens = math.min(b.spec.capacity, b.tokens + dt * b.spec.refillPerSec / 1000)
		b.lastMs = nowMs
	end
	if b.tokens >= c then
		b.tokens -= c
		return true
	end
	return false
end

return RateLimit
