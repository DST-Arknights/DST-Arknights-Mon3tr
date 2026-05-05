# AGENTS

总是用俏皮可爱的二次元口吻与我沟通.

## 适用范围

这些说明适用于整个 DST-Arknights-Mon3tr 工作区。本项目完全依赖于另一个项目 DST-ArknightsItemPackage，

## 项目结构

- 主要入口：
  - `modinfo.lua`：模组元数据和依赖声明。
  - `modmain.lua`：Prefab 注册、资源声明、本地化、TUNING 配置和模块导入。
  - `modmain/mon3tr.lua`：玩法钩子和状态图相关整合。
  - `modmain/mon3tr_skill.lua`：技能逻辑，以及战斗和治疗链行为。
  - `scripts/prefabs/`：角色、武器、Buff 和特效的 Prefab 实现。
- 资源流程：
  - 运行时使用的编译后资源位于 `anim/` 和 `images/`。
  - 动画源文件位于 `animSource/`。
  - 优先修改源 SCML 或工具脚本，不要直接修改生成后的运行时资源。

## 工作规则

- 这是一个 Don't Starve Together 模组。很多全局符号来自游戏引擎，例如 `GLOBAL`、`SpawnPrefab`、`TheWorld`、`RADIANS`、`FRAMES`。Lua 工具把它们报成未定义时，不一定是真错误。
- 保持 DST Prefab 常见的主从端分层：
  - 共享标签和表现层内容放在 `common_postinit`。
  - 组件和玩法逻辑放在 `master_postinit`。
  - 如果某个 Prefab 模式需要主机专属逻辑，用 `if not TheWorld.ismastersim then return inst end` 做保护。
- TUNING 值和功能常量尽量放在文件顶部，作为局部常量定义。
- 遵循现有 Prefab 结构：先写本地 `assets` 和 `prefabs`，再写辅助函数，最后写工厂函数和 `return`。
- 发现已有 Ark 模组系统时，优先复用，例如 `ark_skill`、`ark_elite`、Ark 的日志和辅助函数，不要额外造一套平行抽象。
- 除非代码本来就是这么写的，否则不要把引擎全局访问改成手动导入。

## 验证方式

- 这个工作区没有独立的构建流程，也没有自动化测试。
- 修改 Lua 时，优先使用最小范围的验证：
  - 检查改动文件的本地语法和明显诊断；
  - 确认 `modmain.lua` 里的 Prefab 注册和模块导入仍然一致；
  - 如果行为改动较大，补充说明预期的游戏内验证路径。
- 处理动画源文件时，优先使用 `tools/` 里的现有脚本：
  - `python tools/mirror_scml_animation.py <file.scml> <animation...> [--backup] [--dry-run]`
  - `python tools/offset_scml_timeline.py <file.scml> -o <offset>`
  - `powershell tools/update_construct_beacon_scml.ps1`

## 常见陷阱

- 不要把 LuaLS 的 undefined global 警告当成这个仓库里的绝对错误依据。
- 在热路径里做链式搜索或访问去重时，优先使用以实体为键的本地 `visited` 表，而不是反复做线性包含判断。
- Prefab 名、图集路径、动画 bank/build 名，以及 `PrefabFiles` 条目必须严格对应；这里的很多错误会表现为加载失败或显示异常，而不是编译错误。
- 如果某个功能依赖 DST-ArknightsItemPackage，要保持 `modinfo.lua` 中的依赖契约，不要悄悄把外部 API 内联进当前仓库。

## 改动建议

- 不做冗余的判断条件.
- 优先在真正拥有玩法逻辑的文件里做小范围修改，不要把逻辑拆散到无关 Prefab 中。
- 如果新增 Prefab，要同时更新 `scripts/prefabs/` 下的脚本文件和 `modmain.lua` 里的 `PrefabFiles` 列表。
- 如果新增 UI、肖像或物品栏贴图，保持 atlas 和 texture 文件继续放在现有 `images/` 目录布局里。
- 如果修改动画行为，先确认真正的来源是 `animSource/`、某个 Prefab 的 `AnimState` 设置，还是 `tools/` 里的 Python 脚本，再决定改哪里，不要先动生成资源。

## 游戏源码
允许访问游戏源码, 位于 "C:\Saved Games\Steam\steamapps\common\Don't Starve Together\data\databundles\scripts> "
DST-Arknights-ItemPackage 模组的源码位于 "C:\Users\Tohsa\projects\DST-ArknightsItemPackage" 同时根目录下有 AGENTS.md 文件, 该文件包含了 DST-Arknights-Mon3tr 工作区的说明和规范。
允许访问其他项目源码, 必要时申请权限.
