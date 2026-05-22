# astral-engine — Lichess bot

Stockfish 18 running as a Lichess bot via [lichess-bot](https://github.com/lichess-bot-devs/lichess-bot).

## Deploy on Render

1. Connect this repo to a new Render **Web Service**.
2. Build command: `pip install -r requirements.txt`
3. Start command: `bash start.sh`
4. Add env var: `LICHESS_TOKEN` = your Lichess bot token.
5. Add UptimeRobot monitor on `https://<your-render-url>/` every 5 minutes.

## What start.sh does

1. Downloads Stockfish 18 Linux binary on first run.
2. Generates `config.yml` from env vars (token never committed to git).
3. Starts a tiny Python health server on `$PORT` so Render's health check passes.
4. Starts `lichess-bot.py` in the foreground.
