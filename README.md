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
- Python 3.8+
- Disco Elysium (любая версия)
- Telegram Bot Token

### Быстрая установка на Steam Deck

```bash
# Одна команда для полной установки
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash

# Настройте config.yaml
nano ~/disco_coop/config/config.yaml

# Запустите бота
cd ~/disco_coop && ./start.sh
```

### Ручная установка

1. **Клонирование репозитория:**
   ```bash
   git clone https://github.com/ArtemKiyashko/DiscoCoop.git
   cd DiscoCoop
   ```

2. **Установка зависимостей:**
   ```bash
   python -m venv venv
   source venv/bin/activate  # Linux/Mac
   pip install -r requirements.txt
   ```

3. **Установка Ollama:**
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ollama pull llama3.1:8b
   ollama pull llava:7b
   ```

### Конфигурация

Скопируйте `config/config.example.yaml` в `config/config.yaml` и настройте:

```yaml
telegram:
  bot_token: "YOUR_BOT_TOKEN"
  allowed_chats: [YOUR_CHAT_ID]

llm:
  model_name: "llama3.1:8b"
  vision_model: "llava:7b"

security:
  rate_limit: 10
  session_timeout: 1800
```

## Использование

### Запуск
```bash
./start.sh
```

### Команды в Telegram
- `/start` - Инициализация бота
- `/help` - Справка по командам
- `/describe` - Описание текущего экрана
- `/status` - Статус системы
- `Любой текст` - Игровая команда

### Примеры команд
- "Подойти к двери"
- "Поговорить с барменом"
- "Осмотреть предмет на столе"
- "Открыть инвентарь"

## Безопасность

- Авторизация только для разрешенных чатов
- Ограничения количества команд в минуту
- Автоматическое завершение сессий по таймауту
- Все команды логируются
- Возможность экстренной остановки

## Решение проблем

### ✅ Современная архитектура

**Обновление:** Код полностью переписан для актуальной версии python-telegram-bot 22.x:
- Исправлены все API вызовы для современной версии
- Удален устаревший код совместимости  
- Улучшена архитектура и производительность

✅ **Преимущества современной версии**: 
- Лучшая производительность с нативным asyncio
- Поддержка всех новых функций Telegram Bot API
- Активная поддержка и обновления безопасности
- Более чистый и современный код

### 🔄 Универсальное решение

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

### 🛠️ Исправление сервисов

#### Проблемы с сервисом Ollama

Если после перезагрузки Steam Deck команда `sudo systemctl start ollama` не работает:

```bash
cd ~/disco_coop
./fix_ollama_service.sh
```

**Скрипт исправляет:**
- ❌ Отсутствующий файл `ollama.service`  
- ❌ Неправильные права доступа
- ❌ Неверный путь к исполняемому файлу
- ❌ Проблемы с автозапуском

#### Проблемы с сервисом бота

Если бот не запускается как сервис или работает нестабильно:

```bash
cd ~/disco_coop  
./fix_bot_service.sh
```

**Скрипт исправляет:**
- ❌ Отсутствующий файл `disco-coop.service`
- ❌ Поврежденное виртуальное окружение
- ❌ Отсутствующие зависимости Python
- ❌ Неправильные пути в сервисе
- ❌ Проблемы с конфигурацией

#### Проблемы со скриншотами

Если команда `/describe` выдает ошибки `convert: command not found` или `xwd: command not found`:

```bash
cd ~/disco_coop
./fix_screenshots.sh
```

**Скрипт исправляет:**
- ❌ Отсутствующий ImageMagick (`convert`)
- ❌ Отсутствующий xorg-xwd (`xwd`)
- ❌ Проблемы с правами доступа к X сессии
- ❌ Неправильная конфигурация скриншотов

**Проверка работы сервисов:**
```bash
sudo systemctl status ollama        # Статус Ollama
sudo systemctl status disco-coop    # Статус бота
journalctl -u disco-coop -f         # Логи бота в реальном времени  
```

### 🐛 Если ничего не помогает

1. **Удалите проект и начните заново:**
   ```bash
   rm -rf ~/disco_coop
   curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash
   ```

2. **Проверьте логи системы:**
   ```bash
   sudo journalctl -u disco-coop.service -f
   sudo journalctl -u ollama.service -f
   ```

### 🔧 Частые проблемы

**Проблемы с pynput/evdev:**
- На Steam Deck часто возникают проблемы с evdev
- Ошибка `ModuleNotFoundError: No module named 'six'` - отсутствует зависимость
- **Решение:** `pip install six pynput` или переустановка зависимостей
- Пакет не критичен для базовой функциональности

**Проблемы с Pillow/aiohttp:**
- Скрипт пробует разные версии
- Устанавливает дополнительные инструменты сборки
- Использует совместимые версии для Steam Deck

**Ollama не запускается:**
- Проверьте статус: `sudo systemctl status ollama.service`
- Перезапустите: `sudo systemctl restart ollama.service`
- Логи: `sudo journalctl -u ollama.service -f`

## Системные сервисы

### Управление сервисами
```bash
# Запуск
sudo systemctl start disco-coop.service
sudo systemctl start ollama.service

# Остановка  
sudo systemctl stop disco-coop.service
sudo systemctl stop ollama.service

# Автозапуск
sudo systemctl enable disco-coop.service
sudo systemctl enable ollama.service

# Статус
sudo systemctl status disco-coop.service
sudo systemctl status ollama.service
```

### Логи
```bash
# Логи бота
sudo journalctl -u disco-coop.service -f

# Логи Ollama
sudo journalctl -u ollama.service -f

# Все логи системы
journalctl -f
```

## Развитие проекта

### Планируемые функции
- [ ] Поддержка множественных игр
- [ ] Web-интерфейс для настройки
- [ ] Интеграция с OBS для стриминга
- [ ] Поддержка голосовых команд
- [ ] Расширенный ИИ анализ игровых ситуаций

### Вклад в проект
1. Fork репозитория
2. Создайте feature branch
3. Сделайте изменения
4. Создайте Pull Request

## Лицензия

MIT License - см. файл [LICENSE](LICENSE)

## Поддержка

- GitHub Issues для багов и предложений
- Telegram: @YourUsername для вопросов
- Discord: Сообщество в разработке

---

**Важно:** Данный проект создан для образовательных целей и демонстрации возможностей ИИ. Используйте ответственно и в соответствии с условиями использования игры.