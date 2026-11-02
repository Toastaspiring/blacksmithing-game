--!strict
-- Definitions/Audio (SPEC §12.10, §13.11, §16.16; owner S6): the 14 sound cues as ordered rows
-- {hook, id, volume, pitchRange} [Decision to confirm] (Q20).
--   hook        PascalCase cue name; UI/Sfx.play(hook) keeps one pooled Sound per hook in SoundGroup "SFX"
--               (group Volume = settings.sfxVolume). Fired by the countdown, S3's FeedbackEvents, StepResult, the
--               rarity reveal stamp and buttons; FurnaceLoop and GrindLoop play in 3D on the active station
--               (S7's StationFx). Every cue keeps a visual twin: no information is carried by sound alone.
--   id          a Roblox-published free Creator Store sound ("rbxassetid://<n>"), picked in the build (M9, §17.2);
--               "" is legal and silent, so every id is "" until then.
--   volume      the Sound's own Volume (Roblox 0–10) inside the SFX group
--   pitchRange  {min, max} PlaybackSpeed; each play draws a random pitch in it
-- Volumes and pitch ranges are not set by the SPEC: these are neutral placeholders (Roblox's default Volume 0.5, no
-- pitch variation) until M9 picks the ids and tunes them by ear. The BALANCE Manifest excludes this module.

local Catalog = require("./Catalog")

export type AudioCue = { hook: string, id: string, volume: number, pitchRange: { number } }

export type Audio = { CUES: { AudioCue } }

local Audio: Audio = {
	CUES = {
		{ hook = "Go", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- countdown end
		{ hook = "CountdownTick", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- 3 · 2 · 1
		{ hook = "CycleStart", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- TimingStrike metronome tick
		{ hook = "StrikePerfect", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- TimingStrike grades
		{ hook = "StrikeGood", id = "", volume = 0.5, pitchRange = { 1, 1 } },
		{ hook = "StrikeOk", id = "", volume = 0.5, pitchRange = { 1, 1 } },
		{ hook = "Miss", id = "", volume = 0.5, pitchRange = { 1, 1 } },
		{ hook = "Bellows", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- HoldZone stroke
		{ hook = "FurnaceLoop", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- loop, 3D on the furnace
		{ hook = "GrindLoop", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- loop, 3D on the grindstone
		{ hook = "Pass", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- StepResult
		{ hook = "Fail", id = "", volume = 0.5, pitchRange = { 1, 1 } },
		{ hook = "RarityReveal", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- results card stamp
		{ hook = "UiClick", id = "", volume = 0.5, pitchRange = { 1, 1 } }, -- buttons
	},
}

return Catalog.deepFreeze(Audio)
