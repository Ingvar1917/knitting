#!/usr/bin/env bash
# Ежедневное обновление: свежие новости → блок «Свежее» на сайте → публикация → письмо мастеру.
set -Eeuo pipefail
cd "$(dirname "$0")"

DATE=$(date +%Y-%m-%d)
mkdir -p out
rm -f out/mail.txt

# Любой сбой ниже — письмо себе, иначе падение остаётся незамеченным.
MAILER=${MAILER:-"python3 send_mail.py"}
notify_failure() {
    code=$?
    trap - ERR EXIT
    ALERT_TO=$(sed -n 's/^MAIL_ALERTS=//p' .env | tr -d "\"' " | head -1)
    [ -n "$ALERT_TO" ] || ALERT_TO=$(sed -n 's/^MAIL_USERNAME=//p' .env | tr -d "\"' " | head -1)
    {
        echo "Обновление сайта вязания упало $(date '+%d.%m.%Y %H:%M'), код выхода $code."
        echo
        echo "Хвост out/site-log-$DATE.txt:"
        tail -c 2000 "out/site-log-$DATE.txt" 2>/dev/null || echo "(лога нет)"
    } > out/alert.txt
    if [ -n "$ALERT_TO" ]; then
        $MAILER --file out/alert.txt --subject "СБОЙ: сайт вязания не обновился ($DATE)" --to "$ALERT_TO" || true
    fi
    exit $code
}
trap notify_failure ERR

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
    $MAILER --file out/mail.txt --subject "Вязание: что нового — $(date '+%d.%m.%Y')"
else
    echo "Письмо не сформировано — отправка пропущена." >&2
fi

echo "[$(date '+%H:%M:%S')] Готово."
