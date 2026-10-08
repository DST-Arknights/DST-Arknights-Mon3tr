GLOBAL.setmetatable(env, {
  __index = function(t, k)
    return GLOBAL.rawget(GLOBAL, k)
  end
})

assert(ARK_ITEM_PACKAGE_LOADED, "请安装前置模组: 源枢\n please install the required mod: Arknights: Nexus\n[https://steamcommunity.com/sharedfiles/filedetails/?id=3677284770]")

PrefabFiles = {"mon3tr", "mon3tr_none", "construct_sword", "construct_sword_blade_fx", "mon3tr_buff", "mon3tr_heal_chain_fx", "mon3tr_fx", "construct_beacon", "construct_claw", "mon3tr_reticule"}
Assets = {
  Asset("ATLAS", "bigportraits/mon3tr.xml"),
  Asset("ATLAS", "bigportraits/mon3tr_none.xml"),
  Asset("IMAGE", "bigportraits/mon3tr.tex"),
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
RegisterArkBigPortraitAnim("mon3tr", {
  asset = "anim/mon3tr_bigportrait.zip",
  bank = "mon3tr_bigportrait",
  build = "mon3tr_bigportrait",
  anim = "idle_winter_forest",
  scale = 1,
  offset = { 0, 0 },
})
AddMinimapAtlas("images/map_icons/mon3tr.xml")

RegisterPOFile(GetModConfigData("language"), {
  en = 'languages/mon3tr_english.po',
  zh = 'languages/mon3tr_chinese_s.po',
})
ArkLogger:DeclareLogger('TRACE', 'Mon3tr')

local mon3tr_starting_items = {"construct_sword"}
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

local Elite1Ingredients = {
  Ingredient("ark_gold", 30000),
  Ingredient("ark_item_mtl_sl_g2", 8),
  Ingredient("ark_item_mtl_sl_ketone2", 3),
}

local Elite2Ingredients = {
  Ingredient("ark_gold", 180000),
  Ingredient("ark_item_mtl_sl_oeu", 4),
  Ingredient("ark_item_mtl_sl_pgel4", 5),
}

-- 未开启方舟材料掉落时，使用原版的晶体与治疗材料。
if not TUNING.ARK_CONFIG.enable_all_materials_drop then
  Elite1Ingredients = {
    Ingredient("goldnugget", 30),
    Ingredient("papyrus", 5),
    Ingredient("moonrocknugget", 8),
    Ingredient("healingsalve", 3),
  }
  Elite2Ingredients = {
    Ingredient("goldnugget", 180),
    Ingredient("papyrus", 8),
    Ingredient("greengem", 4),
    Ingredient("bandage", 5),
  }
end

AddEliteLevelUpRecipes("mon3tr", {{
  ingredients = Elite1Ingredients,
  atlas = "images/ark_elite.xml",
  image = "elite1.tex",
}, {
  ingredients = Elite2Ingredients,
  atlas = "images/ark_elite.xml",
  image = "elite2.tex",
}})

modimport("modmain/mon3tr")
modimport("modmain/mon3tr_skill")
RegisterVoice("mon3tr", "languages/mon3tr_voice", { voice_lang = "jp" })
