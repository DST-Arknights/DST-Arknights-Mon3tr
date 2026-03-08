local ATTACK_MULTIPLIER_KEY = "mon3tr_tactical_synergy_buff"
local TIMER_KEY = "mon3tr_tactical_synergy_buff"
local TOTAL_TIME = 10

local function OnTimerDone(inst, data)
  if data.name == TIMER_KEY then
    inst.components.debuff:Stop()
  end
end

local function ApplyEffect(inst, target, remain_time)
  if target.components.combat then
    target.components.combat.attackspeedmodifiers:SetModifier(inst, inst.buffData.attack_speed_multiplier, ATTACK_MULTIPLIER_KEY)
  end
  local template = STRINGS.UI.MON3TR_TACTICAL_SYNERGY_BUFF.DESC
  local percent = math.floor((inst.buffData.attack_speed_multiplier - 1) * 100 + 0.5)
  inst.components.ark_buff_icon:SetDesc(string.format(template, percent))
  inst.components.ark_buff_icon:SetRemainingTime(remain_time)
end


local function OnAttached(inst, target, followsymbol, followoffset, data, buffer)
  inst.entity:SetParent(target.entity)
  inst.Transform:SetPosition(0, 0, 0) --in case of loading
  inst:ListenForEvent("death", function()
    inst.components.debuff:Stop()
  end, target)
  if data then
    inst.buffData = data
  end
  local remain_time = TOTAL_TIME
  if inst.components.timer:TimerExists(TIMER_KEY) then
    remain_time = inst.components.timer:GetTimeLeft(TIMER_KEY)
  else
    inst.components.timer:StartTimer(TIMER_KEY, TOTAL_TIME)
  end
  ApplyEffect(inst, target, remain_time)
  inst.components.ark_buff_icon:AttachTo(target)
end

local function OnExtended(inst, target, followsymbol, followoffset, data, buffer)
  if data then
    inst.buffData = data
  end
  -- 重置计时器, 刷新时间
  inst.components.timer:StopTimer(TIMER_KEY)
  inst.components.timer:StartTimer(TIMER_KEY, TOTAL_TIME)
  ApplyEffect(inst, target, TOTAL_TIME)
end

local function OnDetached(inst, target)
  if target.components.combat then
    target.components.combat.attackspeedmodifiers:RemoveModifier(inst, ATTACK_MULTIPLIER_KEY)
  end
  inst:Remove()
end

local function OnSave(inst, data)
  data.buffData = inst.buffData
end

local function OnLoad(inst, data)
  if data and data.buffData then
    inst.buffData = data.buffData
  end
end

local fn = function()
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
  inst.buffData = { attack_speed_multiplier = 1.1 }
  inst:AddComponent("debuff")
  inst.components.debuff:SetAttachedFn(OnAttached)
  inst.components.debuff:SetDetachedFn(OnDetached)
  inst.components.debuff:SetExtendedFn(OnExtended)
  inst:AddComponent("ark_buff_icon")
  inst.components.ark_buff_icon:SetTitle(STRINGS.UI.MON3TR_TACTICAL_SYNERGY_BUFF.TITLE)
  inst.components.ark_buff_icon:SetTexture("images/ui_mon3tr_skill.xml", "skill1.tex")
  inst.components.ark_buff_icon:SetTotalTime(TOTAL_TIME)
  inst.OnSave = OnSave
  inst.OnLoad = OnLoad
  return inst
end
return Prefab("mon3tr_tactical_synergy_buff", fn)
