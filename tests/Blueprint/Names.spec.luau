--!strict
-- T-BP-13 Blueprint/Names (SPEC §3.9, E-S1.5): the accept / reject list of E-S1.5, every rule of §3.9 at its
-- boundary, the error order, idempotency, and P-TOTAL on hostile values (FUZZ_N_GARBAGE).

local Test = require("../lib/Test")
local A = require("../lib/Assert")
local Dump = require("../lib/Dump")
local Prop = require("../lib/Prop")
local Tol = require("../lib/Tol")
local TestRng = require("../lib/TestRng")
local Drafts = require("./Drafts")
local Names = require("../../src/shared/Blueprint/Names")
local Limits = require("../../src/shared/Definitions/Limits")

type TestRng = TestRng.TestRng

local ERRORS: { [string]: boolean } = {
	NotString = true, TooLong = true, InvalidUtf8 = true, BadChar = true, Empty = true, NoAlnum = true,
}

local function accepts(raw: string, want: string?)
	local name, err = Names.sanitize(raw)
	local expected = want or raw
	if name ~= expected or err ~= nil then
		A.fail(string.format("sanitize(%s) = %s, %s; expected %s", Dump.quote(raw), Dump.short(name), Dump.short(err),
			Dump.quote(expected)))
	end
end

local function rejects(raw: any, code: string)
	local name, err = Names.sanitize(raw)
	if name ~= nil or err ~= code then
		A.fail(string.format("sanitize(%s) = %s, %s; expected nil, %s", Dump.short(raw), Dump.short(name),
			Dump.short(err), code))
	end
end

