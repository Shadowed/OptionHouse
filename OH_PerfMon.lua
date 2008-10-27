local frame
local scriptProfiling
local TOTAL_ROWS = 15
local CREATED_ROWS = 0

local L = {
	["MEMORY"] = "Memory",
	["MEMSEC"] = "Mem/Sec",
	["CPU"] = "CPU",
	["CPUSEC"] = "CPU/Sec",
	["ENABLE_CPU"] = "Enable CPU",
	["DISABLE_CPU"] = "Disable CPU",
	["RELOAD_UI"] = "Reload UI",
	["ADDON_PERFORMANCE"] = "Performance",
	["NAME"] = "Name",
}

local function sortPerformanceList(a, b)
	if( not b ) then
		return false
	end

	if( frame.sortOrder ) then
		if( frame.sortType == "name" ) then
			return ( string.lower(a.title) < string.lower(b.title) )
		elseif( frame.sortType == "memory" ) then
			return ( a.memory < b.memory )
		elseif( frame.sortType == "cpu" ) then
			return ( a.cpu < b.cpu )
		elseif( frame.sortType == "mir" ) then
			-- If mir is 0 for both, sort by name
			-- this prevents everything from moving around randomly
			-- and generally just looking ugly
			if( a.mir == 0 and b.mir == 0 ) then
				return ( string.lower(a.title) < string.lower(b.title) )
			end

			return ( a.mir < b.mir )

		elseif( frame.sortType == "cir" ) then
			if( a.cir == 0 and b.cir == 0 ) then
				return ( string.lower(a.title) < string.lower(b.title) )
			end

			return ( a.cir < b.cir )
		end

		return ( a.memory < b.memory )

	else
		if( frame.sortType == "name" ) then
			return ( string.lower(a.title) > string.lower(b.title) )
		elseif( frame.sortType == "memory" ) then
			return ( a.memory > b.memory )
		elseif( frame.sortType == "cpu" ) then
			return ( a.cpu > b.cpu )
		elseif( frame.sortType == "mir" ) then
			if( a.mir == 0 and b.mir == 0 ) then
				return ( string.lower(a.title) > string.lower(b.title) )
			end

			return ( a.mir > b.mir )

		elseif( frame.sortType == "cir" ) then
			if( a.cir == 0 and b.cir == 0 ) then
				return ( string.lower(a.title) > string.lower(b.title) )
			end

			return ( a.cir > b.cir )
		end

		return ( a.memory > b.memory )
	end
end

local function updateAddonPerformance()
	UpdateAddOnMemoryUsage()
	UpdateAddOnCPUUsage()

	local totalMemory = 0
	local totalCPU = 0
	local totalMIR = 0
	local totalCIR = 0

	for id, addon in pairs(frame.addons) do
		memory = GetAddOnMemoryUsage(addon.name)
		cpu = GetAddOnCPUUsage(addon.name)

		frame.addons[id].mir = memory - addon.memory
		frame.addons[id].cir = cpu - addon.cpu
		frame.addons[id].memory = memory
		frame.addons[id].cpu = cpu

		totalMemory = totalMemory + memory
		totalCPU = totalCPU + cpu
		totalMIR = totalMIR + frame.addons[id].mir
		totalCIR = totalCIR + frame.addons[id].cir
	end

	for id, addon in pairs(frame.addons) do
		frame.addons[id].cpuPerct = frame.addons[id].cpu / totalCPU * 100
		frame.addons[id].memPerct = frame.addons[id].memory / totalMemory * 100
	end

	frame.totalMemory = totalMemory
	frame.totalCPU = totalCPU
	frame.totalMIR = totalMIR
	frame.totalCIR = totalCIR
end

