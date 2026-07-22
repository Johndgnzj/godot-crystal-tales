#!/usr/bin/env bash
# 水晶傳說工具集 — 唯一入口：啟動 hub（一個 port 整合地圖維護／立繪切圖／火柴人動畫／幀對齊，自動開瀏覽器）。
# 用法：
#   ./tools/start.sh                         # 預設 port 8800、載入專案 map-def、匯出到執行目錄 exports/
#   ./tools/start.sh --port 9000 --no-open
#   ./tools/start.sh --map-def <path>        # 指定要載入的 map-def.json
#   ./tools/start.sh --out <dir>             # 立繪切圖匯出根目錄
cd "$(dirname "$0")/hub" || exit 1

# 啟動前清掉佔用目標 port 的舊 hub 進程（serve.py 殘留），避免 port 被卡住而啟動失敗。
PORT=8800
args=("$@")
for ((i = 0; i < ${#args[@]}; i++)); do
  case "${args[i]}" in
    --port) PORT="${args[i + 1]}" ;;
    --port=*) PORT="${args[i]#*=}" ;;
  esac
done

for pid in $(lsof -ti "tcp:$PORT" -sTCP:LISTEN 2>/dev/null); do
  cmd=$(ps -p "$pid" -o command= 2>/dev/null)
  if [[ "$cmd" == *serve.py* ]]; then
    echo "🧹 清掉佔用 port $PORT 的舊 hub 進程 (PID $pid)"
    kill "$pid" 2>/dev/null
  else
    echo "⚠️  port $PORT 被非 hub 進程佔用 (PID $pid)，請手動處理或用 --port 換埠：" >&2
    echo "    $cmd" >&2
    exit 1
  fi
done

# 等 port 真正釋放（最多約 2 秒），仍佔用就強制結束，避免緊接著啟動又撞埠。
for _ in 1 2 3 4; do
  leftover=$(lsof -ti "tcp:$PORT" -sTCP:LISTEN 2>/dev/null)
  [ -z "$leftover" ] && break
  sleep 0.5
done
[ -n "$leftover" ] && kill -9 $leftover 2>/dev/null

exec python3 serve.py "$@"
