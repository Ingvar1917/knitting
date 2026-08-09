#!/usr/bin/env python3
"""Отправка письма через Gmail SMTP. Креды и получатели — из .env рядом со скриптом."""
import argparse
import smtplib
import sys
from email.message import EmailMessage
from pathlib import Path

ENV_PATH = Path(__file__).resolve().parent / ".env"


def load_env(path: Path) -> dict:
    env = {}
    if not path.exists():
        sys.exit(f"Нет файла {path} — скопируй .env.example в .env и заполни.")
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        env[key.strip()] = value.strip().strip('"').strip("'")
    return env


def main() -> None:
    parser = argparse.ArgumentParser(description="Отправить текстовый файл письмом")
    parser.add_argument("--file", required=True, help="файл с текстом письма (utf-8)")
    parser.add_argument("--subject", required=True, help="тема письма")
    parser.add_argument("--to", help="получатели через запятую (по умолчанию MAIL_RECIPIENTS из .env)")
    args = parser.parse_args()

    env = load_env(ENV_PATH)
    sender = env.get("MAIL_USERNAME")
    password = env.get("MAIL_PASSWORD")
    recipients = [a.strip() for a in (args.to or env.get("MAIL_RECIPIENTS", "")).split(",") if a.strip()]
    if not sender or not password or not recipients:
        sys.exit("В .env должны быть MAIL_USERNAME, MAIL_PASSWORD и MAIL_RECIPIENTS.")

    body = Path(args.file).read_text(encoding="utf-8")

    msg = EmailMessage()
    msg["From"] = sender
    msg["To"] = ", ".join(recipients)
    msg["Subject"] = args.subject
    msg.set_content(body, charset="utf-8")

    with smtplib.SMTP_SSL("smtp.gmail.com", 465, timeout=60) as smtp:
        smtp.login(sender, password)
        smtp.send_message(msg)

    print(f"Отправлено: {', '.join(recipients)}")


if __name__ == "__main__":
    main()
