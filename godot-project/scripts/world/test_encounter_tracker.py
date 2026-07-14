#!/usr/bin/env python3
"""MOD-G 驗收腳本：encounter_tracker.gd 的距離累積/觸發/grace 邏輯純 Python 交叉驗證。

跟 `scripts/content/test_derive.py`（MOD-F）同樣的環境限制：這個環境拿不到 Godot 執行檔（見
CORE-1/MOD-F 驗收現況），沒辦法真的跑 `godot --headless` 開場景、掛 `EncounterTracker` 節點、模擬
玩家移動來實測觸發間距。這支腳本改用「同一份邏輯在 Python 逐行翻譯一次」的方式交叉驗證：

  `py_step()` 是 `encounter_tracker.gd` `_physics_process(delta)` 的逐行 Python 翻譯（不是重新設計
  一份邏輯，是同一套判斷式在兩種語言各寫一次，方便肉眼逐行比對——見函式旁的 .gd 行號/函式名對照）。

驗證重點（對應 TASKS/07_遭遇系統.md 驗收標準）：
  1. 「平均觸發間距應落在 600~1400px 移動距離區間」：模擬玩家持續站在 ENC 地形上等速移動數千幀，
     統計每次觸發之間實際移動的距離，取平均值，斷言落在 [600, 1400] 區間內（理論值：`enc_next` 服從
     Uniform(600, 1400)，期望值 1000，實際因為是「累積量超過門檻的那一幀才觸發」而非精確等於門檻，
     會有最多一幀移動量的正向偏移量，dt 夠小時偏移可忽略）。
  2. 「`grace` 期間不會立刻再次觸發」：模擬觸發後緊接著在 grace 尚未歸零前持續站在 ENC 地形上移動，
     斷言這段期間 `enc` 完全不累積、不會觸發。
  3. 額外邊界：不在 ENC 地形上不累積；`encounter_id==""`（對應 `CFG.encGroup` 未設定）完全不累積/
     不觸發；`grace` 每幀無條件倒數（不管 lock/moving 狀態），對應 build_cq2.py L1505。

用法：
    python3 test_encounter_tracker.py
"""

from __future__ import annotations

import random
import statistics
from dataclasses import dataclass, field


ENC_MIN = 600.0
ENC_SPAN = 800.0
INITIAL_GRACE = 1.2


@dataclass
class TrackerState:
    """對應 encounter_tracker.gd 的欄位子集（省略 player/world_state/signal，純數值邏輯）。"""

    enc: float = 0.0
    enc_next: float = 0.0
    grace: float = 0.0
    encounter_id: str = "forest"
    rng: random.Random = field(default_factory=random.Random)

    def reset(self) -> None:
        # 對應 encounter_tracker.gd reset()：enc=0、重抽 enc_next、grace=initial_grace。
        self.enc = 0.0
        self.enc_next = ENC_MIN + self.rng.random() * ENC_SPAN
        self.grace = INITIAL_GRACE


def py_step(
    st: TrackerState,
    delta: float,
    locked: bool,
    is_moving: bool,
    on_enc_terrain: bool,
    speed: float,
) -> float | None:
    """逐行對應 encounter_tracker.gd `_physics_process(delta)`。

    回傳值：這一幀若觸發遭遇，回傳觸發當下的 `enc` 值（即 reset() 之前、실제累積到的距離，用來跟
    `enc_next` 門檻比對誤差）；沒有觸發則回傳 `None`。"""
    # if grace > 0.0: grace = maxf(0.0, grace - delta)
    if st.grace > 0.0:
        st.grace = max(0.0, st.grace - delta)

    # if player == null or encounter_id == "": return
    if st.encounter_id == "":
        return None
    # if world_state != null and world_state.lock: return
    if locked:
        return None
    # if grace > 0.0: return
    if st.grace > 0.0:
        return None
    # if not player.is_moving: return
    if not is_moving:
        return None
    # (is_on_encounter_terrain Callable 有效視為前提，這裡直接吃模擬給的 on_enc_terrain)
    if not on_enc_terrain:
        return None

    # enc += player.velocity.length() * delta
    st.enc += speed * delta
    if st.enc >= st.enc_next:
        triggered_enc = st.enc
        st.reset()  # _trigger() 觸發後呼叫 reset()
        return triggered_enc
    return None


