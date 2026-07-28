# World 遮擋物件素材來源

這裡存放城鎮、野外與地城可重用的**非互動高物件**來源素材，例如建築、樹、井與路燈。

目錄固定採「類型優先、footprint 次要」：

```text
<type>/<footprint>/<id>/
```

- `type`：`architecture`、`nature`、`street`、`structure`、`landmark`
- `footprint`：以 32px 格為單位，如 `1x1`、`2x2`、`4x3`、`6x4`、`6x6_plus`
- `id`：語意名稱，例如 `building_inn_floret_a`；不可只用尺寸命名。

每個物件資料夾至少包含 `design_anchor_alpha.png`、核可的 `final.png` 與 `meta.json`。`meta.json` 格式見本目錄的 `meta.json.example`。

帶入口的建築、礦坑入口與石階，入口必須貼齊素材底邊；入口可偏左、偏右或置中。`bottom_center` 只用於角色遮擋排序，並非入口座標。

建築與可進入結構的正面必須平行於素材底邊，不得側向 45° 或斜跨地格；3/4 視角只表現在屋頂與立面高度。

正式整合後的 PNG 鏡像放至 `godot-project/assets/props/world/<type>/<footprint>/<id>.png`。
