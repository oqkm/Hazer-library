--[========================================================================]--
--                                                                          --
--                         HAZER UI LIBRARY  v2.0.1                         --
--          Clean rebuild: iOS "Liquid Glass" look, overlay dropdowns,      --
--          and a tiny settings file (theme + menu keybind only).           --
--          Fixed: UI alignment, padding, margins, and notification bounds. --
--                                                                          --
--[========================================================================]--

local Players          = game:GetService("Players")
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local HttpService      = game:GetService("HttpService")
local TextService      = game:GetService("TextService")

local Library = { Version = "2.0.1", _windows = {}, _presets = {}, _presetOrder = {} }
local Window = {}
Window.__index = Window

--------------------------------------------------------------------------------
-- Constants & helpers
--------------------------------------------------------------------------------
local WHITE  = Color3.new(1, 1, 1)
local TEXT   = Color3.fromRGB(242, 242, 250)
local SUB    = Color3.fromRGB(158, 160, 178)
local FONT_B = Enum.Font.GothamBold
local FONT_M = Enum.Font.GothamMedium
local FONT_R = Enum.Font.Gotham
local QUART  = Enum.EasingStyle.Quart
local QUINT  = Enum.EasingStyle.Quint
local BACK   = Enum.EasingStyle.Back
local OUT    = Enum.EasingDirection.Out
local IN     = Enum.EasingDirection.`In`

local function new(class, props)
	local inst = Instance.new(class)
	if inst:IsA("GuiObject") then
		inst.BorderSizePixel = 0
	end
	if inst:IsA("GuiButton") then
		inst.AutoButtonColor = false
	end
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then parent = v else inst[k] = v end
	end
	if parent then inst.Parent = parent end
	return inst
end

local function label(props)
	local p = {
		BackgroundTransparency = 1,
		Font = FONT_M,
		TextSize = 13,
		TextColor3 = TEXT,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		Text = "",
	}
	for k, v in pairs(props) do p[k] = v end
	return new("TextLabel", p)
end

local function tween(obj, time, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(time, style or QUART, dir or OUT), props)
	tw:Play()
	return tw
end

local function fire(cb, ...)
	if type(cb) ~= "function" then return end
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = pcall(cb, table.unpack(args, 1, args.n))
		if not ok then warn("[HazerUI] callback error: " .. tostring(err)) end
	end)
end

local function method(obj, fn)
	return function(first, ...)
		if first == obj then return fn(...) end
		return fn(first, ...)
	end
end

local function computeBG(a)
	return Color3.fromRGB(10, 10, 16):Lerp(a, 0.12)
end

local function toColor(v, fallback)
	if typeof(v) == "Color3" then return v end
	if type(v) == "table" and #v >= 3 then
		return Color3.fromRGB(
			math.clamp(tonumber(v[1]) or 0, 0, 255),
			math.clamp(tonumber(v[2]) or 0, 0, 255),
			math.clamp(tonumber(v[3]) or 0, 0, 255))
	end
	return fallback
end

local function fromColor(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function keyFromName(name)
	if type(name) ~= "string" then return nil end
	local ok, key = pcall(function() return Enum.KeyCode[name] end)
	if ok and key then return key end
	return nil
end

local function glass(frame, radius, sheen)
	new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = frame })
	local stroke = new("UIStroke", {
		Thickness = 1, Color = WHITE, Transparency = 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = frame,
	})
	new("UIGradient", {
		Rotation = 45,
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.30),
			NumberSequenceKeypoint.new(0.5, 0.90),
			NumberSequenceKeypoint.new(1, 0.62),
		}),
		Parent = stroke,
	})
	if sheen then
		local s = new("Frame", {
			Name = "Sheen", BackgroundColor3 = WHITE, BackgroundTransparency = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 0, Active = false, Parent = frame,
		})
		new("UICorner", { CornerRadius = UDim.new(0, radius), Parent = s })
		new("UIGradient", {
			Rotation = 60,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.93),
				NumberSequenceKeypoint.new(0.45, 0.985),
				NumberSequenceKeypoint.new(1, 0.995),
			}),
			Parent = s,
		})
	end
	return stroke
end

local function chevron(parent, color)
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
	for i = 1, 2 do
		local bar = new("Frame", {
			BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(7, 2), Position = UDim2.fromOffset(i == 1 and 3.5 or 8.5, 6),
			Rotation = i == 1 and 45 or -45, Parent = c,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	end
	return c
end

local function checkmark(parent, color)
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Parent = parent })
	local a = new("Frame", { BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(5, 2), Position = UDim2.fromOffset(4, 9.5), Rotation = 45, Parent = c })
	local b = new("Frame", { BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 2), Position = UDim2.fromOffset(8.5, 7.2), Rotation = -45, Parent = c })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = a })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = b })
	return c
end

local function cross(parent, color)
	local c = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 12), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = parent })
	for i = 1, 2 do
		local bar = new("Frame", {
			BackgroundColor3 = color, AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(12, 2), Position = UDim2.fromScale(0.5, 0.5),
			Rotation = i == 1 and 45 or -45, Parent = c,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	end
	return c
end

local function makeDraggable(handle, target, track, onClick)
	local dragging, moved, startMouse, startPos = false, false, nil, nil
	track(handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging, moved = true, false
			startMouse, startPos = input.Position, target.Position
			local conn
			conn = input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					conn:Disconnect()
					if onClick and not moved then onClick() end
				end
			end)
		end
	end))
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local d = input.Position - startMouse
			if d.Magnitude > 4 then moved = true end
			if moved then
				target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end
	end))
end

local function getGuiParent()
	local ok, ui = pcall(function() return gethui and gethui() end)
	if ok and ui then return ui end
	ok = pcall(function()
		local f = Instance.new("Folder")
		f.Parent = game:GetService("CoreGui")
		f:Destroy()
	end)
	if ok then return game:GetService("CoreGui") end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

--------------------------------------------------------------------------------
-- Settings storage
--------------------------------------------------------------------------------
local Storage = { Folder = "HazerUI", File = "HazerUI/settings.txt" }

function Storage.supported()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

function Storage.load()
	if not Storage.supported() then return nil end
	local ok, res = pcall(function()
		if not isfile(Storage.File) then return nil end
		return HttpService:JSONDecode(readfile(Storage.File))
	end)
	if ok and type(res) == "table" then return res end
	return nil
end

function Storage.save(data)
	if not Storage.supported() then return false end
	local ok = pcall(function()
		if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder(Storage.Folder) then
			makefolder(Storage.Folder)
		end
		writefile(Storage.File, HttpService:JSONEncode(data))
	end)
	return ok
end

Library.Storage = Storage

