local Analyze = require("./analyze")
local Fx = require("./fixtures")
local fmt = string.format
for _, b in ipairs(Fx.perf()) do
	local R = Analyze.run(b, { measureInvalid = true })
	local e = {}
	for _, x in ipairs(R.validation.errors) do table.insert(e, x.code .. (x.slot and (":" .. x.slot) or "") .. (x.partId and ("#" .. x.partId) or "")) end
	local c = {}
	for _, x in ipairs(R.cleaned or {}) do table.insert(c, x.reason .. "#" .. x.partId) end
	local T = R.T
	print(fmt("%-40s valid=%s err[%s] cleaned[%s] total %.1f | val %.1f surf %.1f mass %.1f edge %.1f fac %.1f | sub %d", R.name, tostring(R.valid), table.concat(e, ","), table.concat(c, ","), T.total*1000, (T.validate or 0)*1000, (T.surface or 0)*1000, (T.mass or 0)*1000, (T.edge or 0)*1000, (T.factors or 0)*1000, R.subSampled or 0))
end
