local skillConfig = require "mon3tr_skill_config"
local ATTACK_RECOVERY_ENERGY = 1
local HEAL_CHAIN_RANGE = 16
local HEAL_CHAIN_EXCLUDE_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }

local SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY = "mon3tr_skill3_attack_damage_multiplier"
local SKILL3_APPROACH_MAX_OFFSET = 2
local SKILL3_APPROACH_MIN_DISTANCE = 1
local SKILL3_POSITION_SEARCH_ATTEMPTS = 12

local function OnSkill1Activate(inst, data)
end

local function connectHealChain(source, target)
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

local function AddActiveSkillConfig(skill, healRate, healChainCount)
    if not skill:IsActivating() then
        return healRate, healChainCount
    end
    local levelConfig = skill:GetLevelConfig()
    healChainCount = math.max(healChainCount, levelConfig.healChainCount or 0)
    healRate = healRate + (levelConfig.healRate or 0)
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

local function OnHitOther(inst, data)
    local arkSkill = inst.components.ark_skill
    if not arkSkill then
        return
    end
    if not data or not data.target then
        return
    end
    local skill1 = arkSkill:GetSkill("skill1")
    local skill2 = arkSkill:GetSkill("skill2")
    local skill3 = arkSkill:GetSkill("skill3")

    -- 技能1自动释放与充能互斥
    if not skill1:TryActivate(data.target) then
        skill1:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
    end
    if not (skill2:IsActivating()) then
        skill2:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
    end
    if not (skill3:IsActivating()) then
        skill3:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
    end

    local healRate = 0
    local healChainCount = 0
    healRate, healChainCount = AddActiveSkillConfig(skill1, healRate, healChainCount)
    healRate, healChainCount = AddActiveSkillConfig(skill2, healRate, healChainCount)
    healRate, healChainCount = AddActiveSkillConfig(skill3, healRate, healChainCount)
    if healChainCount <= 1 or healRate <= 0 then
        return
    end
    local chain = inst.components.mon3tr_skill:HealChain(data.target, {
        rate = healRate,
        count = healChainCount,
        health = inst.components.combat.defaultdamage,
    })
    local playerElite = inst.components.ark_elite and inst.components.ark_elite.elite or 1
    if playerElite > 1 then
        local eliteConfig = skillConfig.elites[playerElite] or {}
        local passive_attack_speed_multiplier = eliteConfig.tactical_synergy_passive_attack_speed_multiplier or 1
        local attack_speed_multiplier = passive_attack_speed_multiplier
        if skill2:IsActivating() then
            local skill2Config = skill2:GetLevelConfig() or {}
            local passive_bonus_scale = skill2Config.tactical_synergy_passive_bonus_scale or 1
            -- 被动 1.1 => 增益部分 0.1；技能二 1.5 倍放大后变为 0.15；最终倍率 1.15
            local passive_bonus = passive_attack_speed_multiplier - 1
            attack_speed_multiplier = 1 + passive_bonus * passive_bonus_scale
        end
        for _, target in ipairs(chain) do
            target:AddDebuff("mon3tr_tactical_synergy_buff", "mon3tr_tactical_synergy_buff", { attack_speed_multiplier = attack_speed_multiplier })
        end
    end
end

-- 一帧内只触发一次onhitother
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

    local R = math.min(SKILL3_APPROACH_MAX_OFFSET, dist)
    local centerX = tx + dirX * R
    local centerZ = tz + dirZ * R
    local radius = math.max(0, R - SKILL3_APPROACH_MIN_DISTANCE)
    local angle = math.atan2(-dirZ, dirX)

    return FindSkill3WalkablePos(centerX, centerZ, angle, radius)
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

local function Skill3ActivateTest(inst, data)
    local skill3 = inst.components.ark_skill:GetSkill("skill3")
    skill3._cache_active_pos = nil

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

    if activePos ~= nil then
        skill3._cache_active_pos = activePos
        return true
    end
    return false
end

local function OnSkill3Activate(inst, data)
    -- 超级跳sg
    inst.sg:GoToState("mon3tr_superjump_pre", {
        targetpos = inst.components.ark_skill:GetSkill("skill3")._cache_active_pos
    })
