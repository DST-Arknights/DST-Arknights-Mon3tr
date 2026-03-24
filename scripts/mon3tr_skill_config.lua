local ARK_CONSTANTS = require "ark_constants"

local skillConfig = {
  elites = {
    {
      self_repair_attack_multiplier = 1.03,
    },
    {
      tactical_synergy_passive_attack_speed_multiplier = 1.1,
      self_repair_attack_multiplier = 1.05,
    },
    {
      tactical_synergy_passive_attack_speed_multiplier = 1.2,
      self_repair_attack_multiplier = 1.15,
    },
  },
  skills = { {
    id = "skill1",
    name = STRINGS.UI.MON3TR_SKILL.NAME[1],
    energyRecoveryMode = ARK_CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK,
    activationMode = ARK_CONSTANTS.ACTIVATION_MODE.AUTO,
    lockedDesc = STRINGS.UI.MON3TR_SKILL.LOCKED_DESC[1],
    atlas = "images/ui_mon3tr_skill.xml",
    image = "skill1_64.tex",
    levels = { {
      activationEnergy = 5,
      maxActivationStacks = 3,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][1],
      config = { healRate = 1.1, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 5) }
    }, {
      activationEnergy = 5,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][2],
      config = { healRate = 1.2, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 5), Ingredient("ark_item_mtl_sl_boss1", 4), Ingredient("ark_item_mtl_sl_rush1", 4) }
    }, {
      activationEnergy = 5,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][3],
      config = { healRate = 1.25, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_g2", 7) }
    }, {
      activationEnergy = 5,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][4],
      config = { healRate = 1.35, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 8), Ingredient("ark_item_mtl_sl_strg2", 4), Ingredient("ark_item_mtl_sl_ketone2", 4) }
    }, {
      activationEnergy = 5,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][5],
      config = { healRate = 1.5, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_strg3", 7) }
    }, {
      activationEnergy = 5,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][6],
      config = { healRate = 1.6, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_ccf", 5), Ingredient("ark_item_mtl_sl_rush3", 3) }
    }, {
      activationEnergy = 3,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][7],
      config = { healRate = 1.7, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_zyk", 4), Ingredient("ark_item_mtl_sl_g3", 10) }
    }, {
      activationEnergy = 3,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][8],
      config = { healRate = 1.8, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 12), Ingredient("ark_item_mtl_sl_htt", 4), Ingredient("ark_item_mtl_sl_pgel4", 9) }
    }, {
      activationEnergy = 3,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][9],
      config = { healRate = 1.9, healChainCount = 4 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 15), Ingredient("ark_item_mtl_sl_ds", 6), Ingredient("ark_item_mtl_sl_pg2", 6) }
    }, {
      activationEnergy = 2,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][10],
      config = { healRate = 2.0, healChainCount = 4 }
    }, }
  }, {
    id = "skill2",
    name = STRINGS.UI.MON3TR_SKILL.NAME[2],
    energyRecoveryMode = ARK_CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK,
    activationMode = ARK_CONSTANTS.ACTIVATION_MODE.MANUAL,
    lockedDesc = STRINGS.UI.MON3TR_SKILL.LOCKED_DESC[2],
    hotkey = KEY_X,
    atlas = "images/ui_mon3tr_skill.xml",
    image = "skill2_64.tex",
    levels = { {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][1],
      config = { healRate = 1.5, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.5 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 5) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][2],
      config = { healRate = 1.6, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.6 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 5), Ingredient("ark_item_mtl_sl_boss1", 4), Ingredient("ark_item_mtl_sl_rush1", 4) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][3],
      config = { healRate = 1.7, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.7 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_g2", 7) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][4],
      config = { healRate = 1.8, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.8 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 8), Ingredient("ark_item_mtl_sl_strg2", 4), Ingredient("ark_item_mtl_sl_ketone2", 4) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][5],
      config = { healRate = 2, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_strg3", 7) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][6],
      config = { healRate = 2.1, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.1 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_ccf", 5), Ingredient("ark_item_mtl_sl_rush3", 3) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][7],
      config = { healRate = 2.3, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.3 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_iron4", 4), Ingredient("ark_item_mtl_sl_pg1", 3) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][8],
      config = { healRate = 2.5, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.5 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 12), Ingredient("ark_item_mtl_sl_rs", 4),
        -- 新材料 手性屈光体  Ingredient("", 9) 
      }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][9],
      config = { healRate = 2.6, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.6 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 15), Ingredient("ark_item_mtl_sl_shj", 6), Ingredient("ark_item_mtl_sl_g4", 2) }
    }, {
      activationEnergy = 15,
      buffDuration = 30,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][10],
      config = { healRate = 2.8, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.8 }
    }, }
  }, {
    id = "skill3",
    name = STRINGS.UI.MON3TR_SKILL.NAME[3],
    energyRecoveryMode = ARK_CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK,
    activationMode = ARK_CONSTANTS.ACTIVATION_MODE.MANUAL,
    lockedDesc = STRINGS.UI.MON3TR_SKILL.LOCKED_DESC[3],
    hotkey = KEY_C,
    atlas = "images/ui_mon3tr_skill.xml",
    image = "skill3_64.tex",
    levels = { {
      activationEnergy = 1, -- TODO: 15
      buffDuration = 125, -- TODO: 25
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][1],
      config = { healChainCount = 3, attack_damage_multiplier = 2, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 2.2, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 5) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][2],
      config = { healChainCount = 3, attack_damage_multiplier = 2.2, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 2.35, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 5), Ingredient("ark_item_mtl_sl_boss1", 4), Ingredient("ark_item_mtl_sl_rush1", 4) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][3],
      config = { healChainCount = 3, attack_damage_multiplier = 2.3, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 2.5, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_g2", 7) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][4],
      config = { healChainCount = 3, attack_damage_multiplier = 2.5, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 2.65, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill1", 8), Ingredient("ark_item_mtl_sl_strg2", 4), Ingredient("ark_item_mtl_sl_ketone2", 4) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][5],
      config = { healChainCount = 3, attack_damage_multiplier = 2.6, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 2.8, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_strg3", 7) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
        desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][6],
      config = { healChainCount = 3, attack_damage_multiplier = 2.7, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 2.95, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_ccf", 5), Ingredient("ark_item_mtl_sl_rush3", 3) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][7],
      config = { healChainCount = 3, attack_damage_multiplier = 2.8, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 3.1, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_plcf", 4), Ingredient("ark_item_mtl_sl_iam3", 7) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][8],
      config = { healChainCount = 3, attack_damage_multiplier = 3, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 3.25, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 12), Ingredient("ark_item_mtl_sl_xwb", 4), Ingredient("ark_item_mtl_sl_rma7024", 7) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][9],
      config = { healChainCount = 3 , attack_damage_multiplier = 3.1, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 3.4, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
      nextLevelIngredients = { Ingredient("ark_item_mtl_skill3", 15), Ingredient("ark_item_mtl_sl_oeu", 6), Ingredient("ark_item_mtl_sl_iam4", 1) }
    }, {
      activationEnergy = 15,
      buffDuration = 25,
      desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][9],
      config = { healChainCount = 3, attack_damage_multiplier = 3.3, health_bonus = 5000, lose_health_per_second = 80, skill3_light_radius = 3.55, skill3_light_falloff = 0.12, skill3_light_intensity = 0.95, skill3_light_green_fade_duration = 60 },
    }}
  } }
}
return skillConfig
