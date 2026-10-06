local assets =
{
    Asset("ANIM", "anim/swap_construct_sword.zip"),
}

local SWORD_SYMBOL = "construct_sword"

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower()
    inst.entity:AddNetwork()

    inst:AddTag("FX")
    inst:AddTag("NOCLICK")

    inst.AnimState:SetBank("swap_construct_sword")
    inst.AnimState:SetBuild("swap_construct_sword")
    inst.AnimState:PlayAnimation("BUILD", true)
    inst.AnimState:SetSymbolBloom(SWORD_SYMBOL)
    inst.AnimState:SetSymbolLightOverride(SWORD_SYMBOL, 0.5)
    inst.AnimState:SetLightOverride(0.1)

    inst:AddComponent("highlightchild")

    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        return inst
    end

    inst:AddComponent("colouradder")
    inst.persists = false

    return inst
end

return Prefab("construct_sword_blade_fx", fn, assets)