return Test.suite("Blueprint/Names", function(t)
	t.it("T-BP-13 the accept / reject list of E-S1.5", function()
		accepts("Épée du Roi")
		A.eq(utf8.len("Épée du Roi"), 11)
		A.eq(#"Épée du Roi", 13)
		accepts("   Big    Sword  ", "Big Sword")
		accepts("Œuvre d'Ætheling")
		accepts("Łódź Blade #2")
		accepts(string.rep("a", 32))
		accepts(string.rep("é", 32))
		A.eq(#string.rep("é", 32), 64)
		rejects("<b>Sword</b>", "BadChar")
		rejects("Zero\u{200B}Width", "BadChar")
		rejects("Emoji \u{1F5E1}", "BadChar")
		rejects("Tab\tName", "BadChar")
		rejects("e\u{0301}pée", "BadChar") -- decomposed e + combining acute
		rejects("Multiplication × sign", "BadChar")
		rejects(string.rep("a", 33), "TooLong")
		rejects("...", "NoAlnum")
		rejects("", "Empty")
		rejects("\255\254", "InvalidUtf8")
	end)

	t.it("T-BP-13 raw input: a string of at most 256 bytes of valid UTF-8, checked before parsing", function()
		for _, v in ({ 5, true, {}, 0 / 0, function() end } :: { any }) do
			rejects(v, "NotString")
		end
		rejects(nil, "NotString")
		rejects(string.rep("a", Limits.NAME_MAX_INPUT_BYTES + 1), "TooLong")
		rejects(string.rep(" ", 300) .. "a", "TooLong") -- bytes count before spaces collapse
		rejects(string.rep("<", 300), "TooLong") -- the byte limit comes before the characters
		accepts(string.rep(" ", Limits.NAME_MAX_INPUT_BYTES - 1) .. "a", "a")
		-- a stray continuation byte, a truncated sequence, overlong forms, a surrogate, beyond U+10FFFF, 0xFF
		local broken = { "\128", "a\128b", "\195", "\192\128", "\224\128\128", "\237\160\128", "\244\144\128\128", "\255" }
		for _, bad in broken do
			rejects(bad, "InvalidUtf8")
		end
		rejects("\255<", "InvalidUtf8") -- UTF-8 is checked before the characters
	end)

	t.it("T-BP-13 whitespace: ASCII space only, runs collapse, ends trimmed", function()
		accepts("a  b   c", "a b c")
		accepts(" Sword", "Sword")
		accepts("Sword ", "Sword")
		accepts("a" .. string.rep(" ", 100) .. "b", "a b")
		rejects("   ", "Empty")
		rejects(" ", "Empty")
		for _, ws in { "\t", "\n", "\r", "\v", "\f", "\u{A0}", "\u{2002}", "\u{3000}", "\0" } do
			rejects("a" .. ws .. "b", "BadChar")
		end
	end)

	t.it("T-BP-13 length: 1–32 code points after normalization", function()
		accepts(string.rep(" a", 16), string.sub(string.rep(" a", 16), 2)) -- 31 code points
		accepts(string.rep("ab", 16)) -- 32
		rejects("a" .. string.rep(" a", 16), "TooLong") -- 33 after collapsing
		accepts(string.rep("ſ", 32)) -- 32 two-byte letters = 64 bytes
		rejects(string.rep("ſ", 33), "TooLong")
	end)

	t.it("T-BP-13 letters: Latin only, with the boundaries of each range", function()
		for _, ok in { "A", "Z", "a", "z", "À", "Ö", "Ø", "ö", "ø", "ÿ", "Ā", "ſ", "ß", "Æ", "Œ" } do
			accepts(ok)
		end
		for _, cp in { 0x40, 0x5B, 0x60, 0x7B, 0xBF, 0xD7, 0xF7, 0x180, 0x391, 0x416, 0x4E00, 0x1F600 } do
			rejects("a" .. utf8.char(cp), "BadChar")
		end
	end)

	t.it("T-BP-13 digits and punctuation: 0–9 and - _ ' . , ! ? & ( ) # + : /, nothing else", function()
		accepts("0123456789")
		accepts("a-_'.,!?&()#+:/")
		rejects("-_'.,!?&()#+:/", "NoAlnum")
		for _, bad in { '"', "\\", "<", ">", "@", "$", "%", "*", "=", ";", "[", "]", "{", "}", "|", "~", "`", "^" } do
			rejects("a" .. bad, "BadChar")
		end
	end)

	t.it("T-BP-13 errors come in check order", function()
		rejects(string.rep("a", 40) .. "<", "BadChar") -- a bad character before the length
		rejects(string.rep("a", 40) .. "!", "TooLong")
		rejects(" ... ", "NoAlnum")
		rejects("", "Empty")
	end)

	t.it("T-BP-13 idempotent, ≤ 32 code points and ≤ 64 bytes, two results (PROP_N names)", function()
		local CHARS = { "a", "Z", "é", "Œ", "ſ", "7", " ", " ", " ", "-", "'", ".", "#", "/", "<", "\t", "×" }
		Prop.check(Tol.PROP_N, function(rng: TestRng): string
			local out = {}
			for i = 1, rng:int(0, 40) do
				out[i] = rng:pick(CHARS)
			end
			return table.concat(out)
		end, function(raw: string)
			local name, err = Names.sanitize(raw)
			A.truthy((name == nil) ~= (err == nil), "exactly one of name and error")
			if name then
				local again, err2 = Names.sanitize(name)
				A.eq(again, name, "sanitize(sanitize(x)) == sanitize(x)")
				A.eq(err2, nil)
				A.truthy((utf8.len(name) :: number) <= Limits.NAME_MAX_CP and #name <= 64, "bounded")
				A.falsy(string.find(name, "  ", 1, true) or string.sub(name, 1, 1) == " " or string.sub(name, -1) == " ",
					"spaces normalized")
			else
				A.truthy(ERRORS[err :: string], "a NameError")
			end
		end)
	end)

	t.it("T-BP-13 total: FUZZ_N_GARBAGE hostile values never throw", function()
		Prop.check(Tol.FUZZ_N_GARBAGE, function(rng: TestRng): any
			return Drafts.garbage(rng, 1)
		end, function(v: any)
			local okCall, name, err = pcall(Names.sanitize, v)
			A.truthy(okCall, "sanitize threw: " .. tostring(name))
			local named = type(name) == "string" and err == nil
			A.truthy(named or (name == nil and ERRORS[err :: any]), "a name or a NameError")
		end)
	end)
end)
