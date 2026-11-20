# Design decisions waiting for you

Written for Louis on 20 Nov 2026, after the sliding fix and M4 (the minigames). Each decision below is a row of the
spec's §17.1, an "O" number. While building, questions came up that are yours to decide. Each one already has a
default built into the game, so nothing waits on you: these pages explain each one well enough for you to keep the
default or choose otherwise. To answer, just tell me, for example "O12: (ii)" or "O4: keep".

Every section was drafted from the spec, its evidence and my journals, then checked sentence by sentence against those
sources by a second agent. Difficulty scores run from 0 up; a step plays Hard from 0.2.

| Decision | What the game does now | My recommendation |
|---|---|---|
| O12, a sword slid sideways | Reads as moved: one arrow-key press can flip a tier | **Change**: measure from the grip (ii) |
| O4, how much harder Steel feels | Steel hammering about 0.9 points lower; the tests accept half a point | Keep |
| O13, the hammering combo | Any strike that scores keeps the combo going | Keep |
| O14, the live score | Your average so far | Keep |
| O7, the complexity cap | Designs past 700,000 work units refused | Keep |
| O8, the Blade label | The label of what shows decides what Sharpening reads | Keep |
| O9, round parts as facets | Accepted for the MVP | Keep |
| O10, the 2 % hiding rule's blind spots | Accepted for the MVP | Keep |
| O11, same-looking swords built differently | Accepted; measuring the solid itself is a later study | Keep |
| O11 (j), near copies when slid | Accepted, as at M3 | Keep |
| O11 (l), a sword and its mirror image | Accepted for the MVP | Keep |

The one change I recommend is O12. The others keep what the game does now.

## From the sliding fix (after M3)

### O11 (j): Near-identical copies when a whole sword is slid

**The question.** Copy a part and nudge the copy a hair sideways or through the thickness: the game shows the one nearer
the build box's fixed centre planes and usually hides the other, so sliding the whole sword can swap them. Keep that
rule, or use another?

