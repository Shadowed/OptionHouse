local OHManage = {}

local frame
local TOTAL_ROWS = 14
local CREATED_ROWS = 0

local STATUS_COLORS = {
	["DISABLED"] = "|cff9d9d9d",
	["NOT_DEMAND_LOADED"] = "|cffff8000",
	["DEP_NOT_DEMAND_LOADED"] = "|cffff8000",
	["LOAD_ON_DEMAND"] = "|cff1eff00",
	["DISABLED_AT_RELOAD"] = "|cffa335ee",
	["INCOMPATIBLE"] = "|cffff2020",
}

local L = {
	["LOAD"] = "Load",
	["RELOAD_UI"] = "Reload UI",
	["ENABLE_ALL"] = "Enable All",
	["DISABLE_ALL"] = "Disable All",
	["AUTHOR"] = "Author: %s",
	["VERSION"] = "Version: %s",
	["DISABLED_AT_RELOAD"] = "Disabled on UI Reload",
	["ENABLED_AT_RELOAD"] = "Enabled on UI Reload",
	["LOD_LOADED"] = "Is Loadable on Demand but already loaded",
	["LOAD_ON_DEMAND"] = "Loadable on Demand",
	["ADDON_MANAGEMENT"] = "Management",
	["LOADED"] = "Loaded",
	["NAME"] = "Name",
	["STATUS"] = "Status",
	["NOTES"] = "Notes: %s",
	["VIEW_ALL"] = "Show all addons",
	["VIEW"] = "[View]",
	["DEPENDS"] = "Dependencies",
	["ENABLE_DEPS"] = "Would you like to enable the %d dependencies for %s?",
	["ENABLE_DEP"] = "Would you like to enable the %d dependency for %s?",
	["ENABLE_CHILDREN"] = "Would you like to enable the %s children addon for %s?",
	["ENABLE_CHILD"] = "Would you like to enable the %s child addon for %s?",
}

local function sortManagementAddons(a, b)
	if( not b ) then
		return false
	end

	if( frame.sortOrder ) then
		if( frame.sortType == "name" ) then
			return ( string.lower(a.title) < string.lower(b.title) )
		--elseif( frame.sortType == "parent" ) then
		--	return ( a.parent < b.parent )
		elseif( frame.sortType == "status" ) then
			return ( a.reason < b.reason )
		end

		return ( string.lower(a.title) < string.lower(b.title) )

	else
		if( frame.sortType == "name" ) then
			return ( string.lower(a.title) > string.lower(b.title) )
		--elseif( frame.sortType == "parent" ) then
		--	return ( a.parent > b.parent )
		elseif( frame.sortType == "status" ) then
			return ( a.reason > b.reason )
		end

		return ( string.lower(a.title) > string.lower(b.title) )
	end
end

-- Turns a vararg into a table
local function createDependencies(...)
	if( select("#", ...) == 0 ) then
		return nil
	end

	local deps = {}
	for i=1, select("#", ...) do
		deps[select(i, ...)] = true
	end

	return deps
end

-- Searchs the passed dependencies to see if parent is mentioned
local function isAddonChildOf(parent, ...)
	if( select("#", ...) == 0 ) then
		return nil
	end

	if( type(parent) == "number" ) then
		parent = string.lower((GetAddOnInfo(parent)))
	end

	for i=1, select("#", ...) do
		if( string.lower(select(i, ...)) == parent ) then
			return true
		end
	end

	return nil
end

local updateManageList;
local function filterParent(self)
	if( frame.parentFilter and frame.parentFilter == self.parentAddon ) then
		frame.parentFilter = nil
	else
		frame.parentFilter = self.parentAddon
	end

	frame.resortList = true
	updateManageList()
end

