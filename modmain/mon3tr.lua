local NORMAL_ATTACK_FRAME = 8 * FRAMES
local MON3TR_SKILL3_ATTACK_FRAME = 21 * FRAMES

local function Chronological(a, b)
	return a.time < b.time
end

AddStategraphPostInit("wilson", function(sg)
  local OldAttackOnEnter = sg.states["attack"].onenter
  sg.states["attack"].onenter = function(inst, ...)
    OldAttackOnEnter(inst, ...)
    if inst.components.mon3tr_skill and inst.components.mon3tr_skill:IsSkill3Activating() then
      -- TODO: 修改这里的动画即可
      inst.AnimState:PlayAnimation("deploytoss_lag")
      -- inst.AnimState:PushAnimation("deploytoss_pre")
			inst.AnimState:PushAnimation("atk", false)
      inst.SoundEmitter:KillAllSounds()
      local comp = inst.components.mon3tr_skill
      if comp then
        if comp.f_weapon then
          comp.f_weapon.AnimState:PlayAnimation("f_attack", false)
          comp.f_weapon.AnimState:PushAnimation("f_idle", true)
        end
        if comp.b_weapon then
          comp.b_weapon.AnimState:PlayAnimation("b_attack", false)
          comp.b_weapon.AnimState:PushAnimation("b_idle", true)
        end
      end
    end
  end
  local normal_attack_fn = nil
  -- 遍历timeline, 替换第六帧攻击函数
  for i, v in ipairs(sg.states["attack"].timeline) do
    if v.time == NORMAL_ATTACK_FRAME then
      normal_attack_fn = v.fn
      sg.states["attack"].timeline[i].fn = function(inst)
        if inst.components.mon3tr_skill and inst.components.mon3tr_skill:IsSkill3Activating() then
          ArkLogger:Debug("Skill3 is activating, skip normal attack")
          return
        end
        normal_attack_fn(inst)
      end
    end
  end
  -- 插入新的技能攻击帧
  if normal_attack_fn then
    table.insert(sg.states["attack"].timeline, TimeEvent(MON3TR_SKILL3_ATTACK_FRAME, function(inst)
      if inst.components.mon3tr_skill and inst.components.mon3tr_skill:IsSkill3Activating() then
        -- 震荡波特效
        local fx = SpawnPrefab("construct_claw_attack_shockwave_fx")
        fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
        normal_attack_fn(inst)
      end
    end))
		table.sort(sg.states["attack"].timeline, Chronological)
  end
  local OldAttackOnExit = sg.states["attack"].onexit
  sg.states["attack"].onexit = function(inst, ...)
    OldAttackOnExit(inst, ...)
    local comp = inst.components.mon3tr_skill
    if comp then
      if comp.f_weapon then
        comp.f_weapon.AnimState:PlayAnimation("f_idle", true)
      end
      if comp.b_weapon then
        comp.b_weapon.AnimState:PlayAnimation("b_idle", true)
      end
    end
  end
end)

AddStategraphPostInit("wilson_client", function(sg)
  local OldAttackOnEnter = sg.states["attack"].onenter
  sg.states["attack"].onenter = function(inst, ...)
    OldAttackOnEnter(inst, ...)
    if inst.components.mon3tr_skill and inst.components.mon3tr_skill:IsSkill3Activating() then
      -- TODO: 修改这里的动画即可
      inst.AnimState:PlayAnimation("deploytoss_lag")
      -- inst.AnimState:PushAnimation("deploytoss_pre")
      inst.AnimState:PushAnimation("atk", false)
      inst.SoundEmitter:KillAllSounds()
    end
  end
end)


local function ToggleOffPhysics(inst)
  inst.sg.statemem.isphysicstoggle = true
  inst.Physics:SetCollisionMask(COLLISION.GROUND)
end

local function ToggleOnPhysics(inst)
  inst.sg.statemem.isphysicstoggle = nil
  inst.Physics:SetCollisionMask(
    COLLISION.WORLD,
    COLLISION.OBSTACLES,
    COLLISION.SMALLOBSTACLES,
    COLLISION.CHARACTERS,
    COLLISION.GIANTS
  )
end

local SUPERJUMP_COLOR_R = 75 / 255
local SUPERJUMP_COLOR_G = 110 / 255
local SUPERJUMP_COLOR_B = 85 / 255
local SUPERJUMP_FLASH_SIDE_MAX = 0x23 / 255

