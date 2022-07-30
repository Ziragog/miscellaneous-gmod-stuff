--[[
	https://github.com/awesomeusername69420/miscellaneous-gmod-stuff

	~ Painting thing ~

	ConVars:
		lepaint			- Opens the menu
		lepaint_getdata - Prints the draw data to console
]]

-- Numbers

local ONE_FIFTH = 1 / 5
local FOUR_FIFTHS = 4 / 5

-- Stuff

local Stuff = {
	meta_cl = debug.getregistry().Color,
	SaveRequested = false,

	Aspect = {
		W = (1890 / 1920),
		H = (1050 / 1080)
	},

	Colors = {
		White = Color(255, 255, 255, 255),
		Black = Color(0, 0, 0, 255),

		Backing = Color(108, 111, 114, 150),

		Outlines = {
			Main = {
				Outter = Color(75, 75, 75, 255),
				Inner = Color(119, 119, 119, 150)
			},
			
			DrawPanel = {
				Outter = Color(234, 234, 234, 255)
			}
		} 
	},

	Materials = {
		Corners = {
			tex_corner8	= "gui/corner8",
			tex_corner16 = "gui/corner16",
			tex_corner32 = "gui/corner32",
			tex_corner64 = "gui/corner64",
			tex_corner512 = "gui/corner512"
		}
	},

	DrawColor = nil,
	DrawSize = 3,
	DrawData = {},
	DrawStack = {}
}

Stuff.DrawColor = Stuff.Colors.Black

-- Menu setup

local Main = vgui.Create("DFrame")
Main:SetTitle("le paint")
Main:SetDeleteOnClose(false)
Main:SetVisible(false)
Main:SetSize(ScrW() * Stuff.Aspect.W, ScrH() * Stuff.Aspect.H)
Main:Center()
Main:SetDraggable(false)

Main._oPaint = Main.Paint

Main.Paint = function(self, w, h)
	local sx, sy = self:LocalToScreen(0, 0)

	render.SetScissorRect(sx, sy, sx + w, sy + 24, true)
		Main._oPaint(self, w, h)
	render.SetScissorRect(0, 0, 0, 0, false)

	draw.BeginMask() -- Outter outline
		render.PerformFullScreenStencilOperation()
	draw.DeMask()
		draw.DrawRoundedStencilBox(8, 1, 24, w - 2, h - 25, Stuff.Colors.White, false, false, true, true)
	draw.DrawOp()
		draw.DrawRoundedStencilBox(8, 0, 24, w, h - 24, Stuff.Colors.Outlines.Main.Outter, false, false, true, true)
	draw.ReMask()
		draw.RoundedBoxEx(8, 2, 24, w, h - 26, Stuff.Colors.Backing, false, false, true, true)
	draw.FinishMask()

	draw.BeginMask() -- Inner outline
		render.PerformFullScreenStencilOperation()
	draw.DeMask()
		draw.DrawRoundedStencilBox(8, 2, 24, w - 4, h - 26, Stuff.Colors.White, false, false, true, true)
	draw.DrawOp()
		draw.DrawRoundedStencilBox(8, 1, 24, w - 2, h - 25, Stuff.Colors.Outlines.Main.Inner, false, false, true, true)
	draw.FinishMask()
end

local DrawPanel = vgui.Create("DPanel", Main)
DrawPanel:SetSize((Main:GetWide() * FOUR_FIFTHS) - 10, Main:GetTall() - 44)
DrawPanel:SetPos(10, 34)
DrawPanel:SetPaintBackgroundEnabled(false)

