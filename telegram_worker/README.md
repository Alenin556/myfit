# MyFit Telegram Worker

Cloudflare Worker для привязки пользователя к Telegram-боту и автоматической отправки плана питания.

## Что делает
- `POST /telegram/webhook`: принимает update от Telegram, читает `/start <code>`, сохраняет `code -> chat_id` (TTL 24 часа)
- `GET /link-status?code=...`: проверяет, привязан ли код
- `POST /send`: отправляет текст пользователю по коду
- `POST /send-email`: отправляет план на **email** через [Resend](https://resend.com) (асинхронно из приложения). Требует секрет `RESEND_API_KEY`. Если ключ не задан, ответ **501** — приложение откроет Gmail вручную.

### Почта (Resend)
1. Зарегистрируйся в Resend, создай API key.
2. В Cloudflare:

```bash
wrangler secret put RESEND_API_KEY
```

3. Опционально — адрес «от кого» (должен быть разрешён в Resend, иначе используй тестовый `onboarding@resend.dev`):

```bash
wrangler secret put RESEND_FROM
# пример: My Pro Health <onboarding@resend.dev>
```

4. Деплой: `wrangler deploy`

Без `RESEND_API_KEY` маршрут вернёт `501` — это нормально: в приложении останется открытие Gmail и копирование в буфер.

## Быстрый старт
### 0) Создай бота
В Telegram открой **@BotFather** → `/newbot` → задай имя/username бота → получи **token**.

1) Установи Wrangler

```bash
npm i -g wrangler
```

2) Залогинься

```bash
wrangler login
```

3) Создай KV namespace

```bash
wrangler kv namespace create MYFIT_LINKS
```

Вставь `id` в `wrangler.toml` вместо `REPLACE_WITH_KV_NAMESPACE_ID`.

4) Задай секреты

```bash
wrangler secret put TELEGRAM_BOT_TOKEN
# optional
wrangler secret put APP_API_KEY
```

5) Деплой

```bash
wrangler deploy
```

6) Настрой webhook у Telegram

```bash
curl -X POST "https://api.telegram.org/bot<YOUR_TOKEN>/setWebhook" \\
  -H "content-type: application/json" \\
  -d "{\"url\":\"https://<worker-domain>/telegram/webhook\"}"
```

Проверка:

```bash
curl "https://api.telegram.org/bot<YOUR_TOKEN>/getWebhookInfo"
```

## Привязка пользователя
Пользователь в приложении получает код и отправляет боту:

`/start <code>`

После этого приложение может отправлять план через `POST /send`.