--------------------------------------------------------------------------------
-- Presets
--------------------------------------------------------------------------------
function Library:AddPreset(name, colorA, colorB)
	name = tostring(name)
	local a = toColor(colorA, Color3.fromRGB(120, 120, 255))
	local b = toColor(colorB, a)
	if not self._presets[name] then table.insert(self._presetOrder, name) end
	self._presets[name] = { A = a, B = b }
	for _, w in ipairs(self._windows) do
		if w._addSwatch then w._addSwatch(name) end
	end
end

Library:AddPreset("Dusk",   Color3.fromRGB(118, 124, 255), Color3.fromRGB(196, 112, 255))
Library:AddPreset("Lagoon", Color3.fromRGB(40, 205, 225),  Color3.fromRGB(64, 128, 255))
Library:AddPreset("Orchid", Color3.fromRGB(204, 104, 255), Color3.fromRGB(255, 108, 188))
Library:AddPreset("Moss",   Color3.fromRGB(112, 214, 132), Color3.fromRGB(38, 160, 150))
Library:AddPreset("Ember",  Color3.fromRGB(255, 150, 64),  Color3.fromRGB(255, 76, 96))

--------------------------------------------------------------------------------
-- Theme plumbing
--------------------------------------------------------------------------------
function Window:_bind(fn)
	table.insert(self._binders, fn)
	fn(self.Theme)
end

function Window:_bindGrad(g)
	self:_bind(function(t) g.Color = ColorSequence.new(t.A, t.B) end)
end

function Window:_bindColor(inst, prop, key)
	self:_bind(function(t) inst[prop] = t[key] end)
end

function Window:_setTheme(a, b, name, animate)
	local t = self.Theme
	local fa, fb, fbg = t.A, t.B, t.BG
	local ta, tb, tbg = a, b, computeBG(a)
	t.Name = name
	if self._themeConn then self._themeConn:Disconnect() self._themeConn = nil end
	if self._themeTween then self._themeTween:Cancel() self._themeTween = nil end

	local function apply(k)
		t.A, t.B, t.BG = fa:Lerp(ta, k), fb:Lerp(tb, k), fbg:Lerp(tbg, k)
		for _, fn in ipairs(self._binders) do fn(t) end
	end
	if not animate then apply(1) return end

	local nv = Instance.new("NumberValue")
	self._themeConn = nv.Changed:Connect(function() apply(nv.Value) end)
	local tw = TweenService:Create(nv, TweenInfo.new(0.5, QUINT, OUT), { Value = 1 })
	self._themeTween = tw
	tw.Completed:Connect(function(state)
		if self._themeTween == tw then
			if state == Enum.PlaybackState.Completed then apply(1) end
			if self._themeConn then self._themeConn:Disconnect() self._themeConn = nil end
			self._themeTween = nil
		end
		nv:Destroy()
	end)
	tw:Play()
end

function Window:SetAccent(name, noSave)
	local p = Library._presets[tostring(name)]
	if not p then warn("[HazerUI] unknown accent preset: " .. tostring(name)) return end
	self:_setTheme(p.A, p.B, tostring(name), self._built == true)
	if not noSave then self:_save() end
end

function Window:_save()
	if self._noSave then return end
	local t = self.Theme
	local p = Library._presets[t.Name]
	local a, b = p and p.A or t.A, p and p.B or t.B
	Storage.save({
		Theme = t.Name,
		ThemeA = fromColor(a),
		ThemeB = fromColor(b),
		ToggleKey = self.ToggleKey and self.ToggleKey.Name or "RightShift",
	})
end

--------------------------------------------------------------------------------
-- Core window methods
--------------------------------------------------------------------------------
function Window:Track(conn)
	table.insert(self._conns, conn)
	return conn
end

function Window:OnUnload(fn)
	table.insert(self._unload, fn)
end

function Window:Open()
	if self.Visible or self._unloaded then return end
	self.Visible = true
	self.Main.Visible = true
	self._scale.Scale = self._base * 0.9
	tween(self._scale, 0.5, { Scale = self._base }, BACK, OUT)
end

function Window:Close()
	if not self.Visible then return end
	self.Visible = false
	self:_closeDropdown(true)
	tween(self._scale, 0.2, { Scale = self._base * 0.92 }, QUART, IN)
	task.delay(0.2, function()
		if not self.Visible and self.Main and self.Main.Parent then self.Main.Visible = false end
	end)
end

function Window:Toggle()
	if self.Visible then self:Close() else self:Open() end
end

function Window:Unload()
	if self._unloaded then return end
	self._unloaded = true
	for _, fn in ipairs(self._unload) do pcall(fn) end
	self:_closeDropdown(true)
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	if self._themeConn then self._themeConn:Disconnect() end
	if self.Gui then self.Gui:Destroy() end
	for i, w in ipairs(Library._windows) do
		if w == self then table.remove(Library._windows, i) break end
	end
	local genv = (getgenv and getgenv()) or _G
	if genv.__HazerUnload == self._genvUnload then genv.__HazerUnload = nil end
end

function Window:_page(nav)
	local p = nav and self.Pages[nav]
	if p then return p end
	if nav then warn("[HazerUI] unknown nav id '" .. tostring(nav) .. "', using fallback page") end
	return self.PageList[#self.PageList] or self.Pages.Settings
end

local function nextOrder(page)
	page.Order += 1
	return page.Order
end

function Window:_parse(str)
	local parts = {}
	for piece in string.gmatch(tostring(str), "[^,]+") do
		table.insert(parts, (piece:match("^%s*(.-)%s*$")))
	end
	local name, desc, nav = parts[1] or "Unnamed", "", nil
	if #parts >= 3 then
		nav = parts[#parts]
		desc = table.concat(parts, ", ", 2, #parts - 1)
	elseif #parts == 2 then
		if self.Pages[parts[2]] then nav = parts[2] else desc = parts[2] end
	end
	return name, desc, nav
end

--------------------------------------------------------------------------------
-- Navigation & pages
--------------------------------------------------------------------------------
function Window:_addNav(id, title, subtitle, pinned)
	self._navOrder += 1
	local btn = new("TextButton", {
		Name = id, Text = "", BackgroundColor3 = WHITE, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36), LayoutOrder = self._navOrder,
		Parent = pinned and self._pinHolder or self._navList,
	})
	new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = btn })
	local indicator = new("Frame", {
		BackgroundColor3 = WHITE, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(3, 16), Parent = btn,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = indicator })
	self:_bindGrad(new("UIGradient", { Rotation = 90, Parent = indicator }))
	local text = label({ Text = title, Position = UDim2.new(0, 20, 0, 0), Size = UDim2.new(1, -26, 1, 0), TextColor3 = SUB, Parent = btn })

	local frame = new("ScrollingFrame", {
		Name = id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollBarImageTransparency = 0.3, ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = self._pageHolder,
	})
	self:_bindColor(frame, "ScrollBarImageColor3", "A")
	new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = frame })
	-- [تصحيح]: تعديل الهوامش لمنع التصاق العناصر وتجاوز الحواف
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 14), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 12), Parent = frame })

	local page = { Id = id, Title = title, Subtitle = subtitle or "", Frame = frame, Button = btn, Order = 0 }
	page.Select = function() self:Select(id) end
	page._style = function(selected)
		tween(btn, 0.25, { BackgroundTransparency = selected and 0.88 or 1 })
		tween(indicator, 0.3, { BackgroundTransparency = selected and 0 or 1 })
		tween(text, 0.25, { TextColor3 = selected and TEXT or SUB })
	end

	btn.MouseEnter:Connect(function()
		if self.Current ~= page then tween(btn, 0.2, { BackgroundTransparency = 0.94 }) end
	end)
	btn.MouseLeave:Connect(function()
		if self.Current ~= page then tween(btn, 0.2, { BackgroundTransparency = 1 }) end
	end)
	btn.MouseButton1Click:Connect(function() self:Select(id) end)

	self.Pages[id] = page
	return page
