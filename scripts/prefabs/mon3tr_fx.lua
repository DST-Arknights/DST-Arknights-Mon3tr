local fxs = { {
  name = "mon3tr_heal_fx",
  bank = "carnival_sparkle",
  build = "carnival_sparkle",
  anim = "sparkle",
  sound = "summerevent/cannon/fire2",
  fn = function(inst)
    inst.AnimState:SetFinalOffset(1)
    -- 设置淡绿色
    inst.AnimState:SetMultColour(0.5, 1, 0.5, 1)
    -- 播放速度1.2倍
    inst.AnimState:SetDeltaTimeMultiplier(1.5)
  end,
}, {
  name = "mon3tr_wrath_fx",
  bank = "mon3tr_wrath_fx",
  build = "mon3tr_wrath_fx",
  anim = "idle",
  loop = true,
} }

local fxPrefabs = {}
for i, v in pairs(fxs) do
  table.insert(fxPrefabs, ArkMakeFx(v))
end

return unpack(fxPrefabs)
