local skillConfig = require "mon3tr_skill_config"
local ATTACK_RECOVERY_ENERGY = 1
local HEAL_CHAIN_RANGE = 16

local function OnSkill1Activate(inst, data)
    local target = data.target
    if not target then
        return
    end
    local chain = inst.components.mon3tr_skill:HealChain(target)
end

local function connectHealChain(source, target)
    local x, y, z = source.Transform:GetWorldPosition()
    local x1, y1, z1 = target.Transform:GetWorldPosition()
    local dx = x1 - x
    local dz = z1 - z
    local dsq = dx * dx + dz * dz
    local fx = SpawnPrefab("mon3tr_heal_chain_fx")
    fx.Transform:SetPosition((x + x1) / 2, 0, (z + z1) / 2)
    fx:SetBeam(math.sqrt(dsq), math.atan2(-dz, dx) * RADIANS)
end

local function OnAttackOther(inst, data)
    if not inst.components.ark_skill then
        return
    end
    local skill1 = inst.components.ark_skill:GetSkill("skill1")
    local skill2 = inst.components.ark_skill:GetSkill("skill2")
    local skill3 = inst.components.ark_skill:GetSkill("skill3")

    -- 技能1自动释放与充能互斥
    if not (data and data.target and skill1:TryActivate(data.target)) then
        skill1:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
    end
    if not (skill2:IsActivating()) then
        skill2:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
    end
    if not (skill3:IsActivating()) then
        skill3:AddEnergyProgress(ATTACK_RECOVERY_ENERGY)
    end
end


local Mon3trSkill = Class(function(self, inst)
    self.inst = inst
    inst:AddComponent("ark_skill")
    for _, skill in ipairs(skillConfig.skills) do
        inst.components.ark_skill:RegisterSkill(skill)
    end
    self:RegisterSkill()
end)

function Mon3trSkill:Heal(target, idx)
    -- 从100%, 每次后续都为前一次的75%
    local percent = 1 * math.pow(0.75, idx)
    local defaultDamage = self.inst.components.combat.defaultdamage
    if target.components.health then
        target.components.health:DoDelta(defaultDamage * percent)
    end
end

function Mon3trSkill:FindHealChain(source, maxCount)
    -- 查找可被治疗的对象, 优先范围内血量百分比最低的.
    -- 条件: 玩家、玩家的随从、以及正在攻击同一目标(source)的单位; 不能重复, 从 source 附近开始一跳一跳寻找.
    -- 注意: source 只作为起点(目标怪物), 不会被加入治疗列表.
    local chain = {}

    local function CanBeHealed(ent)
        if ent == nil or ent == source or not ent:IsValid() then
            return false
        end
        if ent.components == nil or ent.components.health == nil then
            return false
        end
        if ent.components.health:IsDead() or ent:HasTag("playerghost") then
            return false
        end
        if ent.components.combat then
            if ent.components.combat.target == self.inst then
                return false
            end
        end

        -- 玩家
        if ent:HasTag("player") then
            return true
        end

        -- 玩家随从
        if ent.components.follower ~= nil then
            local leader = ent.components.follower.leader
            if leader ~= nil and leader:HasTag("player") then
                return true
            end
        end

        -- 正在攻击同一目标(source) 的单位
        if ent.components.combat ~= nil and ent.components.combat.target == source then
            return true
        end

        return false
    end

    local function findNext(from)
        if #chain >= maxCount then
            return
        end

        local x, y, z = from.Transform:GetWorldPosition()
        local ents = TheSim:FindEntities(x, y, z, HEAL_CHAIN_RANGE, nil,
            { "INLIMBO", "flight", "invisible", "notarget", "noattack" })

        local best
        local best_percent

        for _, v in ipairs(ents) do
            if v ~= from and CanBeHealed(v) and not table.contains(chain, v) then
                local hp = v.components.health
                local percent = hp ~= nil and hp:GetPercent() or 1
                if best == nil or percent < best_percent then
                    best = v
                    best_percent = percent
                end
            end
        end

        if best ~= nil then
            table.insert(chain, best)
            findNext(best)
        end
    end

    -- 从被攻击的怪物(source) 开始搜索
    if source ~= nil and source.Transform ~= nil then
        findNext(source)
    end

    return chain
end

function Mon3trSkill:HealChain(source)
    local healChainCount = 0
    for _, skillConfig in ipairs(skillConfig.skills) do
        local skill = self.inst.components.ark_skill:GetSkill(skillConfig.id)
        if skill:IsActivating() then
            local levelConfig = skill:GetLevelConfig()
            healChainCount = math.max(healChainCount, levelConfig.healChainCount or 0)
        end
    end
    if healChainCount <= 1 then
        return
    end
    local chain = self:FindHealChain(source, healChainCount)
    if #chain > 1 then
        connectHealChain(source, chain[1])
        source:SpawnChild("mon3tr_heal_fx")
        chain[1]:SpawnChild("mon3tr_heal_fx")
        for i = 1, #chain - 1 do
            chain[i + 1]:SpawnChild("mon3tr_heal_fx")
            connectHealChain(chain[i], chain[i + 1])
        end
    end
    local playerElite = self.inst.components.ark_elite and self.inst.components.ark_elite.elite or 1
    for idx, target in ipairs(chain) do
        self:Heal(target, idx)
        if playerElite > 1 then
            local attack_speed = skillConfig.elites[playerElite].tactical_synergy_attack_speed
            target:AddDebuff("mon3tr_tactical_synergy_buff", "mon3tr_tactical_synergy_buff", { attack_speed = attack_speed })
        end
    end
    return chain
end

function Mon3trSkill:RegisterSkill()
    self.inst:ListenForEvent("onattackother", OnAttackOther)
    local skill1 = self.inst.components.ark_skill:GetSkill("skill1")
    skill1:SetOnActive(OnSkill1Activate)
end

function Mon3trSkill:OnRemoveFromEntity()
    self.inst:RemoveComponent("ark_skill")
    self.inst:RemoveEventCallback("onattackother", OnAttackOther)
end

return Mon3trSkill
