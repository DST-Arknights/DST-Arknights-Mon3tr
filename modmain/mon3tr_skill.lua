local ARK_CONSTANTS = require "ark_constants"

local ATTACK_RECOVERY_ENERGY = 1
local HEAL_CHAIN_RANGE = 16
local HEAL_CHAIN_EXCLUDE_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }

local SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY = "mon3tr_skill3_attack_damage_multiplier"
local SKILL3_MIN_HEALTH_KEY = "mon3tr_skill3_min_health"
local SKILL3_MIN_HEALTH_REMOVE_DELAY = 5 -- 3技能结束的无敌保护持续时间
local SKILL3_APPROACH_MAX_OFFSET = 2
local SKILL3_APPROACH_MIN_DISTANCE = 1
local SKILL3_POSITION_SEARCH_ATTEMPTS = 12

local SKILL3_LIGHT_UPDATE_INTERVAL = 0.2

local function ConnectHealChain(source, target)
  if source == nil or target == nil or source.Transform == nil or target.Transform == nil then
    return
  end
  local x, y, z = source.Transform:GetWorldPosition()
  local x1, y1, z1 = target.Transform:GetWorldPosition()
  local dx = x1 - x
  local dz = z1 - z
  local dsq = dx * dx + dz * dz
  local fx = SpawnPrefab("mon3tr_heal_chain_fx")
  if fx == nil then
    return
  end
  fx.Transform:SetPosition((x + x1) / 2, 0, (z + z1) / 2)
  fx:SetBeam(math.sqrt(dsq), math.atan2(-dz, dx) * RADIANS)
end

local function AppendSkillHealChainParam(skill, healRate, healChainCount)
  if not skill or not skill:IsActivating() then
    return healRate, healChainCount
  end
  local params = skill:GetLevelParams() or {}
  healChainCount = math.max(healChainCount, params.healChainCount or 0)
  healRate = healRate + (params.healRate or 0)
  return healRate, healChainCount
end

local function CanBeHealed(ent, source, owner)
  if ent == nil or ent == source or not ent:IsValid() then
    return false
  end
  if ent.components == nil or ent.components.health == nil then
    return false
  end
  if ent.components.health:IsDead() or ent:HasTag("playerghost") then
    return false
  end
  if ent.components.combat and ent.components.combat.target == owner then
    return false
  end

  if ent:HasTag("player") then
    return true
  end

  if ent.components.follower ~= nil then
    local leader = ent.components.follower.leader
    if leader ~= nil and leader:HasTag("player") then
      return true
    end
  end

  if ent.components.combat ~= nil and ent.components.combat.target == source then
    return true
  end

  return false
end

local function FindBestHealTarget(from, source, owner, visited)
  if from == nil or from.Transform == nil then
    return nil
  end

  local x, y, z = from.Transform:GetWorldPosition()
  local ents = TheSim:FindEntities(x, y, z, HEAL_CHAIN_RANGE, nil, HEAL_CHAIN_EXCLUDE_TAGS)

  local best
  local bestPercent
  for _, v in ipairs(ents) do
    if v ~= from and not visited[v] and CanBeHealed(v, source, owner) then
      local hp = v.components.health
      local percent = hp ~= nil and hp:GetPercent() or 1
      if best == nil or percent < bestPercent then
        best = v
        bestPercent = percent
      end
    end
  end

  return best
end

