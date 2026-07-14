extends Node
## InputBridge — autoload（註冊名稱 "InputBridge"，見 ../project.godot [autoload]）。
##
## CORE-6 正式產出：統一鍵盤與觸控輸入，對應 GDevelop 版「觸控 = 合成鍵餵給既有鍵盤流程」的設計
## （../gd-crystal-tales/projects/crystal-quest/DEV_開發指南.md L53：「每幀先蒐集觸控→`st.tk`
## （touch-key 集合）；`keyHit()` 與 `hit` 都吃 `st.tk`，故觸控＝合成鍵餵給既有鍵盤流程（選單/商店/
## 配點零改動）。搖桿用 `b.simulateControl("Right"/…)` 驅動 TopDown」）。
##
## 對照 build_cq2.py 的 `keyHit()`（L2696）：
##   function keyHit(k){var d=isKeyPressed(k);var was=b.kp[k];b.kp[k]=d;return d&&!was;}
## 這是「邊緣觸發」（這一幀剛按下，不是持續按著；`b.kp[k]` 記錄上一幀狀態）。
##
## **設計決定（不自己重做邊緣觸發追蹤）**：Godot 內建 `Input.is_action_just_pressed(action)` 語意
## 跟 `keyHit()` 完全一致（也是引擎每幀自動追蹤「上一幀是否按著」再跟這一幀比較），沒有理由重寫一份
## `kp[]` 狀態表——這裡只做薄轉發。`is_action_pressed(action)`（對應 GDevelop 的 `hit`，持續按著）
## 同理薄轉發，收斂進本檔案只是為了讓呼叫端（選單/商店/配點/移動）統一走 InputBridge 這一個入口，
## 之後如果要換輸入後端（例如未來要疊加「暫停時吃不到輸入」之類的全域開關）只需要改這裡一處。
##
## **觸控/虛擬搖桿設計**：GDevelop 版是「觸控事件蒐集進 `st.tk` 集合，`keyHit()`/`hit` 直接讀
## `st.tk`」；Godot 端等價作法不是另外維護一份觸控鍵狀態表，而是讓觸控 UI 節點（虛擬搖桿/按鈕，
## MOD-D 之後實作實際節點）直接呼叫下面的 `simulate_action_press()`/`simulate_action_release()`
## 把觸控輸入寫回**同一組** InputMap action 的引擎狀態，這樣 `Input.is_action_just_pressed()`/
## `Input.is_action_pressed()`（也就是本檔案的 `is_action_hit()`/`is_action_held()`）自然對觸控
## 輸入也生效，選單/商店/配點/移動邏輯完全不用為觸控另寫一份判斷分支。
##
## 內部實作選了 `Input.action_press()`/`Input.action_release()`，沒有選「建構 InputEventAction 丟給
## `Input.parse_input_event()`」，理由：
## 1. `Input.action_press(action, strength)`/`Input.action_release(action)` 是 Godot 官方文件明白
##    列出的「模擬輸入」API，就是為了「非硬體來源（例如螢幕上的虛擬按鈕）要驅動 InputMap action」
##    這個情境設計的，語意直接對應 GDevelop 的 `b.simulateControl()`。
## 2. 這組 API 會立即同步更新 `Input` 單例的內部狀態（下一次 `is_action_pressed()`/
##    `is_action_just_pressed()` 查詢就看得到），不需要等待事件佇列在下一輪 `_input`/
##    `_unhandled_input` 派發後才生效，時序上更貼近 GDevelop `st.tk` 集合「當幀寫入、當幀可讀」的
##    行為，虛擬搖桿/按鈕的按壓判定不會因為多等一幀而跟畫面回饋脫節。
## 3. 建構 `InputEventAction` 手動塞 `action`/`pressed`/`strength` 三個欄位再丟
##    `parse_input_event()` 效果上等價但多一層事件建構與佇列排程的間接層，對「觸控 UI 節點主動呼叫
##    一個方法通知輸入系統」這種明確的程式化情境沒有額外好處，故不採用。
##
## 規格來源：DEV_開發指南.md L53（觸控段落）；build_cq2.py L1812/L2696（keyHit 兩種變體，邏輯相同，
## 分別用在世界/戰鬥兩個 runtime state）。
## 前置依賴：CORE-1（InputMap 已定義 move_up/down/left/right、menu_toggle、stat_str/agi/int、
## battle_auto，加上 Godot 內建 ui_accept/ui_cancel）。本檔案**不**重新定義新的 action 名稱，只包裝
## 既有 InputMap。
##
## **未實作/刻意留給後續任務**：虛擬搖桿/觸控按鈕的實際 UI 節點（Control 場景、觸控命中判定、視覺回饋）
## 是 MOD-D 的範圍，本檔案只提供 MOD-D 會呼叫的 `simulate_action_press()`/`simulate_action_release()`
## 兩個方法。


## 邊緣觸發：這一幀剛按下（對應 GDevelop `keyHit()`）。鍵盤與觸控（透過
## `simulate_action_press()` 寫回同一個 InputMap action）都會讓這裡回傳 true。
func is_action_hit(action: String) -> bool:
	return Input.is_action_just_pressed(action)


## 持續按住：這一幀有沒有按著（對應 GDevelop 的 `hit`，移動用）。跟 `is_action_hit()` 一樣是薄轉發，
## 收斂進 InputBridge 只是為了統一呼叫入口，不是因為底層邏輯複雜需要包裝。
func is_action_held(action: String) -> bool:
	return Input.is_action_pressed(action)


## 邊緣觸發：這一幀剛放開（`is_action_hit`/`is_action_held` 沒有涵蓋但未來可能用到，例如長按/放開
## 手勢的虛擬按鈕；提供對稱介面，非目前任何呼叫端強制要求）。
func is_action_released_this_frame(action: String) -> bool:
	return Input.is_action_just_released(action)


## 給觸控 UI 節點（虛擬搖桿/按鈕，MOD-D 之後實作）呼叫，模擬「這個 action 被按下」，對應 GDevelop 的
## `b.simulateControl(direction)`。`strength` 保留類比強度參數（預設 1.0＝全按），供之後虛擬搖桿要做
## 類比方向強度時使用；`move_*` action 在 InputMap 裡本來就有 deadzone: 0.5，天生支援類比輸入。
func simulate_action_press(action: String, strength: float = 1.0) -> void:
	Input.action_press(action, strength)


## 給觸控 UI 節點呼叫，模擬「這個 action 放開」（手指離開虛擬搖桿/按鈕範圍）。
func simulate_action_release(action: String) -> void:
	Input.action_release(action)
