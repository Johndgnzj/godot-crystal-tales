# 地圖互動物件美術驗收

## 外觀與狀態

- [ ] 類型、art id、地區材質與 footprint 已記錄在描述檔。
- [ ] 已有獨立、已驗收的 `design_anchor`；它不是任何狀態圖。
- [ ] 每個狀態都實際附上 `design_anchor_alpha.png` 作 reference。
- [ ] 同一外觀族的畫布尺寸、bottom-center 錨點、視角與光向一致。
- [ ] 沒有地板、草、牆、場景投影、角色、文字、UI 或背景。

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
