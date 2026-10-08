-- 对不支持的语言兜底到英文（DST 原版 ChooseTranslationTable 只回退到 tbl[1]，
-- 但我们用字典键值而非数字索引，非 en/zh 语言会返回 nil 导致崩溃）
local function T(tbl)
    return ChooseTranslationTable(tbl) or tbl["en"]
end

name = T({
    en = "Mon3tr",
    zh = "Mon3tr"
})
version = "1.0.2"

-- 版本更新说明（由发布脚本自动维护，请勿手动编辑）
local UPDATE_EN = [[
v1.0.2 (2026-10-08)
- Fixed Skill 3 lifesteal not taking effect.
---
v1.0.1 (2026-10-08)
- Updated the character description to add artist and code information.
]]

local UPDATE_ZH = [[
v1.0.2 (2026-10-08)
- 修复 Skill 3 生命偷取未生效的问题。
---
v1.0.1 (2026-10-08)
- 更新角色描述，补充艺术家和代码信息。
]]

description = T({
    en = [[Artists: Jack Day, GPT-Image-2.5 | Code: 望月心灵, GPT-6.1 Sol

Mon3tr, the operator from Arknights, enters the Constant.
Destroy, and heal: Strike with True damage and support allies with bouncing heals.
Requires "Arknights: Nexus".

Current version: ]] .. version .. "\n" .. UPDATE_EN,
    zh = [[画师: Jack Day, GPT-Image-2.5 | 代码: 望月心灵, GPT-6.1 Sol

明日方舟干员 Mon3tr 来到永恒领域。
毁灭，同时治愈：以真实伤害迎敌，用弹射治疗支援友军。
需要前置模组 源枢。

当前版本: ]] .. version .. "\n" .. UPDATE_ZH,
})
author = "望月心灵"
forumthread = "https://github.com/TohsakaKuro/DST-Arknights-Mon3tr/issues"

api_version = 10

dont_starve_compatible = false
reign_of_giants_compatible = false

dst_compatible = true
all_clients_require_mod = true

icon_atlas = "modicon.xml"
icon = "modicon.tex"


server_filter_tags = {"character", "mon3tr", "arknights", "明日方舟" }
configuration_options = {
    {
        name = "language",
        label = T({
            en = "Text Language",
            zh = "界面文本语言"
        }),
        hover = T({
            en = "Choose the mod's UI text language (Auto follows game language)",
            zh = "选择模组界面文本的语言 (Auto 跟随游戏语言)"
        }),
        options = {{
            description = T({
                en = "Auto (follow game)",
                zh = "自动 (跟随游戏)"
            }),
            data = "auto"
        }, {
            description = T({
                en = "Simplified Chinese",
                zh = "简体中文"
            }),
            data = "zh"
        }},
        default = "auto"
    },
}


mod_dependencies = {
    {["DST-Arknights-Nexus"] = false},
}
