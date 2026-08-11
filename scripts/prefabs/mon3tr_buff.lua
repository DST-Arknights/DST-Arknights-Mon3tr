local function SelfRepairOnAttached(inst, target, followsymbol, followoffset, data, buffer)
    if target.components.combat then
        target.components.combat.externaldamagemultipliers:SetModifier(inst, data.attack_multiplier)
    end
end
local function TacticalSynergyOnAttached(inst, target, followsymbol, followoffset, data, buffer)
    if target.components.combat then
        target.components.combat.attackspeedmodifiers:SetModifier(inst, data.attack_speed_multiplier)
    end
end

local buffs = { {
    name = "mon3tr_self_repair_buff",
    title = STRINGS.UI.MON3TR_SELF_REPAIR_BUFF.TITLE,
    description = function(inst, data, cfg)
        local percent = math.max(0, math.floor((data.attack_multiplier - 1) * 100 + 0.5))
        return string.format(STRINGS.UI.MON3TR_SELF_REPAIR_BUFF.DESC, percent, cfg.duration)
    end,
    icon_atlas = "images/ui_mon3tr_skill.xml",
    icon_image = "skill2.tex",
    keepondespawn = true,
    OnAttached = SelfRepairOnAttached,
    OnDetached = function(inst, target)
        if target.components.combat then
            target.components.combat.externaldamagemultipliers:RemoveModifier(inst)
        end
    end,
    OnExtended = SelfRepairOnAttached,
}, {
    name = "mon3tr_tactical_synergy_buff",
    title = STRINGS.UI.MON3TR_TACTICAL_SYNERGY_BUFF.TITLE,
    description = function(inst, data)
        local percent = math.floor((data.attack_speed_multiplier - 1) * 100 + 0.5)
        return string.format(STRINGS.UI.MON3TR_TACTICAL_SYNERGY_BUFF.DESC, percent)
    end,
    icon_atlas = "images/ui_mon3tr_skill.xml",
    icon_image = "skill1.tex",
    duration = 10,
    keepondespawn = true,
    OnAttached = TacticalSynergyOnAttached,
    OnDetached = function(inst, target)
        if target.components.combat then
            target.components.combat.attackspeedmodifiers:RemoveModifier(inst)
        end
    end,
    OnExtended = TacticalSynergyOnAttached,
} }

local results = {}
for i, v in ipairs(buffs) do
    table.insert(results, ArkMakeBuff(v))
end
return unpack(results)
