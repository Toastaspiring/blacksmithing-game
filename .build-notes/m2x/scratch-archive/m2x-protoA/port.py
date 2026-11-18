# Port the verifiers' attack folders into atk/<tag>/ with requires pointed at protoA's trees.
#   new reading (build under test) -> ../../repo/ ; old build -> ../../base/ ; FORCE Sampling -> ../../v/force_<model>/
import os, re, sys, glob, shutil
ROOT = os.path.dirname(os.path.abspath(__file__))
SCR = os.path.dirname(ROOT)
MODEL = sys.argv[1] if len(sys.argv) > 1 else 'base'
FOLDERS = {
    'v11': ('m2r5-v1-1', {'./tree/': 'NEW', './repo/': 'NEW'}),
    'v12': ('m2r5-v1-2', {'./repo/': 'NEW', './tree/': 'NEW'}),
    'v22': ('m2r5-v2-2/h', {'./repo/': 'NEW', './tree/': 'NEW', './old/': 'OLD'}),
    'v21': ('m2r5-v2-1/study', {'./tree/': 'NEW', './repo/': 'OLD'}),
    'lin': ('m2x-protoA/repo/docs/spec/prototypes/S2/verdict/lines', {'./tree/': 'NEW', './repo/': 'NEW'}),
}
REC = r'''
-- protoA: record every design the harness reads or emulates (RECORD=path in the environment)
do
	local process = require("@lune/process")
	local fs = require("@lune/fs")
	local serde = require("@lune/serde")
	local path = process.env.RECORD
	if path then
		local seen, lines = {}, {}
		local function rec(parts, tag)
			local ok, s = pcall(serde.encode, "json", parts)
			if not ok or seen[s] then return end
			seen[s] = true
			table.insert(lines, serde.encode("json", { name = tag .. " #" .. (#lines + 1), parts = parts }))
			fs.writeFile(path, table.concat(lines, "\n") .. "\n")
		end
		for _, fname in ipairs({ "reads", "emu", "valid", "show", "vsTruth" }) do
			local f = __H[fname]
			if f then
				__H[fname] = function(parts, ...)
					rec(parts, (process.env.RECTAG or "x") .. " " .. fname)
					return f(parts, ...)
				end
			end
		end
	end
end
'''
def rewrite(src, mapping, tag):
    def nw(prefix):
        return '"../../repo/' if (mapping[prefix] == 'NEW' and MODEL != 'old') else '"../../base/'
    for prefix in mapping:
        src = src.replace('"' + prefix, nw(prefix))
    src = src.replace('"./force/Sampling"', '"../../v/force_%s/Sampling"' % MODEL)
    src = src.replace('"./proto/analyze_build"', '"../../proto_%s/analyze_build"' % MODEL)
    src = src.replace('"./proto/fixtures"', '"../../proto_%s/fixtures"' % MODEL)
    src = src.replace('"./proto/analyze"', '"../../proto_%s/analyze"' % MODEL)
    return src
for tag, (folder, mapping) in FOLDERS.items():
    dst = os.path.join(ROOT, 'atk' if MODEL == 'base' else 'atk_' + MODEL, tag)
    os.makedirs(os.path.join(dst, 'out'), exist_ok=True)
    for f in glob.glob(os.path.join(SCR, folder, '*.luau')):
        s = open(f, encoding='utf-8', newline='').read()
        s = rewrite(s, mapping, tag)
        name = os.path.basename(f)
        if name in ('v1.luau', 'lib.luau') and ('function V.reads' in s or 'function L.reads' in s or 'function L.prep' in s):
            var = 'V' if 'local V = {}' in s else 'L'
            idx = s.rstrip().rfind('return ' + var)
            s = s[:idx] + REC.replace('__H', var) + '\n' + s[idx:]
        if tag == 'v12' and name == 'a30_more.luau':
            s = s.replace('local T = V.T', 'local T = require("../v11/truth")')
        if tag == 'v21' and name in ('fuller.luau', 'fuller_sweep.luau'):
            s = s.replace('Sampling.CFG.forceKept', 'require("../../v/force_%s/Sampling").FORCE.kept' % MODEL)
        open(os.path.join(dst, name), 'w', encoding='utf-8', newline='').write(s)
    for extra in ('aftman.toml',):
        p = os.path.join(SCR, folder, extra)
        if os.path.isfile(p): shutil.copy(p, dst)
    print(tag, 'ported to', dst)
