# quest_item 類型模板

## 必填選項

- art id：描述物件本身，例如 `ancient_key`、`sealed_letter`、`crystal_shard`。
- 類別：鑰匙、信件、碎片、遺物等。
- 狀態：首批固定 `present`。

## 狀態文字

| 狀態 | prompt 文字 |
|---|---|
| `present` | 可被玩家拾取的單一任務物件，輪廓明確、自然接地或放置於中性透明畫布中，沒有發光、漂浮、粒子或可讀文字。 |

## 硬限制

- 撿取後由遊戲隱藏 sprite；首批不產 `collected` 空白圖。
- 任務內容、flag、對話與掉落條件不進 prompt。