-- 1) 起手：mon3tr_superjump_pre
AddStategraphState("wilson", State {
  name = "mon3tr_superjump_pre",
  tags = { "aoe", "doing", "busy", "nointerrupt", "nomorph", "pausepredict", "mon3tr_skill" },

  onenter = function(inst, data)
    inst.components.locomotor:Stop()
    inst.AnimState:PlayAnimation("superjump_pre")
    inst.AnimState:PushAnimation("superjump_lag")
    inst.sg.statemem.data = data     -- data.targetpos
    if inst.components.playercontroller ~= nil then
      inst.components.playercontroller:RemotePausePrediction()
    end
  end,

  events = {
    EventHandler("animover", function(inst)
      if inst.AnimState:AnimDone() then
        if inst.AnimState:IsCurrentAnimation("superjump_lag") then
          inst.sg:GoToState("mon3tr_superjump", inst.sg.statemem.data)
        else
          inst.sg:GoToState("idle")
        end
      end
    end),
  },
})

-- 2) 空中段
AddStategraphState("wilson", State {
  name = "mon3tr_superjump",
  tags = { "aoe", "doing", "busy", "nointerrupt", "pausepredict", "nomorph", "mon3tr_skill" },

  onenter = function(inst, data)
    -- 有特效删除特效
    if inst._wrath_fx then
      inst._wrath_fx:Remove()
      inst._wrath_fx = nil
    end
    if inst.components.mon3tr_skill then
      inst.components.mon3tr_skill:RemoveSkill3Weapon()
    end
    if data ~= nil then
      inst.sg.statemem.data = data
      ToggleOffPhysics(inst)
      inst.AnimState:PlayAnimation("superjump")
      inst.AnimState:SetMultColour(.8, .8, .8, 1)
      inst.components.colouradder:PushColour("superjump", .1, .1, .1, 0)

      inst.sg.statemem.data.startingpos = inst:GetPosition()
      if inst.sg.statemem.data.startingpos.x ~= data.targetpos.x
          or inst.sg.statemem.data.startingpos.z ~= data.targetpos.z then
        inst:ForceFacePoint(data.targetpos:Get())
      end

      inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt", nil, .4)
      inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
      local x, y, z = inst.sg.statemem.data.startingpos:Get()
      inst.components.mon3tr_skill:SpawnConstructBeaconAt(x, y, z)
      inst.sg:SetTimeout(0.5)
      return
    end
    inst.sg:GoToState("idle", true)
  end,

  onupdate = function(inst)
    if inst.sg.statemem.dalpha ~= nil and inst.sg.statemem.alpha > 0 then
      inst.sg.statemem.dalpha = math.max(.1, inst.sg.statemem.dalpha - .1)
      inst.sg.statemem.alpha  = math.max(0, inst.sg.statemem.alpha - inst.sg.statemem.dalpha)
      inst.AnimState:SetMultColour(0, 0, 0, inst.sg.statemem.alpha)
    end
  end,

  timeline = {
    TimeEvent(FRAMES, function(inst)
      inst.DynamicShadow:Enable(false)
      inst.sg:AddStateTag("noattack")
      inst.components.health:SetInvincible(true)
      inst.AnimState:SetMultColour(.5, .5, .5, 1)
      inst.components.colouradder:PushColour("superjump", SUPERJUMP_COLOR_R, SUPERJUMP_COLOR_G, SUPERJUMP_COLOR_B, 0)
    end),
    TimeEvent(2 * FRAMES, function(inst)
      inst.AnimState:SetMultColour(0, 0, 0, 1)
      inst.components.colouradder:PushColour("superjump", SUPERJUMP_COLOR_R * .9, SUPERJUMP_COLOR_G * .9,
        SUPERJUMP_COLOR_B * .9, 0)
    end),
    TimeEvent(3 * FRAMES, function(inst)
      inst.sg.statemem.alpha  = 1
      inst.sg.statemem.dalpha = .5
    end),
  },

  events = {
    EventHandler("animover", function(inst)
      if inst.AnimState:AnimDone() then
        inst:Hide()
        inst.Physics:Teleport(inst.sg.statemem.data.targetpos.x, 0, inst.sg.statemem.data.targetpos.z)
      end
    end),
  },

  ontimeout = function(inst)
    inst.sg.statemem.superjump = true
    inst.sg:GoToState("mon3tr_superjump_pst", inst.sg.statemem.data)
  end,

  onexit = function(inst)
    if not inst.sg.statemem.superjump then
      inst.components.health:SetInvincible(false)
      if inst.sg.statemem.isphysicstoggle then
        ToggleOnPhysics(inst)
      end
      inst.components.colouradder:PopColour("superjump")
      inst.AnimState:SetMultColour(1, 1, 1, 1)
      inst.DynamicShadow:Enable(true)
    end
    -- 重新生成特效
    if not inst._wrath_fx then
      inst._wrath_fx = SpawnPrefab("mon3tr_wrath_fx")
      inst._wrath_fx.entity:SetParent(inst.entity)
    end
    if inst.components.mon3tr_skill then
      inst.components.mon3tr_skill:SetupSkill3Weapon()
    end
    inst:Show()
  end,
})

