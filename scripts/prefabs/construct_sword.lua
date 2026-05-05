RegisterInventoryItemAtlas("images/inventoryimages/construct_sword.xml", "construct_sword.tex")
local assets =
{
    Asset("ATLAS", "images/inventoryimages/construct_sword.xml"),
    Asset("ANIM", "anim/construct_sword.zip"),
    Asset("ANIM", "anim/swap_construct_sword.zip"),
}

local MAX_CONDITION = 1000
local INITIAL_CONDITION_PERCENT = 0.05
local BASE_DAMAGE = 42
local MAX_DAMAGE_BONUS = 100
local HEAL_TO_CONDITION_RATE = 0.1
local EXCHANGE_RATE_PER_SECOND = MAX_CONDITION / (6*8 * 60)
local EXCHANGE_TICK = 3
local HUNGER_TO_CONDITION_RATE = 1
local AUTO_CHARGE_CONDITION_THRESHOLD = 0.8
local AUTO_CHARGE_MIN_HUNGER_PERCENT = 0.6
local SKILL3_CONDITION_COST_PERCENT = 0.1

local TRUE_DAMAGE_MODIFIER_KEY = "construct_sword_true_damage"
local BLOOM_SYMBOL = "swap_object"

local function Clamp01(value)
    return math.max(0, math.min(1, value or 0))
end

local function Lerp(from, to, percent)
    return from + (to - from) * percent
end

local function GetDurabilityPercent(inst)
    local finiteuses = inst.components.finiteuses
    return finiteuses ~= nil and Clamp01(finiteuses:GetPercent()) or 0
end

local function UpdateWeaponDamage(inst)
    if inst.components.weapon ~= nil then
        inst.components.weapon:SetDamage(BASE_DAMAGE + MAX_DAMAGE_BONUS * GetDurabilityPercent(inst))
    end
end

local function ClearOwnerCombatModifier(owner)
    if owner ~= nil and owner.components.combat ~= nil and owner.components.combat.truedamagemultipliers ~= nil then
        owner.components.combat.truedamagemultipliers:RemoveModifier(TRUE_DAMAGE_MODIFIER_KEY)
    end
end

local function ApplyOwnerCombatModifier(inst, owner)
    if owner ~= nil and owner.components.combat ~= nil and owner.components.combat.truedamagemultipliers ~= nil then
        owner.components.combat.truedamagemultipliers:SetModifier(TRUE_DAMAGE_MODIFIER_KEY, GetDurabilityPercent(inst))
    end
end

local function ClearSwordBloom(owner)
    if owner == nil or owner.AnimState == nil then
        return
    end

    owner.AnimState:ClearSymbolBloom(BLOOM_SYMBOL)
    owner.AnimState:SetSymbolMultColour(BLOOM_SYMBOL, 1, 1, 1, 1)
    owner.AnimState:SetSymbolAddColour(BLOOM_SYMBOL, 0, 0, 0, 0)
end

local function UpdateSwordBloom(inst, owner)
    if owner == nil or owner.AnimState == nil then
        return
    end

    local percent = GetDurabilityPercent(inst)
    local red = Lerp(0.2, 1.0, percent)
    local green = Lerp(0.45, 0.2, percent)
    local blue = Lerp(1.0, 0.15, percent)
    local intensity = Lerp(0.08, 0.45, percent)

    owner.AnimState:SetSymbolBloom(BLOOM_SYMBOL)
    owner.AnimState:SetSymbolMultColour(BLOOM_SYMBOL, Lerp(0.8, 1.0, percent), Lerp(0.9, 0.75, percent), Lerp(1.0, 0.8, percent), 1)
    owner.AnimState:SetSymbolAddColour(BLOOM_SYMBOL, red * intensity, green * intensity, blue * intensity, 0)
end

local function RefreshSwordState(inst)
    UpdateWeaponDamage(inst)

    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
    if owner ~= nil and inst.components.equippable ~= nil and inst.components.equippable:IsEquipped() then
        ApplyOwnerCombatModifier(inst, owner)
        UpdateSwordBloom(inst, owner)
    end
end

local function RepairCondition(inst, amount)
    local finiteuses = inst.components.finiteuses
    if finiteuses == nil or amount == nil or amount <= 0 then
        return 0
    end

    local before = finiteuses:GetUses()
    finiteuses:Repair(amount)
    return finiteuses:GetUses() - before
end

