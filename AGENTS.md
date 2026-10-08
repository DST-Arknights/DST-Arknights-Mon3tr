# Mon3tr 项目协作约定

## 共享规范与依赖

- 通用的 DST Lua、Prefab、状态图、客户端/主机分层、国际化、动画、音频、发布和验证规范，统一遵循共享项目 `DST-Arknights-AICoding` 中与任务匹配的 skill；本文件只补充 Mon3tr 项目特有约定。
- 本项目依赖 `DST-Arknights-Nexus`（源枢）。源枢的位置从记忆中查找；记忆不明确时先询问用户。保持 `modinfo.lua` 的依赖键和源枢提供的运行时 API 契约，不把源枢代码内联到本项目。

## 入口与玩法范围

- `modmain.lua` 负责源枢依赖检查、Prefab/资源注册、Mon3tr 大肖像注册、语言和语音注册，以及 `modmain/mon3tr.lua`、`modmain/mon3tr_skill.lua` 的导入。
- `modmain/mon3tr.lua` 维护角色、装备、骑乘限制、治疗和生命周期整合；`modmain/mon3tr_skill.lua` 维护技能、目标选择、跳跃/落点、战斗和治疗链。
- `scripts/prefabs/` 中的 Mon3tr、构造剑、构造爪、信标、治疗链、Buff、特效和目标选择器 Prefab，必须与 `modmain.lua` 中的 `PrefabFiles` 一一对应。
- Mon3tr 在本项目文案和视觉中作为独立角色处理，不写成凯尔希的召唤物；源枢提供的共享装备机制按其项目说明使用。

## 资源与文案约定

- 运行时资源位于 `anim/`、`images/`、`sound/` 和 `bigportraits/`；动画可编辑来源优先使用 `animSource/`，不要直接把生成后的 `anim/` 压缩资源当作编辑源。
- `soundSource/` 与 `sound/` 必须保持音频工程、音频事件、soundbank 和运行时文件同步；语音绑定位于 `languages/mon3tr_voice.lua`。
- `languages/mon3tr_chinese_s.po` 与 `mon3tr_english.po` 保存双语文本；新增角色、技能或装备文本时保持两种语言键集合一致。
- `docs/workshop_description_zh-steam.txt` 与 `docs/workshop_description_en-steam.txt` 是工坊说明的双语来源。文案以玩家可见内容为主，省略技能快捷键和过密的内部数值；说明构造剑与 M3 Cocoon Armor 的治疗充能，详细共享装备机制以源枢说明为准。
- 保留艺术家和代码署名的既有格式；不要在说明中加入实现路径、调试信息或开发者机器路径。

## 动画与改动边界

- 修改武器或爪击动画时，先确认实际来源是 `animSource/`、Prefab 的 `AnimState` 设置还是 `tools/` 脚本，再修改来源并重新生成运行时资源。
- 需要保留的原始动画、预览或候选文件按当前目录约定放在 `temp/` 或项目已有的预览目录；不要删除与当前任务无关的来源文件。
- 新增技能、装备或 Prefab 时，同时更新注册列表、对应资源和双语文本；跨项目 API 变更先核对源枢项目的当前公开接口。

## 项目专属检查

- 修改技能、角色状态或装备后，检查 `modmain.lua` 的导入/Prefab 注册、动画 bank/build 名称、双语 PO 和工坊两份说明。
- 修改动画或 FMOD 资源后，按 `DST-Arknights-AICoding` 的对应 skill 检查来源、生成物和清理范围；静态检查通过不等于已完成游戏内或联机验证。