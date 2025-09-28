# Disco Coop - Кооперативная игра в Disco Elysium через Telegram

![Python](https://img.shields.io/badge/python-v3.8+-blue.svg)
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
# Основной скрипт установки (с обходом кэша)
curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" \
  "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh?$(date +%s)" | bash

# Если проблемы с pacman - упрощенный скрипт:
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install_simple.sh" | bash

# Если критические проблемы - минимальный скрипт:
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install_minimal.sh" | bash

# Исправление pacman (если нужно):
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/fix_steamdeck_pacman.sh" | bash

# Исправление Ollama на Steam Deck (если нужно):
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/fix_ollama_steamdeck.sh" | bash

# Переустановка Ollama (если файл поврежден):
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/reinstall_ollama.sh" | bash
```

**Ручная установка:**
1. Клонируйте репозиторий:
```bash
git clone https://github.com/ArtemKiyashko/DiscoCoop.git
cd DiscoCoop
```

2. Установите зависимости:
```bash
pip install -r requirements.txt
```

3. Настройте конфигурацию:
```bash
cp config/config.example.yaml config/config.yaml
# Отредактируйте config.yaml с вашими настройками
```

4. Установите Ollama и модель:
```bash
# Обычная установка:
curl -fsSL https://ollama.ai/install.sh | sh

# Если проблемы на Steam Deck:
./fix_ollama_steamdeck.sh

# Загрузка моделей:
ollama pull llama3.1:8b
ollama pull llava:7b  # для анализа изображений
```

5. Запустите бота:
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

## Решение проблем на Steam Deck

### Проблема с externally-managed-environment

Если при установке Python пакетов вы получаете ошибку:
```
error: externally-managed-environment
```

**Решение: Используйте минимальный скрипт установки**
```bash
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install_minimal.sh" | bash
```

Этот скрипт использует портативный Python и обходит системные ограничения.

### Проблема с установкой Ollama

Если при установке Ollama вы получаете ошибку:
```
install: cannot change owner and permissions of '/usr/local/lib/ollama': No such file or directory
```

**Решение: Установка Ollama в пользовательскую директорию**
```bash
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/fix_ollama_steamdeck.sh" | bash
```

### Проблема с поврежденным файлом Ollama

Если Ollama установился, но при запуске выдает ошибку типа:
```
/home/deck/.local/bin/ollama: line 1: Not: command not found
```

Это означает, что вместо бинарного файла загрузилась HTML-страница или текст ошибки.

**Решение: Переустановка Ollama**
```bash
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/reinstall_ollama.sh" | bash
```

Или вручную:
```bash
rm -f ~/.local/bin/ollama
mkdir -p ~/.local/bin
curl -L https://github.com/ollama/ollama/releases/download/v0.12.3/ollama-linux-amd64.tgz -o /tmp/ollama.tgz
tar -xzf /tmp/ollama.tgz -C /tmp/
cp /tmp/bin/ollama ~/.local/bin/ollama  # или /tmp/ollama если структура другая
chmod +x ~/.local/bin/ollama
export PATH="$HOME/.local/bin:$PATH"
```

### Проблема с PGP ключами pacman

Если получаете ошибки PGP при установке пакетов:
```bash
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/fix_steamdeck_pacman.sh" | bash
```

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