end

local function OnSkill3ActivateEffect(inst)
    local skill3 = inst.components.ark_skill:GetSkill("skill3")
    -- 攻击力增加
    local levelConfig = skill3:GetLevelConfig()
    local attack_damage_multiplier = levelConfig.attack_damage_multiplier or 1
    inst.components.combat.externaldamagemultipliers:SetModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY, attack_damage_multiplier)
    inst.components.combat.truedamagemultipliers:SetModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY, 1)
    if inst.components.health then
        -- 血量上限增加
        local health_bonus = levelConfig.health_bonus or 0
        local current_max_health = inst.components.health.maxhealth
        local new_max_health = current_max_health + health_bonus
        inst.components.health:SetMaxHealth(new_max_health)
        if not inst._skill3_lose_health_task then
            local lose_health_per_second = levelConfig.lose_health_per_second or 0
            inst._skill3_lose_health_task = inst:DoPeriodicTask(1, function()
                inst.components.health:DoDelta(-lose_health_per_second)
            end)
        end
        -- 锁血
        inst._skill3_prev_min_health = inst.components.health.minhealth
        inst.components.health:SetMinHealth(1)
        -- 添加minhealth监听, 强制结束技能
        inst:ListenForEvent("minhealth", inst.components.mon3tr_skill._force_deactivate_skill3_cb)
    end
    -- 卸载手持装备
    if inst.components.inventory then
        local item = inst.components.inventory:Unequip(EQUIPSLOTS.HANDS)
        if item then
            inst.components.inventory:GiveItem(item)
        end
    end
    -- 添加武器
    inst.components.mon3tr_skill:SetupSkill3Weapon()
    -- 无僵直
    -- 添加愤怒特效
    inst._wrath_fx = SpawnPrefab("mon3tr_wrath_fx")
    inst._wrath_fx.entity:SetParent(inst.entity)
     -- 同步技能状态
end

local function OnSkill3Deactivate(inst)
    if inst._skill3_lose_health_task then
        inst._skill3_lose_health_task:Cancel()
        inst._skill3_lose_health_task = nil
    end
    if inst.components.combat then
        inst.components.combat.externaldamagemultipliers:RemoveModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY)
        inst.components.combat.truedamagemultipliers:RemoveModifier(SKILL3_ATTACK_DAMAGE_MULTIPLIER_KEY)
    end
    if inst.components.health then
        -- 血量上限减少
        local skill3 = inst.components.ark_skill:GetSkill("skill3")
        local levelConfig = skill3:GetLevelConfig()
        local health_bonus = levelConfig.health_bonus or 0
        local current_max_health = inst.components.health.maxhealth
        local current_percent = inst.components.health:GetPercent()
        local new_max_health = math.max(current_max_health - health_bonus, 1)
        inst.components.health:SetMaxHealth(new_max_health)
        inst.components.health:SetPercent(current_percent)
        -- 解锁锁血
        local min_health = inst._skill3_prev_min_health or 0
        inst.components.health:SetMinHealth(min_health)
        inst._skill3_prev_min_health = nil
        -- 回到初始位置
        local construct_beacon = inst.components.mon3tr_skill.construct_beacon
        if construct_beacon and construct_beacon:IsValid() then
            local pos = construct_beacon:GetPosition()
            inst.sg:GoToState("mon3tr_return_jump", {
                targetpos = Vector3(pos.x, 0, pos.z),
                beacon = construct_beacon,
            })
        else
            -- 扣除剩余血量
            local lose_health = inst.components.health.currenthealth - 1
            inst.components.health:DoDelta(-lose_health)
        end
        -- 移除minhealth监听
        inst:RemoveEventCallback("minhealth", inst.components.mon3tr_skill._force_deactivate_skill3_cb)
    end
    if inst._wrath_fx then
        inst._wrath_fx:Remove()
        inst._wrath_fx = nil
    end
    inst.components.mon3tr_skill:RemoveSkill3Weapon()
     -- 同步技能状态
end

