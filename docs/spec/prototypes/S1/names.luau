--!strict
-- S1 prototype: player-entered name rules (blueprints, items). Pure Luau (utf8 + string only).
-- Throwaway: run with lune 0.8.9.

local NAME_MIN_CP = 1
local NAME_MAX_CP = 32
local NAME_MAX_INPUT_BYTES = 256 -- reject before any parsing

-- Allowed code point ranges (inclusive). Letters only; digits/space/punctuation handled separately.
local LETTER_RANGES: { { number } } = {
	{ 0x41, 0x5A }, -- A-Z
	{ 0x61, 0x7A }, -- a-z
	{ 0xC0, 0xD6 }, -- Latin-1 letters (excl. U+00D7 multiplication sign)
	{ 0xD8, 0xF6 }, -- (excl. U+00F7 division sign)
	{ 0xF8, 0xFF },
	{ 0x100, 0x17F }, -- Latin Extended-A
}
local DIGIT_LO, DIGIT_HI = 0x30, 0x39
local PUNCT = "-_'.,!?&()#+:/" -- allowed ASCII punctuation (no < > to keep RichText inert, no quotes/backslash)
local PUNCT_SET: { [number]: boolean } = {}
for i = 1, #PUNCT do
	PUNCT_SET[string.byte(PUNCT, i)] = true
end

local function isLetter(cp: number): boolean
	for _, r in LETTER_RANGES do
		if cp >= r[1] and cp <= r[2] then
			return true
		end
	end
	return false
end

export type NameError = "NotString" | "TooLong" | "InvalidUtf8" | "BadChar" | "Empty" | "NoAlnum"

local function sanitizeName(raw: any): (string?, NameError?)
	if type(raw) ~= "string" then
		return nil, "NotString"
	end
	if #raw > NAME_MAX_INPUT_BYTES then
		return nil, "TooLong"
	end
	if utf8.len(raw) == nil then
		return nil, "InvalidUtf8"
	end
	local out = table.create(#raw)
	local count, alnum, pendingSpace = 0, false, false
	for _, cp in utf8.codes(raw) do
		if cp == 0x20 then
			pendingSpace = count > 0 -- collapse runs, drop leading
		else
			local ok = isLetter(cp) or (cp >= DIGIT_LO and cp <= DIGIT_HI) or (cp < 0x80 and PUNCT_SET[cp] == true)
			if not ok then
				return nil, "BadChar"
			end
			if pendingSpace then
				table.insert(out, " ")
				count += 1
				pendingSpace = false
			end
			table.insert(out, utf8.char(cp))
			count += 1
			if isLetter(cp) or (cp >= DIGIT_LO and cp <= DIGIT_HI) then
				alnum = true
			end
		end
	end
	if count < NAME_MIN_CP then
		return nil, "Empty"
	end
	if count > NAME_MAX_CP then
		return nil, "TooLong"
	end
	if not alnum then
		return nil, "NoAlnum"
	end
	return table.concat(out), nil
end

local cases = {
	"Épée du Roi",
	"   Big    Sword  ",
	"<b>Sword</b>",
	"Zero\u{200B}Width",
	"Emoji \u{1F5E1}",
	"Tab\tName",
	"e\u{0301}pée", -- decomposed e + combining acute
	"Œuvre d'Ætheling",
	"Łódź Blade #2",
	string.rep("a", 32),
	string.rep("a", 33),
	string.rep("é", 32),
	"...",
	"",
	"\255\254",
	"Multiplication × sign",
}
for _, c in cases do
	local name, err = sanitizeName(c)
	print(string.format("%-40q -> %s", c, if name then string.format("%q (%d cp, %d B)", name, utf8.len(name) :: number, #name) else ("ERR " .. tostring(err))))
end
