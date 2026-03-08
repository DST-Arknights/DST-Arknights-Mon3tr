local assets =
{
	Asset( "ANIM", "anim/mon3tr.zip" ),
	Asset( "ANIM", "anim/ghost_mon3tr_build.zip" ),
}

local skins =
{
	normal_skin = "mon3tr",
	ghost_skin = "ghost_mon3tr_build",
}

return CreatePrefabSkin("mon3tr_none",
{
	base_prefab = "mon3tr",
	type = "base",
	assets = assets,
	skins = skins, 
	skin_tags = {"MON3TR", "CHARACTER", "BASE"},
	build_name_override = "mon3tr",
	rarity = "Character",
})