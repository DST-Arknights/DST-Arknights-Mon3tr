# 四背景动态立绘源工程

本工程只生成 PNG 和 SCML，由高级编译器打包。Bank / Build 为 `mon3tr_bigportrait`，运行 ZIP 路径为 `anim/mon3tr_bigportrait.zip`。

## 画布与自动对齐

- 原生基础背景保存在 `layout/base_portrait.png`，总画布491×654。
- 原生主体按 alpha≥128 测量，纵向范围为 y=68～643。四个背景按同一比例缩放为约431×576，置于全画布的(30,68)，左右各留30px、顶部留68px、底部留10px。总画布仍为491×654。
- 角色编辑源图保持490×654。角色沿用此前92.3%的相对比例，再乘背景整体比例576/655；SCML的横纵缩放均为0.811676335878，实际显示约397.72×530.84，顶边68px、水平居中，中心锚点位置为(0,-6.41816183206)。背景和角色均等比例缩放，避免纵向挤压；静态PNG在光栅化时取整为398×531。
- 四个动画复用同一组91张角色图片，保留原SCML的3800ms循环及24 FPS换图时间。

| 场景 | 动画名 | 背景源图 |
| --- | --- | --- |
| 冬季雪林（当前默认） | `idle_winter_forest` | `background/background_0.png` |
| 松林营火 | `idle_pine_campfire` | `background/background_1.png` |
| 秋日桦林 | `idle_autumn_birchnut` | `background/background_2.png` |
| 洞穴荧光 | `idle_cave_glow` | `background/background_3.png` |

## 更换画师修补帧

把修补好的490×654 RGBA PNG按原文件名覆盖到 `character/mon3tr_0001.png`～`mon3tr_0091.png`，然后直接用高级编译器打包本目录的 `mon3tr_bigportrait.scml`。既有SCML会自动应用留白、缩放和位置；保留每帧的画布、透明通道及角色在原画布中的位置。

原第0092张是重复首帧，SCML仅引用前91张。四背景共用这些帧，替换一次即可全部更新。

`static/` 存放四套对应的静态首帧。默认冬季静态源图同时写入 `imagesSource/bigportraits/mon3tr/mon3tr.png`，供静态图集打包。替换首帧后，运行 `python tools/build_mon3tr_bigportrait.py` 可同步更新静态首帧和SCML；该脚本不调用任何编译器。

重新调整基础位置时，可用 `--template <原生背景PNG>` 指定新的基准；重新导入背景时，用 `--backgrounds <松林PNG> <秋林PNG> <冬季PNG> <洞穴PNG>`。默认重建使用保存的原生基准，避免反复压缩已处理的静态图。
