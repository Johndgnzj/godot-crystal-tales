# 地圖互動物件美術驗收

## 外觀與狀態

- [ ] 類型、art id、地區材質與 footprint 已記錄在描述檔。
- [ ] 已有獨立、已驗收的 `design_anchor`；它不是任何狀態圖。
- [ ] 每個狀態都實際附上 `design_anchor_alpha.png` 作 reference。
- [ ] 同一外觀族的畫布尺寸、bottom-center 錨點、視角與光向一致。
- [ ] **比例未失真**：`final.png` 的 alpha bbox 寬高比與 `design_anchor_alpha.png` 相差在 15% 內（縮放必須等比，見 `workflow.md` Step 5）。
- [ ] **內容貼齊畫布底邊**：`final.png` 的 alpha bbox 底邊＝畫布底邊，底部沒有留白（否則物件在地圖上浮空）。
- [ ] 有入口的物件，門口／洞口直接接觸素材底邊；位置可偏左、偏右或置中，不因 `bottom_center` 而被強制置中。
- [ ] 建築與可進入結構正面平行於素材底邊；沒有側向 45°、斜跨地格或朝側邊的入口。
- [ ] 沒有地板、草、牆、場景投影、角色、文字、UI 或背景。
- [ ] `icon` 類型：64×64 正方、內容置中留透明邊、**無地面投影**、無稀有度／數量／強化等級裝飾（那些由 UI 疊層）。
- [ ] `icon` 類型：外輪廓在 32px 縮圖下仍可辨識類型（縮到 32px 自檢一次）。

## 類型檢查

- [ ] 寶箱 `opened` 只改變蓋子、內部與少量內容；箱體材質、尺寸與位置不變。
- [ ] 任務拾取物的輪廓清楚，沒有發光、粒子、漂浮或可讀文字。
- [ ] 告示牌（如有）沒有可讀文字；內容由遊戲 UI 顯示。

## 檔案與整合

- [ ] 來源檔在 `assets-source/props/<id>/`，檔名固定且不含日期。
- [ ] 預覽驗收通過前，沒有複製到 `godot-project/assets/`。
- [ ] 整合後 PNG 是透明 RGBA，尺寸符合 footprint，並已 Reimport。
- [ ] 更新 `CREDITS_素材授權.md`。
- [ ] `godot --headless --check-only --path godot-project` 通過。
