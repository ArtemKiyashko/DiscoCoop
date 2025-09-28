# Disco Coop - Кооперативная игра в Disco Elysium через Telegram

![Python](https://img.shields.io/badge### 🔧 Ошибка бота: Updater object has no attribute

**Проблема:** `'Updater' object has no attribute '_Updater__polling_cleanup_cb'`

**Причина:** Устаревшая версия python-telegram-bot или смешанный код разных версий API

**Решение:** Код исправлен для работы с актуальной версией python-telegram-bot 22.x:
```bash
# Обновите до актуальной версии
pip install "python-telegram-bot>=22.0,<23.0" --upgrade

# Или запустите скрипт исправления
./fix_pynput.sh
```

✅ **Преимущества современной версии**: 
- Лучшая производительность
- Больше возможностей API
- Активная поддержка и обновления безопасностиlue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-SteamDeck%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-lightgrey.svg)

Система для совместной игры в Disco Elysium через Telegram чат с использованием Steam Deck и локальной LLM.

## Архитектура

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Telegram      │    │   Steam Deck    │    │      OBS        │
│   Group Chat    │◄──►│   + Bot System  │◄──►│   Streaming     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
            ┌───────▼───┐ ┌───▼────┐ ┌──▼──────┐
            │    LLM    │ │ Screen │ │  Game   │
            │ (Ollama)  │ │ Vision │ │Control  │
            └───────────┘ └────────┘ └─────────┘
```

## Компоненты

### 1. Telegram Bot
- Авторизация по белому списку чатов
- Обработка команд на естественном языке
- Отправка описаний происходящего в игре

### 2. LLM Agent (Ollama)
- Локальная модель для обработки команд
- Генерация игровых действий
- Анализ игрового контекста

### 3. Screen Analyzer
- Захват скриншотов игры
- Описание происходящего на экране
- Анализ UI элементов

### 4. Game Controller
- Эмуляция клавиатуры и мыши
- Выполнение игровых действий
- Управление диалогами и меню

## Установка и настройка

### Требования
- Steam Deck с SteamOS
- Python 3.11+
- Ollama
- Disco Elysium в Steam
- Telegram Bot Token

### Быстрый старт

**Автоматическая установка на Steam Deck:**
```bash
# 🚀 Универсальный скрипт - проверяет все зависимости, можно запускать многократно
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash
```

> 💡 **Один скрипт для всего:** Скрипт умеет обрабатывать все возможные проблемы и может запускаться многократно без вреда для системы.

**Ручная установка (если автоматическая не подходит):**
1. Клонируйте репозиторий:
```bash
git clone https://github.com/ArtemKiyashko/DiscoCoop.git
cd DiscoCoop
```

2. Запустите скрипт установки:
```bash
./install.sh
```

> 💡 **Рекомендация:** Даже при ручной установке лучше использовать скрипт `install.sh` - он автоматически обработает все зависимости и настройки.
```bash
python main.py
```

## Конфигурация

Все настройки находятся в `config/config.yaml`:
- Telegram bot token
- Белый список чатов
- Настройки LLM
- Параметры игры

## Команды бота

- `/describe` - Описать что происходит на экране
- `/help` - Показать помощь
- Любой текст - Интерпретируется как игровая команда

## Безопасность

- Бот работает только в чатах из белого списка
- Все команды логируются
- Возможность экстренной остановки

## Решение проблем

### � Ошибка бота: Updater object has no attribute

**Проблема:** `'Updater' object has no attribute '_Updater__polling_cleanup_cb'`

**Решение:** Эта ошибка возникает из-за несовместимости версий python-telegram-bot. Выполните:

```bash
./fix_pynput.sh
```

Или вручную:
```bash
pip uninstall -y python-telegram-bot
pip install python-telegram-bot==13.15
```

### �🔄 Универсальное решение

При любых проблемах просто запустите скрипт установки повторно:

```bash
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash
```

**Скрипт автоматически:**
- ✅ Определяет и исправляет проблемы с Python
- ✅ Обходит ограничения `externally-managed-environment` 
- ✅ Устанавливает Ollama локально при проблемах с правами
- ✅ Исправляет PGP ключи pacman
- ✅ Проверяет и доустанавливает недостающие зависимости
- ✅ Настраивает systemd сервисы
- ✅ Загружает необходимые модели ИИ
- ✅ Устанавливает актуальную версию python-telegram-bot 22.x

### 🐛 Если ничего не помогает

1. **Удалите проект и начните заново:**
   ```bash
   rm -rf ~/disco_coop
   curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash
   ```

2. **Проверьте логи системы:**
   ```bash
   sudo journalctl -u ollama.service -f
   sudo journalctl -u disco-coop.service -f
   ```

3. **Используйте встроенную диагностику:**
   ```bash
   cd ~/disco_coop
   ./test.sh
   ./status.sh
   ```

### 🔧 Частые проблемы и решения

**Проблемы с установкой Python пакетов:**
- Скрипт автоматически пробует разные версии пакетов
- Использует `--no-cache-dir` для избежания проблем с кэшем
- При неудаче пробует установку через requirements.txt

**Проблемы с pynput/evdev:**
- На Steam Deck часто возникают проблемы с evdev
- Ошибка `ModuleNotFoundError: No module named 'six'` - отсутствует зависимость
- **Решение:** `./fix_pynput.sh` или `pip install six`
- Пакет не критичен для базовой функциональности

**Проблемы с Pillow/aiohttp:**
- Скрипт пробует разные версии
- Устанавливает дополнительные инструменты сборки
- Использует совместимые версии для Steam Deck

## Разработка

### Структура проекта
```
disco_coop/
├── main.py              # Точка входа
├── config/              # Конфигурационные файлы
├── src/
│   ├── bot/            # Telegram bot
│   ├── llm/            # LLM интеграция
│   ├── vision/         # Анализ экрана
│   ├── game/           # Управление игрой
│   └── utils/          # Утилиты
├── tests/              # Тесты
└── docs/               # Документация
```

## Лицензия

MIT License