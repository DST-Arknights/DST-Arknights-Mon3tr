RegisterInventoryItemAtlas("images/inventoryimages/construct_sword.xml", "construct_sword.tex")
local assets =
{
    Asset("ATLAS", "images/inventoryimages/construct_sword.xml"),
    Asset("ANIM", "anim/construct_sword.zip"),
    Asset("ANIM", "anim/swap_construct_sword.zip"),
}

local prefabs =
{
    "construct_sword_blade_fx",
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
local AUTO_CHARGE_MIN_HUNGER = 40
local SKILL3_CONDITION_COST_PERCENT = 0.1

local SWORD_SYMBOL = "construct_sword"

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
    local weapon = inst.components.weapon
    if weapon ~= nil then
        local damage = BASE_DAMAGE + MAX_DAMAGE_BONUS * GetDurabilityPercent(inst)
        local owner = inst.components.inventoryitem.owner
        local is_mon3tr_equipped = inst.components.equippable:IsEquipped()
            and owner ~= nil and owner.prefab == "mon3tr"

        weapon:SetDamage(is_mon3tr_equipped and 0 or damage)
        weapon.true_damage = is_mon3tr_equipped and damage or 0
    end
end

local function SetSwordGlowColour(animstate, percent)
    local red = Lerp(0.2, 1.0, percent)
    local green = Lerp(0.45, 0.2, percent)
    local blue = Lerp(1.0, 0.15, percent)
    local intensity = Lerp(0.08, 0.45, percent)

    animstate:SetSymbolMultColour(SWORD_SYMBOL, Lerp(0.8, 1.0, percent), Lerp(0.9, 0.75, percent), Lerp(1.0, 0.8, percent), 1)
    animstate:SetSymbolAddColour(SWORD_SYMBOL, red * intensity, green * intensity, blue * intensity, 0)
end

local function UpdateSwordGlow(inst)
    local percent = GetDurabilityPercent(inst)
    SetSwordGlowColour(inst.AnimState, percent)
    SetSwordGlowColour(inst.bladefx.AnimState, percent)
end

local function SetFxOwner(inst, owner)
    if inst._fxowner ~= nil and inst._fxowner.components.colouradder ~= nil then
        inst._fxowner.components.colouradder:DetachChild(inst.bladefx)
    end

    inst._fxowner = owner
    if owner ~= nil then
        inst.bladefx.entity:SetParent(owner.entity)
        inst.bladefx.Follower:FollowSymbol(owner.GUID, "swap_object", nil, nil, nil, true)
        inst.bladefx.components.highlightchild:SetOwner(owner)
        if owner.components.colouradder ~= nil then
            owner.components.colouradder:AttachChild(inst.bladefx)
        end
    else
        inst.bladefx.entity:SetParent(inst.entity)
        -- 地面 idle 使用物品本体泛光；此 symbol 只在漂浮时显示。
        inst.bladefx.Follower:FollowSymbol(inst.GUID, "swap_spear", nil, nil, nil, true)
        inst.bladefx.components.highlightchild:SetOwner(inst)
    end
end

local function OnRemoveSword(inst)
    if inst._fxowner ~= nil and inst._fxowner.components.colouradder ~= nil then
        inst._fxowner.components.colouradder:DetachChild(inst.bladefx)
    end
    if inst.bladefx:IsValid() then
        inst.bladefx:Remove()
    end
    inst._fxowner = nil
    inst.bladefx = nil
end

local function RefreshSwordState(inst)
    UpdateWeaponDamage(inst)
    UpdateSwordGlow(inst)
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
    local availableHunger = hunger.current - AUTO_CHARGE_MIN_HUNGER
    if availableHunger <= 0 then
        return
    end

    local current = finiteuses:GetUses()
    local thresholdCondition = finiteuses.total * AUTO_CHARGE_CONDITION_THRESHOLD
    local missingToThreshold = thresholdCondition - current
    if missingToThreshold <= 0 then
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
    SetFxOwner(inst, owner)

    inst:ListenForEvent("mon3tr_healed", inst._OnMon3trSkillHeal, owner)
    RefreshSwordState(inst)
    StartExchangeTask(inst)
end

local function onunequip(inst, owner)
    owner.AnimState:Hide("ARM_carry")
    owner.AnimState:Show("ARM_normal")
    inst:RemoveEventCallback("mon3tr_healed", inst._OnMon3trSkillHeal, owner)
    UpdateWeaponDamage(inst)
    SetFxOwner(inst, nil)
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
    inst.AnimState:SetSymbolBloom(SWORD_SYMBOL)
    inst.AnimState:SetSymbolLightOverride(SWORD_SYMBOL, 0.5)
    inst.AnimState:SetLightOverride(0.1)

    inst:AddTag("sharp")
    inst:AddTag("pointy")

    --weapon (from weapon component) added to pristine state for optimization
    inst:AddTag("weapon")

    MakeInventoryFloatable(inst, "med", 0.05, {1.1, 0.5, 1.1}, true, -9,
        { sym_build = "swap_construct_sword", sym_name = SWORD_SYMBOL })

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst.bladefx = SpawnPrefab("construct_sword_blade_fx")
    SetFxOwner(inst, nil)
    -- inventoryitem 移除时仍会触发卸装，特效要保留到组件清理完成。
    inst.OnRemoveEntity = OnRemoveSword

    -- 只监听持有者身上的被治疗事件。
    inst._OnMon3trSkillHeal = function(_, data)
        if data == nil or data.amount == nil or data.amount <= 0 then
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

return Prefab("construct_sword", fn, assets, prefabs)
