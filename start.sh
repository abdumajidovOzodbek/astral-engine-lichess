#!/bin/bash
set -e

# ── 1. Download Stockfish for Linux if not already present ──────────────────
SF_DIR="./engines"
SF_BIN="$SF_DIR/stockfish"

mkdir -p "$SF_DIR"

if [ ! -f "$SF_BIN" ]; then
  echo "[start] Downloading Stockfish 18 (Linux x86-64)..."
  SF_URL="https://github.com/official-stockfish/Stockfish/releases/download/sf_18/stockfish-ubuntu-x86-64.tar"
  curl -L "$SF_URL" -o /tmp/sf.tar
  tar -xf /tmp/sf.tar -C /tmp
  # The tar contains stockfish-ubuntu-x86-64 binary
  find /tmp -name "stockfish*" -type f -exec cp {} "$SF_BIN" \;
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
  silence_stderr: false

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

# ── 3. Start a tiny health HTTP server in the background ────────────────────
# Render's free Web Service requires the process to bind to PORT.
PORT="${PORT:-10000}"
python3 -c "
import http.server, os, threading
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'ok')
    def log_message(self, *a): pass
port = int(os.environ.get('PORT', 10000))
srv = http.server.HTTPServer(('0.0.0.0', port), H)
t = threading.Thread(target=srv.serve_forever, daemon=True)
t.start()
print(f'[health] listening on port {port}')
import time
while True: time.sleep(3600)
" &

# ── 4. Start lichess-bot ─────────────────────────────────────────────────────
echo "[start] Starting lichess-bot..."
exec python3 lichess-bot.py