**What the game does now.** Since the fix made after M3 (committed on 19 Nov as 19ed843), a whole sword slid up, down or
through its thickness scores the same. Left over, exactly as at M3 (besides O11's rare cases (h) and (k)): slide a sword
so the point halfway between two near copies crosses a centre plane, and the other copy shows. The sword looks the same,
yet a step's difficulty score can move (0.2 and above plays Hard). Positions typed to a billionth of a stud can also
land on the fix's tiny safety margins, where rounding decides, as at any threshold.

**The other choices.** Each was tried in code during the fix. Speed is not the issue (ordering the parts takes about a
tenth of a millisecond); each lets something else choose the copy:
- the grip's centre: a hidden speck in the grip (test sword P5: Hammering Hard to Normal);
- the middle of the sword's outline: a hidden part poking a hair out of it;
- the middle of each group of matching parts: a hidden Ctrl+D copy (71 of 2,644 sample swords given one changed tier;
  counting exact copies once, a hidden copy a hair away still chose), and a mirror image swapped the copies;
- left before right: a mirror image reverses the choice.

**My recommendation.** Keep the default, as I ruled in the shift journal (18 Nov, 11:49) and recommended in the
plain-words M3 write-up. A forged sword cannot show a slide, while every other rule tried lets a hidden part or a mirror
image change the difficulty. Revisit if players build such copies.

**How often it matters.** On 33,389 sample swords and 3,336 test and generated swords, slid up, down and through the
thickness, no score moved. Built on purpose (7,288 nudged copies on 1,091 sample swords), a slide of 0.037 stud back
through the thickness moves the score in 359 cases, by up to 0.51, and 83 swords change tier; sideways (O12 set aside),
in 1,103 cases, by up to 0.46, and the tier label changes on 24 swords.

**Where the details are.** SPEC §17.1 O11 (j), §4.4; E-S2.14 (The fix's round 3); docs/build/M3-notes.md (After M3:
fixers T, W); .build-notes/m3/M3-spec-changes.md (O11 (j)); .build-notes/shift/shift_journal.txt (18 Nov 11:49).

### O11 (l): A sword and its mirror image

**The question.** A sword and its mirror image (the editor's flip, left to right or front to back) are equally fair and
should play the same. Two sampling rules read them differently, enough to flip a tier (on sample swords, only near the
Normal/Hard line). Accept that for the MVP, or change the sampling?

**What the game does now.** It accepts it, like O11's other classes. Thinness (how thin the metal is) reads up to about
400 probe points, picked by walking each part along its own directions, each pointed by a fixed world rule (up if it
can, else right, else forward). A mirror keeps that rule, so it walks some parts from the other end, and twin parts swap
places in the walking order: other points get picked. SurfaceComplexity (visible surface for the volume) spends a
limited budget of fine samples in that order too, so a mirror runs it out elsewhere.

**The other choices.** None is built; those measured also move ordinary swords:
- Probe points picked in mirrored pairs: unmeasured. Making every sample point a probe makes Thinness agree, at up to 30
  times the work.
- Walking from the sword's grip (my idea): tier flips 22 to 20 left/right, 25 to 25 front/back, and test sword P5's
  Hammering turns Hard to Normal.
- An unlimited fine-sample budget: front/back flips 25 to 0, left/right 22 to 16, but a laminated sample sword's own
  Hammering reads Hard (0.21), not Normal (0.17). Speed unmeasured, and the slowest test sword already sits close to its
  time limit. Spending the budget alike on mirror twins: unmeasured.

**My recommendation.** Keep the default, as I recommended in the plain-words M3 write-up: every sample sword that flips
sits within 0.033 of the Normal/Hard line, and the ways out change how the factors sample, a study for later.

**How often it matters.** Of 33,389 sample swords, the left/right mirror changes 3,065 swords' scores (up to 0.085), 22
a tier; front to back, 3,220 (up to 0.12), 25. Of 3,000 randomly generated swords, 15 flip left/right (changes up to
0.26) and 1 front to back. Another generated sword, Gen 57, its tip a wedge turned a quarter turn, plays Hammering Hard
(0.26), mirrored left to right Normal (0.11). Test swords keep their tiers, but C09 with a nudged bevel copy flips front
to back (Sharpening Hard 0.22 to Normal 0.19; there the mirror changes which copy shows, as at M3). Much the same at M3.

**Where the details are.** SPEC §17.1 O11 (l), §5.2, §5.6; E-S2.14 (What a mirror image still reads otherwise);
docs/build/M3-notes.md (After M3: fixer T); .build-notes/m3/M3-spec-changes.md (O11 (l)).

### O12: A whole sword slid sideways

**The question.** Symmetry (Asymmetry) and the grid that traces the sharpenable edge both stand on the build box's fixed
centre line. So a sword slid sideways as a whole reads as changed, though it looks the same. Keep the fixed line, or
measure from the sword itself?

**What the game does now.** Option (i), the fixed line. The Starter Sword slid 0.05 stud (one arrow-key press at the
default step) reads lopsided: Hammering 0.10 to 0.23, Sharpening 0.10 to 0.30, Normal to Hard. A lopsided sword slid the
other way can play easier (a cleaver slid 0.16 stud: Sharpening Hard to Normal). A forged sword is drawn from its own
outline, so the slide never shows in play; the editor draws the line, and "Centre on axis" recentres a sword's outline
on it. Nothing built on the sword moves the line.

**The other choices.** Neither was built (both were measured on moved copies); build time and speed are unknown.
- (ii) From the centre of the sword's visible grip. Slides change nothing (O11 (j)'s near copies aside), but an
  off-centre hilt makes a straight blade read lopsided: test sword A27 (hilt 0.04 stud aside) goes Sharpening Normal
  0.10 to Hard 0.24, breaking the SPEC's statement that no grip part can steer a factor (§4.5, test T-DIF-13). Of 98
  test swords, 20 move and 2 change tier (A27, and a slow test design's Hammering 0.18 to 0.44). Sample swords: 93 of
  33,109 move, by under 0.005, no tier.
- (iii) Centre every sword automatically. Slides change nothing, but every sword not already centred reads differently:
  5,076 sample swords change tier, all cleaver-based, nearly all Hard to Normal, and 4 test swords, two of them Normal
  to Hard. On the saved sword it changes what the player built; on a copy, the editor's line stops showing where
  symmetry is measured.

**My recommendation.** Change to (ii), measuring from the centre of the sword's visible grip, though the approved spec's
default is (i). One arrow-key press changes the Starter Sword's tier while the forged sword looks the same, and (ii)
changed no sample sword's tier; its price, a hilt built off-centre reading lopsided, is something a player can see.
Until you decide, the game keeps (i). Choosing (ii) means a build and checking round of its own.

**How often it matters.** Of 11,043 sample swords slid sideways, 23 % change slightly at 0.0001 stud (none past 0.002),
40 % at 0.0013 (9 a tier), and all at 0.05, 44 % a tier (68 % at 0.1). A slide of only 0.005 stud moves scores by up to
0.44 where it breaks the edge. At 0.05 stud, 55 of 89 test swords change tier.

**Where the details are.** SPEC §17.1 O12, §5.2, §4.6, §4.5, §11.10; E-S2.14 (A whole design moved along X; O12's
options); docs/build/M3-notes.md (After M3: fixer T); .build-notes/m3/M3-spec-changes.md (O12).

## From the minigames (M4)

### O4: How much harder Steel should feel

**The question.** The approved Q13 says Steel "plays slightly tighter minigames", and the spec's O4 row reads that as: a
simulated average player scores 1 to 8 points lower (of 100) on Normal steps in Steel. Hammering measures just under one
point: is half a point enough?

**What the game does now.** The minigames stay as tuned, Steel slightly stricter than Iron: a hammer strike scores
within 108 ms of the beat in Steel, 110 ms in Iron, on a plain Normal design. Only the target the build's tests check
moved, to 0.5 to 8 points, so hammering passes. Plainly, this departs from the approved O4 row (1 to 8 points), though
the spec already named both ways out: retune Steel, or lower the floor (§17.2, row S3).

**The other choices.** Keep the 1-point floor and make Steel hammering stricter, for example a strike window 3 %
narrower than Iron's instead of 2 %, re-measured until the gap clears one point. It is a balance change: the score
tables that rarity is tuned on are regenerated, Steel's rarity shares re-checked and the minigame statistics tests
recomputed.

**My recommendation.** Keep the default I applied for the build, half a point instead of the approved one
(lead-decisions L3). An average player already scores lower in Steel in all three minigames, and hammering is only about
a tenth of a point short, too little to justify a balance change.

**How often it matters.** The alternative would touch every Steel hammering step, and the gaps are small. On paired runs
(the same random draws in both metals, pooled with the approved table's), the average player on Normal loses about 1.6
points in smelting, 0.9 in hammering and 1.2 in sharpening; the approved table's 2,000-run figures (hammering 1.2,
sharpening 0.9) were too noisy to tell which fell short. In the build's test, 20,000 hammering runs, each in both
metals, averaged 64.9 % in Iron and 64.0 % in Steel, 0.86 points apart: small beside an average player's single scores,
which typically swing about 11 points either way. No tier moves: Steel never changes a step's tier.

**Where the details are.** SPEC §17.1 row O4, §6.13, §16.32 (`STEEL_MEAN_DROP`, the tests' Steel floor) and §17.2 row
S3; evidence E-S3.2, and E-S3.10; `docs/build/M4-notes.md` B4; `.build-notes/m4-plan/plan-r2.md` [9.1];
`.build-notes/m4-plan/lead-decisions.md` L3.

### O13: What keeps the hammering combo going

**The question.** Hammering shows a combo ("×5") and the step summary includes the best one, but the approved spec only
says the combo is feedback only, not which strikes keep it going.

**What the game does now.** Every beat struck for points adds one: Perfect, Good or Ok. A beat that ends with no points,
missed or struck too far off, resets it to zero. Stray clicks (a second click on a beat, or one between beats) leave it
alone, since only the first click on a beat counts. The combo is never saved and never touches the score, the pass line
or any balance number; the best combo goes into the step summary that the results card reads.

**The other choices.** The one named in the spec row and the plan: only Good or better keeps a combo, so an Ok strike
breaks it too. Long combos get harder to hold, since Ok is the loosest grade that still scores. It is feedback only as
well: no score, pass or balance figure moves. The change touches hammering's combo rule, its tests and the saved
reference results, which record the best combo.

**My recommendation.** Keep the default, which I chose for the build (lead-decisions L4). Either rule leaves every score
and tier as it is, so switching later moves no balance figure.

**How often it matters.** It is on screen in every hammering step (12 strikes on Normal, 15 on Hard) and never changes a
result: the score is the average of the strikes' points, whatever the combo. Nothing measures how often the two rules
differ. One example: the spec's worked round (8 Perfect, 1 Good, 2 Ok, 1 missed beat; score 81 %) has a best combo of 6
under the default, which the build checks. Worked by hand, the alternative gives 5: both Ok strikes also break the run.

**Where the details are.** SPEC §6.9, §12.7 (the "×5"), §6.14 (the step summary), §0.5; §17.1 row O13; evidence E-S3.4
(the worked round); `docs/build/M4-notes.md` B2 and B4; `.build-notes/m4-plan/plan-r2.md` [3.8] and [9.1] (new O "A");
`.build-notes/m4-plan/lead-decisions.md` L4.

### O14: What the live score shows while you play

**The question.** The Playing screen shows a live score in every step (§12.2), but the approved spec never defines it.
Should it say how well you are doing so far, or how much of the final score you have banked?

**What the game does now.** Your average so far:
- Smelting: the average credit of the scored moments (full in the zone, partial just outside it); 0 during the unscored
  3-second warm-up.
- Hammering: the average points of the beats decided so far, a missed beat counting 0.
- Sharpening: accuracy and pace so far, times the share you covered of the edge the guiding spark has passed, so a
  skipped stretch shows at once.

It ends exactly on the step's score (before any anti-cheat cap). It is display only: the server replays your inputs, and
its score replaces the live one.

**The other choices.** The one named in the spec row and the plan: the points earned so far over the whole step, a bar
that starts at 0 and fills to the final score. It shows progress, not how well you are playing: after 6 dead-centre
strikes of 12 it reads 50 %, where the default reads 100 %. It is display only too, so no score or balance figure moves.

**My recommendation.** Keep the default, which I chose for the build (lead-decisions L4). It tells players at every
moment how the step is going and still ends on the score, and the build's notes leave the screens' data to the interface
work to reshape without a balance change.

**How often it matters.** It is on screen in every step of every craft, three per sword, and never changes a result. The
build checks its end value in all three minigames, on random frame timings, timing offsets from −120 to +120 ms and lost
window focus. Nothing measures how players read either version.

**Where the details are.** SPEC §12.2, §6.8 to §6.10 (each minigame's view, where M4 defines the live score), §6.11;
§17.1 row O14; evidence E-S3.10; `docs/build/M4-notes.md` B2 (deviation 2), B3 and B4; `.build-notes/m4-plan/plan-r2.md`
[3.7] to [3.9] and [9.1] (new O "B"); `.build-notes/m4-plan/lead-decisions.md` L4.

## From the geometry core (M2)

### O7: A cap on the hidden-part check's work

**The question.** The hidden-part check counts its work in units, about one shape test each. Should a design past
700,000 units be refused, and is the slowest allowed design's wait acceptable?

**What the game does now.** Past the cap the design is invalid: the editor shows "Too complex to analyse: use fewer
overlapping parts, or overlap them less", highlights no part and blocks Forge. The cap never changes which parts count
as hidden, so hidden parts can only make their own design visibly invalid. The slowest valid designs known take about 78
ms on a Studio server for the check and about 143 ms for the whole analysis, cut into 4 ms slices over about 36
Heartbeats (server ticks): no stutter, one analysis per player. Studio times are estimates (2.6 × Lune, the test
runner), never measured.

**The other choices.** No other cap value was measured.
- Higher: more honest designs pass, but slower ones too (with no cap, searches found designs whose check would take
  about 0.7 s in Studio), and the slowest valid design already takes about 57 to 59 of the 60 ms the speed test allows
  in Lune.
- Lower: more honest designs refused. 500,000 was the starting value, raised so that P1, the heaviest real design
  tested, stays twice under.
- Checking big designs roughly instead: ruled out, as hidden parts could then change what counts.

**My recommendation.** Keep the default, as I recommended in the M3 plain-words list: real swords stay about twice under
the cap, and the slices mean no hitch.

**How often it matters.** P1 spends under half the cap, the 33,389 plausible sample swords at most 15 % of it. But an
honest sword of 24 thin rods, every part showing, spends two thirds, and two grip rods turned 5 and 9 degrees into the
guard push it over. Near the cap a mirror image, or the same shape built another way, can cost up to about 30 % more or
less, and be refused where the original passes. The cap itself never moves a tier.

**Where the details are.** SPEC §17.1 row O7, §4.4 "The cap", §4.9, §11.12, §17.2 S2 rows "The cost of the verdict" and
"What ids and order still reach"; E-S2.12 ("Cost", "Units and the cap"), E-S2.13; docs/build/M2-notes.md, "O7";
.build-notes/m3/M3-spec-changes.md, "O7".

### O8: The Blade label decides what Sharpening reads

**The question.** Sharpening reads only parts labelled Blade, and a part's label (its slot) is the player's free choice.
So relabelling the main blade, or wrapping it in a part a hair larger labelled otherwise, can drop Sharpening a tier. §5
promises that invisible building choices cannot move a tier. Is a visible label fair game, or should Sharpening pick its
parts by shape?

**What the game does now.** Shape decides what shows; the label of what shows counts. The Rapier with its main blade
labelled Guard plays Sharpening Normal (0.06) instead of Hard (0.61); the Greatsword so relabelled drops from Hard
(0.25) to Normal (0). A Guard part a hair larger round the Rapier's blade is what shows, so it does the same. Hidden
tricks fail: an invisible copy of the blade in another slot (exact, turned, a hair lower or smaller), or skins labelled
Blade hidden inside the Starter Sword's guard, are ignored and change no difficulty. A copy labelled Blade can pull a
part in, but no further than relabelling that part would.

**The other choices.**
- Pick Sharpening's parts by shape, so no label moves it. Not built: what it would change and cost is unmeasured.
- Tried and dropped: ranking parts by label before size let the hidden skins buy a tier (Starter Sword 0.10 Normal to
  0.42 Hard). Treating near-identical parts as copies only moves the line: at 0.001 stud a wrapper 0.0012 larger still
  worked, and 0.01 broke 10 existing tests.

**My recommendation.** Keep the default (accept), as I recommended in the M3 plain-words list: the label is visible and
the player's choice, and wrapping does no more than an open relabel.

**How often it matters.** The relabelled Rapier and Greatsword each drop a tier to Normal, and the Starter Sword with
its guard labelled Blade rises from Normal to Hard (0.10 to 0.28). No source counts this over sample swords: it takes
the blade labelled otherwise, or another part labelled Blade.

**Where the details are.** SPEC §17.1 row O8, §4.4 "Rank", §17.2 S2 row "A label moves Sharpening's tier"; E-S2.12
("After the verifiers' round", "After the second verifiers' round"), E-S2.11 "Ids"; docs/build/M2-notes.md, "O8";
.build-notes/m3/M3-spec-changes.md, "O8".

### O9: Round parts are read as faceted shapes

**The question.** The hidden-part check reads a Cylinder as a 32-sided prism and a Ball as 128 flat triangles. In the
thin band between model and true surface it errs both ways, enough to move a tier, though §5 promises hidden filler
cannot. Accept that for the MVP, or fix it?

**What the game does now.**
- Hidden filler can count: round filler a hair out of a round part, or tucked where it meets another, can be kept though
  under 2 % of it shows. Four such Blade Balls on the Starter Sword's pommel, made a ball, play its Sharpening Hard in
  16 of 20 swords tried, instead of Normal.
- Visible parts can be ignored: thin plates on a Cylinder's curved side, nearly half showing, can be ignored; ten Blade
  plates round a disk guard play Sharpening Normal where reading the true round shape gives Hard. On a Ball, at sword
  sizes, searches found at worst a part showing 2.4 % ignored.

**The other choices.** Tried in copies; none adopted.
- Three rules for round facets leave holes or overcorrect: the cheapest still leaves 5 of 33 test swords with poking
  Balls on a wrong tier (12 now); another ignores a plausible rivet showing 6.3 %, at 18.8 % more work on a test design.
- A "strip" reading fixes plates on a Cylinder at no extra work, but only faces parallel to its axis; slanted faces
  would need trigonometry (which §4.1 forbids) or an untried approximation.
- Finer models cost about 2 to 8 times the work, still miss thin plates and push slow designs past the O7 cap.

**My recommendation.** Keep the default, as I decided in the M2 journals: accept for the MVP. The SPEC adds: revisit if
playtests or telemetry meet filler at round parts or parts lying flush on them. Each fix leaves cases open, errs the
other way or costs far more.

**How often it matters.** On the 33,389 plausible sample swords no part showing under 2 % is kept; 455 round parts
showing 2.5 to 3.6 % are ignored, none showing 4 % or more. Every flip above is a sword reviewers built to find it;
pokes in random directions flipped 3 of 240.

**Where the details are.** SPEC §17.1 row O9, §4.4 "Verdict", §17.2 S2 rows "What hidden parts can still reach" and "The
round-part model band"; E-S2.12, third to fifth verifiers' rounds; docs/build/M2-notes.md, "O9"; journals
.build-notes/m2x/m2x_journal_r4.txt and m2x_journal_r5.txt.

## From difficulty (M3)

### O10: Blind spots of the 2 % hiding rule

**The question.** Some invisible ways of building still change a step's tier, because of how the game decides what is
hidden. Accept that for the MVP, or pay for fixes?

**What the game does now.** It accepts these limits (Hard starts at 0.2):
- A part showing under 2 % of its surface is hidden and counts as air for difficulty: a core sandwiched between two
  plates that slips under 2 % moves a step's difficulty by 0.27 to 0.41, and a blade of 8 flush layers plays Hammering
  0.70 Hard, not 0.06.
- The hide test checks one point 0.012 stud out from a face, so a face against a part thinner than that can show: the
  ornate test sword C09, its core cut diagonally in two, plays Sharpening Hard, not Normal.
- A filler sealed in a cavity still counts, and an empty cavity over 0.012 stud thick shows, so its walls read as thin
  plates (the Starter Sword's blade so hollowed: Hammering 0.54 Hard, not 0.10).
- A hidden gap lowers the volume but adds no surface, raising Sharpening: the plain test sword C02, its blade split
  nearly 0.012 stud apart, plays it Hard, not Normal.
- A hidden slit through a tilted blade makes the rims read thinner where it opens: on the Starter Sword's blade, that
  alone tips Hammering to Hard.
- Related, though visible: a tiny fin splitting the edge, whose longest piece alone counts, drops a test sword's
  Sharpening from Hard to Normal.

**The other choices.**
- Read thickness through hidden parts: cuts up to 0.36 off the core's jump, but lets hidden filler change thinness,
  which the spec forbids. A 2 % rule that sees through cavities and layers is unbuilt and uncosted.
- A segment test (any part within 0.012 stud out hides the face): ends the thin-part cases, but its measuring half alone
  adds a fifth to the slowest sword's time, past the speed test's 60 ms limit, and its hiding half is unbuilt.
- Close the slit's open ends: the end checks alone add a tenth to a sixth to that time, at or past the limit.
- O11's measure that follows the solid (not built): closes most slit openings for 4 to 12 ms more, but leaves the
  thin-part, hidden-gap and hollow-blade cases.

**My recommendation.** Keep the default, as I recommended in the M3 plain-words list: hidden parts must count in no
difficulty factor, the one-point test only errs towards harder when measuring, and each costed fix pushes the slowest
sword past the little time it has left. Revisit if playtests or telemetry meet such builds.

**How often it matters.** The big moves need a sword built to show them; no calibration sword changes tier under either
fix. Of 33,389 generated sample swords, the segment test would lower a step's tier on 197 (185 of them built on C09,
whose bevels cause it), closing slits on 2.

**Where the details are.** SPEC §17.1, row O10, and §5.6; evidence E-S2.12 and E-S2.13; docs/build/M3-notes.md;
.build-notes/m3/M3-spec-changes.md.

### O11: Same-looking swords, built different ways

**The question.** The game measures each part on its own and joins the readings by rules, so the same-looking sword
built another way (cut flush, split invisibly, hollowed, typed differently) can read another difficulty, sometimes
another tier. Accept this for the MVP, or have Thinness and the edge measure the visible solid?

**What the game does now.** Every case is accepted as built (option (i)), tests holding today's figures. Largest effects
(Normal below 0.2, Hard from 0.2):

- (a) A slanted hidden gap reads thinner where it opens to the air: a plausible ribbed bar plays Hammering Hard, Normal
  if the measure closed the opening.
- (b) A flush seam beside a tilted hidden gap: the Starter blade tilted 30° and split invisibly, one plate in 4 flush
  pieces, plays Hammering Hard; uncut, or 0.0005 stud closer, Normal.
- (c) A flush cut aimed where the pieces' Thinness probe points fall: a plate overhanging a thick blade, in 11 pieces,
  Hammering Normal → Hard (0.1075 → 0.3254); on the other edge, Hard → Normal.
- (d) A blade Wedge cut flush into shorter pieces: up to 0.052, a tier on 2 of 450 cuts.
- (e) A face flush on a part thinner than the hide distance (0.012 stud) shows: a Starter blade thinned to 0.05 stud,
  cut diagonally into two Wedges, Sharpening Normal → Hard.
- (f) An empty sealed cavity wider than the hide distance reads its walls as thin plates: the Starter blade as a hollow
  box plays Hammering Normal at a 0.0119-stud cavity, Hard at 0.0121 (0.5355).
- (g) A hidden gap's air raises SurfaceComplexity (visible area against volume): the plain arming sword's blade split
  invisibly, Sharpening Normal → Hard.
- (h) A face typed exactly a ten-billionth of a stud off a measuring line (only typing can): moving the sword up shifts
  difficulty up to 0.0007, no tier.
- (i) A part typed another way (a Ball turned): up to 0.0093, no tier.
- (k) A rib flush under a tilted, split blade: moving the sword through its thickness shifts its cutting score (0.674 or
  0.657, behind the Damage stat), not difficulty.

(a) and (e) to (g) are also O10's; (j), a whole sword moved, and (l), a mirror image, are separate write-ups.

**The other choices.**

- (iii) Measure the solid (described, not built): merge the visible parts, fill invisible gaps, read Thinness and the
  edge on one grid fixed to the sword. It closes (b), (c), (k) and most of (a) and (d), not (e) to (i), (l) or what (c)
  and (d) move through Asymmetry, and reads air under the hide distance as metal even beside a face that may show. It
  moves every sword's Thinness (calibration swords' difficulty by 0.0425 at most, estimated; no tier). Cost: about 4–12
  ms more on the two slowest test designs (59–67 ms in the test tool: at or past its 60 ms limit) unless the analysis
  budget is cut again (O7); calibration table re-recorded.
- (ii) For aimed cuts alone, at least 8 probe points per part (tried, not adopted): (c)'s plates keep their tier, but a
  part and its pieces can still differ by a tier; 1.2 % more probe points on the slowest designs, no measurable time.
- O10's own options for (a) and (e) to (g); grids that follow the solid for Asymmetry, round parts and Wedges (a study,
  cost unmeasured).
- Tried for (b) and dropped: looser hidden-gap rules; each could read visible air as metal.

**My recommendation.** Keep the default, as I recommended in the M3 plain-words list (the round-4 journal records my
decision to stop patching and ask you). The largest moves need swords built to show them, and (iii) would push the
slowest swords past their time limit: a later-phase study. Revisit if playtests or telemetry show cut, layered or hollow
designs changing tier.

**How often it matters.** Of 33,389 plausible generated swords, (e) plays 197 a tier harder than O10's segment test
would, (a) 2 harder than a closure. Unaimed flush cuts of 500 generated swords: 0.038 at most, one tier (a step 0.0011
over the line). (h), (i) and (k) changed no tier; no plausible sword shows (k).

**Where the details are.** SPEC §17.1 O11, §5's opening, §4.6, §5.2, §5.6, §14.11; SPEC-evidence E-S2.13;
docs/build/M3-notes.md; .build-notes/m3/M3-spec-changes.md; m3_journal_r3–r5.
