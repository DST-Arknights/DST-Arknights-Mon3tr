return ArkMakeFx(
  {
    name = "mon3tr_heal_fx",
    bank = "carnival_sparkle",
    build = "carnival_sparkle",
    anim = "sparkle",
    sound = "summerevent/cannon/fire2",
    fn = function(inst)
      inst.AnimState:SetFinalOffset(1)
      -- 设置淡绿色
      inst.AnimState:SetMultColour(0.5, 1, 0.5, 1)
    end,
  })
