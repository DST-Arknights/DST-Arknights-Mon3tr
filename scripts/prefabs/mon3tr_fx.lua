local fxs = { {
  name = "mon3tr_heal_fx",
  bank = "mon3tr_heal_fx",
  build = "mon3tr_heal_fx",
  anim = "idle",
  scale_with_parent_size = true,
  fn = function(inst)
    inst.AnimState:SetDeltaTimeMultiplier(0.3)
    inst.AnimState:SetFinalOffset(1)
    inst.Transform:SetPosition(0, 1.5, 0)
    inst.AnimState:SetScale(3.3, 3.3, 3.3)
    inst.AnimState:SetMultColour(1, 1, 1, 0.95)
  end,
}, {
  name = "mon3tr_heal_fx_2",
  bank = "mon3tr_heal_fx_2",
  build = "mon3tr_heal_fx_2",
  anim = "idle",
  scale_with_parent_size = true,
  fn = function(inst)
    inst.AnimState:SetDeltaTimeMultiplier(0.5)
    inst.AnimState:SetFinalOffset(2)
    inst.Transform:SetPosition(0, 1.5, 0)
    inst.AnimState:SetScale(6, 6, 6)
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