local function updatePerformanceList(skipShown)
	if( not skipShown and not frame:IsShown() ) then
		return
	end

	if( frame.totalMemory > 1024 ) then
		frame.sortButtons[2]:SetFormattedText("%s (%.1f %s)", L["MEMORY"], frame.totalMemory / 1024, "MiB")
	else
		frame.sortButtons[2]:SetFormattedText("%s (%.1f %s)", L["MEMORY"], frame.totalMemory, "KiB")
	end

	if( frame.totalMIR > 1024 ) then
		frame.sortButtons[3]:SetFormattedText("%s (%.2f %s)", L["MEMSEC"], frame.totalMIR / 1024, "MiB/s")
	else
		frame.sortButtons[3]:SetFormattedText("%s (%.2f %s)", L["MEMSEC"], frame.totalMIR, "KiB/s")
	end

	if( scriptProfiling ) then
		frame.sortButtons[4]:SetFormattedText("%s (%.2f)", L["CPU"], frame.totalCPU)
		frame.sortButtons[4]:SetWidth(frame.sortButtons[4]:GetFontString():GetStringWidth() + 3)

		frame.sortButtons[5]:SetFormattedText("%s (%.2f)", L["CPUSEC"], frame.totalCIR)
		frame.sortButtons[5]:SetWidth(frame.sortButtons[5]:GetFontString():GetStringWidth() + 3)
	end

	frame.sortButtons[2]:SetWidth(frame.sortButtons[2]:GetFontString():GetStringWidth() + 3)
	frame.sortButtons[3]:SetWidth(frame.sortButtons[3]:GetFontString():GetStringWidth() + 3)

	table.sort(frame.addons, sortPerformanceList)
	OptionHouse:UpdateScroll(frame.scroll, #(frame.addons))

	for i=1, TOTAL_ROWS do
		local addon = frame.addons[frame.scroll.offset + i]
		local row = frame.rows[i]

		if( addon ) then
			row[1]:SetText(addon.title)

			if( addon.memory > 1024 ) then
				row[2]:SetFormattedText("%.3f MiB (%.2f%%)", addon.memory / 1024, addon.memPerct)
			else
				row[2]:SetFormattedText("%.3f KiB (%.2f%%)", addon.memory, addon.memPerct)
			end

			if( addon.mir > 1024 ) then
				row[3]:SetFormattedText("%.3f MiB/s", addon.mir / 1024)
			else
				row[3]:SetFormattedText("%.3f KiB/s", addon.mir)
			end

			if( scriptProfiling ) then
				row[4]:SetFormattedText("%.3f (%.2f%%)", addon.cpu, addon.cpuPerct)
				row[5]:SetFormattedText("%.3f", addon.cir)
			else
				row[4]:SetText("----")
				row[5]:SetText("----")
			end

			row[1]:Show()
			row[2]:Show()
			row[3]:Show()
			row[4]:Show()
			row[5]:Show()
		else
			row[1]:Hide()
			row[2]:Hide()
			row[3]:Hide()
			row[4]:Hide()
			row[5]:Hide()
		end
	end
end

local elapsed = 0
local function performanceOnUpdate(self, time)
	elapsed = elapsed + time

	if( elapsed >= 0.5 ) then
		elapsed = 0

		updateAddonPerformance()
		updatePerformanceList()
	end
end

local function sortPerfClick(self)
	if( self.sortType ) then
		if( self.sortType ~= frame.sortType ) then
			frame.sortOrder = false
			frame.sortType = self.sortType
		else
			frame.sortOrder = not frame.sortOrder
		end

		updatePerformanceList()
	end
end

-- Create a list now so we aren't creating a new table/list every OnUpdate
local function updateAddonPerfList()
	UpdateAddOnMemoryUsage()
	UpdateAddOnCPUUsage()

	local searchBy = string.trim(string.lower(frame.search:GetText()))
	if( searchBy == "" or frame.search.searchText ) then
		searchBy = nil
	end
	frame.addons = {}
	for i=1, GetNumAddOns() do
		local name, title = GetAddOnInfo(i)
		if( IsAddOnLoaded(i) and ((searchBy and string.find(string.lower(name), searchBy)) or not searchBy ) ) then
			table.insert(frame.addons, {name = name, title = string.gsub(title, "%|cff7fff7f %-(.+)%-%|r", ""), mir = 0, cir = 0, cpu = GetAddOnCPUUsage(i), memory = GetAddOnMemoryUsage(i)})
		end
	end
end


local function createRows()
	local path, size, border = GameFontNormalSmall:GetFont()
	size = OptionHouseDB.perfFontSize

	if( not frame.testFS ) then
		frame.testFS = frame:CreateFontString()
	end

	frame.testFS:SetFont(path, size, border)
	frame.testFS:SetText("*")

	local spacing = -10 - frame.testFS:GetHeight()
	TOTAL_ROWS = floor(305 / abs(spacing))

	if( not frame.rows ) then
		frame.rows = {}
	end

	for i=1, TOTAL_ROWS do
		if( not frame.rows[i] ) then
			frame.rows[i] = {}
			CREATED_ROWS = CREATED_ROWS + 1
		end

		for j=1, 5 do
			if( not frame.rows[i][j] ) then
				text = frame:CreateFontString(nil, frame)
			else
				text = frame.rows[i][j]
			end

			text:SetFont(path, size, border)
			text:SetTextColor(1, 1, 1)
			text:Hide()
			frame.rows[i][j] = text

			if( i > 1 ) then
				text:SetPoint("TOPLEFT", frame.rows[i-1][j], "TOPLEFT", 0, spacing)
			else
				text:SetPoint("TOPLEFT", frame.sortButtons[j], "TOPLEFT", 2, -28)
			end
		end
	end
end

local function createPerfFrame(hide)
	frame = OptionHouse:GetFrame("perf")
	if( frame and hide ) then
		frame:Hide()
		return
	elseif( hide ) then
		return
	elseif( not frame ) then
		frame = CreateFrame("Frame", nil, OptionHouse:GetFrame("main"))
		frame:SetFrameStrata("DIALOG")
		frame:SetAllPoints(OptionHouse:GetFrame("main"))
		frame.sortOrder = nil
		frame.sortType = "name"
		frame.sortButtons = {}
		frame:Hide()

		local toggleCPU = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		toggleCPU:SetWidth(80)
		toggleCPU:SetHeight(22)
		toggleCPU:SetPoint("BOTTOMRIGHT", OptionHouse:GetFrame("main"), "BOTTOMRIGHT", -8, 14)
		toggleCPU:SetScript("OnClick", function(self)
			if( GetCVar("scriptProfile") == "1" ) then
				self:SetText(L["ENABLE_CPU"])
				SetCVar("scriptProfile", "0", 1)
			else
				self:SetText(L["DISABLE_CPU"])
				SetCVar("scriptProfile", "1", 1)
			end
		end)

		-- UI Reload required for CPU profiling to be usable, so check on load
		if( GetCVar("scriptProfile") == "1" ) then
			scriptProfiling = true
			toggleCPU:SetText(L["DISABLE_CPU"])
		else
			toggleCPU:SetText(L["ENABLE_CPU"])
		end

		local reloadUI = CreateFrame("Button", nil, frame, "UIPanelButtonGrayTemplate")
		reloadUI:SetWidth(80)
		reloadUI:SetHeight(22)
		reloadUI:SetPoint("RIGHT", toggleCPU, "LEFT")
		reloadUI:SetText(L["RELOAD_UI"])
		reloadUI:SetScript("OnClick", ReloadUI)

		local button = CreateFrame("Button", nil, frame)
		button.sortType = "name"
		button:SetScript("OnClick", sortPerfClick)
		button:SetNormalFontObject(GameFontNormal)
		button:SetText(L["NAME"])
		button:SetHeight(18)
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -75)
		button:Show()

		frame.sortButtons[1] = button

		local button = CreateFrame("Button", nil, frame)
		button.sortType = "memory"
		button:SetScript("OnClick", sortPerfClick)
		button:SetNormalFontObject(GameFontNormal)
		button:SetText(L["MEMORY"])
		button:SetHeight(18)
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame.sortButtons[1], "TOPLEFT", 180, 0)
		button:Show()

		frame.sortButtons[2] = button

		local button = CreateFrame("Button", nil, frame)
		button.sortType = "mir"
		button:SetScript("OnClick", sortPerfClick)
		button:SetNormalFontObject(GameFontNormal)
		button:SetText(L["MEMSEC"])
		button:SetHeight(18)
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame.sortButtons[2], "TOPLEFT", 180, 0)
		button:Show()

		frame.sortButtons[3] = button

		local button = CreateFrame("Button", nil, frame)
		button.sortType = "cpu"
		button:SetScript("OnClick", sortPerfClick)
		button:SetNormalFontObject(GameFontNormal)
		button:SetText(L["CPU"])
		button:SetHeight(18)
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame.sortButtons[3], "TOPLEFT", 170, 0)
		button:Show()

		frame.sortButtons[4] = button

		local button = CreateFrame("Button", nil, frame)
		button.sortType = "cir"
		button:SetScript("OnClick", sortPerfClick)
		button:SetNormalFontObject(GameFontNormal)
		button:SetText(L["CPUSEC"])
		button:SetHeight(18)
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame.sortButtons[4], "TOPLEFT", 130, 0)
		button:Show()

		frame.sortButtons[5] = button

		-- Create all of the rows for display
		createRows()

		OptionHouse:CreateScrollFrame(frame, TOTAL_ROWS, updatePerformanceList)

		frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -76)
		frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 72)

		frame:SetScript("OnUpdate", performanceOnUpdate)
		frame:SetScript("OnEvent", updatePerformanceList)
		frame:RegisterEvent("ADDON_LOADED")

		OptionHouse:CreateSearchInput(frame, function()
			updateAddonPerfList()
			updateAddonPerformance()
			updatePerformanceList()
		end)

		OptionHouse:RegisterFrame("perf", frame)
	end

	updateAddonPerfList()
	updateAddonPerformance()
	updatePerformanceList(true)

	frame:Show()
end

-- Load it into OH
OptionHouse:RegisterTab(L["ADDON_PERFORMANCE"], createPerfFrame, "bid")

--[[
function OHPerformance:Reload()
	if( frame ) then
		createRows()

		frame.scroll.displayNum = TOTAL_ROWS
		frame.scroll.bar:SetValueStep(TOTAL_ROWS)
		
		updatePerformanceList()
	end
end
]]
