GLOBAL.setmetatable(env, {
  __index = function(t, k)
    return GLOBAL.rawget(GLOBAL, k)
  end
})

PrefabFiles = {"mon3tr", "mon3tr_none", "construct_sword", "mon3tr_self_repair_buff", "mon3tr_tactical_synergy_buff", "mon3tr_heal_chain_fx", "mon3tr_fx", "construct_beacon", "construct_claw", "construct_armor"}
Assets = {
  Asset("ATLAS", "bigportraits/mon3tr.xml"),
  Asset("ATLAS", "images/saveslot_portraits/mon3tr.xml"),
  Asset("ATLAS", "images/selectscreen_portraits/mon3tr.xml"),
  Asset("ATLAS", "images/selectscreen_portraits/mon3tr_silho.xml"),
  Asset("ATLAS", "images/avatars/avatar_mon3tr.xml"),
  Asset("ATLAS", "images/avatars/avatar_ghost_mon3tr.xml"),
  Asset("ATLAS", "images/avatars/self_inspect_mon3tr.xml"),
  Asset("ATLAS", "images/names_mon3tr.xml"),
  Asset("ATLAS", "images/names_gold_mon3tr.xml"),
  Asset("SOUNDPACKAGE", "sound/mon3tr.fev"),
  Asset("SOUND", "sound/mon3tr.fsb"),
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

TUNING.MON3TR_ELITE = {{
    self_repair_attack_multiplier = 1.03,
  },
  {
    tactical_synergy_passive_attack_speed_multiplier = 1.1,
    self_repair_attack_multiplier = 1.05,
  },
  {
    tactical_synergy_passive_attack_speed_multiplier = 1.2,
    self_repair_attack_multiplier = 1.15,
  }
}

modimport("modmain/mon3tr")
modimport("modmain/mon3tr_skill")
local mon3tr_voice = require "mon3tr_voice"
RegisterVoice("mon3tr", mon3tr_voice)
