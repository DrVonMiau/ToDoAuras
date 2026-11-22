-- Settings page (Options → AddOns → ToDoAuras, or /tda): what to track on
-- this character, warning time, size and position.
local ADDON, ns = ...

local panel = CreateFrame("Frame")
panel.name = "ToDoAuras"
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

local built
local function Build()
	if built then return end
	built = true

	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("ToDoAuras")

	local intro = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	intro:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
	intro:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
	intro:SetJustifyH("LEFT")
	intro:SetText("Shows a row only when something runs out within the warning time, or has run out. "
		.. "The list builds from the bottom up. Ticked items are saved per character.")

	local className = UnitClass("player") or "This class"
	local head = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	head:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
	head:SetText(className .. ": track")

	local last = head
	panel.boxes = {}
	if #ns.trackers == 0 then
		local none = panel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
		none:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -8)
		none:SetText("Nothing to track for this class yet.")
		last = none
	end
	for i, t in ipairs(ns.trackers) do
		local cb = Checkbox(panel, t.title, function(v) ns.SetTracked(t.key, v) end)
		cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", i == 1 and -4 or 0, i == 1 and -6 or 0)
		cb.tracker = t
		panel.boxes[#panel.boxes + 1] = cb
		if t.threshold then
			-- "[-] 5 [+]" next to stack trackers: how many stacks count as ready
			local minus = Button(panel, "-", 22, function() ns.SetThreshold(t.key, ns.Threshold(t) - 1); panel.Refresh() end)
			minus:SetPoint("LEFT", cb.label, "RIGHT", 12, 0)
			local val = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
			val:SetWidth(28)
			val:SetPoint("LEFT", minus, "RIGHT", 2, 0)
			local plus = Button(panel, "+", 22, function() ns.SetThreshold(t.key, ns.Threshold(t) + 1); panel.Refresh() end)
			plus:SetPoint("LEFT", val, "RIGHT", 2, 0)
			cb.stackValue = val
		end
		last = cb
	end

	local warn = Stepper(panel, "Warn when less than", function(d) ns.SetWindow(ns.db.window + d); panel.Refresh() end)
	warn:SetPoint("TOPLEFT", last, "BOTTOMLEFT", #ns.trackers > 0 and 4 or 0, -20)
	panel.warn = warn

	local size = Stepper(panel, "List size", function(d) ns.SetScale((ns.db.scale or 1) + d * 0.1); panel.Refresh() end)
	size:SetPoint("TOPLEFT", warn, "BOTTOMLEFT", 0, -16)
	panel.size = size

	local move = Button(panel, "Move list", 120, function() ns.SetUnlocked(not ns.testMode) end)
	move:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -20)
	panel.move = move

	local reset = Button(panel, "Reset position", 120, function() ns.ResetPosition(); panel.Refresh() end)
	reset:SetPoint("LEFT", move, "RIGHT", 8, 0)

	local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hint:SetPoint("TOPLEFT", move, "BOTTOMLEFT", 0, -10)
	hint:SetText("Move list shows sample rows on a blue bar: drag it, then click Lock list.")
end

function panel.Refresh()
	if not built then return end
	for _, cb in ipairs(panel.boxes) do
		cb:SetChecked(ns.Enabled(cb.tracker))
		if cb.stackValue then cb.stackValue:SetText(ns.Threshold(cb.tracker)) end
	end
	panel.warn.value:SetText(ns.db.window .. " s")
	panel.size.value:SetText(string.format("%.1f", ns.db.scale or 1))
	panel.move:SetText(ns.testMode and "Lock list" or "Move list")
end
ns.RefreshPanel = panel.Refresh

panel:SetScript("OnShow", function() Build(); panel.Refresh() end)

function ns.CreatePanel()
	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(panel, "ToDoAuras")
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

function ns.OpenSettings()
	if category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(category.GetID and category:GetID() or category.ID)
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end
