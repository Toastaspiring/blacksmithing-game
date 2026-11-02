--!strict
-- Blueprint/Names (SPEC §3.9, E-S1.5; owner S1): the rules for player-entered names. Blueprints are named here; an
-- item takes its blueprint's name at forge (no item rename in the MVP, Q18). Pure: string and utf8 only.
--
--   raw input    a string of at most NAME_MAX_INPUT_BYTES (256) bytes, valid UTF-8, checked before any parsing
--   whitespace   ASCII space only: runs collapse to one space, leading and trailing spaces are dropped; a tab, a
--                newline or any other space character is a BadChar
--   length       NAME_MIN_CP..NAME_MAX_CP (1–32) code points after that normalization (≤ 64 bytes)
--   letters      A–Z a–z, U+00C0–U+00FF except × (U+00D7) and ÷ (U+00F7), U+0100–U+017F: Latin only (Q18)
--   others       digits 0–9 and - _ ' . , ! ? & ( ) # + : /   (no < >, so RichText stays inert; no quotes, no
--                backslash)
--   content      at least one letter or digit; names need not be unique
--
-- Errors in check order: NotString · TooLong (bytes) · InvalidUtf8 · BadChar (the first disallowed code point) ·
-- Empty · TooLong (code points) · NoAlnum. sanitize returns the normalized name, and sanitize(sanitize(x)) ==
-- sanitize(x). Profile.Data stores this raw sanitized name, never a filtered one; text shown to other players is
-- filtered by S5's TextFilter (§3.9).

local Limits = require("../Definitions/Limits")

export type NameError = "NotString" | "TooLong" | "InvalidUtf8" | "BadChar" | "Empty" | "NoAlnum"

local SPACE = 0x20
local PUNCTUATION = "-_'.,!?&()#+:/"

local PUNCT: { [number]: boolean } = {}
for i = 1, #PUNCTUATION do
	PUNCT[string.byte(PUNCTUATION, i)] = true
end

local function isLetter(cp: number): boolean
	return (cp >= 0x41 and cp <= 0x5A) -- A–Z
		or (cp >= 0x61 and cp <= 0x7A) -- a–z
		or (cp >= 0xC0 and cp <= 0x17F and cp ~= 0xD7 and cp ~= 0xF7) -- Latin-1 letters, Latin Extended-A
end

local function isDigit(cp: number): boolean
	return cp >= 0x30 and cp <= 0x39
end

local Names = {}

function Names.sanitize(raw: unknown): (string?, NameError?)
	if type(raw) ~= "string" then
		return nil, "NotString"
	end
	if #raw > Limits.NAME_MAX_INPUT_BYTES then
		return nil, "TooLong"
	end
	if utf8.len(raw) == nil then
		return nil, "InvalidUtf8"
	end
	local out: { string } = {}
	local count = 0
	local alnum = false
	local pendingSpace = false
	for _, cp in utf8.codes(raw) do
		if cp == SPACE then
			pendingSpace = count > 0 -- collapses runs and drops leading spaces; a trailing one is never written
		else
			local isAlnum = isLetter(cp) or isDigit(cp)
			if not (isAlnum or PUNCT[cp] == true) then
				return nil, "BadChar"
			end
			if pendingSpace then
				table.insert(out, " ")
				count += 1
				pendingSpace = false
			end
			table.insert(out, utf8.char(cp))
			count += 1
			if isAlnum then
				alnum = true
			end
		end
	end
	if count < Limits.NAME_MIN_CP then
		return nil, "Empty"
	end
	if count > Limits.NAME_MAX_CP then
		return nil, "TooLong"
	end
	if not alnum then
		return nil, "NoAlnum"
	end
	return table.concat(out), nil
end

return table.freeze(Names)
