--[[
AdiButtonAuras - Display auras on action buttons.
Copyright 2013 Adirelle (adirelle@gmail.com)
All rights reserved.

This file is part of AdiButtonAuras.

AdiButtonAuras is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

AdiButtonAuras is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with AdiButtonAuras.  If not, see <http://www.gnu.org/licenses/>.
--]]

if select(2, UnitClass("player")) ~= "MONK" then return end

-- Globals: AddRuleFor Configure SimpleAuras UnitBuffs
-- Globals: PassiveModifier SimpleDebuffs SharedSimpleDebuffs SimpleBuffs
-- Globals: LongestDebuffOf SelfBuffs PetBuffs BuffAliases DebuffAliases
-- Globals: SelfBuffAliases SharedBuffs ShowPower SharedSimpleBuffs
-- Globals: BuildAuraHandler_Longest ImportPlayerSpells bit BuildAuraHandler_Single
-- Globals: math

AdiButtonAuras:RegisterRules(function(addon)
	addon.Debug('Rules', 'Adding monk rules')

	local L = addon.L

	local ceil = _G.ceil
	local floor = _G.floor
	local format = _G.format
	local GetNumGroupMembers = _G.GetNumGroupMembers
	local GetSpellBonusHealing = _G.GetSpellBonusHealing
	local GetSpellInfo = _G.GetSpellInfo
	local GetTime = _G.GetTime
	local min = _G.min
	local pairs = _G.pairs
	local select = _G.select
	local SPELL_POWER_MANA = _G.SPELL_POWER_MANA
	local UnitAura = _G.UnitAura
	local UnitBuff = _G.UnitBuff
	local UnitClass = _G.UnitClass
	local UnitDebuff = _G.UnitDebuff
	local UnitHealth = _G.UnitHealth
	local UnitHealthMax = _G.UnitHealthMax
	local UnitPower = _G.UnitPower
	local UnitPowerMax = _G.UnitPowerMax

	-- Mistweaver constants
	local buff = GetSpellInfo(115151) -- Renewing Mist
	local TFT_COUNT    = 4 -- Minimum number of Renewing Mist to highlight Thunder Focus Tea
	local TFT_DURATION = 6 -- Duration threshold to highlight Thunder Focus Tea
	local UPLIFT_THRESHOLD = 3 -- Heal multiplier to highlight Uplight

	return {
		ImportPlayerSpells {
			-- Import all spells for ...
			"MONK",
			-- ... but ...
			115151, -- Renewing Mist
			115294, -- Mana Tea
			116670, -- Uplift
			116680, -- Thunder Focus Tea
			119582, -- Purifying Brew
			123273, -- Surging Mist
			123761, -- Mana Tea (glyphed)
			125195, -- Tigereye Brew (stacking buff)
			128939, -- Elusive Brew (stacking buff)
			134563, -- Healing Elixirs (buff)
		},
		ShowPower {
			-- Show current Chi on spenders and flash when reaching maximum
			{
				100784, -- Blackout Kick
				107428, -- Rising Sun Kick
				113656, -- Fists of Fury
				115181, -- Breath of Fire
				116670, -- Uplift
				124682, -- Enveloping Mist
			},
			"CHI",
			nil,
			"flash"
		},
		DebuffAliases {
			121253, -- Keg Smash
			115180, -- Dizzying Haze
		},
		PassiveModifier {
			116645, -- Teachings of the Monastery
			123273, -- Surging Mist
			118674, -- Vital Mists
			"player",
			"none"
		},
		Configure {
			"HealingElixirs",
			addon.BuildDesc("HELPFUL PLAYER", "good", "player", 122280),
			{
				115203, -- Fortifying Brew
				115288, -- Energizing Brew
				115294, -- Mana Tea
				115308, -- Elusive Brew
				115399, -- Chi Brew
				116680, -- Thunder Focus Tea
				116740, -- Tigereye Brew
				119582, -- Purifying Brew
				137562, -- Nimble Brew
			},
			"player",
			"UNIT_AURA",
			(function()
				local healingElixirs = GetSpellInfo(134563) -- Healing Elixirs (buff)
				return function(units, model)
					if UnitBuff("player", healingElixirs) then
						model.highlight = "good"
					end
				end
			end)(),
			122280, -- Provided by: healing Elixirs (passive)
		},
		Configure {
			"PurifyingBrew",
			format(L["Show %s."], L["stagger level"]),
			119582, -- Purifying Brew
			"player",
			{ "UNIT_AURA", "UNIT_HEALTH_MAX" },
			(function()
				local STANCE_OF_THE_STURY_OX_ID = 23
				local STAGGER_YELLOW_TRANSITION = STAGGER_YELLOW_TRANSITION
				return function(units, model)
					local stagger = GetShapeshiftFormID() == STANCE_OF_THE_STURY_OX_ID and UnitStagger("player")
					if stagger then
						local percent = stagger / UnitHealthMax("player")
						model.count = ceil(percent * 100)
						if percent >= STAGGER_YELLOW_TRANSITION then
							model.hint = true
						end
					end
				end
			end)(),
		},
		Configure {
			"ManaTea",
			L["Suggest using @NAME under 92% mana."],
			123761, -- Mana Tea (glyphed)
			"player",
			{ "UNIT_AURA", "UNIT_POWER", "UNIT_POWER_MAX" },
			(function()
				local buff = GetSpellInfo(115867) -- Mana Tea (stacking buff)
				return function(_, model)
					local name, _, _, count, _, _, expiration = UnitAura("player", buff, nil, "HELPFUL PLAYER")
					if name then
						model.expiration = expiration
						if count >= 2 and UnitPower("player", SPELL_POWER_MANA) / UnitPowerMax("player", SPELL_POWER_MANA) <= 0.92 then
							model.hint = true
						end
					end
				end
			end)()
		},
		Configure {
			"RenewingMist",
			addon.L["Show the number of group member affected by @NAME and the shortest duration."],
			115151, -- Renewing Mist
			"group",
			"UNIT_AURA",
			function(units, model)
				local count, minExpiration = 0, math.huge
				for unit in pairs(units.group) do
					local name, _, _, _, _, _, expiration = UnitAura(unit, buff, nil, "HELPFUL PLAYER")
					if name then
						count, minExpiration = count + 1, min(minExpiration, expiration)
					end
				end
				if count > 0 then
					model.highlight, model.count, model.expiration = "good", count, minExpiration
				end
				if count < 4 and GetNumGroupMembers() >= 5 then
					model.hint = true
				end
			end
		},
		Configure {
			"ThunderFocusTea",
			format(addon.L["Suggest when at least %s %s are running and one of them is below %s seconds."], TFT_COUNT, buff, TFT_DURATION),
			116680, -- Thunder Focus Tea
			"group",
			"UNIT_AURA",
			function(units, model)
				local count, minExpiration = 0, math.huge
				for unit in pairs(units.group) do
					local name, _, _, _, _, _, expiration = UnitAura(unit, buff, nil, "HELPFUL PLAYER")
					if name then
						count, minExpiration = count + 1, min(minExpiration, expiration)
					end
				end
				if count >= TFT_COUNT and minExpiration-GetTime() < TFT_DURATION then
					model.hint, model.expiration = true, minExpiration
				end
			end
		},
		Configure {
			"Uplift",
			format(addon.L["Suggest when total effective healing would be at least %d times the base healing."], UPLIFT_THRESHOLD),
			116670, -- Uplift
			"group",
			{ "UNIT_AURA", "UNIT_HEALTH", "UNIT_HEALTH_MAX" },
			function(units, model)
				-- Rough estimation at level 90
				local heal = 1.2 * ((7210+8379)/2 + 0.68 * GetSpellBonusHealing())
				local totalHeal = 0
				for unit in pairs(units.group) do
					if UnitAura(unit, buff, nil, "HELPFUL PLAYER") then
						totalHeal = totalHeal + min(heal, UnitHealthMax(unit) - UnitHealth(unit))
					end
				end
				if totalHeal >= UPLIFT_THRESHOLD * heal then
					model.hint = true
				end
			end
		},
		Configure {
			"Statue",
			addon.L["Show good border and remaining time of your summoned statue."],
			{
				115313, -- Summon Jade Serpent Statue
				115315, -- Summon Black Ox Statue
			},
			"player",
			"PLAYER_TOTEM_UPDATE",
			function(units, model)
				local found, _, startTime, duration = GetTotemInfo(1)
				if found then
					model.highlight, model.expires = "good", startTime + duration
				else
					model.hint = true
				end
			end,
		},
	}

end)