end

function Window:AddNav(id, title, subtitle)
	id = tostring(id)
	if self.Pages[id] then return self.Pages[id] end
	local page = self:_addNav(id, title or id, subtitle, false)
	table.insert(self.PageList, page)
	if not self.Current then self:Select(id) end
	return page
end

function Window:Select(nav)
	local p = self.Pages[nav]
	if not p or self.Current == p then return end
	self:_closeDropdown(true)
	local old = self.Current
	if old then
		old.Frame.Visible = false
		old._style(false)
	end
	self.Current = p
	p._style(true)
	p.Frame.Position = UDim2.fromOffset(0, 12)
	p.Frame.Visible = true
	tween(p.Frame, 0.4, { Position = UDim2.fromOffset(0, 0) }, QUINT, OUT)
	self._title.Text = p.Title
	self._subtitle.Text = p.Subtitle
end

--------------------------------------------------------------------------------
-- Row builder shared by all elements
--------------------------------------------------------------------------------
function Window:_row(nav, name, desc, rightW, o)
	o = o or {}
	local page = self:_page(nav)
	local hasDesc = desc ~= nil and desc ~= ""
	local h = o.height or (hasDesc and 56 or 44)
	-- [تصحيح]: عرض الفريم مطابق تماماً للمساحة المتاحة (1, -4) لمنع خروجه من الحواف
	local card = new("TextButton", {
		Name = name, Text = "", BackgroundColor3 = WHITE, BackgroundTransparency = 0.93,
		Size = UDim2.new(1, -4, 0, h), LayoutOrder = nextOrder(page), Parent = page.Frame,
	})
	local scale = new("UIScale", { Parent = card })
	local top = hasDesc or o.top
	local nameL = label({
		Text = name, Font = FONT_M, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, top and 9 or 0),
		Size = UDim2.new(1, -(rightW + 28), 0, top and 18 or h), Parent = card,
	})
	if hasDesc then
		label({
			Text = desc, Font = FONT_R, TextSize = 11, TextColor3 = SUB, TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -(rightW + 28), 0, 16), Parent = card,
		})
	end
	glass(card, 12, true)

	card.MouseEnter:Connect(function() tween(card, 0.2, { BackgroundTransparency = 0.87 }) end)
	card.MouseLeave:Connect(function()
		tween(card, 0.25, { BackgroundTransparency = 0.93 })
		if o.pressable then tween(scale, 0.3, { Scale = 1 }, BACK, OUT) end
	end)
	if o.pressable then
		card.MouseButton1Down:Connect(function() tween(scale, 0.1, { Scale = 0.982 }) end)
		card.MouseButton1Up:Connect(function() tween(scale, 0.4, { Scale = 1 }, BACK, OUT) end)
	end
	return card, nameL, page
end

--------------------------------------------------------------------------------
-- Elements
--------------------------------------------------------------------------------
function Window:AddSection(nav, title)
	local page = self:_page(nav)
	local f = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -4, 0, 26), LayoutOrder = nextOrder(page), Parent = page.Frame })
	local pill = new("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 4), Size = UDim2.fromOffset(3, 12), Parent = f })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
	self:_bindGrad(new("UIGradient", { Rotation = 90, Parent = pill }))
	local txt = label({ Text = string.upper(tostring(title)), Font = FONT_B, TextSize = 11, TextColor3 = SUB, Position = UDim2.new(0, 12, 0, 4), Size = UDim2.new(1, -12, 1, 0), Parent = f })
	local obj = {}
	obj.SetText = method(obj, function(t) txt.Text = string.upper(tostring(t)) end)
	return obj
end

function Window:AddLabel(text, nav)
	local page = self:_page(nav)
	local l = label({
		Text = tostring(text), Font = FONT_R, TextSize = 12, TextColor3 = SUB, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, -4, 0, 0), LayoutOrder = nextOrder(page), Parent = page.Frame,
	})
	new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 2), Parent = l })
	local obj = {}
	obj.SetText = method(obj, function(t) l.Text = tostring(t) end)
	obj.Get = method(obj, function() return l.Text end)
	self.Elements[#self.Elements + 1] = obj
	return obj
end

function Window:AddButton(a, b, c, d)
	local name, desc, nav, cb
	if type(b) ~= "string" then
		name, desc, nav = self:_parse(a)
		cb = b
	else
		name, desc, nav, cb = a, b, c, d
	end
	local card = self:_row(nav, name, desc, 30, { pressable = true })
	local arrow = chevron(card, SUB)
	arrow.Position = UDim2.new(1, -22, 0.5, 0)
	arrow.Rotation = -90
	card.MouseButton1Click:Connect(function() fire(cb) end)
	card.MouseEnter:Connect(function() tween(arrow, 0.25, { Position = UDim2.new(1, -18, 0.5, 0) }) end)
	card.MouseLeave:Connect(function() tween(arrow, 0.25, { Position = UDim2.new(1, -22, 0.5, 0) }) end)
	local obj = {}
	obj.Fire = method(obj, function() fire(cb) end)
	self.Elements[name] = obj
	return obj
end

function Window:AddToggle(a, b, c, d, e)
	local name, desc, nav, cb, default
	if type(b) ~= "string" then
		name, desc, nav = self:_parse(a)
		cb, default = b, c
	else
		name, desc, nav, cb, default = a, b, c, d, e
	end
	local card = self:_row(nav, name, desc, 50, { pressable = true })
	local track = new("Frame", {
		BackgroundColor3 = Color3.fromRGB(72, 74, 90), BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(44, 26), Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local fill = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = track })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	self:_bindGrad(new("UIGradient", { Parent = fill }))
	local knob = new("Frame", {
		BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20), Parent = track,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })

	local obj = { Value = false }
	local function visual(on)
		tween(fill, 0.3, { BackgroundTransparency = on and 0 or 1 })
		tween(knob, 0.4, { Position = on and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) }, BACK, OUT)
	end
	local function set(v, silent)
		v = v == true
		if obj.Value == v and not silent then return end
		obj.Value = v
		visual(v)
		if not silent then fire(cb, v) end
	end
	obj.Set = method(obj, function(v) set(v) end)
	obj.Get = method(obj, function() return obj.Value end)
	obj.Toggle = method(obj, function() set(not obj.Value) end)
	card.MouseButton1Click:Connect(function() set(not obj.Value) end)

	if default == true then
		obj.Value = true
		visual(true)
		fire(cb, true)
	end
	self.Elements[name] = obj
	return obj