-- 3) 落地段
AddStategraphState("wilson", State {
  name = "mon3tr_superjump_pst",
  tags = { "aoe", "doing", "busy", "noattack", "pausepredict", "nomorph", "mon3tr_skill" },

  onenter = function(inst, data)
    if data ~= nil then
      inst.sg.statemem.startingpos     = data.startingpos
      inst.sg.statemem.isphysicstoggle = data.isphysicstoggle

      if inst.sg.statemem.startingpos ~= nil then
        inst.AnimState:PlayAnimation("superjump_land")
        inst.AnimState:SetMultColour(.4, .4, .4, .4)
        inst.sg.statemem.targetpos = data.targetpos
        inst.sg.statemem.flash = 0

        if not inst.sg.statemem.isphysicstoggle then
          ToggleOffPhysics(inst)
        end
        inst.Physics:Teleport(data.targetpos.x, 0, data.targetpos.z)
        inst.components.health:SetInvincible(true)
        inst.sg:SetTimeout(22 * FRAMES)
        return
      end
    end
    inst.sg:GoToState("idle", true)
  end,

  onupdate = function(inst)
    if inst.sg.statemem.flash > 0 then
      inst.sg.statemem.flash = math.max(0, inst.sg.statemem.flash - .1)
      local side = math.min(SUPERJUMP_FLASH_SIDE_MAX, inst.sg.statemem.flash)
      inst.components.colouradder:PushColour("superjump", side, SUPERJUMP_COLOR_G, side, 0)
    end
  end,

  timeline = {
    TimeEvent(FRAMES, function(inst)
      inst.SoundEmitter:PlaySound("dontstarve/wilson/attack_weapon")
      inst.AnimState:SetMultColour(.7, .7, .7, .7)
      inst.components.colouradder:PushColour("superjump", SUPERJUMP_COLOR_R, SUPERJUMP_COLOR_G, SUPERJUMP_COLOR_B, 0)
    end),
    TimeEvent(2 * FRAMES, function(inst)
      inst.AnimState:SetMultColour(.9, .9, .9, .9)
      inst.components.colouradder:PushColour("superjump", SUPERJUMP_COLOR_R * .95, SUPERJUMP_COLOR_G * .95,
        SUPERJUMP_COLOR_B * .95, 0)
    end),
    TimeEvent(3 * FRAMES, function(inst)
      inst.AnimState:SetMultColour(1, 1, 1, 1)
      inst.components.colouradder:PushColour("superjump", SUPERJUMP_COLOR_R * .9, SUPERJUMP_COLOR_G * .9,
        SUPERJUMP_COLOR_B * .9, 0)
      inst.DynamicShadow:Enable(true)
    end),
    TimeEvent(4 * FRAMES, function(inst)
      inst.components.colouradder:PushColour("superjump", SUPERJUMP_COLOR_R * .85, SUPERJUMP_COLOR_G * .85,
        SUPERJUMP_COLOR_B * .85, 0)
      inst.components.bloomer:PushBloom("superjump", "shaders/anim.ksh", -2)
      ToggleOnPhysics(inst)
      ShakeAllCameras(CAMERASHAKE.VERTICAL, .7, .025, 1.25, inst, 0x28)
      inst.sg.statemem.flash = 1.3
      inst.sg:RemoveStateTag("noattack")
      inst.components.health:SetInvincible(false)
      local targetpos = inst.sg.statemem.targetpos
      SpawnPrefab("groundpoundring_fx").Transform:SetPosition(targetpos.x, 0, targetpos.z)

      SpawnPrefab("pine_needles_chop").Transform:SetPosition(targetpos.x, 0, targetpos.z)
      SpawnPrefab("boss_ripple_fx").Transform:SetPosition(targetpos.x, 0, targetpos.z)
      -- SpawnPrefab("groundpound_fx").Transform:SetPosition(targetpos.x, 0, targetpos.z)

      inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt")
      inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof")
    end),
    TimeEvent(8 * FRAMES, function(inst)
      inst.components.bloomer:PopBloom("superjump")
    end),
    TimeEvent(0x13 * FRAMES, PlayFootstep),
  },

  ontimeout = function(inst)
    inst.sg:GoToState("idle", true)
  end,

  events = {
    EventHandler("animover", function(inst)
      if inst.AnimState:AnimDone() then
        inst.sg:GoToState("idle")
      end
    end),
  },

  onexit = function(inst)
    if inst.sg.statemem.isphysicstoggle then
      ToggleOnPhysics(inst)
    end
    inst.AnimState:SetMultColour(1, 1, 1, 1)
    inst.DynamicShadow:Enable(true)
    inst.components.health:SetInvincible(false)
    inst.components.bloomer:PopBloom("superjump")
    inst.components.colouradder:PopColour("superjump")
  end,
})

