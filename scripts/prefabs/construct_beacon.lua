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

    inst.AnimState:SetBank("construct_beacon")
    inst.AnimState:SetBuild("construct_beacon")
    inst.AnimState:PlayAnimation("idle", true)
    -- 1.5倍播放
    inst.AnimState:SetDeltaTimeMultiplier(2)
    -- 不可点击
    inst:AddTag("NOCLICK")

    -- 不存档
    inst.persists = false
    return inst
end

return Prefab("construct_beacon", fn, assets)
