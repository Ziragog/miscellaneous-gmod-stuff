--[[
	https://github.com/awesomeusername69420/miscellaneous-gmod-stuff

	Better ESP because BitflagESP kind of sucked...

	Concommand:
		lv_menu		-	Opens the menu
]]

--------------------------- Free Cloud Storage 100gb ---------------------------

local Cache = {
	LocalPlayer = LocalPlayer(),
	AngleZero = Angle(0, 0, 0),
	Menu = nil,
	Registry = debug.getregistry(),
	Clipboard = nil,

	Colors = {
		White = Color(255, 255, 255, 255),
		Black = Color(0, 0, 0, 255),
		Green = Color(120, 255, 120)
	},

	Materials = {
		Visible = CreateMaterial("leVisuals_Chams_Visible", "VertexLitGeneric", {
			["$basetexture"] = "models/debug/debugwhite",
			["$model"] = 1,
			["$ignorez"] = 0
		}),

		Occluded = CreateMaterial("leVisuals_Chams_Occluded", "VertexLitGeneric", {
			["$basetexture"] = "models/debug/debugwhite",
			["$model"] = 1,
			["$ignorez"] = 1
		})
	},

	Settings = {
		Font = "BudgetLabel",

		Player = {
			Enabled = true
		},

		Entity = nil
	},

	ScreenData = {
		Width = ScrW(),
		Height = ScrH(),
		Center = Vector(ScrW() / 2, ScrH() / 2)
	},

	WeaponNames = {},
	EntityData = {},

	EntityClasses = {}, -- Shown on esp
	KnownEntityClasses = {}, -- Shown in menu
	BlacklistedEntityClasses = { -- Don't show anywhere
		player = true,
		worldspawn = true,
		viewmodel = true
	},

	PlayerList = {},
	LastListUpdate = 0,

	NetMessages = {
		BuildMode = { "BuildMode", "buildmode", "_Kyle_Buildmode" },
		GodMode = { "has_god", "god_mode", "ugod" },
		HVHMode = { "HVHER" },
		Protected = { "LibbyProtectedSpawn", "SH_SZ.Safe", "spawn_protect", "InSpawnZone" }
	},

	ModelData = {}
}

-- Inital entity classes
do
	for k, _ in pairs(scripted_ents.GetList()) do
		if not Cache.KnownEntityClasses[k] and not Cache.BlacklistedEntityClasses[k] then
			Cache.KnownEntityClasses[k] = true
		end
	end

	for _, v in ipairs(ents.GetAll()) do
		local Class = v:GetClass()
		if not Cache.KnownEntityClasses[Class] and not Cache.BlacklistedEntityClasses[Class] then
			Cache.KnownEntityClasses[Class] = true
		end
	end
end

-- Setup option tables
do
	-- Quickly make an option table
	local function NewESPOptions(IsPlayer, BaseColor)
		return {
			Enabled = true,

			Box = {
				Enabled = true,

				Fill = true,
				Outline = true
			},

			Name = true,
			Weapon = true,

			Bones = {
				Enabled = false,

				Points = true,
				Lines = true
			},

			Hitboxes = {
				Enabled = false,

				Regular = true,
				BoundingBox = true
			},

			Health = {
				Enabled = IsPlayer and true or false,

				Bar = true,
				Amount = true
			},

			Tracers = true,
			UserGroup = IsPlayer and true or nil, -- If it's an entity, make it nil so it won't be stored
			Team = IsPlayer and true or nil,
			Avatar = IsPlayer and false or nil,

			Chams = {
				Enabled = false,

				Visible = true,
				Occluded = true
			},

			Colors = {
				Box = {
					Fill = BaseColor,
					Outline = Cache.Colors.Black
				},

				Name = Cache.Colors.White,
				Weapon = Cache.Colors.White,

				Bones = {
					Points = BaseColor,
					Lines = BaseColor
				},

				Hitboxes = {
					Regular = BaseColor,
					BoundingBox = Cache.Colors.Green
				},

				Tracers = BaseColor,
				UserGroup = IsPlayer and Cache.Colors.White or nil,
				Team = IsPlayer and Cache.Colors.White or nil,

				Chams = {
					Visible = BaseColor,
					Occluded = Color(math.Clamp(255 - BaseColor.r, 0, 255), math.Clamp(255 - BaseColor.g, 0, 255), math.Clamp(255 - BaseColor.b, 0, 255), BaseColor.a) -- Invert the base color
				}
			}
		}
	end

	Cache.Settings.Player.Normal = NewESPOptions(true, Color(255, 0, 0, 255))
	Cache.Settings.Player.Friend = NewESPOptions(true, Color(255, 255, 0, 255))
	Cache.Settings.Player.Protected = NewESPOptions(true, Color(0, 200, 255, 255))
	Cache.Settings.Entity = NewESPOptions(false, Color(200, 0, 255, 255))
end

--------------------------- Hold my Functions ---------------------------

local Functions = {
	Player = {},
	Entity = {},
	Weapon = {}
}

-- Player

-- Updates the player data for this player
function Functions.Player.UpdateInfo(Player)
	if Player == LocalPlayer() then
		Cache.LocalPlayer = Player
		return
	end

	Functions.Entity.UpdateInfo(Player)
	Cache.EntityData[Player] = Cache.EntityData[Player] or {}
	local PlayerTable = Cache.EntityData[Player]

	PlayerTable.UserGroup = Player:GetUserGroup()
	PlayerTable.Observing = Player:GetObserverMode() ~= OBS_MODE_NONE
	PlayerTable.Team = Player:Team()
	PlayerTable.TeamName = team.GetName(PlayerTable.Team)
	PlayerTable.Protected = Functions.Player.IsProtected(Player)
	PlayerTable.OptionsTable = Cache.Settings.Player[((Cache.Settings.Player.Friend.Enabled and Player:GetFriendStatus() == "friend") and "Friend") or ((Cache.Settings.Player.Protected.Enabled and PlayerTable.Protected) and "Protected") or "Normal"] -- The bee's knees

	if not IsValid(PlayerTable.AvatarImage) then
		local AvatarImage = vgui.Create("AvatarImage")

		AvatarImage:SetSize(16, 16)
		AvatarImage:SetVisible(false)
		AvatarImage:SetPaintedManually(true)
		AvatarImage:SetPlayer(Player, 16)

		PlayerTable.AvatarImage = AvatarImage
	end

	PlayerTable.ShouldRender = PlayerTable.OptionsTable.Enabled and PlayerTable.Alive and not PlayerTable.Dormant and not PlayerTable.Observing and PlayerTable.Team ~= TEAM_SPECTATOR and not PlayerTable.Invisible

	return PlayerTable
end

