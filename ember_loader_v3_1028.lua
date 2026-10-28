--[[
	EMBER LOADER (standalone)
	Shows the loading screen, downloads + compiles the main AichGpt script
	while it loads, then runs the main script after the screen fades out.

	Host THIS file on GitHub and loadstring this one instead of the main script.
]]

local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

----------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------
local CONFIG = {
	-- main script that runs AFTER the loader finishes
	ScriptUrl = "https://raw.githubusercontent.com/joyaich5522-design/Aich-gpt-v6/refs/heads/main/aichgpt_v6-protected.lua.txt",

	Name = "EMBER",
	Tagline = "AichGpt  ·  executor agent",
	Footer = "v1.0",
	Accent = Color3.fromRGB(255, 106, 43),
	AccentSoft = Color3.fromRGB(255, 178, 110),
	Background = Color3.fromRGB(9, 9, 11),
	Track = Color3.fromRGB(28, 28, 34),
	Muted = Color3.fromRGB(116, 116, 128),
	Text = Color3.fromRGB(196, 196, 206),
	Warn = Color3.fromRGB(255, 140, 120),
	MinStepTime = 0.4, -- every step stays on screen at least this long
}

----------------------------------------------------------------
-- ENV HELPERS
----------------------------------------------------------------
local env = (getgenv and getgenv()) or _G

local function exists(name)
	return type(env[name]) == "function"
end

local function getParent()
	local ok, ui = pcall(function()
		return gethui and gethui()
	end)
	if ok and ui then
		return ui
	end
	ok, ui = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok and ui then
		return ui
	end
	return Players.LocalPlayer:WaitForChild("PlayerGui")
end

-- tries game:HttpGet first, then the executor's request function
local function httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	local req = env.request or env.http_request or (type(env.syn) == "table" and env.syn.request)
	if type(req) == "function" then
		local ok2, res = pcall(req, { Url = url, Method = "GET" })
		if ok2 and type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
			return res.Body
		end
	end
	return nil
end

----------------------------------------------------------------
-- STEPS  (return ok, note)
----------------------------------------------------------------
local source -- downloaded main script text
local mainFn -- compiled main script

local STEPS = {
	{
		label = "Checking executor",
		run = function()
			if exists("identifyexecutor") then
				local ok, name = pcall(identifyexecutor)
				if ok and name then
					return true, tostring(name)
				end
			end
			return false, "Unknown executor"
		end,
	},
	{
		label = "Checking environment",
		run = function()
			if exists("getgenv") and exists("loadstring") then
				return true, "Environment OK"
			end
			return false, "Limited environment"
		end,
	},
	{
		label = "Checking HTTP",
		run = function()
			local hasReq = exists("request") or exists("http_request")
				or (type(env.syn) == "table" and type(env.syn.request) == "function")
			if hasReq then
				return true, "HTTP OK"
			end
			return false, "No HTTP, AI chat will not work"
		end,
	},
	{
		label = "Checking file system",
		run = function()
			if exists("writefile") and exists("readfile") and exists("isfile") then
				return true, "Files OK"
			end
			return false, "No file access, settings will not save"
		end,
	},
	{
		label = "Downloading AichGpt",
		run = function()
			source = httpGet(CONFIG.ScriptUrl)
			if not source then
				warn("[Ember Loader] download failed: " .. CONFIG.ScriptUrl)
				return false, "Download failed"
			end
			-- GitHub answers a wrong link with a text page starting with 404
			if source:sub(1, 3) == "404" or source:sub(1, 3) == "400" then
				warn("[Ember Loader] bad link (GitHub returned: " .. source:sub(1, 40) .. ")")
				source = nil
				return false, "Bad link (404)"
			end
			return true, "Download complete"
		end,
	},
	{
		label = "Compiling AichGpt",
		run = function()
			if not source then
				return false, "Nothing to compile"
			end
			if type(loadstring) ~= "function" then
				return false, "No loadstring support"
			end
			local fn, err = loadstring(source)
			if not fn then
				warn("[Ember Loader] compile error: " .. tostring(err))
				return false, "Compile error, check console"
			end
			mainFn = fn
			return true, "Ready to launch"
		end,
	},
}

