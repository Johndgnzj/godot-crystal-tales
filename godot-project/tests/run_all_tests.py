#!/usr/bin/env python3
"""CORE-7 統一測試入口：掃描並執行專案裡所有既有的「純 Python 交叉驗證測試」，彙整 pass/fail 報告。

## 為什麼是這支腳本，而不是 `godot --headless`

CORE-7 的原始驗收標準是「`godot --headless -s tests/smoke_test.gd`（或 GUT 對應指令）可在 CI 環境跑過」。
但這個沙盒環境**沒有 Godot 4.3+ 執行檔**（六種下載管道全被網路政策擋下，見 ../TASKS/00_核心任務.md CORE-1
段落「驗收現況」，不要重試下載）。因此 `.gd` 檔案（含 tests/smoke_test.gd、tests/debug_hooks.gd）目前
**無法實機執行**。

在拿到 Godot 執行檔之前，各 CORE/MOD 任務唯一「實際能跑」的東西，是散落在 scripts/ 底下、各模組自己寫的
**純 Python 交叉驗證測試**（把 .gd 邏輯或 build_cq2.py 公式逐行翻成 Python 再比對）。這支腳本把它們收斂成
單一入口，讓 CI（或 John 本機、或未來任何環境）一鍵跑完全部、拿到彙整的綠/紅報告，不用記每支腳本的路徑。

## 掃描規則

從 godot-project/ 往下遞迴，收集檔名符合以下任一 glob 的 `.py`：
    test_*.py     validate_*.py     verify_*.py
這三種前綴是本專案既有的交叉驗證測試命名慣例（見各檔案檔頭）。**刻意排除** generator / 轉存腳本
（sync_content.py / extract_dialogue.py）——那些會寫檔、有副作用，不是測試，跑它們會污染
resources/。tests/ 目錄本身也排除（避免把這支 runner 或未來的測試工具當成受測目標遞迴自跑）。

被收集到的測試（截至 CORE-7 撰寫時，全部 exit 0 = 綠）：
    scripts/content/validate_content.py     (CORE-2) ContentDB 轉存 vs CONTENT.json 一致性
    scripts/content/test_derive.py          (MOD-F)  derive.gd/exp_need.gd 對照 build_cq2 實測 fixture
    scripts/battle/test_battle_formulas.py  (MOD-E)  damage/atb/exp_scale 公式 + Node.js 交叉驗證
    scripts/world/test_encounter_tracker.py (MOD-G)  遭遇距離累積/grace 邏輯
    scripts/dialogue/verify_dialogue.py     (MOD-A)  對話抽取筆數/action 覆蓋率/matchWhen 分支

每支測試都以自己的 exit code 表態（0=通過、非 0=失敗）——本 runner 只負責 fork 子行程、收 exit code、收
stdout/stderr，不重新實作任何斷言邏輯（受測邏輯的真相留在各測試檔內）。

## 用法

    python3 tests/run_all_tests.py            # 跑全部，印彙整表
    python3 tests/run_all_tests.py -v         # 額外印每支測試的完整輸出
    python3 tests/run_all_tests.py --list      # 只列出會跑哪些，不執行
    python3 tests/run_all_tests.py -k battle   # 只跑路徑含 "battle" 的測試（子字串過濾）

exit code：全部通過回 0；任一支失敗（或一支都沒掃到）回 1。適合直接接 CI。

## 重要誠實聲明

這支腳本跑「全綠」**不等於** Godot 專案能在引擎裡跑起來。它驗證的是「各模組的 Python 鏡像/資料層邏輯跟
權威來源（build_cq2.py / CONTENT.json）一致」，**不涵蓋**：GDScript 語法能否被 Godot 4.3 剖析、autoload
能否載入、場景能否實例化。那一層要等有 Godot 執行檔時，用 tests/smoke_test.gd + `godot --headless
--check-only` 補上（見 tests/README.md 與 tests/VERIFICATION_STATUS.md）。
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

# tests/ 的上一層就是 godot-project/（掃描根）。
TESTS_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = TESTS_DIR.parent

# 交叉驗證測試的命名前綴（見檔頭「掃描規則」）。
TEST_GLOBS = ("test_*.py", "validate_*.py", "verify_*.py")

# 明確排除的目錄（相對 PROJECT_ROOT 的第一層片段）。tests/ 自己不放受測腳本；.godot 是引擎快取。
EXCLUDE_DIR_PARTS = {"tests", ".godot", ".git"}


def discover() -> list[Path]:
    found: dict[Path, None] = {}  # 用 dict 保順序去重
    for pattern in TEST_GLOBS:
        for path in PROJECT_ROOT.rglob(pattern):
            if not path.is_file():
                continue
            rel_parts = path.relative_to(PROJECT_ROOT).parts
            if any(part in EXCLUDE_DIR_PARTS for part in rel_parts[:-1]):
                continue
            found[path] = None
    return sorted(found.keys(), key=lambda p: str(p))


def _last_meaningful_line(text: str) -> str:
    for line in reversed(text.strip().splitlines()):
        s = line.strip()
        if s:
            return s
    return ""


def run_one(path: Path, verbose: bool) -> tuple[bool, float, str]:
    rel = path.relative_to(PROJECT_ROOT)
    started = time.monotonic()
    # cwd 設在測試檔自己的目錄：既有測試用相對路徑找 CONTENT.json / .gd 來源，都是相對自身位置解析的。
    proc = subprocess.run(
        [sys.executable, path.name],
        cwd=str(path.parent),
        capture_output=True,
        text=True,
    )
    elapsed = time.monotonic() - started
    ok = proc.returncode == 0
    if verbose:
        print(f"\n{'-' * 78}\n$ python3 {rel}\n{'-' * 78}")
        if proc.stdout:
            print(proc.stdout, end="" if proc.stdout.endswith("\n") else "\n")
        if proc.stderr:
            print("[stderr]")
            print(proc.stderr, end="" if proc.stderr.endswith("\n") else "\n")
    summary = _last_meaningful_line(proc.stdout) or _last_meaningful_line(proc.stderr)
    if not ok:
        # 失敗時，就算沒開 -v 也把 stderr 尾巴帶出來，方便 CI 直接看到爆點。
        err_tail = _last_meaningful_line(proc.stderr)
        if err_tail and err_tail != summary:
            summary = f"{summary}  |stderr: {err_tail}"
        summary = f"exit={proc.returncode}  {summary}"
    return ok, elapsed, summary


def main() -> int:
    ap = argparse.ArgumentParser(description="CORE-7 統一 Python 交叉驗證測試入口")
    ap.add_argument("-v", "--verbose", action="store_true", help="印出每支測試的完整輸出")
    ap.add_argument("--list", action="store_true", help="只列出會跑哪些測試，不執行")
    ap.add_argument("-k", metavar="SUBSTR", default="", help="只跑相對路徑含此子字串的測試")
    args = ap.parse_args()

    tests = discover()
    if args.k:
        tests = [t for t in tests if args.k in str(t.relative_to(PROJECT_ROOT))]

    print(f"CORE-7 統一測試入口 — 掃描根：{PROJECT_ROOT}")
    print(f"命名慣例：{', '.join(TEST_GLOBS)}（排除 generator：sync_/extract_/gen_）")
    print(f"發現 {len(tests)} 支交叉驗證測試\n")

    if not tests:
        print("[!] 一支測試都沒掃到——命名慣例或目錄結構可能變了，請檢查。")
        return 1

    if args.list:
        for t in tests:
            print(f"  - {t.relative_to(PROJECT_ROOT)}")
        return 0

    results: list[tuple[Path, bool, float, str]] = []
    for t in tests:
        rel = t.relative_to(PROJECT_ROOT)
        print(f"[RUN ] {rel}")
        ok, elapsed, summary = run_one(t, args.verbose)
        tag = "PASS" if ok else "FAIL"
        print(f"[{tag}] {rel}  ({elapsed:.1f}s)")
        if summary:
            print(f"        {summary}")
        results.append((t, ok, elapsed, summary))

    passed = sum(1 for _, ok, _, _ in results if ok)
    failed = len(results) - passed
    total_time = sum(e for _, _, e, _ in results)

    print(f"\n{'=' * 78}")
    print(f"彙整：{passed}/{len(results)} 通過，{failed} 失敗，共 {total_time:.1f}s")
    if failed:
        print("失敗清單：")
        for t, ok, _, summary in results:
            if not ok:
                print(f"  [FAIL] {t.relative_to(PROJECT_ROOT)} — {summary}")
    print("=" * 78)
    print(
        "提醒：全綠只代表『Python 交叉驗證層』一致，不等於 Godot 引擎能跑起來。"
        "GDScript 語法/場景/autoload 那層待有 Godot 4.3+ 執行檔時，用 tests/smoke_test.gd + "
        "`godot --headless --check-only` 補驗（見 tests/README.md）。"
    )
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
