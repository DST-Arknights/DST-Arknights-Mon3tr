-- 按新素材的可见范围校准到原治疗特效的覆盖尺寸。
local HEAL_NORMAL_SCALE = 4.5
local HEAL_SKILL_SCALE = 4
local HEAL_PARTICLE_SCALE = 8
local HEAL_HEIGHT = 1
local HEAL_PARTICLE_HEIGHT = 0
local HEAL_ANIMATION_SPEED = 2

local function ConfigureHealFx(inst, scale, finaloffset, height)
  inst.Transform:SetPosition(0, height, 0)
  inst.AnimState:SetScale(scale, scale, scale)
  inst.AnimState:SetDeltaTimeMultiplier(HEAL_ANIMATION_SPEED)
  inst.AnimState:SetLightOverride(1)
  inst.AnimState:SetFinalOffset(finaloffset)
end

local fxs = { {
  name = "mon3tr_heal_fx",
  bank = "mon3tr_heal_target_01",
  build = "mon3tr_heal_target_01",
  anim = "hit",
  bloom = true,
  scale_with_parent_size = true,
  fn = function(inst)
    ConfigureHealFx(inst, HEAL_NORMAL_SCALE, 1, HEAL_HEIGHT)
  end,
}, {
  name = "mon3tr_skill_heal_fx",
  bank = "mon3tr_heal_target_02",
  build = "mon3tr_heal_target_02",
  anim = "hit",
  bloom = true,
  scale_with_parent_size = true,
  fn = function(inst)
    ConfigureHealFx(inst, HEAL_SKILL_SCALE, 1, HEAL_HEIGHT)
  end,
}, {
  name = "mon3tr_heal_fx_2",
  bank = "mon3tr_s3_heal_particles",
  build = "mon3tr_s3_heal_particles",
  anim = "heal",
  bloom = true,
  scale_with_parent_size = true,
  fn = function(inst)
    ConfigureHealFx(inst, HEAL_PARTICLE_SCALE, 2, HEAL_PARTICLE_HEIGHT)
  end,
}, {
  name = "mon3tr_wrath_fx",
  bank = "mon3tr_wrath_fx",
  build = "mon3tr_wrath_fx",
  anim = "idle",
  loop = true,
}, {
  name = "construct_claw_attack_shockwave_fx",
  bank = "construct_claw_attack_shockwave_fx",
  build = "construct_claw_attack_shockwave_fx",
  anim = "boom",
  fn = function(inst)
    -- 地面播放
    inst.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    -- 随机角度
    inst.Transform:SetRotation(math.random() * 360)
    -- 脚底层级
    inst.AnimState:SetLayer(LAYER_BACKGROUND)
    -- 1级排序
    inst.AnimState:SetSortOrder(1)
  end,
} }

local fxPrefabs = {}
for i, v in pairs(fxs) do
  table.insert(fxPrefabs, ArkMakeFx(v))
end

return unpack(fxPrefabs)
