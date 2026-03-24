local assets =
{
    Asset("ANIM", "anim/mon3tr_weapon.zip"),
}

local function fn()
  local inst = CreateEntity()
  inst.entity:AddTransform()
  inst.entity:AddAnimState()
  inst.entity:AddNetwork()
  inst.Transform:SetFourFaced()
  inst:AddTag("NOCLICK")
  inst:AddTag("FX")

  inst.AnimState:SetBank("mon3tr_weapon")
  inst.AnimState:SetBuild("mon3tr_weapon")
  inst.AnimState:PlayAnimation("f_idle", true)

  inst.entity:SetPristine()
  if not TheWorld.ismastersim then
    return inst
  end

  inst.persists = false

  return inst
end

return Prefab("construct_claw", fn, assets)