local function FindHealChain(inst, source, maxCount)
  local chain = {}
  local visited = {}
  local from = source
  while #chain < maxCount and from ~= nil do
    local best = FindBestHealTarget(from, source, inst, visited)
    if best == nil then
      break
    end
    chain[#chain + 1] = best
    visited[best] = true
    from = best
  end
  return chain
end

local function HealChain(inst, source, data)
  local healRateAttenuation = 0.75
  local healRate = data.rate or 0
  local healCount = data.count or 0
  local healHealth = data.health or 0
  if healCount <= 1 or healRate <= 0 then
    return {}
  end

  local chain = FindHealChain(inst, source, healCount)
  if #chain > 0 and source ~= nil then
    ConnectHealChain(source, chain[1])
    source:SpawnChild("mon3tr_heal_fx")
    source:SpawnChild("mon3tr_heal_fx_2")
    chain[1]:SpawnChild("mon3tr_heal_fx")
    chain[1]:SpawnChild("mon3tr_heal_fx_2")
    if #chain > 1 then
      for i = 1, #chain - 1 do
        chain[i + 1]:SpawnChild("mon3tr_heal_fx")
        chain[i + 1]:SpawnChild("mon3tr_heal_fx_2")
        ConnectHealChain(chain[i], chain[i + 1])
      end
    end
  end

  local nextRate = healRate
  for _, target in ipairs(chain) do
    nextRate = nextRate * healRateAttenuation
    if target.components.health then
      target.components.health:DoDelta(healHealth * nextRate)
    end
  end
  return chain
end

local function OnHitOther(inst, data)
  if data == nil or data.target == nil then
    return
  end

  local arkSkill = inst.components.ark_skill
  if not arkSkill then
    return
  end
  local skill1 = arkSkill:GetSkill("mon3tr_skill1")
  local skill2 = arkSkill:GetSkill("mon3tr_skill2")
  local skill3 = arkSkill:GetSkill("mon3tr_skill3")

  if skill1 and not skill1:TryActivate(data.target) then
    skill1:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
  end
  if skill2 and not skill2:IsActivating() then
    skill2:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
  end
  if skill3 and not skill3:IsActivating() then
    skill3:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
  end

  local healRate = 0
  local healChainCount = 0
  if skill1 and skill1:IsActivating() then
    healRate = healRate + 0.5
    healChainCount = healChainCount + 1
  end
  healRate, healChainCount = AppendSkillHealChainParam(skill1, healRate, healChainCount)
  healRate, healChainCount = AppendSkillHealChainParam(skill2, healRate, healChainCount)
  healRate, healChainCount = AppendSkillHealChainParam(skill3, healRate, healChainCount)
  if healChainCount <= 1 or healRate <= 0 then
    return
  end

  local chain = HealChain(inst, data.target, {
    rate = healRate,
    count = healChainCount,
    health = inst.components.combat.defaultdamage,
  })
  local playerElite = inst.components.ark_elite and inst.components.ark_elite.elite or 1
  if playerElite > 1 then
    local eliteConfig = TUNING.MON3TR_ELITE[playerElite] or {}
    local passiveAttackSpeedMultiplier = eliteConfig.tactical_synergy_passive_attack_speed_multiplier or 1
    local attackSpeedMultiplier = passiveAttackSpeedMultiplier
    if skill2 and skill2:IsActivating() then
      local skill2Config = skill2:GetLevelParams() or {}
      local passiveBonusScale = skill2Config.tactical_synergy_passive_bonus_scale or 1
      local passiveBonus = passiveAttackSpeedMultiplier - 1
      attackSpeedMultiplier = 1 + passiveBonus * passiveBonusScale
    end
    for _, target in ipairs(chain) do
      target:AddDebuff("mon3tr_tactical_synergy_buff", "mon3tr_tactical_synergy_buff", {
        attack_speed_multiplier = attackSpeedMultiplier,
      })
    end
  end
end

local function GetSkill3LifestealAmount(inst, data)
  if data == nil then
    return 0
  end

  local damage = data.damage or data.damageresolved or data.finaldamage
  if damage == nil then
    damage = inst.components.combat.defaultdamage
  end

  return math.max(0, damage or 0)
end

local function OnHitOtherSkill3Lifesteal(inst, data)
  local skill = inst.components.ark_skill and inst.components.ark_skill:GetSkill("mon3tr_skill3") or nil
  if not skill or not skill:IsActivating() then
    return
  end
  if data == nil or data.target == nil or not data.target:IsValid() then
    return
  end
  if data.target.components ~= nil and data.target.components.health ~= nil and data.target.components.health:IsDead() then
    return
  end
  if inst.components.health == nil or inst.components.health:IsDead() then
    return
  end

  local lifesteal = GetSkill3LifestealAmount(inst, data)
  if lifesteal > 0 then
    inst.components.health:DoDelta(lifesteal, false, "mon3tr_skill3_lifesteal", nil, data.target, true)
  end
end

local function OnHitOtherTask(inst, data)
  if inst._onhitother_task then
    return
  end
  inst._onhitother_task = inst:DoTaskInTime(0, function()
    inst._onhitother_task = nil
  end)
  OnHitOther(inst, data)
end

local function SafeMapCall(map, fnName, default, ...)
  local fn = map ~= nil and map[fnName] or nil
  if fn == nil then
    return default
  end
  local ok, result = pcall(fn, map, ...)
  if ok then
    return result
  end
  return default
end

local function BuildSkill3Pos(x, z)
  return Vector3(x, 0, z)
end

local function IsSkill3WalkablePoint(x, z)
  local map = TheWorld ~= nil and TheWorld.Map or nil
  if map == nil then
    return true
  end
  if not SafeMapCall(map, "IsAboveGroundAtPoint", true, x, 0, z) then
    return false
  end
  if not SafeMapCall(map, "IsPassableAtPoint", true, x, 0, z) then
    return false
  end
  if SafeMapCall(map, "IsGroundTargetBlocked", false, x, 0, z) then
    return false
  end
  return true
end

local function FindSkill3WalkablePos(centerX, centerZ, angle, radius)
  if IsSkill3WalkablePoint(centerX, centerZ) then
    return BuildSkill3Pos(centerX, centerZ)
  end

  local searchRadius = radius
  if searchRadius <= 0 then
    searchRadius = 0.5
  end

  if FindWalkableOffset ~= nil then
    local center = BuildSkill3Pos(centerX, centerZ)
    local ok, offset = pcall(FindWalkableOffset, center, angle, searchRadius, SKILL3_POSITION_SEARCH_ATTEMPTS, true)
    if ok and offset ~= nil then
      return BuildSkill3Pos(centerX + offset.x, centerZ + offset.z)
    end
  end

  local step = (math.pi * 2) / SKILL3_POSITION_SEARCH_ATTEMPTS
  for i = 0, SKILL3_POSITION_SEARCH_ATTEMPTS - 1 do
    local ring = math.floor((i + 1) / 2)
    local sign = i % 2 == 0 and 1 or -1
    local theta = angle + ring * step * sign
    local x = centerX + math.cos(theta) * searchRadius
    local z = centerZ - math.sin(theta) * searchRadius
    if IsSkill3WalkablePoint(x, z) then
      return BuildSkill3Pos(x, z)
    end
  end

  return nil
end

local function GetSkill3ActivePosFromTarget(inst, target)
  if inst == nil or inst.Transform == nil or target == nil or target.Transform == nil then
    return nil
  end

  local sx, _, sz = inst.Transform:GetWorldPosition()
  local tx, _, tz = target.Transform:GetWorldPosition()
  local dx = sx - tx
  local dz = sz - tz
  local dsq = dx * dx + dz * dz
  local dist = math.sqrt(dsq)

  local dirX, dirZ = 1, 0
  if dist > 0.001 then
    dirX = dx / dist
    dirZ = dz / dist
  end

  local radius = math.min(SKILL3_APPROACH_MAX_OFFSET, dist)
  local centerX = tx + dirX * radius
  local centerZ = tz + dirZ * radius
  local walkRadius = math.max(0, radius - SKILL3_APPROACH_MIN_DISTANCE)
  local angle = math.atan2(-dirZ, dirX)

  return FindSkill3WalkablePos(centerX, centerZ, angle, walkRadius)
end

local function GetSkill3ActivePosFromPoint(pos)
  if pos == nil then
    return nil
  end

  local x = pos.x
  local z = pos.z
  if (x == nil or z == nil) and pos.Get ~= nil then
    x, _, z = pos:Get()
  end
  if x == nil or z == nil then
    return nil
  end

  return FindSkill3WalkablePos(x, z, 0, 0) or BuildSkill3Pos(x, z)
end

local function CancelSkill3LightTask(skill)
  if skill._mon3tr_skill3_extinguish_task ~= nil then
    skill._mon3tr_skill3_extinguish_task:Cancel()
    skill._mon3tr_skill3_extinguish_task = nil
  end
end

local HitOtherListenerSymbol = Symbol("mon3tr_hit_other_listener")
local function OnCommonSkillInstall(skill)
  local inst = skill.inst
  if not inst[HitOtherListenerSymbol] then
    inst[HitOtherListenerSymbol] = true
    inst:ListenForEvent("onhitother", OnHitOtherTask)
  end
end


local function OnPlayerIdle(inst, data)
  if data.newstate ~= "idle" then
    return
  end
  local skill = inst.components.ark_skill and inst.components.ark_skill:GetSkill("mon3tr_skill3") or nil
  if skill then
    if skill.f_weapon ~= nil then
      skill.f_weapon.AnimState:PlayAnimation("f_idle", true)
    end
    if skill.b_weapon ~= nil then
      skill.b_weapon.AnimState:PlayAnimation("b_idle", true)
    end
  end
end

local function OnAttackSpeedChanged(inst, data)
  local skill = inst.components.ark_skill and inst.components.ark_skill:GetSkill("mon3tr_skill3") or nil
  if skill and data.speed then
    if skill.f_weapon ~= nil then
      skill.f_weapon.AnimState:SetDeltaTimeMultiplier(data.speed)
    end
    if skill.b_weapon ~= nil then
      skill.b_weapon.AnimState:SetDeltaTimeMultiplier(data.speed)
    end
  end
end

local function RemoveConstructBeaconCallback(inst)
  local skill = inst.components.ark_skill and inst.components.ark_skill:GetSkill("mon3tr_skill3") or nil
  if skill then
    skill:RemoveConstructBeacon()
  end
end

local function OnSkill3DoAttack(inst, data)
  local skill = inst.components.ark_skill and inst.components.ark_skill:GetSkill("mon3tr_skill3") or nil
  if skill and skill:IsActivating() then
    local combat = inst.components.combat
    combat:DoAreaAttack(inst, 3, combat:GetWeapon(), nil, nil, nil, nil)
  end
end

local function InstallSkill3Interface(skill)
  function skill:SpawnConstructBeaconAt(x, y, z)
    if not self._construct_beacon then
      local beacon = SpawnPrefab("construct_beacon")
      beacon.Transform:SetPosition(x, y, z)
      self._construct_beacon = beacon
    end
    return self._construct_beacon
  end

  function skill:GetConstructBeacon()
    return self._construct_beacon
  end

  function skill:RemoveConstructBeacon()
    if self._construct_beacon then
      self._construct_beacon:Remove()
      self._construct_beacon = nil
    end
  end

  function skill:SetupSkill3Weapon()
    local inst = self.inst
    if self.f_weapon == nil then
      local f_weapon = SpawnPrefab("construct_claw")
      f_weapon.entity:SetParent(inst.entity)
      f_weapon.Transform:SetPosition(0, 0, 0)
      f_weapon.AnimState:SetFinalOffset(7)
      f_weapon.AnimState:PlayAnimation("f_idle", true)
      self.f_weapon = f_weapon
    end
    if self.b_weapon == nil then
      local b_weapon = SpawnPrefab("construct_claw")
      b_weapon.entity:SetParent(inst.entity)
      b_weapon.Transform:SetPosition(0, 0, 0)
      b_weapon.AnimState:SetFinalOffset(-1)
      b_weapon.AnimState:PlayAnimation("b_idle", true)
      self.b_weapon = b_weapon
    end
  end

  function skill:RemoveSkill3Weapon()
    if self.f_weapon ~= nil then
      self.f_weapon:Remove()
      self.f_weapon = nil
    end
    if self.b_weapon ~= nil then
      self.b_weapon:Remove()
      self.b_weapon = nil
    end
  end

  function skill:SpawnWrathFx()
    if not self._wrath_fx then
      local wrath_fx = SpawnPrefab("mon3tr_wrath_fx")
      wrath_fx.entity:SetParent(self.inst.entity)
      self._wrath_fx = wrath_fx
    end
    return self._wrath_fx
  end

  function skill:RemoveWrathFx()
    if self._wrath_fx then
      self._wrath_fx:Remove()
      self._wrath_fx = nil
    end
  end

  function skill:StartSkill3RedLight()
    CancelSkill3LightTask(self)
    local light = self._mon3tr_skill3_light_fx

    light.Light:Enable(true)
    light.Light:SetRadius(2.4)
    light.Light:SetFalloff(0.95)
    light.Light:SetIntensity(0.95)
    light.Light:SetColour(1, 0.15, 0.15)
  end

  function skill:StartSkill3GreenFade()
    local inst = self.inst
    CancelSkill3LightTask(self)
    local light = self._mon3tr_skill3_light_fx
    light.Light:Enable(true)
    light.Light:SetRadius(2.4)
    light.Light:SetFalloff(0.95)
    light.Light:SetIntensity(0.95)
    light.Light:SetColour(0.2, 1, 0.25)
    local lightDuration = 30
    if not self._skill3_light_start_time then
      self._skill3_light_start_time = GetTime()
    end
    self._mon3tr_skill3_extinguish_task = inst:DoPeriodicTask(SKILL3_LIGHT_UPDATE_INTERVAL, function()
      local remain = self._skill3_light_start_time + lightDuration - GetTime()
      if remain <= 0 then
        light.Light:Enable(false)
        CancelSkill3LightTask(self)
        self._skill3_light_start_time = nil
      else
        local intensity = math.max(0, math.min(1, remain / lightDuration))
        light.Light:SetIntensity(0.95 * intensity)
      end
    end)
  end
end
local function OnSkill3Install(skill)
  local inst = skill.inst
  skill._mon3tr_skill3_light_fx = SpawnPrefab("firefx_light")
  if skill._mon3tr_skill3_light_fx then
    skill._mon3tr_skill3_light_fx.entity:SetParent(inst.entity)
    skill._mon3tr_skill3_light_fx.Transform:SetPosition(0, 0, 0)
    skill._mon3tr_skill3_light_fx.Light:Enable(false)
  end
  skill:ListenForEvent("doattack", OnSkill3DoAttack)
  InstallSkill3Interface(skill)
  OnCommonSkillInstall(skill)
  skill:ListenForEvent("onhitother", OnHitOtherSkill3Lifesteal)
  skill:ListenForEvent("sgstatechange", OnPlayerIdle)
  skill:ListenForEvent("attackspeedchanged", OnAttackSpeedChanged)
  skill:ListenForEvent("ms_playerreroll", RemoveConstructBeaconCallback)
  skill:ListenForEvent("onremove", RemoveConstructBeaconCallback)
end

local function OnSkill3Remove(skill)
  CancelSkill3LightTask(skill)
  skill._mon3tr_skill3_light_fx:Remove()
  skill._mon3tr_skill3_light_fx = nil
end

local function OnSkill3Activate(skill, data)
  local inst = skill.inst
  local activePos = nil
  if inst.components.combat and inst.components.combat.target then
    activePos = GetSkill3ActivePosFromTarget(inst, inst.components.combat.target)
  end
  if activePos == nil and data and data.target then
    activePos = GetSkill3ActivePosFromTarget(inst, data.target)
  end
  if activePos == nil and data and data.targetPos then
    activePos = GetSkill3ActivePosFromPoint(data.targetPos)
  end
  if not activePos then
    -- TODO: 提醒玩家无法找到合适的位置
    return
  end
  inst.sg:GoToState("mon3tr_superjump_pre", {
    targetpos = activePos,
  })
end

local function ForceDeactivateSkill3(inst)
  local skill3 = inst.components.ark_skill and inst.components.ark_skill:GetSkill("mon3tr_skill3")
  if skill3 then
    skill3:SetEnergyRecovering(true)
  end
end

local OnMinHealth = PriorityEventCallback(function(inst)
  ForceDeactivateSkill3(inst)
end, { priority = 10 })

local SKILL3_MODIFIER_KEY = "mon3tr_skill3_modifier"
local function OnSkill3ActivateEffect(skill)
  ArkLogger:Debug("Mon3tr Skill3 Activate Effect")
  local inst = skill.inst

  local levelParams = skill:GetLevelParams()
  local attackDamageMultiplier = levelParams.attack_damage_multiplier or 1
  inst.components.combat.externaldamagemultipliers:SetModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY,
    attackDamageMultiplier)
  inst.components.combat.truedamagemultipliers:SetModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY, 1)
  if inst.components.health then
    if skill._skill3_min_health_remove_task then
      skill._skill3_min_health_remove_task:Cancel()
      skill._skill3_min_health_remove_task = nil
    end
    local healthBonus = levelParams.health_bonus or 0
    inst.components.health.maxhealthaddmodifiers:SetModifier(inst, healthBonus, SKILL3_MODIFIER_KEY)
    if not skill._skill3_lose_health_task then
      local loseHealthPerSecond = levelParams.lose_health_per_second or 0
      skill._skill3_lose_health_task = inst:DoPeriodicTask(1, function()
        inst.components.health:DoDelta(-loseHealthPerSecond)
      end)
    end
    inst.components.health.minhealthmodifiers:SetModifier(SKILL3_MIN_HEALTH_KEY, 1)
    inst:ListenForEvent("minhealth", OnMinHealth)
  end
  skill:StartSkill3RedLight()
  if inst.components.inventory then
    local item = inst.components.inventory:Unequip(EQUIPSLOTS.HANDS)
    if item then
      inst.components.inventory:GiveItem(item)
    end
  end
  skill:SetupSkill3Weapon()
  skill:SpawnWrathFx()
  inst:AddTag("immune_stun")
  inst:AddTag("no_construct_armor_exchange")