-- Displays everything
updateManageList = function(skipShown)
	if( ( not skipShown and not frame:IsShown() ) or not frame.scroll ) then
		return
	end

	-- This way we don't have to recreate the entire list on search
	local searchBy = string.trim(string.lower(frame.search:GetText()))
	if( searchBy == "" or frame.search.searchText ) then
		searchBy = nil
	end

	-- We could reduce all of this into one or two if statements, but this way is saner
	-- and far easier for people to debug
	for id, addon in pairs(frame.addons) do
		if( searchBy and not string.find(string.lower(addon.title), searchBy) ) then
			frame.addons[id].hide = true
		elseif( not frame.parentFilter ) then
			frame.addons[id].hide = nil
		elseif( frame.parentFilter == addon.name or ( frame.dependencies[addon.name] and frame.dependencies[addon.name][frame.parentFilter] ) ) then
			frame.addons[id].hide = nil
		else
			frame.addons[id].hide = true
		end
	end

	if( frame.resortList ) then
		table.sort(frame.addons, sortManagementAddons)
		frame.resortList = nil
	end

	local usedRows = 0
	local totalAddons = 0
	for id, addon in pairs(frame.addons) do
		if( not addon.hide ) then
			totalAddons = totalAddons + 1
			if( totalAddons > frame.scroll.offset and usedRows < TOTAL_ROWS ) then
				usedRows = usedRows + 1
				local row = frame.rows[usedRows]
				if( addon.color ) then
					row.title:SetText(addon.color .. addon.title .. "|r")
					row.reason:SetText(addon.color .. addon.reason .. "|r")
				else
					row.title:SetText(addon.title)
					row.reason:SetText(addon.reason)
				end


				row.enabled.text = addon.tooltip
				row.enabled.addon = addon.name
				row.enabled:SetChecked(addon.isEnabled)

				row.enabled:Show()
				row.title:Show()
				row.reason:Show()

				if( frame.dependencies[addon.name] ) then
					for _, parent in pairs(row.parents) do
						parent:Hide()
					end
					
					local id = 0
					for dep in pairs(frame.dependencies[addon.name]) do
						id = id + 1
						
						local parent
						if( row.parents[id] ) then
							parent = row.parents[id]
						else
							local path, _, border = GameFontHighlightSmall:GetFont()

							parent = CreateFrame("Button", nil, frame)
							parent:SetNormalFontObject(GameFontHighlightSmall)
							parent:SetText("*")
							parent:GetNormalFontObject():SetFont(path, OptionHouseDB.manageFontSize, border)
							parent:SetHeight(18)
							parent:SetScript("OnClick", filterParent)
							
							if( id > 1 ) then
								parent:SetPoint("LEFT", row.parents[id - 1], "TOPRIGHT", 5, -10)
							else
								parent:SetPoint("TOPRIGHT", row.parents[id - 1], "TOPRIGHT", 45, 0)
							end
							row.parents[id] = parent
						end

						if( frame.addonStatus[dep] ) then
							parent:SetText(frame.addonStatus[dep] )
						else
							parent:SetText(STATUS_COLORS["INCOMPATIBLE"] .. dep .. "|r" )
						end

						parent.parentAddon = dep
						parent:SetWidth(parent:GetFontString():GetStringWidth() + 3)
						parent:Show()
					end
				else
					for _, parent in pairs(row.parents) do
						parent:Hide()
					end
				end

				-- Shift the reason to the right if no button so we don't have ugly blank space
				if( not addon.isLoD ) then
					row.reason:SetPoint("RIGHT", row.button, "RIGHT", -5, 0)
					row.button:Hide()
				else
					row.reason:SetPoint("RIGHT", row.button, "LEFT", -5, 0)
					row.button.addon = addon.name
					row.button:Show()
				end
			end
		end
	end
	
	for i=usedRows+1, CREATED_ROWS do
		frame.rows[i].title:Hide()
		frame.rows[i].enabled:Hide()
		frame.rows[i].button:Hide()
		frame.rows[i].reason:Hide()

		for _, parent in pairs(frame.rows[i].parents) do
			parent:Hide()
		end
	end

	OptionHouse:UpdateScroll(frame.scroll, totalAddons)
end

