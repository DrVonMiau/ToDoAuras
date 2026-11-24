-- Settings window (/tda): what to track on this character, stack counts,
-- warning time, list size and position. Options → AddOns → ToDoAuras has a
-- button that opens the same window.
local ADDON, ns = ...

local win, built
local category

local function Checkbox(parent, label, onClick)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	local fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	fs:SetText(label)
	cb.label = fs
	cb:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
	return cb
end

local function Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width, 22)
	b:SetText(text)
	b:SetScript("OnClick", onClick)
	return b
end

-- "label  [-] value [+]"
local function Stepper(parent, label, onStep)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	fs:SetText(label)
	local minus = Button(parent, "-", 24, function() onStep(-1) end)
	minus:SetPoint("LEFT", fs, "RIGHT", 10, 0)
	local value = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	value:SetWidth(44)
	value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	local plus = Button(parent, "+", 24, function() onStep(1) end)
	plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
	fs.value = value
	return fs
end

local function Section(parent, text, anchor, y)
	local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fs:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, y)
	fs:SetText(text)
	return fs
end

local Refresh

local function Build()
	if built then return end
	built = true

	win = CreateFrame("Frame", "ToDoAurasSettings", UIParent, "BackdropTemplate")
	win:SetSize(420, 200)
	win:SetPoint("CENTER")
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetClampedToScreen(true)
	win:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	win:EnableMouse(true)
	win:SetMovable(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	win:Hide()
	tinsert(UISpecialFrames, "ToDoAurasSettings") -- Escape closes it

	local close = CreateFrame("Button", nil, win, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	local title = win:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -20)
	title:SetText("ToDoAuras")

	local intro = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	intro:SetPoint("TOPLEFT", 26, -48)
	intro:SetPoint("RIGHT", win, "RIGHT", -26, 0)
	intro:SetJustifyH("LEFT")
	intro:SetText("Rows appear only when something runs out soon, has run out, or a proc is ready. "
		.. "Ticks are saved per character.")

	local className = UnitClass("player") or "This class"
	local head = Section(win, className .. ": track", intro, -14)

	local last = head
	win.boxes = {}
	win.stackValues = {}
	if #ns.trackers == 0 then
		local none = win:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		none:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
		none:SetText("Nothing to track for this class yet.")
		last = none
	end
	for i, t in ipairs(ns.trackers) do
		local cb = Checkbox(win, t.title, function(v) ns.SetTracked(t.key, v) end)
		cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", i == 1 and -4 or 0, i == 1 and -6 or 0)
		cb.tracker = t
		win.boxes[#win.boxes + 1] = cb
		if t.threshold then
			-- "[-] 5 [+]": how many stacks count as ready
			local minus = Button(win, "-", 22, function() ns.SetThreshold(t.key, ns.Threshold(t) - 1); Refresh() end)
			minus:SetPoint("LEFT", cb.label, "RIGHT", 12, 0)
			local val = win:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			val:SetWidth(28)
			val:SetPoint("LEFT", minus, "RIGHT", 2, 0)
			local plus = Button(win, "+", 22, function() ns.SetThreshold(t.key, ns.Threshold(t) + 1); Refresh() end)
			plus:SetPoint("LEFT", val, "RIGHT", 2, 0)
			win.stackValues[cb] = val
		end
		last = cb
	end

	local disp = Section(win, "Display", last, -16)
	if #ns.trackers > 0 then disp:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -16) end

	local warn = Stepper(win, "Warn when less than", function(d) ns.SetWindow(ns.db.window + d); Refresh() end)
	warn:SetPoint("TOPLEFT", disp, "BOTTOMLEFT", 0, -12)
	win.warn = warn

	local size = Stepper(win, "List size", function(d) ns.SetScale((ns.db.scale or 1) + d * 0.1); Refresh() end)
	size:SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 0, -14)
	win.size = size

	local move = Button(win, "Move list", 120, function() ns.SetUnlocked(not ns.testMode) end)
	move:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -16)
	win.move = move

	local reset = Button(win, "Reset position", 120, function() ns.ResetPosition(); Refresh() end)
	reset:SetPoint("LEFT", move, "RIGHT", 8, 0)

	local hint = win:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", move, "BOTTOMLEFT", 0, -8)
	hint:SetText("Move list shows sample rows on a blue bar: drag it, then click Lock list.")

	-- size the window to its contents
	local rowsHeight = math.max(1, #ns.trackers) * 24
	win:SetHeight(250 + rowsHeight)
	win:SetScript("OnHide", function() if ns.testMode then ns.SetUnlocked(false) end end)
end

function Refresh()
	if not built then return end
	for _, cb in ipairs(win.boxes) do
		cb:SetChecked(ns.Enabled(cb.tracker))
		local val = win.stackValues[cb]
		if val then val:SetText(ns.Threshold(cb.tracker)) end
	end
	win.warn.value:SetText(ns.db.window .. " s")
	win.size.value:SetText(string.format("%.1f", ns.db.scale or 1))
	win.move:SetText(ns.testMode and "Lock list" or "Move list")
end
ns.RefreshPanel = Refresh

function ns.OpenSettings()
	Build()
	if win:IsShown() then win:Hide() else Refresh(); win:Show() end
end

-- Options → AddOns → ToDoAuras: a short page with a button to the window.
function ns.CreatePanel()
	local panel = CreateFrame("Frame")
	panel.name = "ToDoAuras"
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("ToDoAuras")
	local text = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
	text:SetText("All settings are in the ToDoAuras window (also: type /tda).")
	local open = Button(panel, "Open ToDoAuras settings", 200, function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
		Build(); Refresh(); win:Show()
	end)
	open:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(panel, "ToDoAuras")
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end
