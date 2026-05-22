#!/bin/bash
set -e

# Force UTF-8 everywhere — prevents UnicodeDecodeError from Stockfish's banner
export PYTHONIOENCODING=utf-8
export PYTHONUTF8=1
export PYTHONUNBUFFERED=1

# ── 1. Download Stockfish for Linux if not already present ──────────────────
SF_DIR="./engines"
SF_BIN="$SF_DIR/stockfish"

mkdir -p "$SF_DIR"

if [ ! -f "$SF_BIN" ]; then
  echo "[start] Downloading Stockfish 18 (Linux x86-64)..."
  SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-ubuntu-x86-64.tar"
  curl -L "$SF_URL" -o /tmp/sf.tar
  tar -xf /tmp/sf.tar -C /tmp
  find /tmp -name "stockfish*" -type f | head -1 | xargs -I{} cp {} "$SF_BIN"
  chmod +x "$SF_BIN"
  rm -f /tmp/sf.tar
  echo "[start] Stockfish downloaded: $SF_BIN"
else
  echo "[start] Stockfish already present: $SF_BIN"
fi

# ── 2. Generate config.yml from environment variables ───────────────────────
echo "[start] Writing config.yml..."
cat > config.yml << YAML
token: "${LICHESS_TOKEN}"
url: "https://lichess.org/"

engine:
  dir: "./engines"
  name: "stockfish"
  protocol: "uci"
  ponder: true
  silence_stderr: true

  draw_or_resign:
    resign_enabled: false
    offer_draw_enabled: true
    offer_draw_score: 0
    offer_draw_moves: 10
    offer_draw_pieces: 10

  uci_options:
    Threads: 1
    Hash: 256
    Move Overhead: 100
    UCI_ShowWDL: true

abort_time: 30
fake_think_time: false
rate_limiting_delay: 0
move_overhead: 2000
max_takebacks_accepted: 0
quit_after_all_games_finish: false

correspondence:
  move_time: 60
  checkin_period: 300
  disconnect_time: 150
  ponder: false

challenge:
  concurrency: 1
  sort_by: "best"
  preference: "none"
  accept_bot: true
  only_bot: false
  max_increment: 60
  min_increment: 0
  max_base: 1800
  min_base: 0
  variants:
    - standard
    - chess960
  time_controls:
    - bullet
    - blitz
    - rapid
    - classical
  modes:
    - casual
    - rated
  bullet_requires_increment: true
  max_simultaneous_games_per_user: 1

greeting:
  hello: "Hi {opponent}, gl hf!"
  goodbye: "Good game!"
  hello_spectators: "Welcome — running Stockfish 18."
  goodbye_spectators: "Thanks for watching!"

matchmaking:
  allow_matchmaking: true
  challenge_variant: "standard"
  challenge_timeout: 1
  challenge_initial_time:
    - 60
    - 180
    - 300
  challenge_increment:
    - 1
    - 2
    - 3
  opponent_rating_difference: 500
  rating_preference: "none"
  challenge_mode: "rated"
  challenge_filter: "coarse"
  include_challenge_block_list: false
YAML

echo "[start] config.yml written."

# ── 3. Start health server as a separate background process ─────────────────
python3 health.py &
HEALTH_PID=$!
echo "[start] Health server PID: $HEALTH_PID"

# ── 4. Self-ping loop — keeps Render awake without UptimeRobot ──────────────
# Pings our own health endpoint every 4 minutes so Render never idles out.
(
  sleep 30  # wait for health server to be ready
  while true; do
    curl -sf "http://localhost:${PORT:-10000}/" > /dev/null 2>&1 || true
    sleep 240
  done
) &
PING_PID=$!
echo "[start] Self-ping loop PID: $PING_PID"

# ── 5. Start lichess-bot in the foreground ───────────────────────────────────
echo "[start] Starting lichess-bot..."
python3 lichess-bot.py

# If lichess-bot exits, kill background processes so Render restarts cleanly.
kill $HEALTH_PID $PING_PID 2>/dev/null || true
