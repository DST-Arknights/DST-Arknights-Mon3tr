RegisterInventoryItemAtlas("images/inventoryimages/construct_beacon.xml", "construct_beacon.tex")
local assets =
{
    Asset("ANIM", "anim/construct_beacon.zip"),
    Asset("ATLAS", "images/inventoryimages/construct_beacon.xml"),
}

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()
    inst.entity:AddLight()

    inst.Light:SetRadius(1.8)
    inst.Light:SetFalloff(0.9)
    inst.Light:SetIntensity(0.65)
    inst.Light:SetColour(1, 0.15, 0.15)
    inst.Light:Enable(true)

    inst.AnimState:SetBank("construct_beacon")
    inst.AnimState:SetBuild("construct_beacon")
    inst.AnimState:PlayAnimation("idle", true)
    inst.AnimState:SetScale(3, 3, 3)
    -- 1.5倍播放
    inst.AnimState:SetDeltaTimeMultiplier(2)
    -- 不可点击
    inst:AddTag("NOCLICK")

    -- 不存档
    inst.persists = false
    return inst
end

return Prefab("construct_beacon", fn, assets)