local function sortManageClick(self)
	if( self.sortType ) then
		if( self.sortType ~= frame.sortType ) then
			frame.sortOrder = false
			frame.sortType = self.sortType
		else
			frame.sortOrder = not frame.sortOrder
		end

		frame.resortList = true
		updateManageList()
	end
end


local function saveAddonData(id, skipCheck)
	local name, title, notes, enabled, loadable, reason, security = GetAddOnInfo(id)
	local isLoaded = IsAddOnLoaded(id)
	local isLoD = IsAddOnLoadOnDemand(id)
	local author = GetAddOnMetadata(id, "Author")
	local version = GetAddOnMetadata(id, "Version")
	local color

	if( not frame.dependencies[name] ) then
		frame.dependencies[name] = createDependencies(GetAddOnDependencies(id))
	end

	-- Strip out the stupid -Ace2- stuff
	if( title ) then
		title = string.gsub(title, "%-(.+)%-%|r", "|r")
	end

	if( type(version) == "string" ) then
		-- Strip out some of the common strings from version meta data
		version = string.gsub(version, "%$Revision: (%d+) %$", "r%1")
		version = string.gsub(version, "%$Rev: (%d+) %$", "r%1")
		version = string.gsub(version, "%$LastChangedRevision: (%d+) %$", "r%1")
		version = string.trim(version)
	else
		version = nil
	end

	if( type(author) ~= "string" ) then
		author = nil
	end

	if( isLoaded or reason == "INCOMPATIBLE" or reason == "DEP_NOT_DEMAND_LOADED" or reason == "DISABLED" ) then
		isLoD = nil
	end

	if( reason ) then
		color = STATUS_COLORS[reason]
		reason = TEXT(getglobal("ADDON_" .. reason))

	-- Load on Demand
	elseif( loadable and isLoD and not isLoaded and enabled ) then
		reason = L["LOAD_ON_DEMAND"]
		color = STATUS_COLORS["LOAD_ON_DEMAND"]

	-- Currently loaded, but will be disabled at reload
	elseif( isLoaded and not enabled ) then
		reason = L["DISABLED_AT_RELOAD"]
		color = STATUS_COLORS["DISABLED_AT_RELOAD"]

	-- Addon is LoD, but it was already loaded/enabled so dont show the button
	elseif( isLoD and isLoaded and enabled ) then
		reason = L["LOD_LOADED"]
	
	-- Addon is enabled, but isn't LoD so enabled on reload
	elseif( not isLoaded and enabled ) then
		reason = L["ENABLED_AT_RELOAD"]
		color = STATUS_COLORS["NOT_DEMAND_LOADED"]
	
	-- Addon is disabled
	elseif( not enabled ) then
		reason = TEXT(ADDON_DISABLED)
		color = STATUS_COLORS["DISABLED"]
	else
		reason = L["LOADED"]
	end

	local tooltip = "|cffffffff" .. title .. "|r"
	if( author ) then
		tooltip = tooltip .. "\n" .. string.format(L["AUTHOR"], author)
	end

	if( version ) then
		tooltip = tooltip .. "\n" .. string.format(L["VERSION"], version)
	end

	if( notes ) then
		tooltip = tooltip .. "\n" .. string.format(L["NOTES"], notes)
	end

	if( color ) then
		frame.addonStatus[name] = color .. title .. "|r"
	else
		frame.addonStatus[name] = title
	end
	
	local tbl = {name = name, id = id, color = color, title = title, author = author, version = version, tooltip = tooltip, reason = reason or "", isEnabled = enabled, isLoD = isLoD}
	if( not skipCheck ) then
		for i, addon in pairs(frame.addons) do
			if( addon.name == name ) then
				frame.addons[i] = tbl
				return
			end
		end
	end
	
	frame.resortList = true
	table.insert(frame.addons, tbl)
end

local function createManageList()
	frame.dependencies = {}
	frame.addons = {}
	frame.addonStatus = {}

	for i=1, GetNumAddOns() do
		saveAddonData(i, true)
	end
end

-- ADDDON ENABLING/LOADING
local function loadAddon(self)
	LoadAddOn(self.addon)

	saveAddonData(self.addon)
	updateManageList()
