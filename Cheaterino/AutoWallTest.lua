--[[
	https://github.com/awesomeusername69420/miscellaneous-gmod-stuff

	An attempt to improve the autowall from the unfinished project
]]

local Cache = {
	ConVars = {
		SetViewAngles = CreateClientConVar("autowall_setviewangles", 1, true, false, "", 0, 1),

		Penetration = {
			ArcCW = GetConVar("arccw_enable_penetration"),
			M9K = GetConVar("M9KDisablePenetration"),
			TFA = GetConVar("sv_tfa_bullet_penetration"),
			TFA_Multiplier = GetConVar("sv_tfa_bullet_penetration_power_mul"),
			TFA_HardLimit = GetConVar("sv_tfa_penetration_hardlimit")
		}
	},

	AmmoPen = {
		Max = { -- Gets :lower()'d; The 2nd values may need some tweaking to be more reliable as the more penetrations there are the chance of the next shot penetrating goes down
			["357"] = {144, 4},
			ar2 = {256, 8},
			buckshot = {25, 1},
			pistol = {81, 2},
			smg1 = {196, 5},
			sniperpenetratedround = {400, 12},
			sniperround = {400, 12} -- Queer SWB
		},

		Materials = {
			Multipliers = {
				[MAT_SAND] = 0.5,
				[MAT_DIRT] = 0.8,
				[MAT_METAL] = 1.1,
				[MAT_TILE] = 0.9,
				[MAT_WOOD] = 1.2
			},

			NoPenetration = {
				[MAT_SLOSH] = true
			}
		}
	},

	Colors = {
		Red = Color(255, 0, 0),
		Green = Color(0, 255, 0),
		Orange = Color(255, 150, 0),
		Aqua = Color(0, 255, 255),
		Purple = Color(120, 0, 150),
		Pink = Color(255, 0, 200)
	},

	DebugVectors = {
		Mins = Vector(-1, -1, -1),
		Maxs = Vector(1, 1, 1)
	}
}

local function GetConVarBoolSafe(ConVar)
	if not ConVar then return false end
	return ConVar:GetBool()
end

local function GetWeaponBase(Weapon)
	if not Weapon.Base then return "" end
	return Weapon.Base:lower():Split("_")[1]
end

local function WeaponIsBase(Weapon, Base)
	return GetWeaponBase(Weapon) == Base
end

local function GetWeaponAmmoName(Weapon)
	if Weapon.Primary and Weapon.Primary.Ammo then
		return Weapon.Primary.Ammo:lower()
	else
		return tostring(game.GetAmmoName(Weapon:GetPrimaryAmmoType())):lower()
	end
end

-- Shorthand for CW based weapons and similar
local function CWCanPenetrate(Weapon, TraceData)
	if Cache.AmmoPen.Materials.NoPenetration[TraceData.MatType] or (Weapon.CanPenetrate ~= nil and not Weapon.CanPenetrate) then
		return false
	end

	local Entity = TraceData.Entity
	if IsValid(Entity) and (Entity:IsPlayer() or Entity:IsNPC()) then
		return false
	end

	return -TraceData.Normal:Dot(TraceData.HitNormal) > 0.26
end