end

function Window:AddSlider(a, b, c, d, e, f, g)
	local name, desc, nav, min, max, default, cb
	if type(b) ~= "string" then
		name, desc, nav = self:_parse(a)
		min, max, default, cb = b, c, d, e
	else
		name, desc, nav, min, max, default, cb = a, b, c, d, e, f, g
	end
	min, max = tonumber(min) or 0, tonumber(max) or 100
	if max <= min then max = min + 1 end
	default = math.clamp(tonumber(default) or min, min, max)
	local integer = (min % 1 == 0) and (max % 1 == 0)
	local hasDesc = desc ~= nil and desc ~= ""

	local card = self:_row(nav, name, desc, 70, { height = hasDesc and 68 or 54, top = true })
	local valueL = label({ Font = FONT_B, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -84, 0, 9), Size = UDim2.fromOffset(70, 18), Parent = card })
	self:_bindColor(valueL, "TextColor3", "A")

	local track = new("Frame", {
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, Position = UDim2.new(0, 14, 1, -18),
		Size = UDim2.new(1, -28, 0, 6), Parent = card,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = track })
	local fill = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(0, 1), Parent = track })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = fill })
	self:_bindGrad(new("UIGradient", { Parent = fill }))
	local knob = new("Frame", {
		BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14), ZIndex = 2, Parent = track,
	})
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = knob })
	local hit = new("TextButton", { Text = "", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 8, 0, 28), ZIndex = 3, Parent = track })

	local obj = { Value = default }
	local function fmt(v)
		if integer then return tostring(math.floor(v + 0.5)) end
		return (string.format("%.2f", v):gsub("0+$", ""):gsub("%.$", ""))
	end
	local function snap(v)
		if integer then return math.floor(v + 0.5) end
		return tonumber(string.format("%.2f", v))
	end
	local function visual(v, animate)
		local alpha = (v - min) / (max - min)
		valueL.Text = fmt(v)
		if animate then
			tween(fill, 0.25, { Size = UDim2.fromScale(alpha, 1) })
			tween(knob, 0.25, { Position = UDim2.fromScale(alpha, 0.5) })
		else
			fill.Size = UDim2.fromScale(alpha, 1)
			knob.Position = UDim2.fromScale(alpha, 0.5)
		end
	end
	local function set(v, animate, silent)
		v = snap(math.clamp(tonumber(v) or min, min, max))
		if v == obj.Value and not silent then return end
		obj.Value = v
		visual(v, animate)
		if not silent then fire(cb, v) end
	end
	local dragging = false
	local function fromX(x)
		local alpha = math.clamp((x - track.AbsolutePosition.X) / math.max(1, track.AbsoluteSize.X), 0, 1)
		set(min + (max - min) * alpha, false)
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			tween(knob, 0.25, { Size = UDim2.fromOffset(18, 18) }, BACK, OUT)
			fromX(input.Position.X)
		end
	end)
	self:Track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromX(input.Position.X)
		end
	end))
	self:Track(UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			tween(knob, 0.3, { Size = UDim2.fromOffset(14, 14) }, BACK, OUT)
		end
	end))

	visual(default, false)
	obj.Set = method(obj, function(v) set(v, true) end)
	obj.Get = method(obj, function() return obj.Value end)
	self.Elements[name] = obj
	return obj
end

function Window:AddKeybind(a, b, c, d, e, f)
	local name, desc, nav, key, cb, onChanged
	if type(b) ~= "string" then
		name, desc, nav = self:_parse(a)
		key, cb, onChanged = b, c, d
	else
		name, desc, nav, key, cb, onChanged = a, b, c, d, e, f
	end
	if type(key) == "string" then key = keyFromName(key) end

	local card = self:_row(nav, name, desc, 110)
	local btn = new("TextButton", {
		Text = "", BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 30), Parent = card,
	})
	local stroke = glass(btn, 8, false)
	local keyL = label({ Font = FONT_M, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = btn })

	local obj = { Key = key, Callback = cb }
	local listening = false
	local function render()
		keyL.Text = listening and "..." or (obj.Key and obj.Key.Name or "None")
		tween(stroke, 0.2, { Color = listening and self.Theme.A or WHITE })
	end
	local function stop()
		listening = false
		self._capture = nil
		render()
	end
	local function apply(k, silent)
		obj.Key = k
		render()
		if not silent then fire(onChanged, k) end
	end
	btn.MouseButton1Click:Connect(function()
		if listening then stop() return end
		if self._capture then self._capture(Enum.KeyCode.Escape) end
		listening = true
		render()
		self._capture = function(kc)
			if kc == Enum.KeyCode.Escape then stop() return end
			stop()
			apply(kc)
		end
	end)
	btn.MouseEnter:Connect(function() tween(btn, 0.2, { BackgroundTransparency = 0.8 }) end)
	btn.MouseLeave:Connect(function() tween(btn, 0.2, { BackgroundTransparency = 0.88 }) end)
	render()

	obj.Set = method(obj, function(k)
		if type(k) == "string" then k = keyFromName(k) end
		if typeof(k) == "EnumItem" then apply(k) end
	end)
	obj.Get = method(obj, function() return obj.Key end)
	table.insert(self._keybinds, obj)
	self.Elements[name] = obj
	return obj
end

function Window:AddInput(a, b, c, d, e, f)
	local name, desc, nav, placeholder, cb, default
	if type(c) ~= "string" then
		name, desc, nav = self:_parse(a)
		placeholder, cb, default = b, c, d
	else
		name, desc, nav, placeholder, cb, default = a, b, c, d, e, f
	end
	local card = self:_row(nav, name, desc, 160)
	local box = new("Frame", {
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(148, 30), Parent = card,
	})
	local stroke = glass(box, 8, false)
	local tb = new("TextBox", {
		BackgroundTransparency = 1, Font = FONT_M, TextSize = 12, TextColor3 = TEXT, PlaceholderColor3 = SUB,
		PlaceholderText = tostring(placeholder or "Type here..."), Text = tostring(default or ""), ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Parent = box,
	})
	local obj = { Value = tostring(default or "") }
	tb.Focused:Connect(function() tween(stroke, 0.2, { Color = self.Theme.A }) tween(box, 0.2, { BackgroundTransparency = 0.8 }) end)
	tb.FocusLost:Connect(function()
		tween(stroke, 0.25, { Color = WHITE })
		tween(box, 0.25, { BackgroundTransparency = 0.88 })
		obj.Value = tb.Text
		fire(cb, tb.Text)
	end)
	obj.Set = method(obj, function(t) tb.Text = tostring(t) obj.Value = tb.Text fire(cb, tb.Text) end)
	obj.Get = method(obj, function() return obj.Value end)
	self.Elements[name] = obj
	return obj