local Mon3trSkill = Class(function(self, inst)
    self.inst = inst
    self.healRateMultiplier = 0.75
    self.construct_beacon = nil
    inst:AddComponent("ark_skill")
    for _, skill in ipairs(skillConfig.skills) do
        inst.components.ark_skill:RegisterSkill(skill)
    end
    self:RegisterSkill()
end)

function Mon3trSkill:RemoveConstructBeacon()
    local beacon = self.construct_beacon
    self.construct_beacon = nil
    if beacon ~= nil then
        beacon:Remove()
    end
end

function Mon3trSkill:SpawnConstructBeaconAt(x, y, z)
    self:RemoveConstructBeacon()

    local beacon = SpawnPrefab("construct_beacon")
    beacon.Transform:SetPosition(x, y or 0, z)
    self.construct_beacon = beacon
    beacon:ListenForEvent("onremove", function()
        if self.construct_beacon == beacon then
            self.construct_beacon = nil
        end
    end)

    return beacon
end

function Mon3trSkill:OnSave()
    local data = {}
    local beacon = self.construct_beacon
    if beacon ~= nil then
        local x, y, z = beacon.Transform:GetWorldPosition()
        data.construct_beacon = {
            x = x,
            y = y,
            z = z,
        }
    end
    return data
end

function Mon3trSkill:OnLoad(data)
    if data and data.construct_beacon then
        local beaconData = data.construct_beacon
        self:SpawnConstructBeaconAt(beaconData.x, beaconData.y, beaconData.z)
    end
end