local function GetWeaponMaxPenetration(Weapon, TraceData) -- It'd be nicer to make a function table indexed by bases but meh
	if WeaponIsBase(Weapon, "bobs") then
		if GetConVarBoolSafe(Cache.ConVars.Penetration.M9K) then
			return nil
		end

		-- Ricocheting is random :(

		local DataTable = Cache.AmmoPen.Max[GetWeaponAmmoName(Weapon)]
		if not DataTable then return nil end

		return DataTable[1], DataTable[2]
	end

	-- TFA is off by a small fraction, the numbers are weird plus there's some other logic that isn't being accounted for
	if WeaponIsBase(Weapon, "tfa") then
		if not GetConVarBoolSafe(Cache.ConVars.Penetration.TFA) then
			return nil
		end

		local ForceMultiplier = Weapon:GetAmmoForceMultiplier()
		local PenetrationMultiplier = Weapon:GetPenetrationMultiplier(TraceData.MatType)
		local Multiplier = Cache.ConVars.Penetration.TFA_Multiplier:GetFloat()

		local DataTable = Cache.AmmoPen.Max[GetWeaponAmmoName(Weapon)]
		local MaxPen = math.Clamp(DataTable and DataTable[2] or 1, 0, Cache.ConVars.Penetration.TFA_HardLimit:GetInt())

		return math.Truncate(((ForceMultiplier / PenetrationMultiplier) * Multiplier) * 0.9, 5), MaxPen
	end

	-- Haven't quite worked out the penetration logic with these weapons yet
	-- There's more to them than just distance, so some further logic will need implemented at some point
	if WeaponIsBase(Weapon, "arccw") then
		if not GetConVarBoolSafe(Cache.ConVars.Penetration.ArcCW) then
			return nil
		end

		local DataTable = Cache.AmmoPen.Max[GetWeaponAmmoName(Weapon)]
		return math.pow(Weapon.Penetration, 2), DataTable and DataTable[2] or 1 -- Weapon.Penetration seems to be a 'legacy' thing, a new calculation will need to be made (Unless I just looked in the wrong file)
	end

	-- CW and FA:S also have retarded ammo names, so even though that logic may be better I don't feel like constructing that right now
	if not CWCanPenetrate(Weapon, TraceData) then return nil end

	if WeaponIsBase(Weapon, "cw") then
		local Strength = Weapon.PenStr * Weapon.PenMod
		local Multiplier = Weapon.PenetrationMaterialInteraction and Weapon.PenetrationMaterialInteraction[TraceData.MatType] or 1
		return math.pow(Strength, 2) + (Strength * Multiplier), 1
	end

	if WeaponIsBase(Weapon, "fas2") then
		local Strength = Weapon.PenStr * Weapon.PenMod
		local Multiplier = Cache.AmmoPen.Materials.Multipliers[TraceData.MatType] or 1
		return math.pow(Strength, 2) + (Strength * Multiplier), 1
	end

	if WeaponIsBase(Weapon, "swb") then
		local DataTable = Cache.AmmoPen.Max[GetWeaponAmmoName(Weapon)]
		if not DataTable then return nil end

		local Multiplier = Cache.AmmoPen.Materials.Multipliers[TraceData.MatType] or 1
		return DataTable[1] * Multiplier * Weapon.PenMod, 1
	end

	return nil
end

local function WeaponCanPenetrate(Weapon, TraceData, Target, TargetPos)
	local MaxDistance, MaxTimes = GetWeaponMaxPenetration(Weapon, TraceData)
	if not MaxDistance then return false end

	local tr = {}
	local Trace = {
		start = TargetPos,
		endpos = TraceData.HitPos,
		filter = {Target},
		mask = MASK_SHOT,
		output = tr -- Optimization woo
	}

	util.TraceLine(Trace)

	if not Weapon:IsScripted() then -- Engine weapons can't penetrate anything
		return TraceData.Entity == Target
	end

	local CurTimes = 1
	local LastPos = tr.HitPos

	local Mins, Maxs = Cache.DebugVectors.Mins, Cache.DebugVectors.Maxs

	debugoverlay.Text(tr.HitPos, CurTimes, 0.1, false)
	debugoverlay.Box(tr.HitPos, Mins, Maxs, 0.1, Cache.Colors.Orange)

	local World = game.GetWorld()
	local IsTFA = WeaponIsBase(Weapon, "tfa")

	if IsTFA then
		MaxDistance = MaxDistance / 2
	end

	while CurTimes <= MaxTimes do
		if tr.Entity ~= World then
			if tr.Entity == Target then break end -- Success!

			local Entity = tr.Entity

			Trace.start = LastPos

			util.TraceLine(Trace)

			Trace.start = tr.HitPos - TraceData.Normal
			Trace.endpos = LastPos
			Trace.filter[2] = Entity

			util.TraceLine(Trace)
		else
			local OriginalEndPos = Trace.endpos

			debugoverlay.Text(Trace.start, "OriginalStartPos - " .. CurTimes, 0.1, false)
			debugoverlay.Line(Trace.start, Trace.endpos, 0.1, Cache.Colors.Purple, true)

			for i = 1, 75 do -- Trace out until not inside the wall (FractionLeftSolid would work well if there was a known endpos, but there is no such thing unfortunately)
				Trace.start = tr.HitPos - (TraceData.Normal * 10) -- Multiplier to speed this up tremendously
				Trace.endpos = Trace.start
				util.TraceLine(Trace)

				debugoverlay.Box(tr.HitPos, Mins, Maxs, 0.1, Cache.Colors.Purple)

				if not tr.HitWorld then break end
			end

			Trace.endpos = OriginalEndPos
		end

		debugoverlay.Line(Trace.start, tr.HitPos, 0.1, Cache.Colors.Purple, true)

		local ThisDistance

		if IsTFA then -- TFA is retarded
			ThisDistance = tr.HitPos:Distance(LastPos) / 88.88
		else
			ThisDistance = math.floor(tr.HitPos:DistToSqr(LastPos))
		end

		if ThisDistance > MaxDistance then -- This penetration step went too far
			debugoverlay.Text(tr.HitPos, "tr.HitPos", 0.1, false)
			debugoverlay.Box(tr.HitPos, Mins, Maxs, 0.1, Cache.Colors.Pink)

			debugoverlay.Text(LastPos, "LastPos", 0.1, false)
			debugoverlay.Box(LastPos, Mins, Maxs, 0.1, Cache.Colors.Pink)

			return false
		end

		if tr.Hit then -- Initial hit success
			LastPos = tr.HitPos

			debugoverlay.Text(LastPos, CurTimes, 0.1, false)
			debugoverlay.Box(LastPos, Mins, Maxs, 0.1, Cache.Colors.Orange)
		else -- Perform a second trace going the other way to see if there's any further tracing needed
			local OriginalEndPos = TraceData.HitPos

			Trace.endpos = TraceData.HitPos
			util.TraceLine(Trace)
			Trace.endpos = OriginalEndPos

			debugoverlay.Line(Trace.start, tr.HitPos, 0.1, Cache.Colors.Pink, true)

			if tr.Hit then
				LastPos = tr.HitPos

				debugoverlay.Text(LastPos, CurTimes, 0.1, false)
				debugoverlay.Box(LastPos, Mins, Maxs, 0.1, Cache.Colors.Orange)
			else -- At the end or in some kind of empty space
				if IsTFA then
					ThisDistance = tr.HitPos:Distance(LastPos) / 88.88
				else
					ThisDistance = math.floor(tr.HitPos:DistToSqr(LastPos))
				end

				if ThisDistance <= MaxDistance then -- This penetration is good
					break
				end
			end
		end

		CurTimes = CurTimes + 1
	end

	debugoverlay.Text(TraceData.HitPos, "TraceTarget", 0.1, false)
	debugoverlay.Box(TraceData.HitPos, Mins, Maxs, 0.1, Cache.Colors.Aqua)

	if CurTimes <= MaxTimes then
		debugoverlay.Text(tr.HitPos, "tr.HitPos", 0.1, false)
		debugoverlay.Box(tr.HitPos, Mins, Maxs, 0.1, Cache.Colors.Pink)

		debugoverlay.Text(TraceData.HitPos, "TraceData.HitPos", 0.1, false)
		debugoverlay.Box(TraceData.HitPos, Mins, Maxs, 0.1, Cache.Colors.Pink)

		return true
	end

	return false
end

hook.Add("CreateMove", "pentest", function(cmd)
	local Target

	for _, v in ipairs(player.GetAll()) do
		if v ~= LocalPlayer() then
			Target = v
			break
		end
	end

	if not IsValid(Target) or not Target:Alive() then return end

	local StartPos = LocalPlayer():EyePos()
	local EndPos = Target:WorldSpaceCenter()

	local tr = util.TraceLine({
		start = StartPos,
		endpos = EndPos,
		filter = LocalPlayer(),
		mask = MASK_SHOT
	})

	local LineColor = Cache.Colors.Red

	if tr.Entity ~= Target then
		local Weapon = LocalPlayer():GetActiveWeapon()

		if IsValid(Weapon) and WeaponCanPenetrate(Weapon, tr, Target, EndPos) then
			LineColor = Cache.Colors.Green
		else
			LineColor = Cache.Colors.Red
		end
	else
		LineColor = Cache.Colors.Green
	end

	if Cache.ConVars.SetViewAngles:GetBool() then
		cmd:SetViewAngles((EndPos - LocalPlayer():EyePos()):GetNormalized():Angle())
	end

	local NormalHitPos = tr.HitPos + tr.HitNormal

	debugoverlay.Line(StartPos, NormalHitPos, 0.1, LineColor, true) -- For some reason rendering this debug stuff causes a good bit of fps drop, not sure why it's so intensive but oh well it's only for debugging

	local NormalAngle = tr.HitNormal:Angle()
	local Up = NormalAngle:Up() * 6
	local Right = NormalAngle:Right() * 6

	local Mins, Maxs = Cache.DebugVectors.Mins, Cache.DebugVectors.Maxs

	debugoverlay.Box(NormalHitPos, Mins, Maxs, 0.1, LineColor)
	debugoverlay.Box(NormalHitPos + Up, Mins, Maxs, 0.1, LineColor)
	debugoverlay.Box(NormalHitPos - Up, Mins, Maxs, 0.1, LineColor)
	debugoverlay.Box(NormalHitPos + Right, Mins, Maxs, 0.1, LineColor)
	debugoverlay.Box(NormalHitPos - Right, Mins, Maxs, 0.1, LineColor)
end)
