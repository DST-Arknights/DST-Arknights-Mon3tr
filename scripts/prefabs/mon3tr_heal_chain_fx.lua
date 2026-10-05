local assets = {
    Asset("ANIM", "anim/mon3tr_heal_chain_01.zip"),
    Asset("ANIM", "anim/mon3tr_heal_chain_02.zip"),
}

-- 原版 electric field 使用 150 像素/世界单位；这批帧的两个端点相距 459.2 像素。
local BEAM_LENGTH = 459.2 / 150
local BEAM_HEIGHT = 1
local BEAM_THICKNESS_SCALE = 3
local LIFE_TIME = 0.6
local BEAM_BANKS = { "mon3tr_heal_chain_01", "mon3tr_heal_chain_02" }

local function ClearBeam(inst)
    if inst._update_task ~= nil then
        inst._update_task:Cancel()
        inst._update_task = nil
    end
    if inst._beam ~= nil then
        inst._beam:Remove()
        inst._beam = nil
    end
end

local function CreateBeam(inst, variant)
    local fx = CreateEntity()
    fx.entity:AddTransform()
    fx.entity:AddAnimState()
    fx.entity:SetCanSleep(false)
    fx.entity:SetParent(inst.entity)
    fx:AddTag("FX")
    fx:AddTag("NOCLICK")
    fx.persists = false
    fx.AnimState:SetBank(BEAM_BANKS[variant])
    fx.AnimState:SetBuild(BEAM_BANKS[variant])
    fx.AnimState:PlayAnimation("heal")
    fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")
    fx.AnimState:SetLightOverride(1)
    fx.AnimState:SetFinalOffset(0)
    return fx
end

local function UpdateBeam(inst)
    local source = inst._source:value()
    local target = inst._target:value()
    local variant = inst._variant:value()
    if source == nil or target == nil or not source:IsValid() or not target:IsValid() or variant == 0 then
        if inst._beam ~= nil then
            inst._beam:Hide()
        end
        return
    end
    if inst._beam == nil then
        inst._beam = CreateBeam(inst, variant)
    end
    local x, y, z = source.Transform:GetWorldPosition()
    local tx, _, tz = target.Transform:GetWorldPosition()
    local ox, oy, oz = inst.Transform:GetWorldPosition()
    local dx, dz = tx - x, tz - z
    local length = math.sqrt(dx * dx + dz * dz)
    local beam = inst._beam
    beam:Show()
    beam.Transform:SetPosition(x - ox, y + BEAM_HEIGHT - oy, z - oz)
    beam.Transform:SetRotation(math.atan2(-dz, dx) * RADIANS)
    beam.AnimState:SetScale(length / BEAM_LENGTH, BEAM_THICKNESS_SCALE)
end

local function StartBeam(inst)
    if inst._update_task == nil then
        inst._update_task = inst:DoPeriodicTask(FRAMES, UpdateBeam)
    end
    UpdateBeam(inst)
end

local function SetEndpoints(inst, source, target)
    local x, y, z = source.Transform:GetWorldPosition()
    local tx, ty, tz = target.Transform:GetWorldPosition()
    -- 联网控制器留在中点，客户端只更新一个本地精灵，不回写联网 Transform。
    inst.Transform:SetPosition((x + tx) / 2, (y + ty) / 2, (z + tz) / 2)
    inst._source:set(source)
    inst._target:set(target)
    inst._variant:set(math.random(2))
    local function OnEndpointRemoved()
        if inst:IsValid() then
            inst:Remove()
        end
    end
    inst:ListenForEvent("onremove", OnEndpointRemoved, source)
    inst:ListenForEvent("onremove", OnEndpointRemoved, target)
    if not TheNet:IsDedicated() then
        StartBeam(inst)
    end
    inst:DoTaskInTime(LIFE_TIME, inst.Remove)
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddNetwork()
    inst.entity:SetCanSleep(false)
    inst:AddTag("FX")
    inst:AddTag("NOCLICK")
    inst:AddTag("notarget")
    inst._source = net_entity(inst.GUID, "mon3tr_heal_chain_fx.source", "beamdirty")
    inst._target = net_entity(inst.GUID, "mon3tr_heal_chain_fx.target", "beamdirty")
    inst._variant = net_tinybyte(inst.GUID, "mon3tr_heal_chain_fx.variant", "beamdirty")
    inst.persists = false
    inst.entity:SetPristine()
    if not TheNet:IsDedicated() then
        inst:ListenForEvent("onremove", ClearBeam)
    end
    if not TheWorld.ismastersim then
        inst:ListenForEvent("beamdirty", StartBeam)
        -- 初始网络值可能已到达；后续更新也会等待两端实体完成解析。
        inst:DoTaskInTime(0, StartBeam)
        return inst
    end
    inst.SetEndpoints = SetEndpoints
    return inst
end

return Prefab("mon3tr_heal_chain_fx", fn, assets)