function Mon3trSkill:FindHealChain(source, maxCount)
    -- 查找可被治疗的对象, 优先范围内血量百分比最低的.
    -- 条件: 玩家、玩家的随从、以及正在攻击同一目标(source)的单位; 不能重复, 从 source 附近开始一跳一跳寻找.
    -- 注意: source 只作为起点(目标怪物), 不会被加入治疗列表.
    local chain = {}
    local visited = {}

    -- 从被攻击的怪物(source) 开始搜索
    local from = source
    while #chain < maxCount and from ~= nil do
        local best = FindBestHealTarget(from, source, self.inst, visited)
        if best == nil then
            break
        end
        chain[#chain + 1] = best
        visited[best] = true
        from = best
    end

    return chain
end

function Mon3trSkill:HealChain(source, data)
    local healRate = data.rate or 0
    local healCount = data.count or 0
    local healHealth = data.health or 0
    if healCount <= 1 or healRate <= 0 then
        return {}
    end
    local chain = self:FindHealChain(source, healCount)
    if #chain > 0 and source ~= nil then
        connectHealChain(source, chain[1])
        source:SpawnChild("mon3tr_heal_fx")
        chain[1]:SpawnChild("mon3tr_heal_fx")
        if #chain > 1 then
            for i = 1, #chain - 1 do
                chain[i + 1]:SpawnChild("mon3tr_heal_fx")
                connectHealChain(chain[i], chain[i + 1])
            end
        end
    end

    local nextRate = healRate
    for _, target in ipairs(chain) do
        nextRate = nextRate * self.healRateMultiplier
        if target.components.health then
            target.components.health:DoDelta(healHealth * nextRate)
        end
    end
    return chain
end

local attackHookedSymbol = Symbol("mon3tr_skill_attack_hooked")

local function OnPlayerIdle(inst, data)
    if data.newstate == "idle" then
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
end

local function OnAttackSpeedChanged(inst, data)
    ArkLogger:Debug("OnAttackSpeedChanged", data.speed)
    local comp = inst.components.mon3tr_skill
    if comp and data and data.speed then
        if comp.f_weapon then
            comp.f_weapon.AnimState:SetDeltaTimeMultiplier(data.speed)
        end
        if comp.b_weapon then
            comp.b_weapon.AnimState:SetDeltaTimeMultiplier(data.speed)
        end
    end
end


function Mon3trSkill:RegisterSkill()
    self.inst:ListenForEvent("onhitother", OnHitOtherTask)
    local skill1 = self.inst.components.ark_skill:GetSkill("skill1")
    skill1:SetOnActivate(OnSkill1Activate)

    local skill3 = self.inst.components.ark_skill:GetSkill("skill3")
    skill3:SetActivateTest(Skill3ActivateTest)
    skill3:SetOnActivate(OnSkill3Activate)
    skill3:SetOnActivateEffect(OnSkill3ActivateEffect)
    skill3:SetOnDeactivate(OnSkill3Deactivate)
    if not self.inst[attackHookedSymbol] then
        self.inst[attackHookedSymbol] = true
        local _CombatDoAttack = self.inst.components.combat.DoAttack
        function self.inst.components.combat:DoAttack(targ, weapon, projectile, stimuli, instancemult, instrangeoverride, instpos)
            _CombatDoAttack(self, targ, weapon, projectile, stimuli, instancemult, instrangeoverride, instpos)
            if skill3:IsActivating() then
            -- (target, range, weapon, validfn, stimuli, excludetags, onlyontarget)
                self:DoAreaAttack(self.inst, 3, self:GetWeapon(), nil, stimuli, nil, nil)
            end
        end
    end
    -- 监听进入idle时, 有武器播放武器的idle
    self.inst:ListenForEvent("sgstatechange", OnPlayerIdle)
    -- attackspeedchanged, 修改武器攻速
    self.inst:ListenForEvent("attackspeedchanged", OnAttackSpeedChanged)
end

function Mon3trSkill:ForceDeactivateSkill3()
    local skill3 = self.inst.components.ark_skill:GetSkill("skill3")
    skill3:SetEnergyRecovering(true)
end

function Mon3trSkill._force_deactivate_skill3_cb(inst)
    inst.components.mon3tr_skill:ForceDeactivateSkill3()
end

function Mon3trSkill:SetupSkill3Weapon()
    ArkLogger:Debug("SetupSkill3Weapon")
    if not self.f_weapon then
        local f_weapon = SpawnPrefab("mon3tr_weapon")
        f_weapon.entity:SetParent(self.inst.entity)
        -- f_weapon.entity:AddFollower()
        -- f_weapon.Follower:FollowSymbol(self.inst.GUID, "torso", 0, 0, 0, true)
        -- f_weapon.Transform:SetFromProxy(self.inst.GUID)
        f_weapon.Transform:SetPosition(0, 0, 0)
        f_weapon.AnimState:SetFinalOffset(7)
        f_weapon.AnimState:PlayAnimation("f_idle", true)
        self.f_weapon = f_weapon
    end
    if not self.b_weapon then
        local b_weapon = SpawnPrefab("mon3tr_weapon")
        b_weapon.entity:SetParent(self.inst.entity)
        -- b_weapon.entity:AddFollower()
        -- b_weapon.Follower:FollowSymbol(self.inst.GUID, "torso", 0, 0, 0, true)
        -- b_weapon.Transform:SetFromProxy(self.inst.GUID)
        b_weapon.Transform:SetPosition(0, 0, 0)
        b_weapon.AnimState:SetFinalOffset(-1)
        b_weapon.AnimState:PlayAnimation("b_idle", true)
        self.b_weapon = b_weapon
    end
end

function Mon3trSkill:IsSkill3Activating()
    local skill3 = self.inst.components.ark_skill:GetSkill("skill3")
    return skill3:IsActivating()
end

function Mon3trSkill:RemoveSkill3Weapon()
    ArkLogger:Debug("RemoveSkill3Weapon")
    if self.f_weapon then
        self.f_weapon:Remove()
        self.f_weapon = nil
    end
    if self.b_weapon then
        self.b_weapon:Remove()
        self.b_weapon = nil
    end
end

function Mon3trSkill:OnRemoveFromEntity()
    self:RemoveConstructBeacon()
    self.inst:RemoveComponent("ark_skill")
    self.inst:RemoveEventCallback("onhitother", OnHitOther)
    self.inst:RemoveEventCallback("sgstatechange", OnPlayerIdle)
    self.inst:RemoveEventCallback("attackspeedchanged", OnAttackSpeedChanged)
    self:RemoveSkill3Weapon()
end

function Mon3trSkill:OnRemoveEntity()
    self:RemoveConstructBeacon()
end

return Mon3trSkill
