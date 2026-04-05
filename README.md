# MTProxyMax Automation & Key Pool Manager

Этот репозиторий содержит систему автоматизации для [MTProxyMax](https://github.com/SamNet-dev/MTProxyMax), которая переносит нагрузку по генерации ключей на воркера, создает пулы готовых ключей и предоставляет API для удаленного получения прокси-ссылок.

## 🚀 Возможности

- **Key Pools**: Два пула по 100 ключей (обычные и тестовые).
- **Worker**: Автоматическое пополнение пулов ежедневно в 7:00 и при низком остатке (< 20 ключей).
- **Clean API**: HTTP API на порту 8000, возвращающее чистые JSON-ответы с прокси-ссылками.
- **One-Command Setup**: Установка всей системы одной командой.

## 🛠 Установка

Для установки на сервер выполните:
```bash
curl -sL https://raw.githubusercontent.com/TETRIX8/Mtproxymax-script-/main/install_automation.sh | bash
```

## 📡 Использование API

Для доступа к API используйте заголовок `Authorization: Bearer MTProxyMaxSecretToken123`.

### Получить тестовый ключ (1 день)
```bash
curl -X GET "http://YOUR_IP:8000/get-test" -H "Authorization: Bearer MTProxyMaxSecretToken123"
```
**Ответ:** `{"link": "https://t.me/proxy?server=..."}`

### Получить обычный ключ
```bash
curl -X GET "http://YOUR_IP:8000/get-regular?label=user1&period=+30days" -H "Authorization: Bearer MTProxyMaxSecretToken123"
```

## 💻 Локальные команды
- `mtproxymax-pool get-test` — выдать тестовый ключ.
- `mtproxymax-pool get-regular <label> <period>` — выдать обычный ключ.

## ⚙️ Структура
- `worker.sh`: Скрипт генерации ключей.
- `pool_manager.sh`: Логика выдачи из пулов.
- `api_server.py`: FastAPI сервер для удаленного доступа.
- `install_automation.sh`: Скрипт полной установки.