-- 技能3结束返程：轻量版回跳（无起手、无染色、无震屏）
AddStategraphState("wilson", State {
  name = "mon3tr_return_jump",
  tags = { "aoe", "doing", "busy", "nointerrupt", "pausepredict", "nomorph", "mon3tr_skill" },

  onenter = function(inst, data)
    if data == nil or data.targetpos == nil then
      inst.sg:GoToState("idle", true)
      return
    end

    inst.components.locomotor:Stop()
    inst.sg.statemem.data = data
    inst.sg.statemem.startingpos = inst:GetPosition()

    if inst.sg.statemem.startingpos.x ~= data.targetpos.x
        or inst.sg.statemem.startingpos.z ~= data.targetpos.z then
      inst:ForceFacePoint(data.targetpos:Get())
    end

    ToggleOffPhysics(inst)
    inst.DynamicShadow:Enable(false)
    inst.components.health:SetInvincible(true)
    inst.AnimState:PlayAnimation("superjump")
    inst.SoundEmitter:PlaySound("dontstarve/common/deathpoof", nil, .6)
  end,

  events = {
    EventHandler("animover", function(inst)
      if inst.AnimState:AnimDone() then
        local data = inst.sg.statemem.data
        inst:Hide()
        inst.Physics:Teleport(data.targetpos.x, 0, data.targetpos.z)
        inst.sg:GoToState("mon3tr_return_jump_pst", data)
      end
    end),
  },

  onexit = function(inst)
    if not inst.sg:HasStateTag("mon3tr_skill") then
      if inst.sg.statemem.isphysicstoggle then
        ToggleOnPhysics(inst)
      end
      inst.DynamicShadow:Enable(true)
      inst.components.health:SetInvincible(false)
    end
  end,
})

AddStategraphState("wilson", State {
  name = "mon3tr_return_jump_pst",
  tags = { "aoe", "doing", "busy", "noattack", "pausepredict", "nomorph", "mon3tr_skill" },

  onenter = function(inst, data)
    if data == nil or data.targetpos == nil then
      inst.sg:GoToState("idle", true)
      return
    end

    inst.sg.statemem.data = data
    inst:Show()
    inst.Physics:Teleport(data.targetpos.x, 0, data.targetpos.z)
    inst.AnimState:PlayAnimation("superjump_land")
    inst.SoundEmitter:PlaySound("dontstarve/movement/bodyfall_dirt", nil, .35)

    if data.beacon ~= nil and data.beacon:IsValid() then
      data.beacon:Remove()
    end
  end,

  timeline = {
    TimeEvent(4 * FRAMES, function(inst)
      ToggleOnPhysics(inst)
      inst.DynamicShadow:Enable(true)
      inst.components.health:SetInvincible(false)
      inst.sg:RemoveStateTag("noattack")
    end),
    TimeEvent(0x13 * FRAMES, PlayFootstep),
  },

  events = {
    EventHandler("animover", function(inst)
      if inst.AnimState:AnimDone() then
        inst.sg:GoToState("idle")
      end
    end),
  },

  onexit = function(inst)
    if inst.sg.statemem.isphysicstoggle then
      ToggleOnPhysics(inst)
    end
    inst:Show()
    inst.DynamicShadow:Enable(true)
    inst.components.health:SetInvincible(false)
  end,
})

--三技能期间无法装备物品栏
AddComponentPostInit("equippable", function(self)
  local _IsRestricted = self.IsRestricted
  self.IsRestricted = function(self, target)
    if self.equipslot == EQUIPSLOTS.HANDS then
      local skill = target.components.mon3tr_skill
      if skill and skill:IsSkill3Activating() then
        return true
      end
    end
    return _IsRestricted(self, target)
  end
end)

AddClassPostConstruct("components/equippable_replica", function(self)
  local _IsRestricted = self.IsRestricted
  self.IsRestricted = function(self, target)
    if self:EquipSlot() == EQUIPSLOTS.HANDS then
      local comrep = target.replica.mon3tr_skill
      if comrep then
        if comrep:IsSkill3Activating() then
          return true
        end
      end
    end
    return _IsRestricted(self, target)
  end
end)