end

local function OnSkill3Deactivate(skill, data)
  ArkLogger:Debug("Mon3tr Skill3 Deactivate")
  local inst = skill.inst
  if skill._skill3_lose_health_task then
    skill._skill3_lose_health_task:Cancel()
    skill._skill3_lose_health_task = nil
  end
  if inst.components.combat then
    inst.components.combat.externaldamagemultipliers:RemoveModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY)
    inst.components.combat.truedamagemultipliers:RemoveModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY)
  end
  if inst.components.health then
    local currentPercent = inst.components.health:GetPercent()
    inst.components.health.maxhealthaddmodifiers:RemoveModifier(inst, SKILL3_MODIFIER_KEY)
    inst.components.health:SetPercent(currentPercent)
    if skill._skill3_min_health_remove_task then
      skill._skill3_min_health_remove_task:Cancel()
      skill._skill3_min_health_remove_task = nil
    end
    skill._skill3_min_health_remove_task = inst:DoTaskInTime(SKILL3_MIN_HEALTH_REMOVE_DELAY, function()
      skill._skill3_min_health_remove_task = nil
      if inst.components.health then
        inst.components.health.minhealthmodifiers:RemoveModifier(SKILL3_MIN_HEALTH_KEY)
      end
    end)
  end
  local construct_beacon = skill:GetConstructBeacon()
  if construct_beacon then
    local pos = construct_beacon:GetPosition()
    inst.sg:GoToState("mon3tr_return_jump", {
      targetpos = Vector3(pos.x, 0, pos.z),
      beacon = construct_beacon,
    })
  end
  inst:RemoveEventCallback("minhealth", OnMinHealth)
  inst:RemoveTag("immune_stun")
  inst:RemoveTag("no_construct_armor_exchange")
  skill:RemoveWrathFx()
  skill:StartSkill3GreenFade()
  skill:RemoveSkill3Weapon()