def simulate_sustained_encounter_terrain(
    seed: int, speed: float = 190.0, dt: float = 1.0 / 60.0, sim_seconds: float = 6000.0
) -> list[float]:
    """玩家全程站在 ENC 地形上、全程移動、全程不 lock，模擬 sim_seconds 秒。回傳每次觸發當下
    `enc`（實際累積到的移動距離，逼近 `enc_next` 門檻）清單——用來驗證「站上 ENC 地形後要連續移動
    多遠才會觸發一次」這件事符合 [600,1400] 區間，**不是**「兩次觸發之間經過的總游戲時間/距離」
    （兩次觸發之間還夾著 `grace` 期間的移動，那段時間不計入累積量，另外由
    `test_grace_suppresses_immediate_retrigger` 驗證，見該測試）。
    speed=190 對應 player_controller.gd 的 max_speed（GDevelop TopDownMovementBehavior maxSpeed）。
    """
    rng = random.Random(seed)
    st = TrackerState(rng=rng)
    st.reset()

    steps = int(sim_seconds / dt)
    triggered_encs: list[float] = []

    for _ in range(steps):
        triggered_enc = py_step(
            st, dt, locked=False, is_moving=True, on_enc_terrain=True, speed=speed
        )
        if triggered_enc is not None:
            triggered_encs.append(triggered_enc)

    return triggered_encs


def test_average_trigger_distance_in_range() -> None:
    all_distances: list[float] = []
    for seed in range(20):
        all_distances.extend(simulate_sustained_encounter_terrain(seed))

    assert len(all_distances) > 500, f"樣本數太少，模擬時間不足：{len(all_distances)}"

    mean_distance = statistics.mean(all_distances)
    print(
        f"[average_trigger_distance] n={len(all_distances)} "
        f"mean={mean_distance:.1f}px min={min(all_distances):.1f}px max={max(all_distances):.1f}px"
    )
    assert 600.0 <= mean_distance <= 1400.0, (
        f"平均觸發間距 {mean_distance:.1f}px 落在驗收標準 [600, 1400] 區間外"
    )

    # 個別觸發間距的下界：enc_next 本身最小是 600px，觸發判定是「enc >= enc_next 那一幀」才觸發，
    # 所以任何一次的實際移動距離不可能明顯小於 600px（允許一幀的浮點/取樣誤差）。
    min_distance = min(all_distances)
    frame_distance_at_60fps = speed_max_frame_slack()
    assert min_distance >= 600.0 - frame_distance_at_60fps, (
        f"出現遠低於理論下界 600px 的觸發間距：{min_distance:.1f}px"
    )

    # 個別觸發間距的上界：enc_next 最大是 1400px，同樣允許一幀誤差。
    max_distance = max(all_distances)
    assert max_distance <= 1400.0 + frame_distance_at_60fps, (
        f"出現遠高於理論上界 1400px 的觸發間距：{max_distance:.1f}px"
    )

    print("test_average_trigger_distance_in_range: PASS")


def speed_max_frame_slack(speed: float = 190.0, dt: float = 1.0 / 60.0) -> float:
    return speed * dt * 2  # 保守抓兩幀誤差空間


