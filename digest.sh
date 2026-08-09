#!/usr/bin/env bash
# Еженедельный дайджест вязания: Claude ищет новости и пишет письмо, send_mail.py отправляет.
set -euo pipefail
cd "$(dirname "$0")"

DATE=$(date +%Y-%m-%d)
OUT="out/digest-$DATE.txt"
mkdir -p out

# claude может лежать в nvm-пути, которого нет в PATH systemd
CLAUDE_BIN=$(command -v claude || ls -1 "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | tail -1)
if [ -z "$CLAUDE_BIN" ]; then
    echo "Не найден бинарник claude." >&2
    exit 1
fi

echo "[$(date '+%H:%M:%S')] Генерирую дайджест..."
"$CLAUDE_BIN" -p "$(cat prompt-digest.md)" --allowedTools "WebSearch,WebFetch" > "$OUT"

if [ ! -s "$OUT" ]; then
    echo "Дайджест пустой — отправка отменена." >&2
    exit 1
fi

echo "[$(date '+%H:%M:%S')] Отправляю письмо..."
python3 send_mail.py --file "$OUT" --subject "Дайджест вязания — $DATE"

echo "[$(date '+%H:%M:%S')] Готово. Текст сохранён в $OUT"
