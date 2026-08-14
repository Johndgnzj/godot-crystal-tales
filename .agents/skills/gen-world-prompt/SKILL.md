---
name: gen-world-prompt
description: 組出《水晶戰記》world sprite 的 D1 非 Pixel Art Design Reference、D2 Pixel Art Reference、D3 Native Seed、walk／idle／事件 actor strip prompt，並依 W0～W7 Gate 驗收。當 John 說 world design、world seed、world idle、world walk、Native Seed 或地圖角色動畫時使用。
---

# gen-world-prompt

本 skill 只負責辨識目前層級、收集缺少資訊、組 prompt 與執行 Gate；**不保存任何尺寸、bbox、步態、Alpha、命名或驗收數值副本**。

## 開工必讀

1. 完整讀 `CLAUDE.md` 的兩階段產圖驗收。
2. 完整讀 `docs/design/世界立繪規格.md`，取得所有現行設計數值。
3. 完整讀 `docs/pipeline/世界立繪流程.md`，確認目前 W0～W7 Gate。
4. 組 prompt 時讀 `docs/pipeline/prompt/role_world.md` 或 `enemies_world.md`；模板中的 `[SPEC_*]` 必須從本次讀到的權威規格填入。

## 流程

1. 確認需求是 D1、D2、D3、Walk Strip、Idle Animation Strip 或事件姿態；未明確時先依現有素材與 metadata 判斷，會跨 Gate 才詢問 John。
2. W0 先鎖定角色／variant、體型、目標地圖、方向、持物、mirror safety 與身份特徵表；缺會改變輪廓的資訊就停在 W0。
3. D1 使用當前環境的大型產圖能力；D2／D3／strip 使用原生 Pixel Art／sprite 流程。不得把 D1 resize 成下游素材。
4. 每次只交付當前 Gate 的預覽；John 明確核可前不得進下一 Gate或寫入 runtime。
5. D3／strip 執行 `tools/validate_world_strip.py`，再做原生 1×、8×、實景、動態與 camera QA；validator 不能取代美術驗收。
6. W7 才同步來源、runtime、`world_art_meta.json`、CREDITS、Reimport 與測試。

## 邊界

- 對話／設定立繪用 `gen-role-prompt`；戰鬥 sprite 用 `gen-battle-prompt`。
- world 不依角色 cm 縮放；角色立繪與戰鬥立繪的身高規格不可帶入。
- `*_native64_ref.png` 與 `tools/art/make_native64_ref.py` 是舊 layout diagnostic，不是 D2／D3。
- 規則若要修改，只改權威 design／pipeline／prompt 文件；不得在本 skill 新增另一套數值。
