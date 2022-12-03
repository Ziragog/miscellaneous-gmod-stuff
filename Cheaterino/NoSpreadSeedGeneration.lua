--[[
	https://github.com/awesomeusername69420/miscellaneous-gmod-stuff

	Automatically generates nospread seeds for engine weapons

	https://developer.valvesoftware.com/wiki/CShotManipulator
	https://github.com/ValveSoftware/source-sdk-2013/blob/master/mp/src/game/shared/shot_manipulator.h

	Requires https://github.com/awesomeusername69420/miscellaneous-gmod-stuff/blob/main/includes/modules/CUniformRandomStream.lua
]]

require("CUniformRandomStream")

local RandomStream = CUniformRandomStream.New()

local ShotBiasMin = GetConVar("ai_shot_bias_min"):GetFloat()
local ShotBiasMax = GetConVar("ai_shot_bias_max"):GetFloat()
local ShotBiasDif = (ShotBiasMax - ShotBiasMin) + ShotBiasMin
local Flatness = math.abs(ShotBiasDif) / 2
local iFlatness = 1 - Flatness

local SpreadSeeds = {}

for Seed = 0, 255 do
	RandomStream:SetSeed(Seed)

	local FirstRan = false
	local X, Y, Z = 0, 0, 0

	while true do
		if Z <= 1 and FirstRan then break end

		X = (RandomStream:RandomFloat(-1, 1) * Flatness) + (RandomStream:RandomFloat(-1, 1) * iFlatness)
		Y = (RandomStream:RandomFloat(-1, 1) * Flatness) + (RandomStream:RandomFloat(-1, 1) * iFlatness)

		if ShotBiasDif < 0 then
			X = X >= 0 and 1 - X or -1 - X
			Y = Y >= 0 and 1 - Y or -1 - Y
		end

		Z = (X * X) + (Y * Y)
		FirstRan = true
	end

	SpreadSeeds[Seed] = {
		X = X,
		Y = Y,
		Z = Z
	 }
end