DrawPanel.Think = function(self)
	local w, h = self:GetSize()

	if self._IsDrawing then
		if not self._LastMouse then
			self._LastMouse = {
				x = gui.MouseX(),
				y = gui.MouseY()
			}
		else
			local mx, my = gui.MouseX(), gui.MouseY()

			if mx ~= self._LastMouse.x or my ~= self._LastMouse.y then
				local px, py = self:ScreenToLocal(mx, my)

				Stuff.DrawData[#Stuff.DrawData + 1] = {
					x = math.Round(math.Clamp(px - (Stuff.DrawSize * 0.5), 0, w)),
					y = math.Round(math.Clamp(py - (Stuff.DrawSize * 0.5), 0, h)),
					color = Stuff.DrawColor,
					size = Stuff.DrawSize
				}

				table.insert(Stuff.DrawStack[#Stuff.DrawStack], #Stuff.DrawData) -- Icky table.insert

				self._LastMouse.x = mx
				self._LastMouse.y = my
			end
		end
	end
end

DrawPanel.Paint = function(self, w, h)
	draw.BeginMask()
		render.PerformFullScreenStencilOperation()
	draw.DeMask()
		draw.DrawRoundedStencilBox(8, 1, 1, w - 2, h - 2, Stuff.Colors.White, true, true, true, true)
	draw.DrawOp()
		draw.DrawRoundedStencilBox(8, 0, 0, w, h, Stuff.Colors.Outlines.DrawPanel.Outter, true, true, true, true)
	draw.ReMask()
		draw.RoundedBox(8, 0, 0, w, h, Stuff.Colors.Outlines.DrawPanel.Outter)

		for _, v in ipairs(Stuff.DrawData) do
			surface.SetDrawColor(v.color)
			surface.DrawRect(v.x, v.y, v.size, v.size)
		end

		if vgui.GetHoveredPanel() == self then
			local mx, my = self:ScreenToLocal(gui.MouseX(), gui.MouseY())

			surface.SetDrawColor(Stuff.Colors.Black)
			surface.DrawOutlinedRect(mx - (Stuff.DrawSize * 0.5), my - (Stuff.DrawSize * 0.5), Stuff.DrawSize, Stuff.DrawSize)
		end
	draw.FinishMask()
end

DrawPanel.OnMousePressed = function(self, code)
	if code ~= MOUSE_LEFT then return end

	Stuff.DrawStack[#Stuff.DrawStack + 1] = {}
	self._IsDrawing = true
end

DrawPanel.OnMouseReleased = function(self, code)
	if not self._IsDrawing or code ~= MOUSE_LEFT then return end

	self._IsDrawing = false
end

DrawPanel.OnCursorExited = function(self)
	if not self._IsDrawing then return end

	self._IsDrawing = false
end

local ToolPanel = vgui.Create("DPanel", Main)
ToolPanel:SetSize((Main:GetWide() * ONE_FIFTH) - 22, DrawPanel:GetTall())
ToolPanel:SetPos(DrawPanel:GetPos() + DrawPanel:GetWide() + 10, DrawPanel:GetY())

ToolPanel.Paint = function(self, w, h)
	draw.RoundedBox(8, 0, 0, w, h, Stuff.Colors.Outlines.DrawPanel.Outter)
end

local ToolColorPicker = vgui.Create("DColorMixer", ToolPanel)
ToolColorPicker:SetWide(ToolPanel:GetWide() - 20)
ToolColorPicker:SetTall(ToolColorPicker:GetWide() - 80)
ToolColorPicker:SetPos(10, 10)
ToolColorPicker:SetColor(Stuff.DrawColor)
ToolColorPicker:SetAlphaBar(false)
ToolColorPicker:SetPalette(false)

ToolColorPicker.ValueChanged = function(self, newColor)
	Stuff.DrawColor = setmetatable(newColor, Stuff.meta_cl)
end

ToolColorPicker.Paint = function(self, w, h)
	local oClip = DisableClipping(true)

	surface.SetDrawColor(Stuff.Colors.Black)
	surface.DrawOutlinedRect(-1, -1, w + 2, h + 2)

	DisableClipping(oClip)
end

local ToolUndoButton = vgui.Create("DButton", ToolPanel)
ToolUndoButton:SetSize((ToolColorPicker:GetWide() * 0.5) - 5, 24)
ToolUndoButton:SetPos(ToolColorPicker:GetX(), ToolColorPicker:GetY() + ToolColorPicker:GetTall() + 10)
ToolUndoButton:SetText("Undo")

ToolUndoButton.DoClick = function()
	local target = Stuff.DrawStack[#Stuff.DrawStack]
	if not target then return end

	for i = #Stuff.DrawData, (#Stuff.DrawData - #target) + 1, -1 do
		table.remove(Stuff.DrawData, i)
	end

	table.remove(Stuff.DrawStack, #Stuff.DrawStack)
end

local ToolClearButton = vgui.Create("DButton", ToolPanel)
ToolClearButton:SetSize(ToolUndoButton:GetSize())
ToolClearButton:SetPos(ToolUndoButton:GetX() + ToolUndoButton:GetWide() + 10, ToolUndoButton:GetY())
ToolClearButton:SetText("Clear")

ToolClearButton.DoClick = function()
	table.Empty(Stuff.DrawData)
end

local ToolSaveButton = vgui.Create("DButton", ToolPanel)
ToolSaveButton:SetSize(ToolColorPicker:GetWide(), ToolUndoButton:GetTall())
ToolSaveButton:SetPos(ToolUndoButton:GetX(), ToolUndoButton:GetY() + ToolUndoButton:GetTall() + 10)
ToolSaveButton:SetText("Save")

ToolSaveButton.DoClick = function()
	if not Stuff.SaveRequested then
		Stuff.SaveRequested = true
	end
end

local ToolBrushSize = vgui.Create("DNumSlider", ToolPanel)
ToolBrushSize:SetWide(ToolColorPicker:GetWide())
ToolBrushSize:SetPos(ToolSaveButton:GetX(), ToolSaveButton:GetY() + ToolSaveButton:GetTall() + 10)
ToolBrushSize:SetText("Brush Size")
ToolBrushSize:SetDark(true)
ToolBrushSize:SetMinMax(1, 100)
ToolBrushSize:SetDecimals(0)
ToolBrushSize:SetValue(Stuff.DrawSize)

ToolBrushSize.OnValueChanged = function(self, new)
	new = math.Round(math.Clamp(new, self:GetMin(), self:GetMax()), self:GetDecimals())

	Stuff.DrawSize = new
end

-- Hooks

hook.Add("OnScreenSizeChanged", "lePaint_OnScreenSizeChanged", function()
	Main:SetSize(ScrW() * Stuff.Aspect.W, ScrH() * Stuff.Aspect.H)
	Main:Center()
end)

hook.Add("PostRender", "lePaint_PostRender", function()
	if not Stuff.SaveRequested then return end

	local sx, sy = DrawPanel:LocalToScreen(0, 0)

	local data = render.Capture({
		format = "jpg",
		quality = 100,
		x = sx,
		y = sy,
		w = DrawPanel:GetWide(),
		h = DrawPanel:GetTall()
	})

	file.Write(os.date("%Y_%d%m%M%S_") .. SysTime() .. ".jpg", data)

	Stuff.SaveRequested = false
end)

-- ConCommand

concommand.Add("lepaint", function()
	Main:SetVisible(true)
	Main:MakePopup()
end)

concommand.Add("lepaint_getdata", function()
	PrintTable(Stuff.DrawData)
end)

-- Final setup

do
	function draw.SetMaskDraw(newState) -- https://github.com/2048khz-gachi-rmx/beizwors/blob/784c72a0bde378a6f8a6196bb19b744e55b0b130/addons/core_panellib/lua/moarpanels/exts/clipping.lua
		if newState then
			render.SetStencilCompareFunction(STENCIL_ALWAYS)
			render.SetStencilPassOperation(STENCIL_REPLACE)
		else
			render.SetStencilCompareFunction(STENCIL_NEVER)
			render.SetStencilFailOperation(STENCIL_REPLACE)
		end
	end
	
	function draw.BeginMask()
		render.SetStencilPassOperation(STENCIL_KEEP)
	
		render.SetStencilEnable(true)
	
		render.ClearStencil()
	
		render.SetStencilTestMask(0xFF)
		render.SetStencilWriteMask(0xFF)
	
		draw.SetMaskDraw(false)
	
		render.SetStencilReferenceValue(1)
	end
	
	function draw.DeMask()
		render.SetStencilReferenceValue(0)
	end
	
	function draw.ReMask()
		render.SetStencilReferenceValue(1)
	end
	
	function draw.DrawOp(val)
		render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
		render.SetStencilFailOperation(STENCIL_KEEP)
		render.SetStencilPassOperation(STENCIL_KEEP)
	
		render.SetStencilReferenceValue(val or 0)
	end
	
	function draw.FinishMask()
		render.SetStencilEnable(false)
	end
	
	function draw.DrawRoundedStencilBox(bordersize, x, y, w, h, color, tl, tr, bl, br) -- https://github.com/2048khz-gachi-rmx/beizwors/blob/784c72a0bde378a6f8a6196bb19b744e55b0b130/addons/core_panellib/lua/moarpanels/exts/draw.lua
		surface.SetDrawColor(color:Unpack())
	
		if bordersize <= 0 then
			surface.DrawRect(x, y, w, h)
			return
		end
	
		x = math.Round(x)
		y = math.Round(y)
		w = math.Round(w)
		h = math.Round(h)
		bordersize = math.min(math.Round(bordersize), math.floor(w * 0.5))
	
		surface.DrawRect(x + bordersize, y, w - bordersize * 2, h)
		surface.DrawRect(x, y + bordersize, bordersize, h - bordersize * 2)
		surface.DrawRect(x + w - bordersize, y + bordersize, bordersize, h - bordersize * 2)
	
		local tex = Stuff.Materials.Corners.tex_corner8
		if bordersize > 8 then tex = Stuff.Materials.Corners.tex_corner16 end
		if bordersize > 16 then tex = Stuff.Materials.Corners.tex_corner32 end
		if bordersize > 32 then tex = Stuff.Materials.Corners.tex_corner64 end
		if bordersize > 64 then tex = Stuff.Materials.Corners.tex_corner512 end
	
		surface.SetMaterial(tex)
	
		if tl then
			surface.DrawTexturedRectUV(x, y, bordersize, bordersize, 0, 0, 1, 1)
		else
			surface.DrawRect(x, y, bordersize, bordersize)
		end
	
		if tr then
			surface.DrawTexturedRectUV(x + w - bordersize, y, bordersize, bordersize, 1, 0, 0, 1)
		else
			surface.DrawRect(x + w - bordersize, y, bordersize, bordersize)
		end
	
		if bl then
			surface.DrawTexturedRectUV(x, y + h -bordersize, bordersize, bordersize, 0, 1, 1, 0)
		else
			surface.DrawRect(x, y + h - bordersize, bordersize, bordersize)
		end
	
		if br then
			surface.DrawTexturedRectUV(x + w - bordersize, y + h - bordersize, bordersize, bordersize, 1, 1, 0, 0)
		else
			surface.DrawRect(x + w - bordersize, y + h - bordersize, bordersize, bordersize)
		end
	end

	for name, mat in pairs(Stuff.Materials.Corners) do
		Stuff.Materials.Corners[name] = CreateMaterial("alt05_" .. mat:gsub("gui/", ""), "UnlitGeneric", {
			["$basetexture"] = mat,
			["$alphatest"] = 1,
			["$alphatestreference"] = 0.5,
			["$vertexalpha"] = 1,
			["$vertexcolor"] = 1
		})
	end
end