local assets =
{
    Asset("ANIM", "anim/wagdrone_laserwire_fx.zip"),
}

local MAX_LEN = 15
local SEG_LEN = 2
local LIFE_TIME = 0.3
local BEAM_COLOUR = { 0.5, 1, 0.5 }

local function CreateSegFxBase()
    local fx = CreateEntity()

    fx:AddTag("FX")
    fx:AddTag("NOCLICK")
    --[[Non-networked entity]]
    fx.entity:SetCanSleep(false)
    fx.persists = false

    fx.entity:AddTransform()
    fx.entity:AddAnimState()
    fx.entity:AddFollower()

    fx.AnimState:SetBuild("wagdrone_laserwire_fx")
    fx.AnimState:SetBank("wagdrone_laserwire_fx")
    fx.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
    fx.AnimState:SetBloomEffectHandle("shaders/anim.ksh")

    fx.persists = false

    return fx
end

local function CreateSegFxShadow(seg, rot, scale, isend)
    local fx = CreateSegFxBase()

    fx.Transform:SetRotation(rot)

    fx._base_alpha = isend and 0.03 or 0.04
    fx.AnimState:SetScale(scale, 1)
    fx.AnimState:SetMultColour(BEAM_COLOUR[1], BEAM_COLOUR[2], BEAM_COLOUR[3], fx._base_alpha)
    fx.AnimState:SetLightOverride(1)
    fx.AnimState:SetLayer(LAYER_BACKGROUND)
    fx.AnimState:SetSortOrder(3)

    fx.entity:SetParent(seg.entity)

    return fx
end

local variations = { 1, 1, 1, 2, 3, 4, 4, 4 }

local function RandomizeAnim(fx)
    local variation = tostring(variations[math.random(#variations)])
    fx.AnimState:PlayAnimation("beam_" .. variation)
    fx.shadow.AnimState:PlayAnimation("shadow_" .. variation)
end

local function CreateSegFx(seg, rot, scale, isend)
    local fx = CreateSegFxBase()

    fx.Transform:SetRotation(rot)

    fx._base_alpha = 1
    fx.AnimState:SetScale(scale, 1)
    fx.AnimState:SetMultColour(BEAM_COLOUR[1], BEAM_COLOUR[2], BEAM_COLOUR[3], fx._base_alpha)
    fx.AnimState:SetLightOverride(1)

    fx.entity:SetParent(seg.entity)
    fx.Follower:FollowSymbol(seg.GUID, "marker")

    fx.shadow = CreateSegFxShadow(seg, rot, scale, isend)

    fx:ListenForEvent("animover", RandomizeAnim)
    RandomizeAnim(fx)

    local frame = math.random(fx.AnimState:GetCurrentAnimationNumFrames()) - 1
    fx.AnimState:SetFrame(frame)
    fx.shadow.AnimState:SetFrame(frame)

    fx.persists = false

    return fx
end

local function CreateSegAt(inst, x, z, rot, scale, isend)
    local seg = CreateEntity()

    seg:AddTag("FX")
    seg:AddTag("NOCLICK")
    --[[Non-networked entity]]
    seg.entity:SetCanSleep(false)
    seg.persists = false

    seg.entity:AddTransform()
    seg.entity:AddAnimState()

    seg.entity:SetParent(inst.entity)
    seg.Transform:SetPosition(x, 0, z)

    seg.AnimState:SetBuild("wagdrone_laserwire_fx")
    seg.AnimState:SetBank("wagdrone_laserwire_fx")
    seg.AnimState:PlayAnimation("follow_marker")

    -- fx will be ground oriented, but raised by following the billboard "follow_marker" symbol.
    seg.fx = CreateSegFx(seg, rot, scale, isend)

    return seg
end

local function ClearSegs(inst)
    if inst.segs then
        for _, v in ipairs(inst.segs) do
            v:Remove()
        end
        inst.segs = nil
    end
end

local function StartLifeTimer(inst)
    if inst.removetask ~= nil then
        inst.removetask:Cancel()
    end
    inst.removetask = inst:DoTaskInTime(LIFE_TIME, function()
        inst:Remove()
    end)
end

local function RefreshSegs(inst)
    local len = inst.len:value() / 255 * MAX_LEN
    local rot = inst.rot:value() / 255 * 360
    local theta = rot * DEGREES
    local costheta = math.cos(theta)
    local sintheta = math.sin(theta)

    if inst.segs == nil and not TheNet:IsDedicated() then
        inst.segs = {}
        local num = math.max(1, math.floor(len / SEG_LEN + 0.5))
        local scale = len / (num * SEG_LEN)
        local spacing = len / num
        local dx = spacing * costheta
        local dz = -spacing * sintheta
        local dstart = (1 - num) / 2
        local x = dx * dstart
        local z = dz * dstart
        for i = 1, num do
            inst.segs[i] = CreateSegAt(inst, x, z, rot, scale, i == 1 or i == num)
            x = x + dx
            z = z + dz
        end
    end
end

local function OnBeamDirty(inst)
    ClearSegs(inst)
    RefreshSegs(inst)
    if TheWorld.ismastersim then
        StartLifeTimer(inst)
    end
end

local function SetBeam(inst, len, rot)
    inst.len:set_local(0) -- force dirty, because we might be calling this when moved
    inst.len:set(math.min(255, math.floor(len / MAX_LEN * 255 + 0.5)))
    inst.rot:set(math.floor((rot < 0 and rot + 360 or rot) / 360 * 255 + 0.5))

    if not inst:IsAsleep() then
        OnBeamDirty(inst)
    end
end

local function CanMouseThrough() -- So that we don't block trying to select other entities.
    return true, false
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddNetwork()

    inst:AddTag("CLASSIFIED")
    inst:AddTag("notarget")

    inst.len = net_byte(inst.GUID, "mon3tr_heal_chain_fx.len", "beamdirty")
    inst.rot = net_byte(inst.GUID, "mon3tr_heal_chain_fx.rot", "beamdirty")

    inst:SetPrefabNameOverride("mon3tr")
    inst.CanMouseThrough = CanMouseThrough

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("beamdirty", OnBeamDirty)
        return inst
    end

    inst.removetask = nil
    inst.SetBeam = SetBeam
    inst.OnEntitySleep = ClearSegs
    inst.OnEntityWake = RefreshSegs

    inst.persists = false

    return inst
end

return Prefab("mon3tr_heal_chain_fx", fn, assets)