end

local function OnSkill3Save(skill, data)
  local data = {
    skill3_light_start_time = skill._skill3_light_start_time,
  }
  local construct_beacon = skill:GetConstructBeacon()
  if construct_beacon then
    local x, y, z = construct_beacon.Transform:GetWorldPosition()
    data.construct_beacon_pos = {
      x = x,
      y = y,
      z = z,
    }
  end
  return data
end

local function OnSkill3Load(skill, data)
  if data.skill3_light_start_time then
    skill._skill3_light_start_time = data.skill3_light_start_time
  end
  if data.construct_beacon_pos then
    local beaconData = data.construct_beacon_pos
    skill:SpawnConstructBeaconAt(beaconData.x, beaconData.y, beaconData.z)
  end
end

local skills = { {
  id = "mon3tr_skill1",
  name = STRINGS.UI.MON3TR_SKILL.NAME[1],
  energyRecoveryMode = ARK_CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK,
  activationMode = ARK_CONSTANTS.ACTIVATION_MODE.AUTO,
  lockedDesc = STRINGS.UI.MON3TR_SKILL.LOCKED_DESC[1],
  atlas = "images/ui_mon3tr_skill.xml",
  image = "skill1_64.tex",
  OnInstall = OnCommonSkillInstall,
  levels = { {
    activationEnergy = 5,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][1],
    params = { healRate = 1.1, healChainCount = 4 },
  }, {
    activationEnergy = 5,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][2],
    params = { healRate = 1.2, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 5) }
  }, {
    activationEnergy = 5,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][3],
    params = { healRate = 1.25, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 5), Ingredient("ark_item_mtl_sl_boss1", 4), Ingredient("ark_item_mtl_sl_rush1", 4) }
  }, {
    activationEnergy = 5,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][4],
    params = { healRate = 1.35, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_g2", 7) }
  }, {
    activationEnergy = 5,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][5],
    params = { healRate = 1.5, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 8), Ingredient("ark_item_mtl_sl_strg2", 4), Ingredient("ark_item_mtl_sl_ketone2", 4) }
  }, {
    activationEnergy = 5,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][6],
    params = { healRate = 1.6, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_strg3", 7) }
  }, {
    activationEnergy = 3,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][7],
    params = { healRate = 1.7, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_ccf", 5), Ingredient("ark_item_mtl_sl_rush3", 3) }
  }, {
    activationEnergy = 3,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][8],
    params = { healRate = 1.8, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_zyk", 4), Ingredient("ark_item_mtl_sl_g3", 10) }
  }, {
    activationEnergy = 3,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][9],
    params = { healRate = 1.9, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 12), Ingredient("ark_item_mtl_sl_htt", 4), Ingredient("ark_item_mtl_sl_pgel4", 9) }
  }, {
    activationEnergy = 2,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[1][10],
    params = { healRate = 2.0, healChainCount = 4 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 15), Ingredient("ark_item_mtl_sl_ds", 6), Ingredient("ark_item_mtl_sl_pg2", 6) }
  }, }
}, {
  id = "mon3tr_skill2",
  name = STRINGS.UI.MON3TR_SKILL.NAME[2],
  energyRecoveryMode = ARK_CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK,
  activationMode = ARK_CONSTANTS.ACTIVATION_MODE.MANUAL,
  lockedDesc = STRINGS.UI.MON3TR_SKILL.LOCKED_DESC[2],
  hotkey = KEY_X,
  atlas = "images/ui_mon3tr_skill.xml",
  image = "skill2_64.tex",
  OnInstall = OnCommonSkillInstall,
  levels = { {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][1],
    params = { healRate = 1.5, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.5 },
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][2],
    params = { healRate = 1.6, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.6 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 5) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][3],
    params = { healRate = 1.7, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.7 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 5), Ingredient("ark_item_mtl_sl_boss1", 4), Ingredient("ark_item_mtl_sl_rush1", 4) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][4],
    params = { healRate = 1.8, healChainCount = 3, tactical_synergy_passive_bonus_scale = 1.8 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_g2", 7) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][5],
    params = { healRate = 2, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 8), Ingredient("ark_item_mtl_sl_strg2", 4), Ingredient("ark_item_mtl_sl_ketone2", 4) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][6],
    params = { healRate = 2.1, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.1 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_strg3", 7) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][7],
    params = { healRate = 2.3, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.3 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_ccf", 5), Ingredient("ark_item_mtl_sl_rush3", 3) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][8],
    params = { healRate = 2.5, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.5 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_iron4", 4), Ingredient("ark_item_mtl_sl_pg1", 3) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][9],
    params = { healRate = 2.6, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.6 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 12), Ingredient("ark_item_mtl_sl_rs", 4) }
  }, {
    activationEnergy = 15,
    buffDuration = 30,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[2][10],
    params = { healRate = 2.8, healChainCount = 3, tactical_synergy_passive_bonus_scale = 2.8 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 15), Ingredient("ark_item_mtl_sl_shj", 6), Ingredient("ark_item_mtl_sl_g4", 2) }
  }, }
}, {
  id = "mon3tr_skill3",
  name = STRINGS.UI.MON3TR_SKILL.NAME[3],
  energyRecoveryMode = ARK_CONSTANTS.ENERGY_RECOVERY_MODE.ATTACK,
  activationMode = ARK_CONSTANTS.ACTIVATION_MODE.MANUAL,
  lockedDesc = STRINGS.UI.MON3TR_SKILL.LOCKED_DESC[3],
  hotkey = KEY_C,
  atlas = "images/ui_mon3tr_skill.xml",
  image = "skill3_64.tex",
  OnAdd = OnCommonSkillAdd,
  OnInstall = OnSkill3Install,
  OnRemove = OnSkill3Remove,
  OnActivate = OnSkill3Activate,
  OnActivateEffect = OnSkill3ActivateEffect,
  OnDeactivate = OnSkill3Deactivate,
  OnSave = OnSkill3Save,
  OnLoad = OnSkill3Load,
  levels = { {
    activationEnergy = 1,
    buffDuration = 125,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][1],
    params = { healChainCount = 3, attack_damage_multiplier = 2, health_bonus = 5000, lose_health_per_second = 80 },
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][2],
    params = { healChainCount = 3, attack_damage_multiplier = 2.2, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 5) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][3],
    params = { healChainCount = 3, attack_damage_multiplier = 2.3, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 5), Ingredient("ark_item_mtl_sl_boss1", 4), Ingredient("ark_item_mtl_sl_rush1", 4) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][4],
    params = { healChainCount = 3, attack_damage_multiplier = 2.5, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_g2", 7) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][5],
    params = { healChainCount = 3, attack_damage_multiplier = 2.6, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill1", 8), Ingredient("ark_item_mtl_sl_strg2", 4), Ingredient("ark_item_mtl_sl_ketone2", 4) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][6],
    params = { healChainCount = 3, attack_damage_multiplier = 2.7, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill2", 8), Ingredient("ark_item_mtl_sl_strg3", 7) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][7],
    params = { healChainCount = 3, attack_damage_multiplier = 2.8, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_ccf", 5), Ingredient("ark_item_mtl_sl_rush3", 3) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][8],
    params = { healChainCount = 3, attack_damage_multiplier = 3, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 8), Ingredient("ark_item_mtl_sl_plcf", 4), Ingredient("ark_item_mtl_sl_iam3", 7) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][9],
    params = { healChainCount = 3, attack_damage_multiplier = 3.1, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 12), Ingredient("ark_item_mtl_sl_xwb", 4), Ingredient("ark_item_mtl_sl_rma7024", 7) }
  }, {
    activationEnergy = 15,
    buffDuration = 25,
    desc = STRINGS.UI.MON3TR_SKILL.LEVEL_DESC[3][9],
    params = { healChainCount = 3, attack_damage_multiplier = 3.3, health_bonus = 5000, lose_health_per_second = 80 },
    recipeIngredients = { Ingredient("ark_item_mtl_skill3", 15), Ingredient("ark_item_mtl_sl_oeu", 6), Ingredient("ark_item_mtl_sl_iam4", 1) }
  } }
} }

for _, skill in ipairs(skills) do
  RegisterArkSkill(skill)
end