-- Tells if a player is protected
function Functions.Player.IsProtected(Player)
	if Player:HasGodMode() then return true end

	local CurTable = Cache.NetMessages.BuildMode
	for i = 1, #CurTable do
		if Cache.LocalPlayer:GetNWBool(CurTable[i]) then return true end -- Assume we can't attack while in build mode
		if Player:GetNWBool(CurTable[i]) then return true end
	end

	CurTable = Cache.NetMessages.Protected
	for i = 1, #CurTable do
		if Player:GetNWBool(CurTable[i]) then return true end
	end

	do
		local LocalHVH = false
		local PlayerHVH = false

		CurTable = Cache.NetMessages.HVHMode
		for i = 1, #CurTable do
			if LocalHVH and PlayerHVH then break end
			LocalHVH = Cache.LocalPlayer:GetNWBool(CurTable[i])
			PlayerHVH = Player:GetNWBool(CurTable[i])
		end

		if LocalHVH ~= PlayerHVH then return true end
	end

	CurTable = Cache.NetMessages.GodMode
	for i = 1, #CurTable do
		if Player:GetNWBool(CurTable[i]) then return true end
	end

	return false
end

-- Entity

-- Updates the entity data for this entity
function Functions.Entity.UpdateInfo(Entity)
	Cache.EntityData[Entity] = Cache.EntityData[Entity] or {}
	local EntityTable = Cache.EntityData[Entity]

	local IsPlayer = Entity:IsPlayer()

	EntityTable.Dormant = Entity:IsDormant()
	EntityTable.Name = IsPlayer and Entity:GetName() or (Entity.PrintName or Entity.ClassName or Entity:GetClass())
	if not IsPlayer and EntityTable.Name:len() < 1 then EntityTable.Name = Entity:GetClass() end
	EntityTable.MaxHealth = Entity:GetMaxHealth()
	EntityTable.HealthColor = Functions.Entity.GetHealthColor(Entity)
	EntityTable.Health = Entity:Health()
	if IsPlayer then -- Doing this as an inline didn't work for some reason
		EntityTable.Alive = Entity:Alive()
	else
		if Entity:IsNPC() or Entity:IsNextBot() then
			EntityTable.Alive = EntityTable.Health >= 1
		else
			EntityTable.Alive = true
		end
	end
	EntityTable.Weapon = Entity.GetActiveWeapon and Functions.Weapon.GetName(Entity:GetActiveWeapon()) or ""
	EntityTable.Invisible = Entity:IsEffectActive(EF_NODRAW) or Entity:GetColor().a < 1
	EntityTable.OptionsTable = Cache.Settings.Entity
	EntityTable.Mins, EntityTable.Maxs = Entity:GetCollisionBounds()
	EntityTable.BoundingRadius = Entity:BoundingRadius()

	EntityTable.ShouldRender = EntityTable.OptionsTable.Enabled and EntityTable.Alive and not EntityTable.Dormant and not EntityTable.Invisible

	return EntityTable
end