end

--------------------------------------------------------------------------------
-- Dropdown
--------------------------------------------------------------------------------
function Window:AddDropdown(a, b, c, d, e, f)
	local name, desc, nav, options, default, cb
	if type(b) == "table" then
		name, desc, nav = self:_parse(a)
		options, default, cb = b, c, d
	else
		name, desc, nav, options, default, cb = a, b, c, d, e, f
	end
	options = options or {}

	local card, _, page = self:_row(nav, name, desc, 150)
	local btn = new("TextButton", {
		Text = "", BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(136, 30), Parent = card,
	})
	local stroke = glass(btn, 8, false)
	local valueL = label({
		Font = FONT_M, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -32, 1, 0), Parent = btn,
	})
	local arrow = chevron(btn, SUB)
	arrow.Position = UDim2.new(1, -16, 0.5, 0)

	local dd = { Options = options, Value = nil, Button = btn, Page = page, Searchable = nil }
	local obj = dd

	local function showValue()
		if dd.Value ~= nil then
			valueL.Text = tostring(dd.Value)
			valueL.TextColor3 = TEXT
		else
			valueL.Text = "Select..."
			valueL.TextColor3 = SUB
		end
	end
	local function indexOf(v)
		for i, o in ipairs(dd.Options) do
			if o == v or tostring(o) == tostring(v) then return i end
		end
	end
	dd._setOpen = function(open)
		tween(arrow, 0.3, { Rotation = open and 180 or 0 }, QUINT, OUT)
		tween(stroke, 0.2, { Color = open and self.Theme.A or WHITE })
		tween(btn, 0.2, { BackgroundTransparency = open and 0.8 or 0.88 })
	end
	dd._select = function(opt)
		dd.Value = opt
		showValue()
		fire(cb, opt)
	end

	btn.MouseButton1Click:Connect(function() self:_openDropdown(dd) end)
	btn.MouseEnter:Connect(function() if not (self._dd and self._dd.dd == dd) then tween(btn, 0.2, { BackgroundTransparency = 0.82 }) end end)
	btn.MouseLeave:Connect(function() if not (self._dd and self._dd.dd == dd) then tween(btn, 0.2, { BackgroundTransparency = 0.88 }) end end)

	obj.Set = method(obj, function(opt)
		local i = indexOf(opt)
		if i then dd._select(dd.Options[i]) end
	end)
	obj.Get = method(obj, function() return dd.Value end)
	obj.Refresh = method(obj, function(newOptions, newDefault)
		if self._dd and self._dd.dd == dd then self:_closeDropdown(true) end
		dd.Options = newOptions or {}
		obj.Options = dd.Options
		if newDefault ~= nil and indexOf(newDefault) then
			dd._select(dd.Options[indexOf(newDefault)])
		elseif dd.Value ~= nil and not indexOf(dd.Value) then
			dd.Value = nil
			showValue()
		end
	end)
	obj.SetOptions = obj.Refresh

	if default ~= nil and indexOf(default) then
		dd.Value = options[indexOf(default)]
		showValue()
		fire(cb, dd.Value)
	else
		showValue()
	end
	self.Elements[name] = obj
	return obj
end

function Window:_closeDropdown(instant)
	local st = self._dd
	if not st then return end
	self._dd = nil
	for _, c in ipairs(st.conns) do pcall(function() c:Disconnect() end) end
	st.dd._setOpen(false)
	local panel = st.panel
	if instant then
		panel:Destroy()
		self.Overlay.Visible = false
	else
		tween(panel, 0.18, { Size = UDim2.fromOffset(st.w, 0) }, QUART, IN)
		task.delay(0.19, function()
			panel:Destroy()
			if not self._dd and self.Overlay then self.Overlay.Visible = false end
		end)
	end
end

