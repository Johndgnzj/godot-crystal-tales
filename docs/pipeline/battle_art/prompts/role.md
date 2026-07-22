# Battle Role Prompt 組裝規則

依照下列順序組裝（`sections/` 依檔名數字序）：

1. 10_風格.md
2. 20_角色設計.md
3. 30_服裝.md
4. 40_武器.md
5. 50_去背螢光底.md
6. 60_畫面.md
7. 70_動畫.md
8. 80_禁項.md

最後加入：

<角色描述>

<姿勢描述>

- 角色描述＝外觀＋服裝配色＋武器；姿勢描述含面向（面向我方＝畫面左側）。各單位**最後一版**存 [descriptions/](descriptions)（一單位一檔）。敵人組裝規則另見 [enemy.md](enemy.md)。
- 產動作前必須由 [`actions/`](actions) 選出動作模板與選項，再將其「動作文字＋硬限制」接在角色描述後；不可自行以模糊姿勢文字取代。
- 每個單位的描述檔必須記錄已驗收的固定 seed 路徑。產 `idle`／`hurt`／`cast`／`death`／`attack` 時，必須實際附上該 `battle_seed_alpha.png` 作 image reference；seed 不屬於任何動作幀。
- 持武器角色的描述檔必須記錄武器規格（主手、武器總長相對身高、劍身／劍柄比例、護手與主色）；所有動作皆以 seed 為準，不得改變。
- 去背底色依 `sections/50_去背螢光底.md` 的挑色規則帶入。
- 語言一律繁體中文、整段同一語言。

---

## 正式版本

**正式產圖用凍結 preset：[`presets/battle_role_hd_pixel_v2.md`](presets/battle_role_hd_pixel_v2.md)**（2026-07-22 凍結）。

- `sections/`＝最小可維護單元（一檔一規則）：改去背只動 `50_去背螢光底.md`、測新動畫限制只動 `70_動畫.md`。
- `presets/`＝release 快照：**不改舊 preset**；sections 實驗成功後另存新檔（如 `battle_role_v2.md`），再回來更新本節與 [`../workflow.md`](../workflow.md) 的指向。