-- Parses an entity's model to get hitbox data (Thanks 0572)
function Functions.Entity.GenerateModelData(Model)
	Model = Model or "models/error.mdl"
	if Cache.ModelData[Model] then return Cache.ModelData[Model] end

	local FileStream = file.Open(Model, "rb", "GAME")
	if not FileStream then return Cache.ModelData[Model] end

	local ID = FileStream:Read(4)
	if ID ~= "IDST" then return Cache.ModelData[Model] end

	local Data = {}
	Data.Version = FileStream:ReadLong()
	Data.Checksum = FileStream:ReadLong()

	FileStream:Read(64) -- Name

	Data.DataLength = FileStream:ReadLong()

	FileStream:Read(12) -- eyeposition
	FileStream:Read(12) -- illumposition

	FileStream:Read(12) -- hull_min
	FileStream:Read(12) -- hull_max

	FileStream:Read(12) -- view_bbmin
	FileStream:Read(12) -- view_bbmax

	FileStream:ReadLong() -- flags

	-- mstudiobone_t
	FileStream:ReadLong() -- bonecount
	FileStream:ReadLong() -- boneoffset

	-- mstudiobonecontroller_t
	FileStream:ReadLong() -- bonecontrollercount
	FileStream:ReadLong() -- bonecontrolleroffset

	-- mstudiobonecontroller_t
	FileStream:ReadLong() -- hitboxcount
	Data.HitboxOffset = FileStream:ReadLong()

	FileStream:Seek(Data.HitboxOffset)

	FileStream:ReadLong() -- sznameindex
	Data.HitboxOffsetCount = FileStream:ReadLong()
	Data.HitboxIndex = FileStream:ReadLong()

	FileStream:Seek(Data.HitboxOffset + Data.HitboxIndex)

	Data.Hitboxes = {}

	for i = 1, Data.HitboxOffsetCount do
		local Temp = {}

		Temp.Bone = FileStream:ReadLong()
		FileStream:ReadLong() -- hitgroup

		Temp.Mins = Vector(FileStream:ReadFloat(), FileStream:ReadFloat(), FileStream:ReadFloat())
		Temp.Maxs = Vector(FileStream:ReadFloat(), FileStream:ReadFloat(), FileStream:ReadFloat())
		Temp.Center = (Temp.Mins + Temp.Maxs) / 2

		FileStream:ReadLong() -- szhitboxnameindex
		FileStream:Read(32) -- Unused

		Data.Hitboxes[#Data.Hitboxes + 1] = Temp
	end

	FileStream:Close()

	Cache.ModelData[Model] = Data
	return Data
end

-- Tests if an entity is on screen
function Functions.Entity.OnScreen(Entity)
	local Direction = Entity:GetPos() - EyePos()
	local Length = Direction:Length()
	local Radius = Cache.EntityData[Entity].BoundingRadius

	local Max = math.abs(math.cos(math.acos(Length / math.sqrt((Length * Length) + (Radius * Radius))) + 60 * (math.pi / 180)))

	Direction:Normalize()

	return Direction:Dot(EyeVector()) > Max
end

-- Gets the color the health bar and text should be for the entity
function Functions.Entity.GetHealthColor(Entity)
	local DataTable = Cache.EntityData[Entity]

	local Health = Entity:Health()
	local ClampedHealth = math.Clamp(Health, 0, DataTable.MaxHealth)
	local Percent = ClampedHealth * (ClampedHealth / DataTable.MaxHealth)

	if Health ~= DataTable.Health or not DataTable.HealthColor then
		DataTable.Health = Health
		DataTable.HealthColor = Color(255 - (Percent * 2.55), Percent * 2.55, 0)
	end

	return DataTable.HealthColor, Percent / ClampedHealth
end

-- Gets the bounds for the entity's 2D box
function Functions.Entity.Get2DBounds(Entity)
	local Mins = Cache.EntityData[Entity].Mins
	local Maxs = Cache.EntityData[Entity].Maxs

	local Coords = { -- I'm sorry garbage collection :(
		Entity:LocalToWorld(Mins):ToScreen(),
		Entity:LocalToWorld(Vector(Mins.x, Maxs.y, Mins.z)):ToScreen(),
		Entity:LocalToWorld(Vector(Maxs.x, Maxs.y, Mins.z)):ToScreen(),
		Entity:LocalToWorld(Vector(Maxs.x, Mins.y, Mins.z)):ToScreen(),
		Entity:LocalToWorld(Maxs):ToScreen(),
		Entity:LocalToWorld(Vector(Mins.x, Maxs.y, Maxs.z)):ToScreen(),
		Entity:LocalToWorld(Vector(Mins.x, Mins.y, Maxs.z)):ToScreen(),
		Entity:LocalToWorld(Vector(Maxs.x, Mins.y, Maxs.z)):ToScreen()
	}

	local Left, Right, Top, Bottom = Coords[1].x, Coords[1].x, Coords[1].y, Coords[1].y

	for i = 1, #Coords do -- Pick the best corners
		local v = Coords[i]
		if Left > v.x then Left = v.x end
		if Top > v.y then Top = v.y end
		if Right < v.x then Right = v.x end
		if Bottom < v.y then Bottom = v.y end
	end

	return math.Round(Left), math.Round(Right), math.Round(Top), math.Round(Bottom)
end

-- Tells if an entity's bounding box should rotate with them
function Functions.Entity.RotateBounds(Entity)
	return not (Entity:IsPlayer() or Entity:IsNPC() or Entity:IsNextBot())
end

-- Draws 2D esp for an entity
function Functions.Entity.ESP2D(Entity, OptionsTable)
	local Colors = OptionsTable.Colors
	local EntityTable =  Cache.EntityData[Entity]

	if OptionsTable.Tracers then
		local WorldSpaceCenter = Entity:WorldSpaceCenter():ToScreen()

		surface.SetDrawColor(Colors.Tracers)
		surface.DrawLine(WorldSpaceCenter.x, WorldSpaceCenter.y, Cache.ScreenData.Center.x, Cache.ScreenData.Center.y)
	end

	if OptionsTable.Bones.Enabled then
		Entity:SetupBones()

		if OptionsTable.Bones.Lines then
			surface.SetDrawColor(Colors.Bones.Lines) -- Don't call SetDrawColor a bunch of times
		end

		for Bone = 0, Entity:GetBoneCount() - 1 do
			if not Entity:BoneHasFlag(Bone, BONE_USED_BY_HITBOX) then continue end

			local BoneMatrix = Entity:GetBoneMatrix(Bone)
			if not BoneMatrix then continue end
			BoneMatrix = BoneMatrix:GetTranslation():ToScreen()

			if OptionsTable.Bones.Points then
				surface.DrawCircle(BoneMatrix.x, BoneMatrix.y, 2, Colors.Bones.Points)
			end

			if OptionsTable.Bones.Lines then
				local Parent = Entity:GetBoneParent(Bone)
				if Parent == -1 or not Entity:BoneHasFlag(Parent, BONE_USED_BY_HITBOX) then continue end

				local ParentMatrix = Entity:GetBoneMatrix(Parent)
				if not ParentMatrix then continue end
				ParentMatrix = ParentMatrix:GetTranslation():ToScreen()

				surface.DrawLine(BoneMatrix.x, BoneMatrix.y, ParentMatrix.x, ParentMatrix.y)
			end
		end
	end

	local Left, Right, Top, Bottom = Functions.Entity.Get2DBounds(Entity)
	local Width = Right - Left
	local Height = Bottom - Top

	if OptionsTable.Box.Enabled then
		if OptionsTable.Box.Fill then
			surface.SetDrawColor(Colors.Box.Fill)
			surface.DrawOutlinedRect(Left, Top, Width - 1, Height - 1)
		end

		if OptionsTable.Box.Outline then
			surface.SetDrawColor(Colors.Box.Outline)
			surface.DrawOutlinedRect(Left - 1, Top - 1, Width + 1, Height + 1)
			surface.DrawOutlinedRect(Left + 1, Top + 1, Width - 3, Height - 3)
		end
	end

	surface.SetFont(Cache.Settings.Font)
	local tw, th = 0, 0

	if OptionsTable.Health.Enabled then
		local Barwidth, Spacer = 4, 2
		local HealthColor, HealthPercent = Functions.Entity.GetHealthColor(Entity)
		local HealthScreen = math.Round((Height * HealthPercent) - 1)
		local HealthPos = (Bottom - HealthScreen) - 1

		if OptionsTable.Health.Bar then
			surface.SetDrawColor(Cache.Colors.Black)
			surface.DrawRect(Left - Spacer - Barwidth, Top - 1, Barwidth, Height + 1)

			surface.SetDrawColor(HealthColor)
			surface.DrawRect((Left - Spacer - Barwidth) + 1, HealthPos, Barwidth - Spacer, HealthScreen)
		end

		if OptionsTable.Health.Amount and EntityTable.Health ~= (EntityTable.MaxHealth) then
			tw, th = surface.GetTextSize(EntityTable.Health)

			local tx = Left - tw - Spacer
			if OptionsTable.Health.Bar then tx = tx - Spacer - Barwidth end

			local ty = math.Clamp(OptionsTable.Health.Bar and HealthPos or Top, Top, Bottom - th)

			surface.SetTextColor(HealthColor)
			surface.SetTextPos(tx, ty)
			surface.DrawText(EntityTable.Health)
		end
	end

	if OptionsTable.UserGroup then
		_, th = surface.GetTextSize(EntityTable.UserGroup)

		surface.SetTextColor(Colors.UserGroup)
		surface.SetTextPos(Right + 2, math.Clamp(Top, Top, Bottom - th))
		surface.DrawText(EntityTable.UserGroup)
	end

	if OptionsTable.Team then
		_, th = surface.GetTextSize(EntityTable.TeamName)

		surface.SetTextColor(Colors.Team)
		surface.SetTextPos(Right + 2, math.Clamp(Top + (OptionsTable.UserGroup and th or 0), Top, Bottom - th))
		surface.DrawText(EntityTable.TeamName)
	end

	if OptionsTable.Name then
		tw, th = surface.GetTextSize(EntityTable.Name)

		surface.SetTextColor(Colors.Name)
		surface.SetTextPos(Left + (Width / 2) - (tw / 2), Top - th - 3)
		surface.DrawText(EntityTable.Name)
	end

	if OptionsTable.Weapon then
		local Weapon = Entity.GetActiveWeapon and Entity:GetActiveWeapon() or NULL
		if Weapon:IsValid() then
			tw = surface.GetTextSize(EntityTable.Weapon)

			surface.SetTextColor(Colors.Weapon)
			surface.SetTextPos(Left + (Width / 2) - (tw / 2), Bottom)
			surface.DrawText(EntityTable.Weapon)
		end
	end

	if OptionsTable.Avatar then -- Having this above other things break the surface library
		if IsValid(EntityTable.AvatarImage) then
			local y = Top - 24
			if OptionsTable.Name then
				y = y - th
			end

			EntityTable.AvatarImage:PaintAt(Left + ((Width / 2) - 8), y)
		end
	end
end

-- Draws 3D esp for an entity (Doesn't reset anything since it's made to be called in the loop below to avoid calling the function a bunch of times)
function Functions.Entity.ESP3D(Entity, OptionsTable)
	local Colors = OptionsTable.Colors

	if OptionsTable.Hitboxes.Enabled then

		if OptionsTable.Hitboxes.Regular then
			local ModelData = Functions.Entity.GenerateModelData(Entity:GetModel())

			Entity:SetupBones()

			for i = 1, #ModelData.Hitboxes do
				local BoneMatrix = Entity:GetBoneMatrix(ModelData.Hitboxes[i].Bone)
				local Position = BoneMatrix:GetTranslation()
				BoneMatrix = BoneMatrix:GetAngles()

				render.DrawWireframeBox(Position, BoneMatrix, ModelData.Hitboxes[i].Mins, ModelData.Hitboxes[i].Maxs, Colors.Hitboxes.Regular, true)
			end
		end

		if OptionsTable.Hitboxes.BoundingBox then
			render.DrawWireframeBox(Entity:GetPos(), Functions.Entity.RotateBounds(Entity) and Entity:GetAngles() or Cache.AngleZero, Cache.EntityData[Entity].Mins, Cache.EntityData[Entity].Maxs, Colors.Hitboxes.BoundingBox, true)
		end
	end

	if OptionsTable.Chams.Enabled then
		Colors = OptionsTable.Colors.Chams

		local Weapon = Entity.GetActiveWeapon and Entity:GetActiveWeapon() or NULL

		if OptionsTable.Chams.Occluded then
			render.SetColorModulation(Colors.Occluded.r / 255, Colors.Occluded.g / 255, Colors.Occluded.b / 255)
			render.SetBlend(Colors.Occluded.a / 255)
			render.MaterialOverride(Cache.Materials.Occluded)

			Entity:DrawModel()
			if Weapon:IsValid() then Weapon:DrawModel() end
		end

		if OptionsTable.Chams.Visible then
			render.SetColorModulation(Colors.Visible.r / 255, Colors.Visible.g / 255, Colors.Visible.b / 255)
			render.SetBlend(Colors.Visible.a / 255)
			render.MaterialOverride(Cache.Materials.Visible)

			Entity:DrawModel()
			if Weapon:IsValid() then Weapon:DrawModel() end
		end
	end
end

-- Sorts entities by distance to camera
function Functions.Entity.Sort(A, B)
	return A[1]:GetPos():DistToSqr(EyePos()) > B[1]:GetPos():DistToSqr(EyePos())
end

-- Weapon

-- Gets the "fancy" name of a weapon for display
function Functions.Weapon.GetName(Weapon)
	if not Weapon:IsValid() then return "" end

	local Class = Weapon:GetClass()
	if Cache.WeaponNames[Class] then return Cache.WeaponNames[Class] end

	if Weapon.PrintName then
		Cache.WeaponNames[Class] = language.GetPhrase(Weapon.PrintName)
	else
		Cache.WeaponNames[Class] = Weapon.GetPrintName and language.GetPhrase(Weapon:GetPrintName()) or Class
	end

	return Cache.WeaponNames[Class]
end

--------------------------- Hooks ---------------------------

-- Collect entity classes
hook.Add("NetworkEntityCreated", "leVisuals_NetworkEntityCreated", function(Entity)
	local Class = Entity:GetClass()
	if not Cache.KnownEntityClasses[Class] and not Cache.BlacklistedEntityClasses[Class] then
		Cache.KnownEntityClasses[Class] = true
	end
end)

-- Update player list and remove bad data
hook.Add("Tick", "leVisuals_Tick", function()
	if SysTime() - Cache.LastListUpdate >= 0.3 then
		-- Regenerate player list
		for i = #Cache.PlayerList, 1, -1 do Cache.PlayerList[i] = nil end
		for _, v in ipairs(player.GetAll()) do Cache.PlayerList[#Cache.PlayerList + 1] = v end

		-- Find and remove invalid property tables
		local InValid = {}
		for k, _ in pairs(Cache.EntityData) do
			if not k:IsValid() then
				InValid[#InValid + 1] = k
			end
		end

		for i = #InValid, 1, -1 do
			Cache.EntityData[InValid[i]] = nil
		end

		-- Prevent buildup of unused tables in memory
		InValid = nil
		collectgarbage("step")

		-- Update our timing
		Cache.LastListUpdate = SysTime()
	end

	-- Collect player data
	for i = 1, #Cache.PlayerList do
		if not Cache.PlayerList[i]:IsValid() then continue end
		Functions.Player.UpdateInfo(Cache.PlayerList[i])
	end

	-- Collect entity data
	for i = 1, #Cache.EntityClasses do
		local Ents = ents.FindByClass(Cache.EntityClasses[i])

		for ii = 1, #Ents do
			Functions.Entity.UpdateInfo(Ents[ii])
		end
	end
end)

-- Render 2D visuals
hook.Add("PostDrawHUD", "leVisuals_PostDrawHUD", function()
	cam.Start2D() -- Seems pointless, but this actually fixes a major issue caused by the rendering of the Avatar ESP
		local EntitiesThisFrame = {} -- Used to sort the ESP so we don't get visual overlapping issues

		if Cache.Settings.Player.Enabled then
			for i = 1, #Cache.PlayerList do
				if not Cache.PlayerList[i]:IsValid() then continue end

				local PlayerTable = Cache.EntityData[Cache.PlayerList[i]] or Functions.Player.UpdateInfo(Cache.PlayerList[i])
				if not PlayerTable or not PlayerTable.ShouldRender then continue end
				if not Functions.Entity.OnScreen(Cache.PlayerList[i]) then continue end

				EntitiesThisFrame[#EntitiesThisFrame + 1] = { Cache.PlayerList[i], PlayerTable.OptionsTable }
			end
		end

		if Cache.Settings.Entity.Enabled then
			for i = 1, #Cache.EntityClasses do
				local Ents = ents.FindByClass(Cache.EntityClasses[i])

				for ii = 1, #Ents do
					local EntityTable = Cache.EntityData[Ents[ii]] or Functions.Entity.UpdateInfo(Ents[ii])
					if not EntityTable or not EntityTable.ShouldRender then continue end
					if not Functions.Entity.OnScreen(Ents[ii]) then continue end

					EntitiesThisFrame[#EntitiesThisFrame + 1] = { Ents[ii], EntityTable.OptionsTable }
				end
			end
		end

		table.sort(EntitiesThisFrame, Functions.Entity.Sort)

		for i = 1, #EntitiesThisFrame do
			Functions.Entity.ESP2D(EntitiesThisFrame[i][1], EntitiesThisFrame[i][2])
		end
	cam.End2D()
end)

-- Render 3D visuals
hook.Add("PreDrawEffects", "leVisuals_PreDrawEffects", function()
	local Blend = render.GetBlend()

	if Cache.Settings.Player.Enabled then
		for i = 1, #Cache.PlayerList do
			if not Cache.PlayerList[i]:IsValid() then continue end

			local PlayerTable = Cache.EntityData[Cache.PlayerList[i]] or Functions.Player.UpdateInfo(Cache.PlayerList[i])
			if not PlayerTable or not PlayerTable.ShouldRender then continue end
			if not Functions.Entity.OnScreen(Cache.PlayerList[i]) then continue end

			Functions.Entity.ESP3D(Cache.PlayerList[i], PlayerTable.OptionsTable)
		end
	end

	if Cache.Settings.Entity.Enabled then
		for i = 1, #Cache.EntityClasses do
			local Ents = ents.FindByClass(Cache.EntityClasses[i])

			for ii = 1, #Ents do
				local EntityTable = Cache.EntityData[Ents[ii]] or Functions.Entity.UpdateInfo(Ents[ii])
				if not EntityTable or not EntityTable.ShouldRender then continue end
				if not Functions.Entity.OnScreen(Ents[ii]) then continue end

				Functions.Entity.ESP3D(Ents[ii], EntityTable.OptionsTable)
			end
		end
	end

	-- Reset everything
	render.SetBlend(Blend)
	render.SetColorModulation(1, 1, 1)
	render.MaterialOverride(nil)
end)

-- Update screen cache
hook.Add("OnScreenSizeChanged", "leVisuals_OnScreenSizeChanged", function()
	Cache.ScreenData.Width = ScrW()
	Cache.ScreenData.Height = ScrH()
	Cache.ScreenData.Center.x = Cache.ScreenData.Width / 2
	Cache.ScreenData.Center.y = Cache.ScreenData.Height / 2
end)

--------------------------- Menu Setup ---------------------------

do
	-- Set stuff up
	local Frame = vgui.Create("DFrame")
	Frame:SetSize(400, 320)
	Frame:SetMinimumSize(400, 320)
	Frame:Center()
	Frame:SetVisible(false)
	Frame:SetDeleteOnClose(false)
	Frame:SetTitle("le Visuals")
	Frame:SetSizable(true)
	Frame:SetSkin("Default")

	Frame.m_pTabs = vgui.Create("DPropertySheet", Frame)
	Frame.m_pTabs.m_fFadeTime = 0
	Frame.m_pTabs:Dock(FILL)
	Frame.m_pTabs:SetSkin("Default")

	function Frame:MakePanel(Scroll)
		local Panel = vgui.Create(Scroll and "DScrollPanel" or "DPanel")

		Panel.m_tMenuItems = {}
		Panel.m_bScroll = Scroll

		Panel:SetSkin("Default")

		if Scroll then
			Panel:SetPaintBackgroundEnabled(true)
			Panel:SetPaintBorderEnabled(true)
			Panel:SetPaintBackground(true)

			function Panel:Rebuild() -- Add extra padding
				self.pnlCanvas:SizeToChildren(false, true)
				self.pnlCanvas:SetTall(self.pnlCanvas:GetTall() + 10)

				if self.m_bNoSizing and self.pnlCanvas:GetTall() < self:GetTall() then
					self.pnlCanvas.x = 0
					self.pnlCanvas.y = (self:GetTall() - self.pnlCanvas:GetTall()) / 2
				end
			end

			function Panel:PerformLayout(Width, Height)
				self:PerformLayoutInternal(Width, Height)
			end

			function Panel:PerformLayoutInternal(Width, Height) -- Fix retarded bug with resizing
				Width = (Width or self:GetWide()) - (self.VBar.Enabled and self.VBar:GetWide() or 0) -- These shouldn't need to be here but sometimes they're nil
				Height = Height or self:GetTall()

				self:Rebuild()

				self.VBar:SetUp(Height, self.pnlCanvas:GetTall())

				self.pnlCanvas.x = 0
				self.pnlCanvas.y = self.VBar:GetOffset()
				self.pnlCanvas:SetWide(Width)

				self:Rebuild()

				if Height ~= self.pnlCanvas:GetTall() then
					self.VBar:SetScroll(self.VBar:GetScroll())
				end
			end
		end

		function Panel:AddCheckbox(Indent, Label, Table, Key, Right)
			local Checkbox = vgui.Create("DCheckBoxLabel", self)

			Checkbox.m_iIndent = Indent
			Checkbox.m_tTable = Table
			Checkbox.m_strKey = Key
			Checkbox.m_bRight = Right
			Checkbox.m_flLastThink = 0

			Checkbox:SetTextColor(Cache.Colors.Black)
			Checkbox:SetText(Label)
			Checkbox:SetSkin("Default")
			Checkbox:SetChecked(tobool(Table[Key]))

			function Checkbox:Think()
				if CurTime() - self.m_flLastThink >= 0.3 then
					self:SetChecked(self.m_tTable[self.m_strKey])
					self.m_flLastThink = CurTime()
				end
			end

			function Checkbox:OnChange(NewValue)
				self.m_tTable[self.m_strKey] = NewValue
			end

			self.m_tMenuItems[#self.m_tMenuItems + 1] = Checkbox

			return Checkbox
		end

		function Panel:AddColorbox(Indent, Table, Key, Right)
			local Colorbox = vgui.Create("DButton", self)
			Colorbox:SetSize(15, 15)
			Colorbox:SetText("")

			Colorbox.m_iIndent = Indent
			Colorbox.m_tTable = Table
			Colorbox.m_strKey = Key
			Colorbox.m_bRight = Right

			function Colorbox:Paint(Width, Height)
				surface.SetDrawColor(Cache.Colors.Black)
				surface.DrawRect(0, 0, Width, Height)

				surface.SetDrawColor(self.m_tTable[self.m_strKey])
				surface.DrawRect(1, 1, Width - 2, Height - 2)
			end

			function Colorbox:DoClick()
				local ScreenX, ScreenY = self:LocalToScreen(0, 0)

				local ColorPanel = vgui.Create("DPanel")
				ColorPanel:SetSize(190, 130)
				ColorPanel:DockPadding(4, 4, 4, 4)
				ColorPanel:SetPos(ScreenX, ScreenY + self:GetTall() + 5)
				ColorPanel:MakePopup()

				function ColorPanel:PerformLayout()
					function self:Think()
						if not self:HasFocus() then
							self:Remove()
						end
					end
				end

				function ColorPanel:Paint(Width, Height)
					surface.SetDrawColor(Cache.Colors.White)
					surface.DrawRect(1, 1, Width - 2, Height - 2)

					surface.SetDrawColor(Cache.Colors.Black)
					surface.DrawOutlinedRect(0, 0, Width, Height)
				end

				ColorPanel:InvalidateLayout()

				local Mixer = vgui.Create("DColorMixer", ColorPanel)
				Mixer:Dock(FILL)
				Mixer:SetPalette(false)
				Mixer:SetWangs(false)
				Mixer:SetColor(self.m_tTable[self.m_strKey])
				Mixer:SetSkin("Default")

				Mixer.m_tTable = self.m_tTable
				Mixer.m_strKey = self.m_strKey

				function Mixer:ValueChanged(NewColor)
					debug.setmetatable(NewColor, Cache.Registry.Color)
					self.m_tTable[self.m_strKey] = NewColor
				end
			end

			function Colorbox:ColorToHex(Color)
				return string.format("#%02x%02x%02x%02x", Color.r, Color.g, Color.b, Color.a)
			end

			function Colorbox:DoRightClick()
				local Menu = DermaMenu()

				Menu:AddOption("Copy", function(self)
					Cache.Clipboard = tostring(self.m_pColorbox.m_tTable[self.m_pColorbox.m_strKey])
					SetClipboardText(self.m_pColorbox:ColorToHex(self.m_pColorbox.m_tTable[self.m_pColorbox.m_strKey]))
				end).m_pColorbox = self

				Menu:AddOption("Paste", function(self)
					self.m_pColorbox.m_tTable[self.m_pColorbox.m_strKey] = string.ToColor(Cache.Clipboard)
				end).m_pColorbox = self

				Menu:Open()
			end

			self.m_tMenuItems[#self.m_tMenuItems + 1] = Colorbox

			return Colorbox
		end

		Panel.m_fPerformLayout = Panel.PerformLayout
		function Panel:PerformLayout(Width, Height)
			if self.m_fPerformLayout then
				self:m_fPerformLayout(Width, Height)
			end

			local X = 10
			local Y = 10

			for i = 1, #self.m_tMenuItems do
				local CurItem = self.m_tMenuItems[i]

				if CurItem.m_bRight then
					Y = math.max(Y - 25, 15)

					CurItem.x = self:GetWide() - CurItem:GetWide() - 10

					if self.m_bScroll then
						CurItem.x = CurItem.x - self.VBar:GetWide()
					end
				else
					CurItem.x = X + (CurItem.m_iIndent * 25)
				end

				CurItem.y = Y

				Y = Y + 25
			end
		end

		return Panel
	end

	function Frame:AddTab(Name, Setup, Scrollable)
		local Panel = self:MakePanel(Scrollable)

		self.m_pTabs:AddSheet(Name, Panel)

		if type(Setup) == "function" then Setup(Panel) end

		return Panel
	end

	Cache.Menu = Frame

	-- Build the menu
	Frame:AddTab("Players", function(Panel)
		Panel:AddCheckbox(0, "Enabled", Cache.Settings.Player, "Enabled")

		Panel:DockPadding(0, 35, 0, 0)

		Panel.m_pTabs = vgui.Create("DPropertySheet", Panel)
		Panel.m_pTabs.m_fFadeTime = 0
		Panel.m_pTabs:Dock(FILL)
		Panel.m_pTabs:SetSkin("Default")

		Panel.MakePanel = Frame.MakePanel
		Panel.AddTab = Frame.AddTab

		Panel:AddTab("Normal", function(SubPanel)
			local VarTable = Cache.Settings.Player.Normal

			SubPanel:AddCheckbox(0, "Enabled", VarTable, "Enabled")

			SubPanel:AddCheckbox(1, "Box", VarTable.Box, "Enabled")
			SubPanel:AddCheckbox(2, "Fill", VarTable.Box, "Fill")
			SubPanel:AddColorbox(0, VarTable.Colors.Box, "Fill", true)
			SubPanel:AddCheckbox(2, "Outline", VarTable.Box, "Outline")
			SubPanel:AddColorbox(0, VarTable.Colors.Box, "Outline", true)

			SubPanel:AddCheckbox(1, "Name", VarTable, "Name")
			SubPanel:AddColorbox(0, VarTable.Colors, "Name", true)
			SubPanel:AddCheckbox(1, "Weapon", VarTable, "Weapon")
			SubPanel:AddColorbox(0, VarTable.Colors, "Weapon", true)

			SubPanel:AddCheckbox(1, "Bones", VarTable.Bones, "Enabled")
			SubPanel:AddCheckbox(2, "Points", VarTable.Bones, "Points")
			SubPanel:AddColorbox(0, VarTable.Colors.Bones, "Points", true)
			SubPanel:AddCheckbox(2, "Lines", VarTable.Bones, "Lines")
			SubPanel:AddColorbox(0, VarTable.Colors.Bones, "Lines", true)

			SubPanel:AddCheckbox(1, "Hitboxes", VarTable.Hitboxes, "Enabled")
			SubPanel:AddCheckbox(2, "Regular", VarTable.Hitboxes, "Regular")
			SubPanel:AddColorbox(0, VarTable.Colors.Hitboxes, "Regular", true)
			SubPanel:AddCheckbox(2, "Bounding Box", VarTable.Hitboxes, "BoundingBox")
			SubPanel:AddColorbox(0, VarTable.Colors.Hitboxes, "BoundingBox", true)

			SubPanel:AddCheckbox(1, "Health", VarTable.Health, "Enabled")
			SubPanel:AddCheckbox(2, "Bar", VarTable.Health, "Bar")
			SubPanel:AddCheckbox(2, "Amount", VarTable.Health, "Amount")

			SubPanel:AddCheckbox(1, "Tracers", VarTable, "Tracers")
			SubPanel:AddColorbox(0, VarTable.Colors, "Tracers", true)
			SubPanel:AddCheckbox(1, "User Group", VarTable, "UserGroup")
			SubPanel:AddColorbox(0, VarTable.Colors, "UserGroup", true)
			SubPanel:AddCheckbox(1, "Team", VarTable, "Team")
			SubPanel:AddColorbox(0, VarTable.Colors, "Team", true)
			SubPanel:AddCheckbox(1, "Avatar", VarTable, "Avatar")

			SubPanel:AddCheckbox(1, "Chams", VarTable.Chams, "Enabled")
			SubPanel:AddCheckbox(2, "Visible", VarTable.Chams, "Visible")
			SubPanel:AddColorbox(0, VarTable.Colors.Chams, "Visible", true)
			SubPanel:AddCheckbox(2, "Occluded", VarTable.Chams, "Occluded")
			SubPanel:AddColorbox(0, VarTable.Colors.Chams, "Occluded", true)
		end, true)

		Panel:AddTab("Friends", function(SubPanel)
			local VarTable = Cache.Settings.Player.Friend

			SubPanel:AddCheckbox(0, "Enabled", VarTable, "Enabled")

			SubPanel:AddCheckbox(1, "Box", VarTable.Box, "Enabled")
			SubPanel:AddCheckbox(2, "Fill", VarTable.Box, "Fill")
			SubPanel:AddColorbox(0, VarTable.Colors.Box, "Fill", true)
			SubPanel:AddCheckbox(2, "Outline", VarTable.Box, "Outline")
			SubPanel:AddColorbox(0, VarTable.Colors.Box, "Outline", true)

			SubPanel:AddCheckbox(1, "Name", VarTable, "Name")
			SubPanel:AddColorbox(0, VarTable.Colors, "Name", true)
			SubPanel:AddCheckbox(1, "Weapon", VarTable, "Weapon")
			SubPanel:AddColorbox(0, VarTable.Colors, "Weapon", true)

			SubPanel:AddCheckbox(1, "Bones", VarTable.Bones, "Enabled")
			SubPanel:AddCheckbox(2, "Points", VarTable.Bones, "Points")
			SubPanel:AddColorbox(0, VarTable.Colors.Bones, "Points", true)
			SubPanel:AddCheckbox(2, "Lines", VarTable.Bones, "Lines")
			SubPanel:AddColorbox(0, VarTable.Colors.Bones, "Lines", true)

			SubPanel:AddCheckbox(1, "Hitboxes", VarTable.Hitboxes, "Enabled")
			SubPanel:AddCheckbox(2, "Regular", VarTable.Hitboxes, "Regular")
			SubPanel:AddColorbox(0, VarTable.Colors.Hitboxes, "Regular", true)
			SubPanel:AddCheckbox(2, "Bounding Box", VarTable.Hitboxes, "BoundingBox")
			SubPanel:AddColorbox(0, VarTable.Colors.Hitboxes, "BoundingBox", true)

			SubPanel:AddCheckbox(1, "Health", VarTable.Health, "Enabled")
			SubPanel:AddCheckbox(2, "Bar", VarTable.Health, "Bar")
			SubPanel:AddCheckbox(2, "Amount", VarTable.Health, "Amount")

			SubPanel:AddCheckbox(1, "Tracers", VarTable, "Tracers")
			SubPanel:AddColorbox(0, VarTable.Colors, "Tracers", true)
			SubPanel:AddCheckbox(1, "User Group", VarTable, "UserGroup")
			SubPanel:AddColorbox(0, VarTable.Colors, "UserGroup", true)
			SubPanel:AddCheckbox(1, "Team", VarTable, "Team")
			SubPanel:AddColorbox(0, VarTable.Colors, "Team", true)
			SubPanel:AddCheckbox(1, "Avatar", VarTable, "Avatar")

			SubPanel:AddCheckbox(1, "Chams", VarTable.Chams, "Enabled")
			SubPanel:AddCheckbox(2, "Visible", VarTable.Chams, "Visible")
			SubPanel:AddColorbox(0, VarTable.Colors.Chams, "Visible", true)
			SubPanel:AddCheckbox(2, "Occluded", VarTable.Chams, "Occluded")
			SubPanel:AddColorbox(0, VarTable.Colors.Chams, "Occluded", true)
		end, true)

		Panel:AddTab("Protected", function(SubPanel)
			local VarTable = Cache.Settings.Player.Protected

			SubPanel:AddCheckbox(0, "Enabled", VarTable, "Enabled")

			SubPanel:AddCheckbox(1, "Box", VarTable.Box, "Enabled")
			SubPanel:AddCheckbox(2, "Fill", VarTable.Box, "Fill")
			SubPanel:AddColorbox(0, VarTable.Colors.Box, "Fill", true)
			SubPanel:AddCheckbox(2, "Outline", VarTable.Box, "Outline")
			SubPanel:AddColorbox(0, VarTable.Colors.Box, "Outline", true)

			SubPanel:AddCheckbox(1, "Name", VarTable, "Name")
			SubPanel:AddColorbox(0, VarTable.Colors, "Name", true)
			SubPanel:AddCheckbox(1, "Weapon", VarTable, "Weapon")
			SubPanel:AddColorbox(0, VarTable.Colors, "Weapon", true)

			SubPanel:AddCheckbox(1, "Bones", VarTable.Bones, "Enabled")
			SubPanel:AddCheckbox(2, "Points", VarTable.Bones, "Points")
			SubPanel:AddColorbox(0, VarTable.Colors.Bones, "Points", true)
			SubPanel:AddCheckbox(2, "Lines", VarTable.Bones, "Lines")
			SubPanel:AddColorbox(0, VarTable.Colors.Bones, "Lines", true)

			SubPanel:AddCheckbox(1, "Hitboxes", VarTable.Hitboxes, "Enabled")
			SubPanel:AddCheckbox(2, "Regular", VarTable.Hitboxes, "Regular")
			SubPanel:AddColorbox(0, VarTable.Colors.Hitboxes, "Regular", true)
			SubPanel:AddCheckbox(2, "Bounding Box", VarTable.Hitboxes, "BoundingBox")
			SubPanel:AddColorbox(0, VarTable.Colors.Hitboxes, "BoundingBox", true)

			SubPanel:AddCheckbox(1, "Health", VarTable.Health, "Enabled")
			SubPanel:AddCheckbox(2, "Bar", VarTable.Health, "Bar")
			SubPanel:AddCheckbox(2, "Amount", VarTable.Health, "Amount")

			SubPanel:AddCheckbox(1, "Tracers", VarTable, "Tracers")
			SubPanel:AddColorbox(0, VarTable.Colors, "Tracers", true)
			SubPanel:AddCheckbox(1, "User Group", VarTable, "UserGroup")
			SubPanel:AddColorbox(0, VarTable.Colors, "UserGroup", true)
			SubPanel:AddCheckbox(1, "Team", VarTable, "Team")
			SubPanel:AddColorbox(0, VarTable.Colors, "Team", true)
			SubPanel:AddCheckbox(1, "Avatar", VarTable, "Avatar")

			SubPanel:AddCheckbox(1, "Chams", VarTable.Chams, "Enabled")
			SubPanel:AddCheckbox(2, "Visible", VarTable.Chams, "Visible")
			SubPanel:AddColorbox(0, VarTable.Colors.Chams, "Visible", true)
			SubPanel:AddCheckbox(2, "Occluded", VarTable.Chams, "Occluded")
			SubPanel:AddColorbox(0, VarTable.Colors.Chams, "Occluded", true)
		end, true)
	end)

	Frame:AddTab("Entities", function(Panel)
		local VarTable = Cache.Settings.Entity

		Panel:AddCheckbox(0, "Enabled", VarTable, "Enabled")

		Panel:AddCheckbox(1, "Box", VarTable.Box, "Enabled")
		Panel:AddCheckbox(2, "Fill", VarTable.Box, "Fill")
		Panel:AddColorbox(0, VarTable.Colors.Box, "Fill", true)
		Panel:AddCheckbox(2, "Outline", VarTable.Box, "Outline")
		Panel:AddColorbox(0, VarTable.Colors.Box, "Outline", true)

		Panel:AddCheckbox(1, "Name", VarTable, "Name")
		Panel:AddColorbox(0, VarTable.Colors, "Name", true)
		Panel:AddCheckbox(1, "Weapon", VarTable, "Weapon")
		Panel:AddColorbox(0, VarTable.Colors, "Weapon", true)

		Panel:AddCheckbox(1, "Bones", VarTable.Bones, "Enabled")
		Panel:AddCheckbox(2, "Points", VarTable.Bones, "Points")
		Panel:AddColorbox(0, VarTable.Colors.Bones, "Points", true)
		Panel:AddCheckbox(2, "Lines", VarTable.Bones, "Lines")
		Panel:AddColorbox(0, VarTable.Colors.Bones, "Lines", true)

		Panel:AddCheckbox(1, "Hitboxes", VarTable.Hitboxes, "Enabled")
		Panel:AddCheckbox(2, "Regular", VarTable.Hitboxes, "Regular")
		Panel:AddColorbox(0, VarTable.Colors.Hitboxes, "Regular", true)
		Panel:AddCheckbox(2, "Bounding Box", VarTable.Hitboxes, "BoundingBox")
		Panel:AddColorbox(0, VarTable.Colors.Hitboxes, "BoundingBox", true)

		Panel:AddCheckbox(1, "Health", VarTable.Health, "Enabled")
		Panel:AddCheckbox(2, "Bar", VarTable.Health, "Bar")
		Panel:AddCheckbox(2, "Amount", VarTable.Health, "Amount")

		Panel:AddCheckbox(1, "Chams", VarTable.Chams, "Enabled")
		Panel:AddCheckbox(2, "Visible", VarTable.Chams, "Visible")
		Panel:AddColorbox(0, VarTable.Colors.Chams, "Visible", true)
		Panel:AddCheckbox(2, "Occluded", VarTable.Chams, "Occluded")
		Panel:AddColorbox(0, VarTable.Colors.Chams, "Occluded", true)
	end, true)

	Frame:AddTab("Entity List", function(Panel)
		local List = vgui.Create("DListView", Panel)
		List:Dock(FILL)
		List:AddColumn("Class Name")
		List:AddColumn("Shown on ESP")
		List:SetMultiSelect(false)
		List:SetSkin("Default")

		local Textbox = vgui.Create("DTextEntry", Panel)
		Textbox:Dock(BOTTOM)
		Textbox:SetUpdateOnType(true)
		Textbox:SetSkin("Default")

		Textbox.m_pList = List
		List.m_pTextbox = Textbox

		List.m_fRebuildTick = setfenv(function()
			for k, _ in SortedPairs(self.m_tClasses) do
				self:AddLine(k, table.HasValue(Cache.EntityClasses, k) and "True" or "False")

				coroutine.yield()

				if self.m_bKillCoroutine then break end
			end
		end, setmetatable({ -- The coroutine doesn't call with the context of the panel so we need to fix this function up a bit
			self = List
		}, {
			__index = _G,

			__newindex = function(_, K, V)
				_G[K] = V
			end
		}))

		function List:Think()
			if self.m_pCoroutine then
				coroutine.resume(self.m_pCoroutine)

				if self.m_bKillCoroutine then
					self.m_bKillCoroutine = false
				end
			end
		end

		function List:Rebuild(Classes)
			self:Clear()
			self.m_pTextbox:SetValue("")

			self.m_tClasses = Classes or Cache.KnownEntityClasses
			self.m_pCoroutine = coroutine.create(self.m_fRebuildTick)
		end

		function List:DoDoubleClick(_, Line) -- Toggle on double click
			local Class = Line:GetColumnText(1)
			if Line:GetColumnText(2) == "True" then
				table.remove(Cache.EntityClasses, table.KeyFromValue(Cache.EntityClasses, Class))
				Line:SetColumnText(2, "False")
			else
				if not table.HasValue(Cache.EntityClasses, Class) then
					Cache.EntityClasses[#Cache.EntityClasses + 1] = Class
					Line:SetColumnText(2, "True")
				end
			end
		end

		Panel.m_pList = List
		Frame.m_pList = List

		function Textbox:OnValueChange(NewValue)
			if self.m_bCalled then return end -- Prevent infinite loop

			if NewValue == "" then -- Textbox was cleared, restore everything
				self.m_bCalled = true
				self.m_pList:Rebuild()
				self.m_bCalled = false

				return
			end

			self.m_pList.m_bKillCoroutine = true -- Stop the current building

			NewValue = NewValue:lower()

			self.m_pList:Clear()

			local Classes = {}

			for k, _ in SortedPairs(Cache.KnownEntityClasses) do
				if k:find(NewValue, 1, true) then
					Classes[k] = true
				end
			end

			self.m_bCalled = true
			self.m_pList:Rebuild(Classes)
			self.m_bCalled = false
		end

		Panel.m_pTextbox = Textbox
	end)

	Frame:AddTab("Config", function(Panel)
		local SaveButton = vgui.Create("DButton", Panel)
		SaveButton:Dock(TOP)
		SaveButton:SetText("Save")
		SaveButton:SetSkin("Default")

		function SaveButton:DoClick()
			file.Write("levisuals.txt", util.TableToJSON({ Cache.Settings, Cache.EntityClasses }, true))
		end

		local LoadButton = vgui.Create("DButton", Panel)
		LoadButton:Dock(TOP)
		LoadButton:SetText("Load")
		LoadButton:SetSkin("Default")

		function LoadButton:MergeTable(Destination, Source) -- Fix JSONToTable color issue
			for k, v in pairs(Source) do
				if type(v) == "table" and type(Destination[k]) == "table" then
					if v.r and v.g and v.b and v.a then
						debug.setmetatable(v, Cache.Registry.Color)
						Destination[k] = v

						continue
					end

					self:MergeTable(Destination[k], v)
				else
					Destination[k] = v
				end
			end
		end

		function LoadButton:DoClick()
			if file.Exists("levisuals.txt", "DATA") then
				local Data = file.Read("levisuals.txt", "DATA")
				Data = util.JSONToTable(Data)

				self:MergeTable(Cache.Settings, Data[1])
				self:MergeTable(Cache.EntityClasses, Data[2])
			end
		end

		local Textbox = vgui.Create("DTextEntry", Panel)

		Textbox.m_flLastThink = 0

		Textbox:Dock(TOP)
		Textbox:SetUpdateOnType(true)
		Textbox:SetValue(Cache.Settings.Font)
		Textbox:SetSkin("Default")

		Textbox.m_fThink = Textbox.Think
		function Textbox:Think()
			self:m_fThink()

			if self:IsEditing() then return end
			if CurTime() - self.m_flLastThink >= 0.3 then
				self:SetValue(Cache.Settings.Font)
				self.m_flLastThink = CurTime()
			end
		end

		function Textbox:OnValueChange(NewValue)
			pcall(function()
				draw.GetFontHeight(NewValue) -- If this errors the font doesn't exist, don't try to use it
				Cache.Settings.Font = NewValue
			end)
		end
	end)
end

concommand.Add("lv_menu", function()
	if Cache.Menu:IsValid() and not Cache.Menu:IsVisible() then
		Cache.Menu:SetVisible(true)
		Cache.Menu:MakePopup()

		if Cache.Menu.m_pList:IsValid() then
			Cache.Menu.m_pList:Rebuild() -- TODO: Investigate potential buildup of coroutines?
		end
	end
end)
