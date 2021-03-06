function widget:GetInfo()
	return {
		name    = 'Modoptions Panel',
		desc    = 'Implements the modoptions panel.',
		author  = 'GoogleFrog',
		date    = '29 July 2016',
		license = 'GNU GPL v2',
		layer   = 0,
		enabled = true,
	}
end

local battleLobby
local modoptionDefaults = {}
local modoptionChanges = {}
local modoptionLocalChanges = {}
local modoptionStructure = {}

local modoptionListenerLobby

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Functions

local function ProcessListOption(data, index)
	local label = Label:New {
		x = 5,
		y = 0,
		width = 350,
		height = 30,
		valign = "center",
		align = "left",
		caption = data.name,
		font = WG.Chobby.Configuration:GetFont(2),
		tooltip = data.desc,
	}
	
	local defaultItem = 1
	local defaultKey = modoptionChanges[data.key] or data.def 
	
	local items = {}
	local itemNameToKey = {}
	for i, itemData in pairs(data.items) do
		items[i] = itemData.name
		itemNameToKey[itemData.name] = itemData.key
		
		if itemData.key == defaultKey then
			defaultItem = i
		end
	end
	
	local list = ComboBox:New {
		x = 340,
		y = 1,
		width = 180,
		height = 30,
		items = items,
		font = WG.Chobby.Configuration:GetFont(2),
		itemFontSize = WG.Chobby.Configuration:GetFont(2).size,
		selectByName = true,
		selected = defaultItem,
		OnSelectName = {
			function (obj, selectedName)
				modoptionLocalChanges[data.key] = itemNameToKey[selectedName]
			end
		}
	}
	
	return Control:New {
		x = 0,
		y = index*32,
		width = 600,
		height = 32,
		padding = {0, 0, 0, 0},
		children = {
			label,
			list
		}
	}
end

local function ProcessBoolOption(data, index)
	return Checkbox:New {
		x = 5,
		y = index*32,
		width = 355,
		height = 40,
		boxalign = "right",
		boxsize = 20,
		caption = data.name,
		checked = (modoptionChanges[data.key] ~= nil and modoptionChanges[data.key] ~= 0) or (modoptionChanges[data.key] == nil and modoptionDefaults[data.key] == 1),
		font = WG.Chobby.Configuration:GetFont(2),
		tooltip = data.desc,
		
		OnChange = {
			function (obj, newState)
				modoptionLocalChanges[data.key] = tostring((newState and 1) or 0)
			end
		},
	}
end

local function ProcessNumberOption(data, index)
	
	local label = Label:New {
		x = 5,
		y = 0,
		width = 350,
		height = 30,
		valign = "center",
		align = "left",
		caption = data.name,
		font = WG.Chobby.Configuration:GetFont(2),
		tooltip = data.desc,
	}
	
	local oldText = modoptionChanges[data.key] or modoptionDefaults[data.key]
	
	local numberBox = EditBox:New {
		x = 340,
		y = 1,
		width = 180,
		height = 30,
		text   = oldText,
		fontSize = WG.Chobby.Configuration:GetFont(2).size,
		OnFocusUpdate = {
			function (obj)
				if obj.focused then
					return
				end
				
				local newValue = tonumber(obj.text)
				
				if not newValue then
					obj:SetText(oldText)
					return
				end
				
				local places = 0
				if data.step < 0.01  then
					places = 3
				elseif data.step < 0.1 then
					places = 2
				elseif data.step < 1 then
					places = 3
				end
				
				-- Bound the number
				newValue = math.min(data.max, math.max(data.min, newValue))
				-- Round to step size
				newValue = math.floor(newValue/data.step)*data.step + 0.01*data.step
				
				-- Remove excess accuracy
				oldText = string.format("%." .. places .. "f", newValue)
				-- Remove trailing zeros
				while oldText:find("%.") and (oldText:find("0", oldText:len()) or oldText:find("%.", oldText:len())) do
					Spring.Echo("oldText", oldText)
					oldText = oldText:sub(0, oldText:len() - 1)
				end
				
				modoptionLocalChanges[data.key] = oldText
				obj:SetText(oldText)
			end
		}
	}
	
	return Control:New {
		x = 0,
		y = index*32,
		width = 600,
		height = 32,
		padding = {0, 0, 0, 0},
		children = {
			label,
			numberBox
		}
	}
end

local function ProcessStringOption(data, index)
	return Label:New {
		x = 5,
		y = index*32,
		width = 355,
		height = 40,
		valign = "center",
		align = "left",
		caption = data.name .. " (Not implemented)",
		font = WG.Chobby.Configuration:GetFont(2),
		tooltip = data.desc,
	}
end

