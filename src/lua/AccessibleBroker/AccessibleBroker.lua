--[[
Mod: AccessibleBroker
Author: hllf
Version: 6

Intended as an accessibility mod. Modifies the Wretched Broker interface to allow for proper OCR results.
Use the mod importer to import this mod.
--]]

local function _Log(msg) if LogEvent then LogEvent(msg) end end

ModUtil.WrapBaseFunction("OpenMarketScreen", function(baseFunc)
	_Log("[SCREEN-OPEN] Wretched Broker (OpenMarketScreen)")

	local screen = { Components = {} }
	screen.Name = "Market"
	screen.NumSales = 0
	screen.NumItemsOffered = 0

	if IsScreenOpen( screen.Name ) then
		return
	end
	OnScreenOpened({ Flag = screen.Name, PersistCombatUI = true })
	FreezePlayerUnit()
	EnableShopGamepadCursor()

	PlaySound({ Name = "/SFX/Menu Sounds/DialoguePanelIn" })

	local components = screen.Components

	components.ShopBackgroundDim = CreateScreenComponent({ Name = "rectangle01", Group = "Combat_Menu" })
	components.ShopBackground = CreateScreenComponent({ Name = "ShopBackground", Group = "Combat_Menu" })
	components.CloseButton = CreateScreenComponent({ Name = "ButtonClose", Group = "Combat_Menu", Scale = 0.7 })
	Attach({ Id = components.CloseButton.Id, DestinationId = components.ShopBackground.Id, OffsetX = 0, OffsetY = 440 })
	components.CloseButton.OnPressedFunctionName = "CloseMarketScreen"
	components.CloseButton.ControlHotkey = "Cancel"
	SetScale({ Id = components.ShopBackgroundDim.Id, Fraction = 4 })
	SetColor({ Id = components.ShopBackgroundDim.Id, Color = {0.090, 0.055, 0.157, 0.7} })

	-- Title
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "MarketScreen_Title", FontSize = 32, OffsetX = 0, OffsetY = -445, Color = Color.White, Font = "SpectralSCLightTitling", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 3}, Justification = "Center" })
	CreateTextBox({ Id = components.ShopBackground.Id, Text = "MarketScreen_Hint", FontSize = 14, OffsetX = 0, OffsetY = 380, Width = 865, Color = Color.Gray, Font = "AlegreyaSansSCBold", ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2}, Justification = "Center" })

	-- Flavor Text
	local flavorTextOptions = { "MarketScreen_FlavorText01", "MarketScreen_FlavorText02", "MarketScreen_FlavorText03", }
	local flavorText = GetRandomValue( flavorTextOptions )
	CreateTextBox(MergeTables({ Id = components.ShopBackground.Id, Text = flavorText,
			FontSize = 16,
			OffsetY = -385, Width = 990,
			Color = {0.698, 0.702, 0.514, 1.0},
			Font = "AlegreyaSansSCExtraBold",
			ShadowBlur = 0, ShadowColor = {0,0,0,0}, ShadowOffset={0, 3},
			Justification = "Center" }, LocalizationData.MarketScreen.FlavorText))

	-- image

	local tooltipData = {}
	local yScale = math.min( 3 / CurrentRun.MarketOptions , 1 )

	local itemLocationStartY = ShopUI.ShopItemStartY - ( ShopUI.ShopItemSpacerY * (1 - yScale) * 0.5)
	local itemLocationYSpacer = ShopUI.ShopItemSpacerY * yScale
	local itemLocationMaxY = itemLocationStartY + 4 * itemLocationYSpacer

	local itemLocationStartX = ShopUI.ShopItemStartX
	local itemLocationXSpacer = ShopUI.ShopItemSpacerX
	local itemLocationMaxX = itemLocationStartX + 1 * itemLocationXSpacer

	local itemLocationTextBoxOffset = 380

	local itemLocationX = itemLocationStartX
	local itemLocationY = itemLocationStartY

	local textSymbolScale = 0.8

	-- Function modification by hllf: Insert next 18 lines
	local nameToDisplayTextSingular = {
		["MetaPoints"] = "Darkness",
		["Gems"] = "Gemstone",
		["LockKeys"] = "Chthonic Key",
		["GiftPoints"] = "Nectar",
		["SuperGems"] = "Diamond",
		["SuperGiftPoints"] = "Ambrosia",
		["SuperLockKeys"] = "Titan Blood",
	}
	local nameToDisplayTextPlural = {
		["MetaPoints"] = "Darkness",
		["Gems"] = "Gemstones",
		["LockKeys"] = "Chthonic Keys",
		["GiftPoints"] = "Nectar",
		["SuperGems"] = "Diamonds",
		["SuperGiftPoints"] = "Ambrosia",
		["SuperLockKeys"] = "Titan Blood",
	}

	local firstUseable = false
	for itemIndex, item in ipairs( CurrentRun.MarketItems ) do

		if not item.SoldOut then

			-- Function modification by hllf: Insert next 15 lines
			local displayText = ""
			if item.BuyAmount == 1 then
				displayText = displayText .. "1 " .. (nameToDisplayTextSingular[item.BuyName] or item.BuyName)
			else
				displayText = displayText .. tostring(item.BuyAmount) .. " " .. (nameToDisplayTextPlural[item.BuyName] or item.BuyName)
			end
			displayText = displayText .. ":  "
			if item.CostAmount == 1 then
				displayText = displayText .. "1 " .. (nameToDisplayTextSingular[item.CostName] or item.CostName)
			else
				displayText = displayText .. tostring(item.CostAmount) .. " " .. (nameToDisplayTextPlural[item.CostName] or item.CostName)
			end
			if not item.Priority then
				displayText = displayText .. "  (Special)"
			end

			screen.NumItemsOffered = screen.NumItemsOffered + 1

			--local itemBackingSoldOutKey = "ItemBackingSoldOut"..itemIndex
			--components[itemBackingSoldOutKey] = CreateScreenComponent({ Name = "MarketSlotInactive", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			--SetScaleY({ Id = components[itemBackingSoldOutKey].Id , Fraction = yScale })
			local purchaseButtonKey = "PurchaseButton"..itemIndex
			components[purchaseButtonKey] = CreateScreenComponent({ Name = "MarketSlot", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })
			SetInteractProperty({ DestinationId = components[purchaseButtonKey].Id, Property = "TooltipOffsetX", Value = 665 })

			local iconKey = "Icon"..itemIndex
			components[iconKey] = CreateScreenComponent({ Name = "BlankObstacle", X = itemLocationX - 360, Y = itemLocationY, Group = "Combat_Menu" })
			if not item.Priority then
				--SetAnimation({ Name = "MarketLimitedOffer", DestinationId = components[iconKey].Id })
				--SetScale({ Id = components[iconKey].Id, Fraction = yScale * 1.25 })
			end

			local itemBackingKey = "Backing"..itemIndex
			components[itemBackingKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", X = itemLocationX + itemLocationTextBoxOffset, Y = itemLocationY })

			local purchaseButtonTitleKey = "PurchaseButtonTitle"..itemIndex
			components[purchaseButtonTitleKey] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1, X = itemLocationX, Y = itemLocationY })



			local costColor = {0.878, 0.737, 0.259, 1.0}
			if not HasResource( item.CostName, item.CostAmount ) then
				costColor = Color.TradeUnaffordable
			end

			components[purchaseButtonKey].OnPressedFunctionName = "HandleMarketPurchase"
			components[purchaseButtonKey].OnMouseOverFunctionName = "OnBrokerItemMouseOver"
			components[purchaseButtonKey].displayText = displayText
			components[purchaseButtonKey].marketItem = item
			AttachLua({ Id = components[purchaseButtonKey].Id, Table = components[purchaseButtonKey] })
			if not firstUseable then
				screen.FirstButtonId = components[purchaseButtonKey].Id
				screen.FirstDisplayText = displayText
				screen.FirstMarketItem = item
				firstUseable = true
			end

			-- left side text
			local buyResourceData = ResourceData[item.BuyName]
			if buyResourceData then
				components[purchaseButtonTitleKey .. "Icon"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1 })
				SetAnimation({ Name = buyResourceData.Icon, DestinationId = components[purchaseButtonTitleKey .. "Icon"].Id, Scale = 1 })
				Attach({ Id = components[purchaseButtonTitleKey .. "Icon"].Id, DestinationId = components[purchaseButtonTitleKey].Id, OffsetX = -400, OffsetY = 0 })
				components[purchaseButtonTitleKey .. "SellText"] = CreateScreenComponent({ Name = "BlankObstacle", Group = "Combat_Menu", Scale = 1 })
				Attach({ Id = components[purchaseButtonTitleKey .. "SellText"].Id, DestinationId = components[purchaseButtonTitleKey].Id, OffsetX = 0, OffsetY = 0 })

				local titleText = "MarketScreen_Entry_Title"
				if item.BuyAmount == 1 then
					titleText = "MarketScreen_Entry_Title_Singular"
				end
				-- Function modification by hllf: Modify next line
				CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = (displayText or titleText),
					FontSize = 48 * yScale ,
					OffsetX = -350, OffsetY = -35,
					Width = 720,
					Color = {0.878, 0.737, 0.259, 1.0},
					Font = "AlegreyaSansSCMedium",
					ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
					Justification = "Left",
					VerticalJustification = "Top",
					LuaKey = "TempTextData",
					LuaValue = item,
					LineSpacingBottom = 20,
					TextSymbolScale = textSymbolScale,
				})
				-- Function modification by hllf: Modify next line
				CreateTextBox({ Id = components[purchaseButtonTitleKey.."SellText"].Id, Text = (" " or "MarketScreen_Cost"),
					FontSize = 48 * yScale ,
					OffsetX = 420, OffsetY = -24,
					Width = 720,
					Color = costColor,
					Font = "AlegreyaSansSCMedium",
					ShadowBlur = 0, ShadowColor = {0,0,0,1}, ShadowOffset={0, 2},
					Justification = "Right",
					LuaKey = "TempTextData",
					LuaValue = item,
					LineSpacingBottom = 20,
					TextSymbolScale = textSymbolScale,
				})
				ModifyTextBox({ Ids = components[purchaseButtonTitleKey.."SellText"].Id, BlockTooltip = true })

				CreateTextBoxWithFormat({ Id = components[purchaseButtonKey].Id, Text = buyResourceData.IconString or item.BuyName,
					FontSize = 16 * yScale,
					OffsetX = -350, OffsetY = 0,
					Width = 650,
					Color = Color.White,
					Justification = "Left",
					VerticalJustification = "Top",
					LuaKey = "TempTextData",
					LuaValue = item,
					TextSymbolScale = textSymbolScale,
					Format = "MarketScreenDescriptionFormat",
					VariableAutoFormat = "BoldFormatGraft",
					UseDescription = true
				})
				if not item.Priority then
					CreateTextBox({ Id = components[purchaseButtonKey].Id, Text = "Market_LimitedTimeOffer", OffsetX = 300, OffsetY = 0, FontSize = 28, Color = costColor, Font = "AlegreyaSansSCRegular", Justification = "Left", TextSymbolScale = textSymbolScale })
				end
			end

			components[purchaseButtonKey].Data = item
			components[purchaseButtonKey].Index = itemIndex
			components[purchaseButtonKey].TitleId = components[purchaseButtonTitleKey].Id
		end

		itemLocationX = itemLocationX + itemLocationXSpacer
		if itemLocationX >= itemLocationMaxX then
			itemLocationX = itemLocationStartX
			itemLocationY = itemLocationY + itemLocationYSpacer
		end
	end

	if screen.NumItemsOffered == 0 then
		thread( PlayVoiceLines, GlobalVoiceLines.MarketSoldOutVoiceLines, true )
	else
		thread( PlayVoiceLines, GlobalVoiceLines.OpenedMarketVoiceLines, true )
	end

	-- TeleportCursor to first button using DestinationId and speak it
	if screen.FirstButtonId then
		TeleportCursor({ DestinationId = screen.FirstButtonId })
		if AccessibilityEnabled and AccessibilityEnabled() and screen.FirstDisplayText then
			TolkSilence()
			local speech = UIStrings.WretchedBroker .. ", " .. screen.FirstDisplayText
			if screen.FirstMarketItem and not HasResource(screen.FirstMarketItem.CostName, screen.FirstMarketItem.CostAmount) then
				speech = speech .. ", " .. UIStrings.CannotAfford
			end
			TolkSpeak(speech)
		end
	end

	HandleScreenInput( screen )
	return screen

end)

-- Mouse over handler for broker items
function OnBrokerItemMouseOver(button)
	if not AccessibilityEnabled or not AccessibilityEnabled() or not button then
		return
	end
	local speech = button.displayText or "Unknown Item"
	if button.marketItem then
		if not HasResource(button.marketItem.CostName, button.marketItem.CostAmount) then
			speech = speech .. ", " .. UIStrings.CannotAfford
		end
	end
	TolkSilence()
	TolkSpeak(speech)
end