end

local function enableChildren(self, children)
	for _, child in pairs(children) do
		EnableAddOn(child)
		saveAddonData(child)
	end

	updateManageList()
end

local function enableAddon(self, addon, useDeps)
	EnableAddOn(addon)
	saveAddonData(addon)

	if( useDeps and frame.dependencies[self.addon] ) then
		for dep, _ in pairs(frame.dependencies[self.addon]) do
			if( not select(4, GetAddOnInfo(dep)) ) then
				EnableAddOn(dep)
				saveAddonData(dep)
			end
		end
	end

	updateManageList()
end

-- Toggle addon on
local function toggleAddOnStatus(self)
	-- Addons disabled
	if( select(4, GetAddOnInfo(self.addon)) ) then
		PlaySound("igMainMenuOptionCheckBoxOff")
		DisableAddOn(self.addon)

		saveAddonData(self.addon)
		updateManageList()
		return
	end

	PlaySound("igMainMenuOptionCheckBoxOn")

	local addonEnabled

	-- ENABLING THE DEPENDENCIES OF AN ADDON
	if( OptionHouseDB.dependMode ~= "no" and frame.dependencies[self.addon] ) then
		-- Ask before enabling children
		if( OptionHouseDB.dependMode == "ask" ) then
			if( not StaticPopupDialogs["ENABLE_ADDON_DEPS"] ) then
				OHManage.EnableAddon = enableAddon

				StaticPopupDialogs["ENABLE_ADDON_DEPS"] = {
					button1 = YES,
					button2 = NO,
					OnAccept = function(id)
						OHManage:EnableAddon(id, true)
					end,
					OnCancel = function(id)
						OHManage:EnableAddon(id)
					end,
					timeout = 0,
					whileDead = 1,
					hideOnEscape = 1,
					multiple = 1,
				}
			end

			local totalDeps = 0
			for dep, _ in pairs(frame.dependencies[self.addon]) do
				if( not select(4, GetAddOnInfo(dep)) ) then
					totalDeps = totalDeps + 1
				end
			end

			if( totalDeps > 0 ) then
				if( totalDeps > 1 ) then
					StaticPopupDialogs["ENABLE_ADDON_DEPS"].text = L["ENABLE_DEPS"]
				else
					StaticPopupDialogs["ENABLE_ADDON_DEPS"].text = L["ENABLE_DEP"]
				end


				-- damn you slouken =(
				local dialog = StaticPopup_Show("ENABLE_ADDON_DEPS", totalDeps, self.addon)
				if( dialog ) then
					dialog.data = self.addon
				end
				addonEnabled = true
			end
		else
			enableAddon(self, self.addon, true)
			addonEnabled = true
		end
	end

	-- Don't enable it already through the dep mode
	if( not addonEnabled ) then
		enableAddon(self, self.addon)
	end

	-- ENABLING THE CHILDREN OF AN ADDON
	-- BigWigs, LightHeaded (damn clad), ect
	if( OptionHouseDB.childMode ~= "no" ) then
		-- Find all of the addons with us as a dependency
		local children = {}
		for i=1, GetNumAddOns() do
			if( not select(4, GetAddOnInfo(i) ) and isAddonChildOf(self.addon, GetAddOnDependencies(i)) ) then
				table.insert(children, i)
			end
		end

		if( #(children) > 0 ) then
			-- Ask for enabling
			if( OptionHouseDB.childMode == "ask" ) then
				if( not StaticPopupDialogs["ENABLE_ADDON_CHILDREN"] ) then
					OHManage.EnableChildren = enableChildren

					StaticPopupDialogs["ENABLE_ADDON_CHILDREN"] = {
						button1 = YES,
						button2 = NO,
						OnAccept = function(children)
							OHManage:EnableChildren(children)
						end,
						timeout = 0,
						whileDead = 1,
						hideOnEscape = 1,
						multiple = 1,
					}
				end

				if( #(children) > 0 ) then
					if( #(children) > 1 ) then
						StaticPopupDialogs["ENABLE_ADDON_CHILDREN"].text = L["ENABLE_CHILDREN"]
					else
						StaticPopupDialogs["ENABLE_ADDON_CHILDREN"].text = L["ENABLE_CHILD"]
					end


					-- damn you slouken =(
					local dialog = StaticPopup_Show("ENABLE_ADDON_CHILDREN", #(children), self.addon)
					if( dialog ) then
						dialog.data = children
					end
				end

			-- Always enable children
			elseif( OptionHouseDB.childMode == "yes" ) then
				enableChildren(self, children)
			end
		end
	end
end

local function showTooltip(self)
	if( self.text ) then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.text, nil, nil, nil, nil, 1)
	end
end

local function hideTooltip()
	GameTooltip:Hide()
end

local function createRows()
	local path, size, border = GameFontHighlightSmall:GetFont()

	-- We need a fake FS so we can calculate total height
	if( not frame.testFS ) then
		frame.testFS = frame:CreateFontString()
	end

	frame.testFS:SetFont(path, OptionHouseDB.manageFontSize, border)
	frame.testFS:SetText("*")

	local spacing = -12 - frame.testFS:GetHeight()

	TOTAL_ROWS = ceil(305 / abs(spacing))

	if( not frame.rows ) then
		frame.rows = {}
	end

	for i=1, TOTAL_ROWS do
		local row
		if( not frame.rows[i] ) then
			CREATED_ROWS = CREATED_ROWS + 1

			row = { parents = {} }
			frame.rows[i] = row

			row.enabled = CreateFrame("CheckButton", nil, frame, "OptionsCheckButtonTemplate")
			row.reason = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.title = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			row.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			row.parents[1] = CreateFrame("Button", nil, frame)
			row.parents[1]:SetNormalFontObject(GameFontHighlightSmall)
			row.parents[1]:SetText("*")
		else
			row = frame.rows[i]
		end

		-- Enable checkbox
		row.enabled:SetWidth(22)
		row.enabled:SetHeight(22)
		row.enabled:SetScript("OnClick", toggleAddOnStatus)
		row.enabled:SetScript("OnEnter", showTooltip)
		row.enabled:SetScript("OnLeave", hideTooltip)

		-- Load a LoD addon
		row.button:SetWidth(50)
		row.button:SetHeight(18)
		row.button:SetText(L["LOAD"])
		row.button:SetScript("OnClick", loadAddon)

		-- Reason (Disabled/Not LoD/LoD/Dependency Missing/ect)
		row.reason:SetFont(path, OptionHouseDB.manageFontSize, border)

		-- Addon parent (LightHeaded, BigWigs, and so on)
		row.parents[1]:GetNormalFontObject():SetFont(path, OptionHouseDB.manageFontSize, border)
		row.parents[1]:SetHeight(18)
		row.parents[1]:SetScript("OnClick", filterParent)

		-- Addon title
		row.title:SetFont(path, size, border)
		row.title:SetHeight(22)
		row.title:SetJustifyH("LEFT")
		row.title:SetNonSpaceWrap(false)

		if( i > 1 ) then
			row.enabled:SetPoint("TOPLEFT", frame.rows[i-1].enabled, "TOPLEFT", 0, spacing)
			row.button:SetPoint("TOPRIGHT", frame.rows[i-1].button, "TOPRIGHT", 0, spacing)
			row.title:SetPoint("TOPLEFT", frame.rows[i-1].title, "TOPLEFT", 0, spacing)
			row.parents[1]:SetPoint("TOPLEFT", frame.sortButtons[2], "TOPLEFT", 0, spacing * i)
		else
			row.enabled:SetPoint("TOPLEFT", frame.sortButtons[1], "TOPLEFT", 0, -22)
			row.parents[1]:SetPoint("TOPLEFT", frame.sortButtons[2], "TOPLEFT", 0, -22)
			row.button:SetPoint("TOPRIGHT", frame.sortButtons[3], "TOPRIGHT", 4, -22)
			row.title:SetPoint("LEFT", row.enabled, "RIGHT", 5, 0)
		end
	end
end

local function createManageFrame(hide)
	frame = OptionHouse:GetFrame("manage")
	if( frame and hide ) then
		frame:Hide()
		return
	elseif( hide ) then
		return
	elseif( not frame ) then
		frame = CreateFrame("Frame", nil, OptionHouse:GetFrame("main"))
		frame.sortOrder = true
		frame.sortType = "name"
		frame.sortButtons = {}
		frame:SetFrameStrata("DIALOG")
		frame:SetAllPoints(OptionHouse:GetFrame("main"))
		frame:RegisterEvent("ADDON_LOADED")
		frame:SetScript("OnEvent", function(self, event, name)
			if( frame.addons ) then
				saveAddonData(name)
				updateManageList()
			end
		end)


		OptionHouse:CreateSearchInput(frame, updateManageList)

		local disableAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		disableAll:SetWidth(80)
		disableAll:SetHeight(22)
		disableAll:SetPoint("BOTTOMRIGHT", OptionHouse:GetFrame("main"), "BOTTOMRIGHT", -8, 14)
		disableAll:SetText(L["DISABLE_ALL"])
		disableAll:SetScript("OnClick", function()
			DisableAllAddOns()
			EnableAddOn("OptionHouse")

			createManageList()
			updateManageList()
		end)

		local enableAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		enableAll:SetWidth(80)
		enableAll:SetHeight(22)
		enableAll:SetPoint("RIGHT", disableAll, "LEFT")
		enableAll:SetText(L["ENABLE_ALL"])
		enableAll:SetScript("OnClick", function()
			EnableAllAddOns()

			createManageList()
			updateManageList()
		end)

		local reloadUI = CreateFrame("Button", nil, frame, "UIPanelButtonGrayTemplate")
		reloadUI:SetWidth(80)
		reloadUI:SetHeight(22)
		reloadUI:SetPoint("RIGHT", enableAll, "LEFT")
		reloadUI:SetText(L["RELOAD_UI"])
		reloadUI:SetScript("OnClick", ReloadUI)

		local button = CreateFrame("Button", nil, frame)
		button:SetScript("OnClick", sortManageClick)
		button:SetHeight(20)
		button:SetWidth(75)
		button:SetNormalFontObject(GameFontNormal)
		button.sortType = "name"
		button:SetText(L["NAME"])
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -73)
		button:Show()

		frame.sortButtons[1] = button

		button = CreateFrame("Button", nil, frame)
		--button:SetScript("OnClick", sortManageClick)
		button:SetHeight(20)
		button:SetWidth(75)
		button:SetNormalFontObject(GameFontNormal)
		button.sortType = "parent"
		button:SetText(L["DEPENDS"])
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 260, -73)
		button:Show()

		frame.sortButtons[2] = button

		button = CreateFrame("Button", nil, frame)
		button:SetScript("OnClick", sortManageClick)
		button:SetHeight(20)
		button:SetWidth(75)
		button:SetNormalFontObject(GameFontNormal)
		button.sortType = "status"
		button:SetText(L["STATUS"])
		button:SetWidth(button:GetFontString():GetStringWidth() + 3)
		button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, -73)
		button:Show()

		frame.sortButtons[3] = button

		-- Create all of the rows for display
		createRows()

		OptionHouse:CreateScrollFrame(frame, TOTAL_ROWS, updateManageList)
		OptionHouse:RegisterFrame("manage", frame)

		frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 25, -76)
		frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -35, 72)
	end

	createManageList()
	updateManageList(true)

	frame:Show()
end

-- Load it into OH
OptionHouse:RegisterTab(L["ADDON_MANAGEMENT"], createManageFrame, "bid")

--[[
function OHManage:Reload()
	if( frame ) then
		createRows()

		frame.scroll.displayNum = TOTAL_ROWS
		frame.scroll.bar:SetValueStep(TOTAL_ROWS)

		updateManageList()
	end
end
]]