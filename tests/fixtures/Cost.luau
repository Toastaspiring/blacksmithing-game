--!strict
-- tests/fixtures/Cost.luau — S2's cost fixtures P1–P5 (SPEC §4.9, §14.7; E-S2.8), P1–P3 with a Dust speck, X08's
-- aliases and T-PERF-01's cases (§14.11). P1 is the adversarial one, 24 large tilted blocks, every pair overlapping;
-- P2–P4 chain 24 Cylinders, Wedges and Balls along Y; P5 is a comb blade. The rows are the prototype's
-- (docs/spec/prototypes/S2/v2/fixtures.luau, perf()), pasted with the bits Lune computed for them: their rotations and
-- P2–P4's positions came from trigonometry. tests/FixtureSet/Cost.spec checks them against it bit for bit.
-- Deep-frozen; Cost.core(id) hands out a mutable copy.
--
--   P1-floating …  P1, P2, P3 with part 24 a 0.05 Iron cube at (0.7, 0.2, 0.2): Dust and floating, so Disconnected and
--                  measured with measureInvalid only (E-S2.11's case, verdict/lines/d_cost.luau)
--   P1-attached …  the same cube at part 23's centre: Dust, connected and valid, the path a preview takes (it passes no
--                  measureInvalid, §11.13)
--   X08            E-S8.4's cost cases as aliases: X08a = P2 (24 rotated cylinders), X08b = P1 (24 overlapping
--                  hitbox-sized blocks), X08c = P5 (the sawtooth blade). Its 256-point zigzag edge is an EdgeChain for
--                  M4's T-PERF-02, not a blueprint
--   TPERF          T-PERF-01's cases in order: X08's aliases (P1 once, under both names), P3, P4, the specks, then
--                  WorstDesigns' valid and TooComplex designs
--
-- expect (Build.Expected): canon, validation and save as Calibration's (a floating speck is invalid). tiers and tierRaw
-- as measured for the M3 plan (.build-notes/m3-plan/plan-r2.md, [7.2]; a floating speck's with measureInvalid), which
-- T-DIF-12's goldens bless from Analyze.run; but P3's and P5's Hammering, Hard since fix round 1's θ takes every local
-- axis, a Wedge's taper among them (P3 0.1804 → 0.2752, P5 0.1902 → 0.2167, P3 with a speck 0.1759 → 0.2559). P4's Balls sit 0.01 from the hitbox, under §14.7's 0.02: it stays
-- bit-identical to the prototype, and tests/FixtureSet/Cost.spec exempts it.

local Build = require("./Build")
local WorstDesigns = require("./WorstDesigns")

type Part = Build.Part
type Core = Build.Core
type Measured = Build.Measured
export type PerfCase = { name: string, core: Core, measureInvalid: boolean }

local P = Build.part
local I, Z45, Z90 = Build.I, Build.Z45, Build.Z90

local N, H, He = "Normal", "Hard", "Hell"

local function tiers(smelting: string, hammering: string, sharpening: string): { [string]: string }
	return { Smelting = smelting, Hammering = hammering, Sharpening = sharpening }
end

local function enclosed(ids: { number }, dust: number?): { Build.Cleaned }
	local out: { Build.Cleaned } = {}
	for _, id in ids do
		table.insert(out, { partId = id, reason = "Enclosed" })
	end
	if dust then
		table.insert(out, { partId = dust, reason = "Dust" })
	end
	return out
end

-- P1: the blocks buried under the others are Enclosed (Physics' verdict, Reference.spec's OWN_VERDICT).
local GIANTS = enclosed({ 6, 8, 11, 12, 13, 15, 16, 18, 22 })

local function fixture(id: string, label: string, what: string, name: string, parts: { Part },
	played: { [string]: string }, raw: { [string]: string }?, cleaned: { Build.Cleaned }?,
	disconnected: number?): Measured
	return {
		id = id,
		label = label,
		what = what,
		core = Build.core(name, parts),
		expect = {
			canon = { ok = true, equals = "draft" },
			validation = if disconnected
				then { valid = false, errors = { { code = "Disconnected", partId = disconnected } } }
				else { valid = true, errors = {} },
			tiers = played,
			tierRaw = raw or Build.copy(played),
			cleaned = Build.copy(cleaned or {}),
			save = if disconnected then "Invalid" else "Valid",
		},
	}
end

local LIST: { Measured } = {
	fixture("P1", "P1 24 large overlapping tilted blocks",
		"24 blocks 1.0 × (3.5 − 0.01 i) × 0.40, tilted up to 8° about Z and 4° about Y", "24 tilted blocks", {
			P(1, "Pommel", "Block", "Iron", { 0, 1.95, 0 }, { -0.0005388808076438045, -0.019721167854814217, -0.02730948307934742, 0.9994323275139024 }, { 1, 3.49, 0.4 }), -- Giant1
			P(2, "Pommel", "Block", "Iron", { 0, 2, 0 }, { 6.909746847312518e-05, -0.004552492752026639, 0.015176036186609523, 0.9998744711017205 }, { 1, 3.48, 0.4 }), -- Giant2
			P(3, "Grip", "Block", "Iron", { 0, 2.05, 0 }, { -0.0006123387578596884, 0.01060588121525467, 0.057636532149416296, 0.9982811079483989 }, { 1, 3.47, 0.4 }), -- Giant3
			P(4, "Grip", "Block", "Iron", { 0, 2.1, 0 }, { 0.0011741700190963937, 0.025770922255863162, -0.045499451194499316, 0.9986312036141509 }, { 1, 3.46, 0.4 }), -- Giant4
			P(5, "Guard", "Block", "Iron", { 0, 2.15, 0 }, { -9.672397836332268e-05, -0.03186568762917756, -0.0030338090733234156, 0.999487550997459 }, { 1, 3.45, 0.4 }), -- Giant5
			P(6, "Guard", "Block", "Iron", { 0, 2.2, 0 }, { 0.000658555231923388, -0.016680683399754134, 0.03944388125585982, 0.9990823296094258 }, { 1, 3.44, 0.4 }), -- Giant6
			P(7, "Guard", "Block", "Iron", { 0, 2.25, 0 }, { -9.667496894580782e-05, -0.001514594833978171, -0.06369922970210773, 0.9979679878592286 }, { 1, 3.43, 0.4 }), -- Giant7
			P(8, "Guard", "Block", "Iron", { 0, 2.3, 0 }, { 0.0002901906512252273, 0.01365559073898388, -0.02124390596351709, 0.9996810176703209 }, { 1, 3.42, 0.4 }), -- Giant8
			P(9, "Guard", "Block", "Iron", { 0, 2.35, 0 }, { -0.0006125588587544225, 0.028825370642961083, 0.02123705541842788, 0.9993586494627917 }, { 1, 3.41, 0.4 }), -- Giant9
			P(10, "Guard", "Block", "Iron", { 0, 2.4, 0 }, { 0.0018365705700003425, -0.028773324966032864, 0.06367282166853383, 0.9975542564490953 }, { 1, 3.4, 0.4 }), -- Giant10
			P(11, "Guard", "Block", "Iron", { 0, 2.45, 0 }, { -0.0005388261911116282, -0.013648041448517547, -0.03944569849623195, 0.9991283588714214 }, { 1, 3.39, 0.4 }), -- Giant11
			P(12, "Guard", "Block", "Iron", { 0, 2.5, 0 }, { -4.606681816073459e-06, 0.0015176700363440936, 0.0030353470641514054, 0.9999942416457405 }, { 1, 3.38, 0.4 }), -- Giant12
			P(13, "Blade", "Block", "Iron", { 0, 2.55, 0 }, { -0.0007598060738239984, 0.016676378156137702, 0.04550825671199184, 0.9988244689019983 }, { 1, 3.37, 0.4 }), -- Giant13
			P(14, "Blade", "Block", "Iron", { 0, 2.6, 0 }, { 0.0018367398401659973, 0.031812855740531325, -0.057610512788245714, 0.997830445222367 }, { 1, 3.36, 0.4 }), -- Giant14
			P(15, "Blade", "Block", "Iron", { 0, 2.65, 0 }, { -0.00039151023490356445, -0.025794686059098564, -0.015171142624515684, 0.99955205833529 }, { 1, 3.35, 0.4 }), -- Giant15
			P(16, "Blade", "Block", "Iron", { 0, 2.7, 0 }, { 0.0002901799563400604, -0.01061957959146253, 0.027313257846308784, 0.9995704708877282 }, { 1, 3.34, 0.4 }), -- Giant16
			P(17, "Blade", "Block", "Iron", { 0, 2.75, 0 }, { -0.00031760241782726774, 0.00454192617967253, 0.06975575071575843, 0.9975537104724554 }, { 1, 3.33, 0.4 }), -- Giant17
			P(18, "Blade", "Block", "Iron", { 0, 2.8, 0 }, { 0.0006585916421061618, 0.0197175330893992, -0.033376206855350296, 0.9992481243224158 }, { 1, 3.32, 0.4 }), -- Giant18
			P(19, "Blade", "Block", "Iron", { 0, 2.85, 0 }, { -0.0003177927166032321, 0.03489804977183037, 0.009100392724115974, 0.9993493923459298 }, { 1, 3.31, 0.4 }), -- Giant19
			P(20, "Blade", "Block", "Iron", { 0, 2.9, 0 }, { 0.0011740834605970744, -0.022732899169788413, 0.051564777725642545, 0.9984101915152254 }, { 1, 3.3, 0.4 }), -- Giant20
			P(21, "Blade", "Block", "Iron", { 0, 2.95, 0 }, { -0.00039139120325889116, -0.007578214886956825, -0.05157665738290318, 0.9986402084260676 }, { 1, 3.29, 0.4 }), -- Giant21
			P(22, "Blade", "Block", "Iron", { 0, 3, 0 }, { 6.909874174412557e-05, 0.007588000613519473, -0.009105677641326786, 0.9999297495858123 }, { 1, 3.28, 0.4 }), -- Giant22
			P(23, "Blade", "Block", "Iron", { 0, 3.05, 0 }, { -0.000759897096345617, 0.022750510610515532, 0.0333740540450984, 0.999183671473848 }, { 1, 3.27, 0.4 }), -- Giant23
			P(24, "Blade", "Block", "Iron", { 0, 3.1, 0 }, { -0.0024344658254111962, -0.03481448328257625, -0.06971397998507722, 0.9969563611936845 }, { 1, 3.26, 0.4 }), -- Giant24
		}, tiers(H, N, N), tiers(He, N, N), GIANTS),
	fixture("P2", "P2 24 rotated cylinders", "24 Cylinders 1.0 × 0.30 turned about Z and X, chained along Y",
		"24 rotated cylinders", {
			P(1, "Pommel", "Cylinder", "Iron", { 0.12622064772118446, 0.61, 0 }, { 0.10041247696272328, -0.052271426971080025, -0.45878042650802353, 0.8813089995261217 }, { 1, 0.3, 0.3 }), -- Cyl1
			P(2, "Pommel", "Cylinder", "Iron", { 0.13639461402385225, 0.77, 0 }, { 0.20387489225394947, -0.09506842356354184, -0.41178658307170884, 0.8830791771702637 }, { 1, 0.3, 0.3 }), -- Cyl2
			P(3, "Grip", "Cylinder", "Iron", { 0.021168001208980082, 0.9299999999999999, 0 }, { 0.30839732505795714, -0.12774235463858982, -0.36073328130090104, 0.8708871801159841 }, { 1, 0.3, 0.3 }), -- Cyl3
			P(4, "Grip", "Cylinder", "Iron", { -0.11352037429618922, 1.09, 0 }, { 0.4119341318031523, -0.14993176245463802, -0.30740566853549883, 0.8445901329136354 }, { 1, 0.3, 0.3 }), -- Cyl4
			P(5, "Guard", "Cylinder", "Iron", { -0.14383864119947076, 1.25, 0 }, { 0.5124317441107493, -0.16156910830126447, -0.25361269900822864, 0.8043567179878038 }, { 1, 0.3, 0.3 }), -- Cyl5
			P(6, "Guard", "Cylinder", "Iron", { -0.04191232472983888, 1.41, 0 }, { 0.6078768187253738, -0.16288010267506386, -0.2011401756495736, 0.7506653549675371 }, { 1, 0.3, 0.3 }), -- Cyl6
			P(7, "Guard", "Cylinder", "Iron", { 0.09854798980781836, 1.57, 0 }, { 0.6963435655857265, -0.15437565185610952, -0.15170453057069944, 0.6842949160893145 }, { 1, 0.3, 0.3 }), -- Cyl7
			P(8, "Guard", "Cylinder", "Iron", { 0.14840373699350726, 1.73, 0 }, { 0.7760390996088926, -0.13683663134575172, -0.10690849325003436, 0.6063081941316425 }, { 1, 0.3, 0.3 }), -- Cyl8
			P(9, "Guard", "Cylinder", "Iron", { 0.061817772786263485, 1.89, 0 }, { 0.8453457095497858, -0.1112918739870186, -0.06819974809281501, 0.5180285170628188 }, { 1, 0.3, 0.3 }), -- Cyl9
			P(10, "Guard", "Cylinder", "Iron", { -0.08160316663340546, 2.0500000000000003, 0 }, { 0.9028590122851735, -0.07898992833716563, -0.03683360850073487, 0.4210100716628344 }, { 1, 0.3, 0.3 }), -- Cyl10
			P(11, "Guard", "Cylinder", "Iron", { -0.14999853098260552, 2.21, 0 }, { 0.9474210612177604, -0.041365296864150546, -0.013840634720558555, 0.3170026526811497 }, { 1, 0.3, 0.3 }), -- Cyl11
			P(12, "Guard", "Cylinder", "Iron", { -0.08048593770006524, 2.37, 0 }, { 0.9781476007338056, 0, 0, 0.20791169081775945 }, { 1, 0.3, 0.3 }), -- Cyl12
			P(13, "Blade", "Cylinder", "Iron", { 0.06302505552399613, 2.5300000000000002, 0 }, { 0.994448801748072, 0.0434185723585608, 0.0041807330065017825, 0.09575452860150471 }, { 1, 0.3, 0.3 }), -- Cyl13
			P(14, "Blade", "Cylinder", "Iron", { 0.14859110335423054, 2.6900000000000004, 0 }, { -0.9960429728140489, -0.08714246850588939, 0.0015210774457754522, 0.01738599476176405 }, { 1, 0.3, 0.3 }), -- Cyl14
			P(15, "Blade", "Cylinder", "Iron", { 0.09754317602356752, 2.85, 0 }, { -0.9829629131445341, -0.12940952255126037, 0.017037086855465854, 0.1294095225512604 }, { 1, 0.3, 0.3 }), -- Cyl15
			P(16, "Blade", "Cylinder", "Iron", { -0.04318549749975979, 3.0100000000000002, 0 }, { -0.9555547539512126, -0.16849008466583743, 0.04200929630861168, 0.2382465584099628 }, { 1, 0.3, 0.3 }), -- Cyl16
			P(17, "Blade", "Cylinder", "Iron", { -0.14420962378193353, 3.1700000000000004, 0 }, { -0.9144693183434972, -0.20273296702748084, 0.07579875039807311, 0.34190606798754614 }, { 1, 0.3, 0.3 }), -- Cyl17
			P(18, "Blade", "Cylinder", "Iron", { -0.11264808701575142, 3.33, 0 }, { -0.8606462131056, -0.23060945777054942, 0.11750138762820568, 0.43852114858830876 }, { 1, 0.3, 0.3 }), -- Cyl18
			P(19, "Blade", "Cylinder", "Iron", { 0.02248158144944285, 3.49, 0 }, { -0.7952910434940782, -0.25075430281998584, 0.1659706524442407, 0.526391658636985 }, { 1, 0.3, 0.3 }), -- Cyl19
			P(20, "Blade", "Cylinder", "Iron", { 0.13694178760914413, 3.6500000000000004, 0 }, { -0.7198463103929542, -0.2620026302293849, 0.2198463103929542, 0.6040227735550537 }, { 1, 0.3, 0.3 }), -- Cyl20
			P(21, "Blade", "Cylinder", "Iron", { 0.12549834578040842, 3.81, 0 }, { -0.6359567035939505, -0.26342189171070074, 0.2775887540486503, 0.670158534786501 }, { 1, 0.3, 0.3 }), -- Cyl21
			P(22, "Blade", "Cylinder", "Iron", { -0.0013276963935605814, 3.97, 0 }, { -0.545429641838343, -0.25433801897395736, 0.33751795102058385, 0.7238095817598482 }, { 1, 0.3, 0.3 }), -- Cyl22
			P(23, "Blade", "Cylinder", "Iron", { -0.1269330606262756, 4.13, 0 }, { -0.45019202619968474, -0.23435513526068436, 0.3978560699567411, 0.7642743994938895 }, { 1, 0.3, 0.3 }), -- Cyl23
			P(24, "Blade", "Cylinder", "Iron", { -0.13583675430099357, 4.29, 0 }, { -0.3522442655536472, -0.2033683215379002, 0.4567727288213003, 0.7911535738303732 }, { 1, 0.3, 0.3 }), -- Cyl24
		}, tiers(H, N, N), tiers(He, N, N)),
	fixture("P3", "P3 24 rotated wedges",
		"24 Wedges and CornerWedges 0.30 × 0.40 × 0.30 turned 11 i° about Z, chained along Y", "24 rotated wedges", {
			P(1, "Pommel", "CornerWedge", "Iron", { 0.10097651817694758, 0.62, 0 }, { 0, 0, 0.09584575252022398, 0.9953961983671789 }, { 0.3, 0.4, 0.3 }), -- W1
			P(2, "Pommel", "Wedge", "Iron", { 0.1091156912190818, 0.74, 0 }, { 0, 0, 0.1908089953765448, 0.981627183447664 }, { 0.3, 0.4, 0.3 }), -- W2
			P(3, "Grip", "CornerWedge", "Iron", { 0.016934400967184064, 0.86, 0 }, { 0, 0, 0.28401534470392265, 0.958819734868193 }, { 0.3, 0.4, 0.3 }), -- W3
			P(4, "Grip", "Wedge", "Iron", { -0.09081629943695138, 0.98, 0 }, { 0, 0, 0.374606593415912, 0.9271838545667874 }, { 0.3, 0.4, 0.3 }), -- W4
			P(5, "Guard", "CornerWedge", "Iron", { -0.11507091295957661, 1.1, 0 }, { 0, 0, 0.4617486132350339, 0.8870108331782217 }, { 0.3, 0.4, 0.3 }), -- W5
			P(6, "Guard", "Wedge", "Iron", { -0.0335298597838711, 1.22, 0 }, { 0, 0, 0.5446390350150271, 0.838670567945424 }, { 0.3, 0.4, 0.3 }), -- W6
			P(7, "Guard", "CornerWedge", "Iron", { 0.07883839184625469, 1.3399999999999999, 0 }, { 0, 0, 0.6225146366376196, 0.7826081568524139 }, { 0.3, 0.4, 0.3 }), -- W7
			P(8, "Guard", "Wedge", "Iron", { 0.11872298959480582, 1.46, 0 }, { 0, 0, 0.6946583704589973, 0.7193398003386512 }, { 0.3, 0.4, 0.3 }), -- W8
			P(9, "Guard", "CornerWedge", "Iron", { 0.04945421822901079, 1.58, 0 }, { 0, 0, 0.7604059656000309, 0.6494480483301837 }, { 0.3, 0.4, 0.3 }), -- W9
			P(10, "Guard", "Wedge", "Iron", { -0.06528253330672437, 1.7, 0 }, { 0, 0, 0.8191520442889918, 0.573576436351046 }, { 0.3, 0.4, 0.3 }), -- W10
			P(11, "Guard", "CornerWedge", "Iron", { -0.11999882478608441, 1.8199999999999998, 0 }, { 0, 0, 0.8703556959398997, 0.4924235601034671 }, { 0.3, 0.4, 0.3 }), -- W11
			P(12, "Guard", "Wedge", "Iron", { -0.06438875016005219, 1.94, 0 }, { 0, 0, 0.9135454576426009, 0.4067366430758002 }, { 0.3, 0.4, 0.3 }), -- W12
			P(13, "Blade", "CornerWedge", "Iron", { 0.05042004441919691, 2.06, 0 }, { 0, 0, 0.9483236552061993, 0.3173046564050921 }, { 0.3, 0.4, 0.3 }), -- W13
			P(14, "Blade", "Wedge", "Iron", { 0.11887288268338443, 2.1799999999999997, 0 }, { 0, 0, 0.9743700647852352, 0.22495105434386492 }, { 0.3, 0.4, 0.3 }), -- W14
			P(15, "Blade", "CornerWedge", "Iron", { 0.07803454081885401, 2.3, 0 }, { 0, 0, 0.9914448613738104, 0.1305261922200517 }, { 0.3, 0.4, 0.3 }), -- W15
			P(16, "Blade", "Wedge", "Iron", { -0.034548397999807835, 2.42, 0 }, { 0, 0, 0.9993908270190958, 0.03489949670250108 }, { 0.3, 0.4, 0.3 }), -- W16
			P(17, "Blade", "CornerWedge", "Iron", { -0.11536769902554682, 2.54, 0 }, { 0, 0, -0.998134798421867, 0.06104853953485678 }, { 0.3, 0.4, 0.3 }), -- W17
			P(18, "Blade", "Wedge", "Iron", { -0.09011846961260114, 2.66, 0 }, { 0, 0, -0.9876883405951378, 0.1564344650402308 }, { 0.3, 0.4, 0.3 }), -- W18
			P(19, "Blade", "CornerWedge", "Iron", { 0.01798526515955428, 2.78, 0 }, { 0, 0, -0.9681476403781077, 0.2503800040544414 }, { 0.3, 0.4, 0.3 }), -- W19
			P(20, "Blade", "Wedge", "Iron", { 0.10955343008731531, 2.9, 0 }, { 0, 0, -0.9396926207859084, 0.3420201433256687 }, { 0.3, 0.4, 0.3 }), -- W20
			P(21, "Blade", "CornerWedge", "Iron", { 0.10039867662432672, 3.02, 0 }, { 0, 0, -0.9025852843498607, 0.4305110968082949 }, { 0.3, 0.4, 0.3 }), -- W21
			P(22, "Blade", "Wedge", "Iron", { -0.0010621571148484651, 3.1399999999999997, 0 }, { 0, 0, -0.8571673007021123, 0.5150380749100543 }, { 0.3, 0.4, 0.3 }), -- W22
			P(23, "Blade", "CornerWedge", "Iron", { -0.10154644850102047, 3.26, 0 }, { 0, 0, -0.8038568606172174, 0.5948227867513411 }, { 0.3, 0.4, 0.3 }), -- W23
			P(24, "Blade", "Wedge", "Iron", { -0.10866940344079486, 3.38, 0 }, { 0, 0, -0.7431448254773942, 0.6691306063588582 }, { 0.3, 0.4, 0.3 }), -- W24
		}, tiers(H, H, N)),
	fixture("P4", "P4 24 overlapping balls", "24 Balls 0.58 across chained along Y, 0.01 from the hitbox's sides",
		"24 overlapping balls", {
			P(1, "Pommel", "Ball", "Iron", { 0.16829419696157932, 0.5700000000000001, 0 }, I, { 0.58, 0.58, 0.58 }), -- B1
			P(2, "Pommel", "Ball", "Iron", { 0.18185948536513635, 0.74, 0 }, I, { 0.58, 0.58, 0.58 }), -- B2
			P(3, "Grip", "Ball", "Iron", { 0.028224001611973443, 0.91, 0 }, I, { 0.58, 0.58, 0.58 }), -- B3
			P(4, "Grip", "Ball", "Iron", { -0.15136049906158566, 1.08, 0 }, I, { 0.58, 0.58, 0.58 }), -- B4
			P(5, "Guard", "Ball", "Iron", { -0.1917848549326277, 1.25, 0 }, I, { 0.58, 0.58, 0.58 }), -- B5
			P(6, "Guard", "Ball", "Iron", { -0.055883099639785175, 1.42, 0 }, I, { 0.58, 0.58, 0.58 }), -- B6
			P(7, "Guard", "Ball", "Iron", { 0.13139731974375782, 1.5900000000000003, 0 }, I, { 0.58, 0.58, 0.58 }), -- B7
			P(8, "Guard", "Ball", "Iron", { 0.19787164932467638, 1.7600000000000002, 0 }, I, { 0.58, 0.58, 0.58 }), -- B8
			P(9, "Guard", "Ball", "Iron", { 0.08242369704835133, 1.9300000000000002, 0 }, I, { 0.58, 0.58, 0.58 }), -- B9
			P(10, "Guard", "Ball", "Iron", { -0.10880422217787396, 2.1, 0 }, I, { 0.58, 0.58, 0.58 }), -- B10
			P(11, "Guard", "Ball", "Iron", { -0.1999980413101407, 2.27, 0 }, I, { 0.58, 0.58, 0.58 }), -- B11
			P(12, "Guard", "Ball", "Iron", { -0.107314583600087, 2.44, 0 }, I, { 0.58, 0.58, 0.58 }), -- B12
			P(13, "Blade", "Ball", "Iron", { 0.08403340736532819, 2.61, 0 }, I, { 0.58, 0.58, 0.58 }), -- B13
			P(14, "Blade", "Ball", "Iron", { 0.19812147113897408, 2.7800000000000002, 0 }, I, { 0.58, 0.58, 0.58 }), -- B14
			P(15, "Blade", "Ball", "Iron", { 0.13005756803142338, 2.95, 0 }, I, { 0.58, 0.58, 0.58 }), -- B15
			P(16, "Blade", "Ball", "Iron", { -0.057580663333013066, 3.12, 0 }, I, { 0.58, 0.58, 0.58 }), -- B16
			P(17, "Blade", "Ball", "Iron", { -0.19227949837591138, 3.29, 0 }, I, { 0.58, 0.58, 0.58 }), -- B17
			P(18, "Blade", "Ball", "Iron", { -0.15019744935433524, 3.46, 0 }, I, { 0.58, 0.58, 0.58 }), -- B18
			P(19, "Blade", "Ball", "Iron", { 0.02997544193259047, 3.6300000000000003, 0 }, I, { 0.58, 0.58, 0.58 }), -- B19
			P(20, "Blade", "Ball", "Iron", { 0.18258905014552554, 3.8000000000000003, 0 }, I, { 0.58, 0.58, 0.58 }), -- B20
			P(21, "Blade", "Ball", "Iron", { 0.16733112770721123, 3.97, 0 }, I, { 0.58, 0.58, 0.58 }), -- B21
			P(22, "Blade", "Ball", "Iron", { -0.0017702618580807752, 4.140000000000001, 0 }, I, { 0.58, 0.58, 0.58 }), -- B22
			P(23, "Blade", "Ball", "Iron", { -0.16924408083503414, 4.3100000000000005, 0 }, I, { 0.58, 0.58, 0.58 }), -- B23
			P(24, "Blade", "Ball", "Iron", { -0.18111567240132476, 4.48, 0 }, I, { 0.58, 0.58, 0.58 }), -- B24
		}, tiers(H, N, N), tiers(He, N, N)),
	fixture("P5", "P5 comb blade (sawtooth)", "F5 + 10 Wedge teeth, 5 a side on the blade's edges (15 parts)",
		"Comb blade", {
			P(1, "Pommel", "Ball", "Iron", { 0, 0.17, 0 }, I, { 0.26, 0.26, 0.26 }), -- Pommel
			P(2, "Grip", "Block", "Iron", { 0, 0.75, 0 }, I, { 0.16, 0.9, 0.16 }), -- Grip
			P(3, "Guard", "Block", "Iron", { 0, 1.29, 0 }, I, { 1, 0.18, 0.24 }), -- Guard
			P(4, "Blade", "Block", "Iron", { 0, 2.68, 0 }, I, { 0.16, 2.6, 0.06 }), -- Blade
			P(5, "Blade", "Block", "Iron", { 0, 3.98, 0 }, Z45, { 0.113, 0.113, 0.055 }), -- Tip
			P(6, "Blade", "Wedge", "Iron", { -0.14, 1.6, 0 }, { 0, 0, -0.7071067811865476, 0.7071067811865476 }, { 0.08, 0.12, 0.06 }), -- Tooth0-1
			P(7, "Blade", "Wedge", "Iron", { 0.14, 1.6, 0 }, Z90, { 0.08, 0.12, 0.06 }), -- Tooth01
			P(8, "Blade", "Wedge", "Iron", { -0.14, 2.0500000000000003, 0 }, { 0, 0, -0.7071067811865476, 0.7071067811865476 }, { 0.08, 0.12, 0.06 }), -- Tooth1-1
			P(9, "Blade", "Wedge", "Iron", { 0.14, 2.0500000000000003, 0 }, Z90, { 0.08, 0.12, 0.06 }), -- Tooth11
			P(10, "Blade", "Wedge", "Iron", { -0.14, 2.5, 0 }, { 0, 0, -0.7071067811865476, 0.7071067811865476 }, { 0.08, 0.12, 0.06 }), -- Tooth2-1
			P(11, "Blade", "Wedge", "Iron", { 0.14, 2.5, 0 }, Z90, { 0.08, 0.12, 0.06 }), -- Tooth21
			P(12, "Blade", "Wedge", "Iron", { -0.14, 2.95, 0 }, { 0, 0, -0.7071067811865476, 0.7071067811865476 }, { 0.08, 0.12, 0.06 }), -- Tooth3-1
			P(13, "Blade", "Wedge", "Iron", { 0.14, 2.95, 0 }, Z90, { 0.08, 0.12, 0.06 }), -- Tooth31
			P(14, "Blade", "Wedge", "Iron", { -0.14, 3.4000000000000004, 0 }, { 0, 0, -0.7071067811865476, 0.7071067811865476 }, { 0.08, 0.12, 0.06 }), -- Tooth4-1
			P(15, "Blade", "Wedge", "Iron", { 0.14, 3.4000000000000004, 0 }, Z90, { 0.08, 0.12, 0.06 }), -- Tooth41
		}, tiers(N, H, N)),
}

local BY_ID: { [string]: Measured } = {}
for _, f in LIST do
	BY_ID[f.id] = f
end

-- P1–P3 with part 24 replaced by a 0.05 Iron cube in its slot, at (0.7, 0.2, 0.2) or at part 23's centre.
local function speck(id: string, kind: string, played: { [string]: string }, raw: { [string]: string }?,
	cleaned: { Build.Cleaned }): Measured
	local base = BY_ID[id]
	local parts = Build.copy(base.core.parts)
	local last = parts[24]
	local floating = kind == "floating"
	local pos = if floating then { 0.7, 0.2, 0.2 } else parts[23].pos
	parts[24] = P(last.id, last.slot, "Block", "Iron", pos, I, { 0.05, 0.05, 0.05 })
	local where = if floating then "at (0.7, 0.2, 0.2), floating" else "at part 23's centre, attached"
	return fixture(id .. "-" .. kind, base.label .. " + a " .. kind .. " speck",
		id .. " with part 24 a 0.05 Iron cube " .. where, base.core.name .. " + a speck", parts, played, raw, cleaned,
		if floating then 24 else nil)
end

type Specked = { id: string, played: { [string]: string }, raw: { [string]: string }?, cleaned: { Build.Cleaned } }
local SPECKED: { Specked } = {
	-- without Giant24, Giant15 shows enough to be kept
	{ id = "P1", played = tiers(H, N, N), raw = tiers(He, N, N), cleaned = enclosed({ 6, 8, 11, 12, 13, 16, 18, 22 },
		24) },
	{ id = "P2", played = tiers(H, N, N), raw = tiers(He, N, N), cleaned = enclosed({}, 24) },
	{ id = "P3", played = tiers(H, H, N), cleaned = enclosed({}, 24) },
}
for _, kind in { "floating", "attached" } do
	for _, s in SPECKED do
		local f = speck(s.id, kind, s.played, s.raw, s.cleaned)
		table.insert(LIST, f)
		BY_ID[f.id] = f
	end
end

local ORDER: { string } = {}
for _, f in LIST do
	table.insert(ORDER, f.id)
end

local X08: { [string]: string } = { X08a = "P2", X08b = "P1", X08c = "P5" }

local TPERF: { PerfCase } = {}
local function case(name: string, core: Core, measureInvalid: boolean?)
	table.insert(TPERF, { name = name, core = core, measureInvalid = measureInvalid == true })
end
case("P2 (X08a)", BY_ID.P2.core)
case("P1 (X08b)", BY_ID.P1.core)
case("P5 (X08c)", BY_ID.P5.core)
case("P3", BY_ID.P3.core)
case("P4", BY_ID.P4.core)
for _, kind in { "floating", "attached" } do
	for _, id in { "P1", "P2", "P3" } do
		case(id .. " + " .. kind .. " speck", BY_ID[id .. "-" .. kind].core, kind == "floating")
	end
end
for k, d in WorstDesigns.valid do
	case(string.format("worst valid %d: %s", k, d.name), Build.core("Worst valid " .. k, d.parts))
end
for k, d in WorstDesigns.tooComplex do
	case(string.format("TooComplex %d: %s", k, d.name), Build.core("TooComplex " .. k, d.parts))
end

local Cost = {
	order = ORDER, -- {"P1", …, "P5", "P1-floating", "P2-floating", "P3-floating", "P1-attached", …}
	list = LIST, -- the fixtures, in that order
	X08 = X08, -- alias → fixture id
	TPERF = TPERF,
}

-- The fixture with this id; errors on an unknown id (a test bug).
function Cost.get(id: string): Measured
	local f = BY_ID[id]
	if f == nil then
		error("Cost.get: no fixture " .. tostring(id), 2)
	end
	return f
end

-- A fresh, mutable deep copy of the fixture's core.
function Cost.core(id: string): Core
	return Build.copy(Cost.get(id).core)
end

Build.freeze(LIST)
table.freeze(ORDER)
table.freeze(X08)
Build.freeze(TPERF)
return table.freeze(Cost)