function Window:_openDropdown(dd)
	if self._dd and self._dd.dd == dd then self:_closeDropdown() return end
	self:_closeDropdown(true)
	local options = dd.Options
	local n = #options
	if n == 0 then return end

	local ITEM, GAP = 30, 2
	local searchable = dd.Searchable
	if searchable == nil then searchable = n > 7 end
	local searchH = searchable and 42 or 0
	local contentH = n * (ITEM + GAP) + 8
	local listH = math.min(contentH, 192)
	local panelH = searchH + listH

	local overlay = self.Overlay
	overlay.Visible = true
	local btn = dd.Button
	local vs = overlay.AbsoluteSize
	local bp, bs = btn.AbsolutePosition, btn.AbsoluteSize
	local w = math.max(bs.X, 176)
	local flip = (bp.Y + bs.Y + 6 + panelH > vs.Y - 8) and (bp.Y - 6 - panelH > 8)

	local function place()
		local p, s = btn.AbsolutePosition, btn.AbsoluteSize
		local x = math.clamp(p.X + s.X - w, 8, math.max(8, vs.X - w - 8))
		return UDim2.fromOffset(x, flip and (p.Y - 6) or (p.Y + s.Y + 6))
	end

	local t = self.Theme
	local panel = new("Frame", {
		Name = "DropdownPanel", BackgroundColor3 = t.BG:Lerp(WHITE, 0.06), BackgroundTransparency = 0.04,
		AnchorPoint = Vector2.new(0, flip and 1 or 0), Position = place(), Size = UDim2.fromOffset(w, 0),
		ClipsDescendants = true, Parent = overlay,
	})
	glass(panel, 14, true)

	local search
	if searchable then
		local sb = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 28), Parent = panel })
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = sb })
		search = new("TextBox", {
			BackgroundTransparency = 1, Font = FONT_M, TextSize = 12, TextColor3 = TEXT, PlaceholderColor3 = SUB,
			PlaceholderText = "Search...", Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Parent = sb,
		})
	end

	local list = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(0, searchH), Size = UDim2.new(1, 0, 0, listH),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 3,
		ScrollBarImageColor3 = t.A, ScrollBarImageTransparency = 0.3, Parent = panel,
	})
	new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = list })

	local empty = label({
		Text = "No results", Font = FONT_R, TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, searchH), Size = UDim2.new(1, 0, 0, 36), Visible = false, Parent = panel,
	})

	local items = {}
	local function styleItem(it, selected, hovering)
		tween(it.btn, 0.2, { BackgroundTransparency = selected and 0.84 or (hovering and 0.92 or 1) })
		it.text.TextColor3 = selected and TEXT or Color3.fromRGB(205, 206, 220)
		it.text.Font = selected and FONT_B or FONT_M
		it.bar.Visible = selected
		it.check.Visible = selected
	end
	local selectedIndex
	for i, opt in ipairs(options) do
		local selected = (opt == dd.Value) or (dd.Value ~= nil and tostring(opt) == tostring(dd.Value))
		if selected then selectedIndex = i end
		local b = new("TextButton", {
			Text = "", BackgroundColor3 = WHITE, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, ITEM),
			LayoutOrder = i, Parent = list,
		})
		new("UICorner", { CornerRadius = UDim.new(0, 8), Parent = b })
		local bar = new("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(3, 14), Visible = false, Parent = b })
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(t.A, t.B), Parent = bar })
		local text = label({ Text = tostring(opt), Font = FONT_M, TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -40, 1, 0), Parent = b })
		local ck = checkmark(b, t.A)
		ck.Position = UDim2.new(1, -16, 0.5, 0)
		ck.Visible = false
		local it = { btn = b, text = text, bar = bar, check = ck, name = string.lower(tostring(opt)), selected = selected }
		items[i] = it
		styleItem(it, selected, false)
		b.MouseEnter:Connect(function() if not it.selected then styleItem(it, false, true) end end)
		b.MouseLeave:Connect(function() if not it.selected then styleItem(it, false, false) end end)
		b.MouseButton1Click:Connect(function()
			dd._select(opt)
			self:_closeDropdown()
		end)
	end

	if search then
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local q = string.lower(search.Text)
			local shown = 0
			for _, it in ipairs(items) do
				local vis = q == "" or string.find(it.name, q, 1, true) ~= nil
				it.btn.Visible = vis
				if vis then shown += 1 end
			end
			empty.Visible = shown == 0
			list.Visible = shown > 0
			list.CanvasPosition = Vector2.new(0, 0)
		end)
	end

	local conns = {}
	table.insert(conns, RunService.RenderStepped:Connect(function()
		if not btn.Parent or not self.Visible or not btn:IsDescendantOf(self.Gui) or not dd.Page.Frame.Visible then
			self:_closeDropdown(true)
			return
		end
		panel.Position = place()
	end))
	table.insert(conns, dd.Page.Frame:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		self:_closeDropdown()
	end))
	self._dd = { dd = dd, panel = panel, conns = conns, w = w }

	dd._setOpen(true)
	tween(panel, 0.32, { Size = UDim2.fromOffset(w, panelH) }, QUINT, OUT)
	if selectedIndex then
		task.delay(0.04, function()
			if list.Parent then
				list.CanvasPosition = Vector2.new(0, math.clamp((selectedIndex - 1) * (ITEM + GAP) - listH / 2 + ITEM / 2, 0, math.max(0, contentH - listH)))
			end
		end)
	end
end