local function PopulateTab(options)
	-- list = combobox
	-- bool = tickbox
	-- number = sliderbar (with label)
	-- string = editBox
	local children = {}
	for i = 1, #options do
		local data = options[i]
		if data.type == "list" then
			children[#children + 1] = ProcessListOption(data, #children)
		elseif data.type == "bool" then
			children[#children + 1] = ProcessBoolOption(data, #children)
		elseif data.type == "number" then
			children[#children + 1] = ProcessNumberOption(data, #children)
		elseif data.type == "string" then
			children[#children + 1] = ProcessStringOption(data, #children)
		end
	end
	return children
end

local function CreateModoptionWindow()
	local modoptionsSelectionWindow = Window:New {
		caption = "",
		name = "modoptionsSelectionWindow",
		parent = WG.Chobby.lobbyInterfaceHolder,
		width = 800,
		height = 500,
		resizable = false,
		draggable = false,
		classname = "overlay_window",
	}

	modoptionLocalChanges = {}
	
	local tabs = {}

	for key, data in pairs(modoptionStructure.sections) do
		tabs[#tabs + 1] = {
			name = key,
			caption = modoptionStructure.sectionTitles[data.title] or data.title,
			font = WG.Chobby.Configuration:GetFont(2),
			children = PopulateTab(data.options)
		}
	end

	local tabPanel = Chili.DetachableTabPanel:New {
		x = 5,
		right = 5,
		y = 45,
		bottom = 85,
		padding = {0, 0, 0, 0},
		minTabWidth = 130,
		tabs = tabs,
		parent = modoptionsSelectionWindow,
		OnTabChange = {
		}
	}

	local tabBarHolder = Control:New {
		name = "tabBarHolder",
		x = 0,
		y = 0,
		width = "100%",
		height = 50,
		resizable = false,
		draggable = false,
		padding = {0, 0, 0, 0},
		parent = modoptionsSelectionWindow,
		children = {
			tabPanel.tabBar
		}
	}
	local function CancelFunc()
		modoptionsSelectionWindow:Dispose()
	end

	local buttonAccept
	
	local function AcceptFunc()
		screen0:FocusControl(buttonAccept) -- Defocus the text entry
		battleLobby:SetModOptions(modoptionLocalChanges)
		modoptionsSelectionWindow:Dispose()
	end

	buttonAccept = Button:New {
		right = 150,
		width = 135,
		bottom = 1,
		height = 70,
		caption = i18n("apply"),
		font = WG.Chobby.Configuration:GetFont(3),
		parent = modoptionsSelectionWindow,
		classname = "action_button",
		OnClick = {
			function()
				AcceptFunc()
			end
		},
	}

	local buttonCancel = Button:New {
		right = 1,
		width = 135,
		bottom = 1,
		height = 70,
		caption = i18n("cancel"),
		font = WG.Chobby.Configuration:GetFont(3),
		parent = modoptionsSelectionWindow,
		classname = "negative_button",
		OnClick = {
			function()
				CancelFunc()
			end
		},
	}

	local popupHolder = WG.Chobby.PriorityPopup(modoptionsSelectionWindow, CancelFunc, AcceptFunc)
end

local function InitializeModoptionsDisplay()

	local mainScrollPanel = ScrollPanel:New {
		x = 0,
		right = 0,
		y = 0,
		bottom = 0,
		horizontalScrollbar = false,
	}

	local lblText = TextBox:New {
		x = 1,
		right = 1,
		y = 1,
		autoresize = true,
		font = WG.Chobby.Configuration:GetFont(1),
		text = "",
		parent = mainScrollPanel,
	}

	modoptionListenerLobby = battleLobby
	local function OnSetModOptions(listener, data)
		local modoptions = battleLobby:GetMyBattleModoptions()
		local text = ""
		local empty = true
		for key, value in pairs(modoptions) do
			if modoptionDefaults[key] == nil or modoptionDefaults[key] ~= value then
				text = text .. "\255\120\120\120" .. tostring(key) .. " = \255\255\255\255" .. tostring(value) .. "\n"
				empty = false
				modoptionChanges[key] = value
			else
				modoptionChanges[key] = nil
			end
		end
		lblText:SetText(text)

		if mainScrollPanel.parent then
			if empty and mainScrollPanel.visible then
				mainScrollPanel:Hide()
			end
			if (not empty) and (not mainScrollPanel.visible) then
				mainScrollPanel:Show()
			end
		end
	end
	battleLobby:AddListener("OnSetModOptions", OnSetModOptions)

	local externalFunctions = {}

	function externalFunctions.Update()
		if modoptionListenerLobby then
			modoptionListenerLobby:RemoveListener("OnSetModOptions", OnSetModOptions)
		end
		battleLobby:AddListener("OnSetModOptions", OnSetModOptions)

		OnSetModOptions()
	end

	function externalFunctions.GetControl()
		return mainScrollPanel
	end

	return externalFunctions
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- External Interface
local modoptionsDisplay

local ModoptionsPanel = {}

function ModoptionsPanel.LoadModotpions(gameName, newBattleLobby)
	battleLobby = newBattleLobby

	modoptions = WG.Chobby.Configuration:GetGameConfig(gameName, "ModOptions.lua")
	modoptionDefaults = {}
	modoptionChanges = {}
	modoptionStructure = {
		sectionTitles = {},
		sections = {}
	}
	if not modoptions then
		return
	end

	-- Set modoptionDefaults
	for i = 1, #modoptions do
		local data = modoptions[i]
		if data.key and data.def ~= nil then
			if type(data.def) == "boolean" then
				modoptionDefaults[data.key] = tostring((data.def and 1) or 0)
			else
				modoptionDefaults[data.key] = tostring(data.def)
			end
		end
	end

	-- Populate the sections
	for i = 1, #modoptions do
		local data = modoptions[i]
		if data.type == "section" then
			modoptionStructure.sectionTitles[data.key] = data.name
		else
			if data.section then
				modoptionStructure.sections[data.section] = modoptionStructure.sections[data.section] or {
					title = data.section,
					options = {}
				}

				local options = modoptionStructure.sections[data.section].options
				options[#options + 1] = data
			end
		end
	end
end

function ModoptionsPanel.ShowModoptions()
	CreateModoptionWindow()
end

function ModoptionsPanel.GetModoptionsControl()
	if not modoptionsDisplay then
		modoptionsDisplay = InitializeModoptionsDisplay()
	else
		modoptionsDisplay.Update()
	end
	return modoptionsDisplay.GetControl()
end

--------------------------------------------------------------------------
--------------------------------------------------------------------------
-- Initialization

function widget:Initialize()
	CHOBBY_DIR = LUA_DIRNAME .. "widgets/chobby/"
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)

	WG.ModoptionsPanel = ModoptionsPanel
end
