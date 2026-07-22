# chest 類型模板

## 必填選項

- art id：例如 `chest_wood`、`chest_mossy`、`chest_mine`。
- 地區材質：只描述木材、金屬包角、苔痕、磨損等物件本身特徵；不得描述地板或背景。
- 狀態：`closed` 或 `opened`。

## 狀態文字

| 狀態 | prompt 文字 |
|---|---|
| `closed` | 箱蓋完全闔上、鎖扣清楚，完整箱體穩定落地。 |
| `opened` | 與 anchor 完全相同的箱體；箱蓋自然掀開，內部可見少量非特定內容，但不得溢出、漂浮或新增地面。 |

## 硬限制

- `closed` 與 `opened` 只能改變蓋子、內部與少量可見內容。
- 箱體材質、金屬包角、比例、視角、接地位置與 bottom-center 錨點必須一致。
- 同一外觀族可重用於多個寶箱實體；loot、tier、位置不進 prompt。