----------------------------------------------------------------
-- UI HELPERS
----------------------------------------------------------------
local function new(class, props, parent)
	local obj = Instance.new(class)
	for k, v in pairs(props or {}) do
		obj[k] = v
	end
	obj.Parent = parent
	return obj
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(
		obj,
		TweenInfo.new(t, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out),
		props
	)
	tw:Play()
	return tw
end

----------------------------------------------------------------
-- BUILD
----------------------------------------------------------------
local parent = getParent()
local old = parent:FindFirstChild("EmberLoader")
if old then
	old:Destroy()
end

local gui = new("ScreenGui", {
	Name = "EmberLoader",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 999999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})
pcall(function()
	if env.syn and env.syn.protect_gui then
		env.syn.protect_gui(gui)
	end
end)
local okParent = pcall(function()
	gui.Parent = parent
end)
if not okParent then
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
end

local root = new("CanvasGroup", {
	Name = "Root",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = CONFIG.Background,
	BorderSizePixel = 0,
	GroupTransparency = 1,
}, gui)

-- soft ember glow (two layered circles)
local function circle(size, transparency)
	local c = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = CONFIG.Accent,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
	}, root)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, c)
	return c
end

local glowOuter = circle(500, 0.975)
local glowInner = circle(250, 0.94)

TweenService:Create(
	glowInner,
	TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Size = UDim2.fromOffset(310, 310) }
):Play()
TweenService:Create(
	glowOuter,
	TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
	{ Size = UDim2.fromOffset(580, 580) }
):Play()

-- centered holder
local holder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(320, 120),
	BackgroundTransparency = 1,
}, root)

local uiScale = new("UIScale", {}, holder)
local cam = workspace.CurrentCamera
local function rescale()
	local v = cam and cam.ViewportSize or Vector2.new(800, 600)
	uiScale.Scale = math.clamp(math.min(v.X, v.Y) / 520, 0.85, 1.5)
end
rescale()
if cam then
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
end

-- wordmark
local row = new("Frame", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundTransparency = 1,
}, holder)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 9),
}, row)

local letters = {}
for i = 1, #CONFIG.Name do
	local slot = new("Frame", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = i,
	}, row)
	local lbl = new("TextLabel", {
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0),
		Position = UDim2.fromOffset(0, 14),
		Text = CONFIG.Name:sub(i, i),
		Font = Enum.Font.GothamBold,
		TextSize = 36,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 1,
	}, slot)
	letters[i] = lbl
end

-- tagline
local tagline = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 52),
	Size = UDim2.new(1, 0, 0, 14),
	BackgroundTransparency = 1,
	Text = CONFIG.Tagline,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextColor3 = CONFIG.Muted,
	TextTransparency = 1,
}, holder)

-- progress bar
local track = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 88),
	Size = UDim2.fromOffset(240, 2),
	BackgroundColor3 = CONFIG.Track,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, holder)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)

local fill = new("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, track)
new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
local shimmer = new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, CONFIG.Accent),
		ColorSequenceKeypoint.new(0.5, CONFIG.AccentSoft),
		ColorSequenceKeypoint.new(1, CONFIG.Accent),
	}),
	Offset = Vector2.new(-1, 0),
}, fill)
TweenService:Create(
	shimmer,
	TweenInfo.new(1.4, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1),
	{ Offset = Vector2.new(1, 0) }
):Play()

-- status + percent
local info = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 98),
	Size = UDim2.fromOffset(240, 16),
	BackgroundTransparency = 1,
}, holder)

