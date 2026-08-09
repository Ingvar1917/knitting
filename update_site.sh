#!/usr/bin/env bash
# Ежедневное обновление: свежие новости → блок «Свежее» на сайте → публикация → письмо мастеру.
set -euo pipefail
cd "$(dirname "$0")"

DATE=$(date +%Y-%m-%d)
mkdir -p out
rm -f out/mail.txt

# claude может лежать в nvm-пути, которого нет в PATH systemd
CLAUDE_BIN=$(command -v claude || ls -1 "$HOME"/.nvm/versions/node/*/bin/claude 2>/dev/null | tail -1)
if [ -z "$CLAUDE_BIN" ]; then
    echo "Не найден бинарник claude." >&2
    exit 1
fi

echo "[$(date '+%H:%M:%S')] Ищу свежее и обновляю сайт..."
"$CLAUDE_BIN" -p "$(cat prompt-site.md)" \
    --allowedTools "WebSearch,WebFetch,Read,Edit,Write" \
    > "out/site-log-$DATE.txt"

# Публикуем сайт, если страница изменилась
if ! git diff --quiet -- index.html; then
    git add index.html
    git commit -q -m "Свежее на $DATE"
    git push -q
    echo "[$(date '+%H:%M:%S')] Сайт обновлён и опубликован."
else
    echo "[$(date '+%H:%M:%S')] Изменений на странице нет."
fi

# Письмо с обновлениями
if [ -s out/mail.txt ]; then
    cp out/mail.txt "out/mail-$DATE.txt"
    python3 send_mail.py --file out/mail.txt --subject "Вязание: что нового — $(date '+%d.%m.%Y')"
else
    echo "Письмо не сформировано — отправка пропущена." >&2
fi

echo "[$(date '+%H:%M:%S')] Готово."