def test_grace_suppresses_immediate_retrigger() -> None:
    """模擬觸發那一刻，立刻檢查接下來 grace 秒內（即使持續站在 ENC 地形上移動）完全不會再次觸發，
    也確認這段期間 enc 完全沒有累積（對應原始碼 grace>0 時整個 if 區塊被短路跳過）。"""
    rng = random.Random(42)
    st = TrackerState(rng=rng)
    st.reset()
    st.grace = INITIAL_GRACE  # 模擬「剛觸發完/剛從戰鬥返回世界」的狀態

    dt = 1.0 / 60.0
    speed = 190.0
    # 留 5 幀安全邊界，避免「扣減後 grace 剛好在這一幀跨過 0」的浮點邊界情況（那一幀本身依照
    # encounter_tracker.gd 的邏輯是允許累積的——grace 每幀「先扣減、再用扣減後的新值判斷」，跟
    # build_cq2.py L1505 的 `if(st.grace>0)st.grace-=dt;` 語意一致，不是本測試要驗證的邊界）。
    safe_frames = max(int(INITIAL_GRACE / dt) - 5, 0)

    for _ in range(safe_frames):
        triggered = py_step(
            st, dt, locked=False, is_moving=True, on_enc_terrain=True, speed=speed
        )
        assert not triggered, "grace 倒數期間不應該觸發遭遇"
        assert st.enc == 0.0, f"grace 倒數期間不應該累積 enc，實際 enc={st.enc}"

    assert st.grace > 0.0, f"安全邊界內 grace 不應該提早歸零，實際 grace={st.grace}"

    # 跑到 grace 真正歸零為止（不再斷言 enc==0，因為跨過 0 的那一幀本身就允許累積）。
    guard = 0
    while st.grace > 0.0:
        py_step(st, dt, locked=False, is_moving=True, on_enc_terrain=True, speed=speed)
        guard += 1
        assert guard < 100, "grace 遲遲沒有歸零，邏輯可能有誤"

    assert st.grace <= 0.0, "跑滿 grace 秒數後 grace 應該已經歸零"

    # grace 歸零之後，恢復正常累積（用大 dt 直接跳到門檻之上，確認邏輯沒有被永久卡死）。
    triggered = py_step(
        st, st.enc_next / speed + 0.01, locked=False, is_moving=True, on_enc_terrain=True, speed=speed
    )
    assert triggered, "grace 歸零後累積量超過門檻應該正常觸發"

    print("test_grace_suppresses_immediate_retrigger: PASS")


def test_no_accumulation_off_terrain_or_when_idle_or_no_encounter_group() -> None:
    dt = 1.0 / 60.0
    speed = 190.0

    # 不在 ENC 地形上：不累積。
    st = TrackerState(rng=random.Random(1))
    st.reset()
    for _ in range(600):
        triggered = py_step(st, dt, locked=False, is_moving=True, on_enc_terrain=False, speed=speed)
        assert not triggered and st.enc == 0.0

    # 沒有移動：不累積。
    st = TrackerState(rng=random.Random(2))
    st.reset()
    for _ in range(600):
        triggered = py_step(st, dt, locked=False, is_moving=False, on_enc_terrain=True, speed=speed)
        assert not triggered and st.enc == 0.0

    # 被 lock（例如對話中）：不累積。
    st = TrackerState(rng=random.Random(3))
    st.reset()
    for _ in range(600):
        triggered = py_step(st, dt, locked=True, is_moving=True, on_enc_terrain=True, speed=speed)
        assert not triggered and st.enc == 0.0

    # encounter_id 空字串（CFG.encGroup 未設定的場景，例如 Town）：不累積、不觸發。
    st = TrackerState(rng=random.Random(4), encounter_id="")
    st.reset()
    for _ in range(6000):
        triggered = py_step(st, dt, locked=False, is_moving=True, on_enc_terrain=True, speed=speed)
        assert not triggered and st.enc == 0.0

    print("test_no_accumulation_off_terrain_or_when_idle_or_no_encounter_group: PASS")


if __name__ == "__main__":
    test_average_trigger_distance_in_range()
    test_grace_suppresses_immediate_retrigger()
    test_no_accumulation_off_terrain_or_when_idle_or_no_encounter_group()
    print("\n全部通過（純 Python 交叉驗證；未能實機在 Godot 執行環境驗證，見 encounter_tracker.gd 檔頭）")
