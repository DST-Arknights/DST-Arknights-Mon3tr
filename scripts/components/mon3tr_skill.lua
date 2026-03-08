local skillConfig = require "mon3tr_skill_config"
local ATTACK_RECOVERY_ENERGY = 1
local HEAL_CHAIN_RANGE = 16
local HEAL_CHAIN_EXCLUDE_TAGS = { "INLIMBO", "flight", "invisible", "notarget", "noattack" }

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
        local attack_speed = skillConfig.elites[playerElite].tactical_synergy_attack_speed
        for _, target in ipairs(chain) do
            target:AddDebuff("mon3tr_tactical_synergy_buff", "mon3tr_tactical_synergy_buff", { attack_speed = attack_speed })
        end
    end
end


local Mon3trSkill = Class(function(self, inst)
    self.inst = inst
    self.healRateMultiplier = 0.75
    inst:AddComponent("ark_skill")
    for _, skill in ipairs(skillConfig.skills) do
        inst.components.ark_skill:RegisterSkill(skill)
    end
    self:RegisterSkill()
end)

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

function Mon3trSkill:RegisterSkill()
    self.inst:ListenForEvent("onhitother", OnHitOther)
    local skill1 = self.inst.components.ark_skill:GetSkill("skill1")
    skill1:SetOnActive(OnSkill1Activate)
end

function Mon3trSkill:OnRemoveFromEntity()
    self.inst:RemoveComponent("ark_skill")
    self.inst:RemoveEventCallback("onhitother", OnHitOther)
end

return Mon3trSkill
