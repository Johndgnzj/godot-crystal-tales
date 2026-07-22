# Battle Enemy Prompt 組裝規則

依照下列順序組裝（`sections/` 依檔名數字序）：

1. 15_魔物風格.md
2. 50_去背螢光底.md
3. 65_魔物畫面.md

最後加入：

<魔物描述>

- 魔物描述＝本體特徵（照 `portrait_<id>`，image-to-image 時可用參考圖帶入、不必逐字寫外觀）＋特殊姿勢；面向一律**右方**（我方左、敵方右）。各魔物**最後一版**存 [descriptions/](descriptions)（一單位一檔）。
- 去背底色依 `sections/50_去背螢光底.md` 挑色（避開魔物自身配色）。
- 語言一律繁體中文、整段同一語言。

---

## 正式版本

**正式產圖用凍結 preset：[`presets/battle_enemy_v2.md`](presets/battle_enemy_v2.md)**（2026-07-22 凍結）。

- 實驗改 `sections/` 對應檔、成功後另存新 preset 再更新指向——守則同 [role.md](role.md)。

---

## Gemini 產戰鬥圖流程（bear_dire 首例，2026-07-21）

以 Gemini（Claude 端 gen-art）產，供缺呼吸圖的敵人沿用：

- **產圖（image-to-image）**：`--type raw --ar 3:2`，餵 `portrait_<id>`（保特徵）＋近似姿勢的 `bear/portrait`（錨右向側身）；prompt＝preset 全文＋該魔物描述。
- **後製 combat_0**：色距鍵去背＋despill→裁 bounding box→最近鄰縮到高 72px（bear_dire 101×72）。
- **呼吸 combat_1**：不整體縮放/不重繪，抓 3–4 重點部位局部位移（bear_dire：頭/口鼻 −1.6px、肩背 +1.4px、前掌 +3.2px、胸腔 +0.9px）；呼吸幅度原則見 [design 規格 §5-2](../../../design/戰鬥立繪規格.md)。
- 原始兩幀存 `assets-source/role/enemies/<id>/combat_0|1.png`；未接 runtime，待建資料才複製 `foe_<id>_0|1.png`。

---

## 現況帳本

**已整合戰鬥圖**（2026-07-19，均兩幀呼吸→目標 4 幀）：

- **礦山**：`wogol`、`skeleton`、`orc`、`wolf`、`bear`（骷髏礦工/獸人右向站姿、洞熊右向低重心）。
- **東之森**：`bird`、`gslime`、`goblin`、`worm`、`wolf`、`maskedorc`（掠翅鳥拍翅、綠黏史萊姆壓縮起伏、哥布林持刀手兩幀一致）。
- **東之森深處候選**：`goblin_shaman`、`goblin_tamer`、`wild_hare`、`horn_hare`、`thorn_boar`、`fungus_owl`、`rotwood_beetle`（野兔/掠角兔共用蓄力跳基底）。此批戰鬥圖已整合，尚未建數值/遭遇表。

**待優化**：

- 多數現有戰鬥圖為 OpenAI imagegen 產、產圖當下未存 prompt；`bear_dire` 為首張 Gemini 產。
- 缺呼吸圖待補：`necro`／`ogre`／`shadow_demon`／`chort`／`goblin_chief`（沿用上節 Gemini 流程）。
