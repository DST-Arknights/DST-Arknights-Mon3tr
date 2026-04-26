local MakePlayerCharacter = require "prefabs/player_common"

local assets =
{
  Asset("SCRIPT", "scripts/prefabs/player_common.lua"),
  Asset("ATLAS", "images/ui_mon3tr_skill.xml"),
  Asset("ATLAS", "images/map_icons/mon3tr.xml"),
}

local start_inv = { "construct_sword", "ark_backpack" }
local prefabs = FlattenTree(start_inv, true)


-- When the character is revived from human
local function onbecamehuman(inst)
  -- Set speed when not a ghost (optional)
  inst.components.locomotor:SetExternalSpeedMultiplier(inst, "mon3tr_speed_mod", 1)
end

local function onbecameghost(inst)
  -- Remove speed modifier when becoming a ghost
  inst.components.locomotor:RemoveExternalSpeedMultiplier(inst, "mon3tr_speed_mod")
end

-- When loading or spawning the character
local function Onload(inst)
  inst:ListenForEvent("ms_respawnedfromghost", onbecamehuman)
  inst:ListenForEvent("ms_becameghost", onbecameghost)

  if inst:HasTag("playerghost") then
    onbecameghost(inst)
  else
    onbecamehuman(inst)
  end
end

local function OnNewSpawn(inst)
  inst.components.ark_skill:AddSkill("mon3tr_skill1")
  inst.components.ark_skill:AddSkill("mon3tr_skill2")
  inst.components.ark_skill:AddSkill("mon3tr_skill3")
  Onload(inst)
end

local function OnApplyElite(inst, elite)
end

-- This initializes for both the server and client. Tags can be added here.
local common_postinit = function(inst)
  -- Minimap icon
  inst.MiniMapEntity:SetIcon("mon3tr.tex")
end

-- This initializes for the server only. Components are added here.
local master_postinit = function(inst)

  -- inst.AnimState:AddOverrideBuild("mon3tr_attacks")

  -- choose which sounds this character will play
  inst.soundsname = "willow"

  -- Uncomment if "wathgrithr"(Wigfrid) or "webber" voice is used
  -- inst.talker_path_override = "dontstarve_DLC001/characters/"

  -- Stats	
  inst.components.health:SetMaxHealth(TUNING.MON3TR_HEALTH)
  inst.components.hunger:SetMax(TUNING.MON3TR_HUNGER)
  inst.components.sanity:SetMax(TUNING.MON3TR_SANITY)

  -- Damage multiplier (optional)
  -- inst.components.combat:SetDefaultDamage(10)

  -- Hunger rate (optional)
  inst.components.hunger.hungerrate = 1 * TUNING.WILSON_HUNGER_RATE

  -- Skill
  inst:AddComponent("ark_elite")
  inst.components.ark_elite:SetRarity(6)
  inst.components.ark_elite:SetOnApplyElite(OnApplyElite)
  inst.components.ark_elite:SetMaxHealthBonus(100)
  inst.components.ark_elite:SetMaxDamageBonus(20)
  inst:AddComponent("ark_skill")
  inst.components.ark_skill:DeclareBuiltinSkill("mon3tr_skill1", {
    requiredElite = 1,
  })
  inst.components.ark_skill:DeclareBuiltinSkill("mon3tr_skill2", {
    requiredElite = 2,
  })
  inst.components.ark_skill:DeclareBuiltinSkill("mon3tr_skill3", {
    requiredElite = 3,
  })
  inst:AddComponent("ark_currency")
  inst.OnLoad = Onload
  inst.OnNewSpawn = OnNewSpawn

end

return MakePlayerCharacter("mon3tr", prefabs, assets, common_postinit, master_postinit, start_inv)