local status = new("TextLabel", {
	Size = UDim2.new(0.8, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "",
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextColor3 = CONFIG.Muted,
	TextTransparency = 1,
}, info)

local pct = new("TextLabel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.fromScale(1, 0),
	Size = UDim2.new(0.2, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "0%",
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = CONFIG.Muted,
	TextTransparency = 1,
}, info)

-- footer
local footer = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -22),
	Size = UDim2.fromOffset(200, 14),
	BackgroundTransparency = 1,
	Text = CONFIG.Footer,
	Font = Enum.Font.Gotham,
	TextSize = 10,
	TextColor3 = CONFIG.Muted,
	TextTransparency = 1,
}, root)

----------------------------------------------------------------
-- PROGRESS (smoothed)
----------------------------------------------------------------
local shown, target = 0, 0
local conn = RunService.Heartbeat:Connect(function(dt)
	shown = shown + (target - shown) * math.min(1, dt * 6)
	fill.Size = UDim2.fromScale(math.clamp(shown, 0, 1), 1)
	pct.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
end)

local function setStatus(text, color)
	status.Text = text
	status.TextColor3 = color or CONFIG.Muted
	status.TextTransparency = 0.75
	tween(status, 0.3, { TextTransparency = 0 })
end

----------------------------------------------------------------
-- INTRO
----------------------------------------------------------------
tween(root, 0.5, { GroupTransparency = 0 }, Enum.EasingStyle.Sine)
task.wait(0.35)

for i, lbl in ipairs(letters) do
	task.delay(0.08 * i, function()
		tween(lbl, 0.6, { Position = UDim2.fromOffset(0, 0), TextTransparency = 0 })
	end)
end

local introEnd = 0.08 * #letters + 0.3
task.delay(introEnd, function()
	tween(tagline, 0.6, { TextTransparency = 0.25 })
	tween(track, 0.5, { BackgroundTransparency = 0 })
	tween(fill, 0.5, { BackgroundTransparency = 0 })
	tween(pct, 0.5, { TextTransparency = 0 })
	tween(footer, 0.8, { TextTransparency = 0.45 })
end)
task.wait(introEnd + 0.4)

----------------------------------------------------------------
-- RUN STEPS
----------------------------------------------------------------
for i, step in ipairs(STEPS) do
	setStatus(step.label .. "...")
	local t0 = os.clock()
	local ok, result, note = pcall(step.run)
	local passed = ok and result ~= false
	local message = ok and note or nil
	if ok and result ~= false and type(result) == "string" then
		message = result
	end
	if not ok then
		message = "Step failed"
	end

	local elapsed = os.clock() - t0
	if elapsed < CONFIG.MinStepTime then
		task.wait(CONFIG.MinStepTime - elapsed)
	end

	target = i / #STEPS
	if message then
		setStatus(message, passed and CONFIG.Text or CONFIG.Warn)
		task.wait(0.25)
	end
end

----------------------------------------------------------------
-- FINISH
----------------------------------------------------------------
target = 1
while shown < 0.995 do
	task.wait()
end
shown = 1

if mainFn then
	setStatus("Launching", CONFIG.Text)
	for i, lbl in ipairs(letters) do
		task.delay(0.07 * i, function()
			tween(lbl, 0.35, { TextColor3 = CONFIG.Accent })
		end)
	end
	tween(glowInner, 0.8, { BackgroundTransparency = 0.86 })
	tween(glowOuter, 0.8, { BackgroundTransparency = 0.94 })
	task.wait(0.07 * #letters + 0.7)
else
	setStatus("Could not load AichGpt", CONFIG.Warn)
	task.wait(2.2)
end

tween(root, 0.7, { GroupTransparency = 1 }, Enum.EasingStyle.Sine).Completed:Wait()
conn:Disconnect()
gui:Destroy()

----------------------------------------------------------------
-- RUN MAIN SCRIPT (after the loader is gone)
----------------------------------------------------------------
if mainFn then
	task.spawn(function()
		local ok, err = pcall(mainFn)
		if not ok then
			warn("[Ember Loader] AichGpt error: " .. tostring(err))
		end
	end)
end
