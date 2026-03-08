GLOBAL.setmetatable(env, {
  __index = function(t, k)
    return GLOBAL.rawget(GLOBAL, k)
  end
})

PrefabFiles = {"mon3tr", "mon3tr_none", "construct_sword", "mon3tr_self_repair_buff", "mon3tr_tactical_synergy_buff", "mon3tr_heal_chain_fx", "mon3tr_heal_fx"}
Assets = {
  Asset("ATLAS", "bigportraits/mon3tr.xml"),
  Asset("ATLAS", "images/saveslot_portraits/mon3tr.xml"),
  Asset("ATLAS", "images/selectscreen_portraits/mon3tr.xml"),
  Asset("ATLAS", "images/selectscreen_portraits/mon3tr_silho.xml"),
  Asset("ATLAS", "images/map_icons/mon3tr.xml"),
  Asset("ATLAS", "images/avatars/avatar_mon3tr.xml"),
  Asset("ATLAS", "images/avatars/avatar_ghost_mon3tr.xml"),
  Asset("ATLAS", "images/avatars/self_inspect_mon3tr.xml"),
  Asset("ATLAS", "images/names_mon3tr.xml"),
  Asset("ATLAS", "images/names_gold_mon3tr.xml"),
}

AddMinimapAtlas("images/map_icons/mon3tr.xml")

MergePOFile('languages/mon3tr_chinese_s.po', LOC.GetLocaleCode(LANGUAGE.CHINESE_S), true)
ArkLogger:DeclareLogger('TRACE', 'Mon3tr')

local mon3tr_starting_items = {"construct_sword", "ark_backpack"}
TUNING.GAMEMODE_STARTING_ITEMS.DEFAULT.MON3TR = mon3tr_starting_items
TUNING.GAMEMODE_STARTING_ITEMS.LAVAARENA.MON3TR = mon3tr_starting_items
TUNING.GAMEMODE_STARTING_ITEMS.QUAGMIRE.MON3TR = mon3tr_starting_items

TUNING.MON3TR_HEALTH = 150
TUNING.MON3TR_HUNGER = 150
TUNING.MON3TR_SANITY = 200

local skin_modes = {
    { 
        type = "ghost_skin",
        anim_bank = "ghost",
        idle_anim = "idle", 
        scale = 0.75, 
        offset = { 0, -25 } 
    },
}
AddModCharacter('mon3tr', 'FEMALE', skin_modes)
local skillConfig = require "mon3tr_skill_config"
AddSkillLevelUpRecipes('mon3tr', skillConfig.skills)
