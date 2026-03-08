local ATTACK_MULTIPLIER_KEY = "mon3tr_self_repair_buff"
local TIMER_KEY = "mon3tr_self_repair_buff"

local function BuildBuffData(data)
    return {
        duration = data.duration,
        attack_multiplier = data.attack_multiplier,
    }
end

local function OnTimerDone(inst, data)
    if data.name == TIMER_KEY then
        inst.components.debuff:Stop()
    end
end

local function BuildDesc(buffData)
    local percent = math.max(0, math.floor((buffData.attack_multiplier - 1) * 100 + 0.5))
    return string.format(STRINGS.UI.MON3TR_SELF_REPAIR_BUFF.DESC, percent, buffData.duration)
end

local function ApplyEffect(inst, target, remainTime)
    if target.components.combat ~= nil then
        target.components.combat.externaldamagemultipliers:SetModifier(inst, inst.buffData.attack_multiplier, ATTACK_MULTIPLIER_KEY)
    end

    inst.components.ark_buff_icon:SetDesc(BuildDesc(inst.buffData))
    inst.components.ark_buff_icon:SetRemainingTime(remainTime)
    inst.components.ark_buff_icon:SetTotalTime(inst.buffData.duration)
end

local function OnAttached(inst, target, followsymbol, followoffset, data, buffer)
    inst.entity:SetParent(target.entity)
    inst.Transform:SetPosition(0, 0, 0) -- in case of loading
    inst:ListenForEvent("death", function()
        inst.components.debuff:Stop()
    end, target)

    inst.buffData = BuildBuffData(data)

    local remainTime = inst.buffData.duration
    if inst.components.timer:TimerExists(TIMER_KEY) then
        remainTime = inst.components.timer:GetTimeLeft(TIMER_KEY)
    else
        inst.components.timer:StartTimer(TIMER_KEY, inst.buffData.duration)
    end

    ApplyEffect(inst, target, remainTime)
    inst.components.ark_buff_icon:AttachTo(target)
end

local function OnExtended(inst, target, followsymbol, followoffset, data, buffer)
    inst.buffData = BuildBuffData(data)
    inst.components.timer:StopTimer(TIMER_KEY)
    inst.components.timer:StartTimer(TIMER_KEY, inst.buffData.duration)
    ApplyEffect(inst, target, inst.buffData.duration)
end

local function OnDetached(inst, target)
    if target.components.combat ~= nil then
        target.components.combat.externaldamagemultipliers:RemoveModifier(inst, ATTACK_MULTIPLIER_KEY)
    end
    inst:Remove()
end

local function OnSave(inst, data)
    data.buffData = inst.buffData
end

local function OnLoad(inst, data)
    if data and data.buffData then
        inst.buffData = BuildBuffData(data.buffData)
    end
end

local function mon3tr_self_repair_buff_fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:Hide()
    inst:AddTag("CLASSIFIED")

    if not TheWorld.ismastersim then
        return inst
    end

    inst.persists = false
    inst.entity:SetCanSleep(false)
    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", OnTimerDone)

    inst.buffData = nil

    inst:AddComponent("debuff")
    inst.components.debuff:SetAttachedFn(OnAttached)
    inst.components.debuff:SetDetachedFn(OnDetached)
    inst.components.debuff:SetExtendedFn(OnExtended)

    inst:AddComponent("ark_buff_icon")
    inst.components.ark_buff_icon:SetTitle(STRINGS.UI.MON3TR_SELF_REPAIR_BUFF.TITLE)
    inst.components.ark_buff_icon:SetTexture("images/ui_mon3tr_skill.xml", "skill2.tex")
    -- buff icon will be initialized when the debuff is attached with valid buffData

    inst.OnSave = OnSave
    inst.OnLoad = OnLoad

    return inst
end

return Prefab("mon3tr_self_repair_buff", mon3tr_self_repair_buff_fn)