--------------------------------------------------------------------------------
-- Notifications (تصحيح المحاذاة والمظهر)
--------------------------------------------------------------------------------
function Window:Notify(title, message, seconds)
	if self._unloaded then return end
	seconds = tonumber(seconds) or 4
	title, message = tostring(title or self.Name), tostring(message or "")
	local width = 292
	local textH = 0
	if message ~= "" then
		local ok, size = pcall(function() return TextService:GetTextSize(message, 12, FONT_R, Vector2.new(width - 38, 1000)) end)
		textH = ok and size.Y or 16
	end
	local h = message == "" and 46 or (36 + textH + 14)

	local wrap = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(width, h), Parent = self.NotifyHolder })
	local card = new("Frame", {
		BackgroundColor3 = self.Theme.BG, BackgroundTransparency = 0.1, ClipsDescendants = true,
		Position = UDim2.fromOffset(width + 40, 0), Size = UDim2.fromScale(1, 1), Parent = wrap,
	})
	glass(card, 14, true)
	local bar = new("Frame", { BackgroundColor3 = WHITE, Position = UDim2.fromOffset(10, 11), Size = UDim2.new(0, 3, 1, -22), Parent = card })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = bar })
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(self.Theme.A, self.Theme.B), Parent = bar })
	label({ Text = title, Font = FONT_B, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(22, 9), Size = UDim2.new(1, -34, 0, 18), Parent = card })
	if message ~= "" then
		label({
			Text = message, Font = FONT_R, TextSize = 12, TextColor3 = SUB, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(22, 29), Size = UDim2.new(1, -34, 0, textH), Parent = card,
		})
	end
	local prog = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.25, Position = UDim2.new(0, 0, 1, -2), Size = UDim2.new(1, 0, 0, 2), Parent = card })
	new("UIGradient", { Color = ColorSequence.new(self.Theme.A, self.Theme.B), Parent = prog })

	tween(card, 0.55, { Position = UDim2.fromOffset(0, 0) }, QUINT, OUT)
	tween(prog, seconds, { Size = UDim2.new(0, 0, 0, 2) }, Enum.EasingStyle.Linear, OUT)
	task.delay(seconds, function()
		if not wrap.Parent then return end
		tween(card, 0.4, { Position = UDim2.fromOffset(width + 40, 0) }, QUART, IN)
		task.wait(0.35)
		if wrap.Parent then
			tween(wrap, 0.25, { Size = UDim2.fromOffset(width, 0) })
			task.wait(0.27)
			wrap:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- CreateWindow
--------------------------------------------------------------------------------
function Library:CreateWindow(opts)
	opts = opts or {}
	local genv = (getgenv and getgenv()) or _G
	if genv.__HazerUnload then pcall(genv.__HazerUnload) end

	local self = setmetatable({}, Window)
	self.Name = tostring(opts.Name or "Hazer")
	self.Subtitle = tostring(opts.Subtitle or "")
	self.Elements, self.Pages, self.PageList = {}, {}, {}
	self._conns, self._unload, self._binders, self._keybinds = {}, {}, {}, {}
	self._navOrder = 0
	self.Visible = false
	self.Current = nil

	local saved = Storage.load()
	local defaultKey = (typeof(opts.ToggleKey) == "EnumItem" and opts.ToggleKey) or Enum.KeyCode.RightShift
	local defaultAccent = (opts.Accent and Library._presets[tostring(opts.Accent)]) and tostring(opts.Accent) or "Dusk"
	local accentName = defaultAccent
	self.ToggleKey = defaultKey
	if saved then
		local sName = type(saved.Theme) == "string" and saved.Theme or nil
		if sName and Library._presets[sName] then
			accentName = sName
		elseif sName and saved.ThemeA and saved.ThemeB then
			local ca, cb = toColor(saved.ThemeA), toColor(saved.ThemeB)
			if ca and cb then
				Library:AddPreset(sName, ca, cb)
				accentName = sName
			end
		end
		local k = keyFromName(saved.ToggleKey)
		if k then self.ToggleKey = k end
	end
	local preset = Library._presets[accentName]
	self.Theme = { A = preset.A, B = preset.B, BG = computeBG(preset.A), Name = accentName }

	local parent = getGuiParent()
	local old = parent:FindFirstChild("HazerUI")
	if old then old:Destroy() end
	local gui = new("ScreenGui", {
		Name = "HazerUI", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	})
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	gui.Parent = parent
	self.Gui = gui

	local W, H = tonumber(opts.Width) or 640, tonumber(opts.Height) or 440
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	self._base = math.min(1, (vp.X - 24) / W, (vp.Y - 24) / H)
	local main = new("Frame", {
		Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundColor3 = self.Theme.BG, BackgroundTransparency = 0.14,
		ClipsDescendants = true, Visible = false, ZIndex = 1, Parent = gui,
	})
	self.Main = main
	self._scale = new("UIScale", { Scale = self._base, Parent = main })
	glass(main, 20, true)
	self:_bindColor(main, "BackgroundColor3", "BG")

	local function glow(anchor, pos, size)
		local g = new("Frame", {
			BackgroundColor3 = WHITE, BackgroundTransparency = 0, AnchorPoint = anchor, Position = pos,
			Size = UDim2.fromOffset(size, size), ZIndex = 0, Active = false, Parent = main,
		})
		new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = g })
		new("UIGradient", {
			Rotation = 45,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.80), NumberSequenceKeypoint.new(1, 1) }),
			Parent = g,
		})
		return g
	end
	local glowA = glow(Vector2.new(1, 0), UDim2.new(1, 70, 0, -70), 320)
	local glowB = glow(Vector2.new(0, 1), UDim2.new(0, -90, 1, 90), 300)
	self:_bindColor(glowA, "BackgroundColor3", "A")
	self:_bindColor(glowB, "BackgroundColor3", "B")

	local sidebar = new("Frame", { Name = "Sidebar", BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72, Size = UDim2.new(0, 170, 1, 0), Parent = main })
	new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.92, Position = UDim2.new(1, -1, 0, 0), Size = UDim2.new(0, 1, 1, 0), Parent = sidebar })
	local brand = label({ Text = self.Name, Font = FONT_B, TextSize = 20, TextColor3 = WHITE, Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -30, 0, 26), Parent = sidebar })
	self:_bindGrad(new("UIGradient", { Parent = brand }))
	label({ Text = self.Subtitle, Font = FONT_R, TextSize = 11, TextColor3 = SUB, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -30, 0, 16), Parent = sidebar })

	self._navList = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 78), Size = UDim2.new(1, -20, 1, -144),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 0, Parent = sidebar,
	})
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = self._navList })
	new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, Position = UDim2.new(0, 16, 1, -62), Size = UDim2.new(1, -32, 0, 1), Parent = sidebar })
	self._pinHolder = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0, 10, 1, -54), Size = UDim2.new(1, -20, 0, 36), Parent = sidebar })
	label({ Text = "v" .. Library.Version, Font = FONT_R, TextSize = 10, TextColor3 = SUB, TextTransparency = 0.4, Position = UDim2.new(0, 18, 1, -18), Size = UDim2.new(1, -30, 0, 14), Parent = sidebar })

	local content = new("Frame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(170, 0), Size = UDim2.new(1, -170, 1, 0), Parent = main })
	local topbar = new("Frame", { Name = "Topbar", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), Parent = content })
	self._title = label({ Text = "", Font = FONT_B, TextSize = 17, Position = UDim2.fromOffset(20, 10), Size = UDim2.new(1, -80, 0, 22), Parent = topbar })
	self._subtitle = label({ Text = "", Font = FONT_R, TextSize = 11, TextColor3 = SUB, Position = UDim2.fromOffset(20, 32), Size = UDim2.new(1, -80, 0, 16), Parent = topbar })
	local closeBtn = new("TextButton", {
		Text = "", BackgroundColor3 = WHITE, BackgroundTransparency = 0.9, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(28, 28), Parent = topbar,
	})
	glass(closeBtn, 14, false)
	local x = cross(closeBtn, SUB)
	closeBtn.MouseEnter:Connect(function()
		tween(closeBtn, 0.2, { BackgroundColor3 = Color3.fromRGB(255, 82, 96), BackgroundTransparency = 0.3 })
		tween(x, 0.35, { Rotation = 90 }, BACK, OUT)
	end)
	closeBtn.MouseLeave:Connect(function()
		tween(closeBtn, 0.25, { BackgroundColor3 = WHITE, BackgroundTransparency = 0.9 })
		tween(x, 0.3, { Rotation = 0 }, QUART, OUT)
	end)
	closeBtn.MouseButton1Click:Connect(function() self:Close() end)
	makeDraggable(topbar, main, function(c) return self:Track(c) end)

	self._pageHolder = new("Frame", { Name = "Pages", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(16, 58), Size = UDim2.new(1, -24, 1, -70), Parent = content })

	local overlay = new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50, Visible = false, Parent = gui })
	self.Overlay = overlay
	local catcher = new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = overlay })
	catcher.MouseButton1Click:Connect(function() self:_closeDropdown() end)

	local holder = new("Frame", {
		Name = "Notifications", BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18), Size = UDim2.new(0, 300, 1, -36), ZIndex = 100, Parent = gui,
	})
	new("UIListLayout", {
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = holder,
	})
	self.NotifyHolder = holder

	local launcher = new("TextButton", {
		Name = "Launcher", Text = "", BackgroundColor3 = self.Theme.BG, BackgroundTransparency = 0.12,
		Position = UDim2.new(0, 22, 0.5, -23), Size = UDim2.fromOffset(46, 46), ZIndex = 60,
		Visible = opts.Launcher ~= false, Parent = gui,
	})
	glass(launcher, 23, true)
	self:_bindColor(launcher, "BackgroundColor3", "BG")
	local core = new("Frame", { BackgroundColor3 = WHITE, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 1, -12), Parent = launcher })
	new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = core })
	self:_bindGrad(new("UIGradient", { Rotation = 45, Parent = core }))
	label({ Text = string.upper(string.sub(self.Name, 1, 1)), Font = FONT_B, TextSize = 18, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), Parent = launcher })
	launcher.MouseEnter:Connect(function() tween(launcher, 0.3, { Size = UDim2.fromOffset(50, 50) }, BACK, OUT) end)
	launcher.MouseLeave:Connect(function() tween(launcher, 0.3, { Size = UDim2.fromOffset(46, 46) }, BACK, OUT) end)
	makeDraggable(launcher, launcher, function(c) return self:Track(c) end, function() self:Toggle() end)
	self.Launcher = launcher

	self:Track(UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if self._capture then self._capture(input.KeyCode) return end
		if UserInputService:GetFocusedTextBox() then return end
		if input.KeyCode == Enum.KeyCode.Escape and self._dd then self:_closeDropdown() return end
		if input.KeyCode == self.ToggleKey then self:Toggle() return end
		for _, kb in ipairs(self._keybinds) do
			if kb.Key == input.KeyCode and kb.Callback then fire(kb.Callback) end
		end
	end))

	self._genvUnload = function() self:Unload() end
	genv.__HazerUnload = self._genvUnload
	table.insert(Library._windows, self)

	local settings = self:_addNav("Settings", "Settings", "Appearance, controls and configuration", true)
	self._navOrder = 10000

	self:AddSection("Settings", "Appearance")
	do
		local page = settings
		local card = new("Frame", {
			Name = "AccentTheme", BackgroundColor3 = WHITE, BackgroundTransparency = 0.93,
			AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -4, 0, 0), LayoutOrder = nextOrder(page), Parent = page.Frame,
		})
		new("UIPadding", { PaddingBottom = UDim.new(0, 14), Parent = card })
		label({ Text = "Accent & Background Theme", Font = FONT_M, TextSize = 13, Position = UDim2.fromOffset(14, 9), Size = UDim2.new(1, -28, 0, 18), Parent = card })
		label({ Text = "Tints the whole menu. Saved automatically.", Font = FONT_R, TextSize = 11, TextColor3 = SUB, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 16), Parent = card })
		glass(card, 12, false)
		local grid = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 54), Size = UDim2.new(1, -28, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Parent = card })
		new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -8, 0, 38), CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid,
		})
		local made = {}
		self._addSwatch = function(pname)
			if made[pname] or not grid.Parent then return end
			made[pname] = true
			local p = Library._presets[pname]
			local sw = new("TextButton", { Text = "", BackgroundTransparency = 1, LayoutOrder = #Library._presetOrder, Parent = grid })
			local scale = new("UIScale", { Parent = sw })
			local fillF = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), Parent = sw })
			new("UICorner", { CornerRadius = UDim.new(0, 11), Parent = fillF })
			new("UIGradient", { Rotation = 25, Color = ColorSequence.new(p.A, p.B), Parent = fillF })
			local shine = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.8, Size = UDim2.new(1, 0, 0.5, 0), Parent = fillF })
			new("UICorner", { CornerRadius = UDim.new(0, 11), Parent = shine })
			new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }), Parent = shine })
			label({ Text = pname, Font = FONT_B, TextSize = 12, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 2, Parent = sw })
			local ring = new("UIStroke", { Thickness = 2, Color = WHITE, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = fillF })
			self:_bind(function(t) ring.Transparency = (t.Name == pname) and 0 or 1 end)
			sw.MouseEnter:Connect(function() tween(scale, 0.25, { Scale = 1.04 }, BACK, OUT) end)
			sw.MouseLeave:Connect(function() tween(scale, 0.3, { Scale = 1 }, BACK, OUT) end)
			sw.MouseButton1Down:Connect(function() tween(scale, 0.1, { Scale = 0.95 }) end)
			sw.MouseButton1Up:Connect(function() tween(scale, 0.35, { Scale = 1.04 }, BACK, OUT) end)
			sw.MouseButton1Click:Connect(function() self:SetAccent(pname) end)
		end
		for _, pname in ipairs(Library._presetOrder) do self._addSwatch(pname) end
	end

	self:AddSection("Settings", "Controls")
	self:AddKeybind("Menu Keybind", "Key used to open or close the menu", "Settings", self.ToggleKey, nil, function(k)
		self.ToggleKey = k
		self:_save()
	end)
	self:AddToggle("Launcher Button", "Show the floating button that opens the menu", "Settings", function(on)
		launcher.Visible = on
	end, opts.Launcher ~= false)

	self:AddSection("Settings", "Configuration")
	self:AddLabel(Storage.supported()
		and "Only the theme and the menu keybind are stored, in HazerUI/settings.txt."
		or "File saving is not available in this executor, so settings will not persist.", "Settings")
	self:AddButton("Reset UI Settings", "Restore the default theme and menu keybind", "Settings", function()
		self:SetAccent(defaultAccent, true)
		local kb = self.Elements["Menu Keybind"]
		if kb then kb.Set(defaultKey) end
		self:_save()
		self:Notify("Settings", "Theme and keybind reset to defaults.", 3)
	end)
	self:AddButton("Unload " .. self.Name, "Remove the menu and stop all of its connections", "Settings", function()
		self:Unload()
	end)

	self._built = true

	task.defer(function()
		if self._unloaded then return end
		if not self.Current then self:Select("Settings") end
	end)

	task.spawn(function()
		if opts.Splash ~= false then
			local sp = new("Frame", {
				BackgroundColor3 = self.Theme.BG, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(240, 120), ZIndex = 200, Parent = gui,
			})
			local sc = new("UIScale", { Scale = 0.85, Parent = sp })
			glass(sp, 22, true)
			local t = label({ Text = self.Name, Font = FONT_B, TextSize = 28, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 36), Parent = sp })
			new("UIGradient", { Color = ColorSequence.new(self.Theme.A, self.Theme.B), Parent = t })
			label({ Text = self.Subtitle, Font = FONT_R, TextSize = 12, TextColor3 = SUB, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 16), Parent = sp })
			local barBG = new("Frame", { BackgroundColor3 = WHITE, BackgroundTransparency = 0.88, Position = UDim2.new(0.5, -60, 1, -24), Size = UDim2.fromOffset(120, 4), Parent = sp })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barBG })
			local barF = new("Frame", { BackgroundColor3 = WHITE, Size = UDim2.fromScale(0, 1), Parent = barBG })
			new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = barF })
			new("UIGradient", { Color = ColorSequence.new(self.Theme.A, self.Theme.B), Parent = barF })
			tween(sc, 0.5, { Scale = 1 }, BACK, OUT)
			tween(barF, 1.0, { Size = UDim2.fromScale(1, 1) }, QUART, OUT)
			task.wait(1.15)
			if self._unloaded then return end
			tween(sc, 0.35, { Scale = 1.08 }, QUART, IN)
			tween(sp, 0.35, { BackgroundTransparency = 1 })
			task.wait(0.3)
			sp:Destroy()
		end
		if self._unloaded then return end
		self:Open()
		if opts.Welcome ~= false then
			local msg = type(opts.Welcome) == "string" and opts.Welcome
				or ("Press " .. self.ToggleKey.Name .. " to open or close the menu.")
			self:Notify(self.Name, msg, 4)
		end
	end)

	return self
end

return Library