local function DoSwordHungerExchange(inst)
    if inst.components.equippable == nil or not inst.components.equippable:IsEquipped() then
        return
    end

    local owner = inst.components.inventoryitem ~= nil and inst.components.inventoryitem.owner or nil
    if owner == nil or owner.components.hunger == nil or owner.components.health == nil or owner.components.health:IsDead() then
        return
    end

    local finiteuses = inst.components.finiteuses
    if finiteuses == nil then
        return
    end

    local percent = GetDurabilityPercent(inst)
    if percent >= AUTO_CHARGE_CONDITION_THRESHOLD then
        return
    end

    local hunger = owner.components.hunger
    if hunger:GetPercent() <= AUTO_CHARGE_MIN_HUNGER_PERCENT then
        return
    end

    local current = finiteuses:GetUses()
    local thresholdCondition = finiteuses.total * AUTO_CHARGE_CONDITION_THRESHOLD
    local missingToThreshold = thresholdCondition - current
    if missingToThreshold <= 0 then
        return
    end

    local minHunger = hunger.max * AUTO_CHARGE_MIN_HUNGER_PERCENT
    local availableHunger = hunger.current - minHunger
    if availableHunger <= 0 then
        return
    end

    local maxRepairFromHunger = availableHunger * HUNGER_TO_CONDITION_RATE
    local repair = math.min(EXCHANGE_RATE_PER_SECOND * EXCHANGE_TICK, missingToThreshold, maxRepairFromHunger)
    if repair <= 0 then
        return
    end

    hunger:DoDelta(-(repair / HUNGER_TO_CONDITION_RATE), true, true)
    RepairCondition(inst, repair)
end

local function StartExchangeTask(inst)
    if inst._exchange_task == nil then
        inst._exchange_task = inst:DoPeriodicTask(EXCHANGE_TICK, DoSwordHungerExchange)
    end
end

local function StopExchangeTask(inst)
    if inst._exchange_task ~= nil then
        inst._exchange_task:Cancel()
        inst._exchange_task = nil
    end
end

local function onequip(inst, owner)
    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("equipskinneditem", inst:GetSkinName())
        owner.AnimState:OverrideItemSkinSymbol("swap_object", skin_build, "swap_construct_sword", inst.GUID, "construct_sword")
    else
        owner.AnimState:OverrideSymbol("swap_object", "swap_construct_sword", "construct_sword")
    end
    owner.AnimState:Show("ARM_carry")
    owner.AnimState:Hide("ARM_normal")

    inst:ListenForEvent("mon3tr_healed", inst._OnMon3trSkillHeal, owner)
    RefreshSwordState(inst)
    StartExchangeTask(inst)
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    inst:RemoveEventCallback("mon3tr_healed", inst._OnMon3trSkillHeal, owner)
    ClearOwnerCombatModifier(owner)
    ClearSwordBloom(owner)
    StopExchangeTask(inst)

    local skin_build = inst:GetSkinBuild()
    if skin_build ~= nil then
        owner:PushEvent("unequipskinneditem", inst:GetSkinName())
    end
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("construct_sword")
    inst.AnimState:SetBuild("construct_sword")
    inst.AnimState:PlayAnimation("idle")

    inst:AddTag("sharp")
    inst:AddTag("pointy")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    MakeInventoryFloatable(inst, "med", 0.05, {1.1, 0.5, 1.1}, true, -9)

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst._OnMon3trSkillHeal = function(owner, data)
        if data == nil or data.amount == nil or data.amount <= 0 then
            return
        end
        -- 只有持有者自己被治疗才充能
        if data.target ~= owner then
            return
        end
        -- 80% 以上才接受治疗充能
        if GetDurabilityPercent(inst) < AUTO_CHARGE_CONDITION_THRESHOLD then
            return
        end
        local amount = math.floor(data.amount * HEAL_TO_CONDITION_RATE)
        RepairCondition(inst, amount)
    end

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(BASE_DAMAGE)

    -------
    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "construct_sword"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/construct_sword.xml"

    inst:AddComponent("finiteuses")
    inst.components.finiteuses:SetMaxUses(MAX_CONDITION)
    inst.components.finiteuses:SetUses(MAX_CONDITION * INITIAL_CONDITION_PERCENT)
    inst.components.finiteuses:SetDoesNotStartFull(true)
    inst.components.finiteuses:SetIgnoreCombatDurabilityLoss(true)
    inst:ListenForEvent("percentusedchange", function() RefreshSwordState(inst) end)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    function inst:ConsumeSkill3DurabilityBonus()
        local finiteuses = self.components.finiteuses
        if finiteuses == nil then
            return 0
        end

        local current = finiteuses:GetUses()
        if current <= 0 then
            return 0
        end

        local percentBefore = current / finiteuses.total
        local drain = math.min(current, finiteuses.total * SKILL3_CONDITION_COST_PERCENT)
        if drain <= 0 then
            return 0
        end

        finiteuses:Use(drain)
        return drain * (0.5 + percentBefore)
    end

    RefreshSwordState(inst)

    MakeHauntableLaunch(inst)

    return inst
end

return Prefab("construct_sword", fn, assets)
