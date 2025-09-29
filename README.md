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

## 🚀 Быстрая установка на Steam Deck

### Автоматическая установка (рекомендуется)

Переключитесь в Desktop Mode на Steam Deck и откройте Konsole

```bash
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash
```

**Что делает скрипт:**
- ✅ Устанавливает Python без использования pacman
- ✅ Настраивает Ollama и загружает нужные модели
- ✅ Создает все необходимые конфигурации
- ✅ Настраивает systemd сервисы
- ✅ Устанавливает альтернативы для скриншотов

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

### Команды и примеры использования

📖 **Подробное руководство по командам и примеры игровых действий:** [docs/usage_examples.md](docs/usage_examples.md)

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

### ️ Исправление сервисов

#### Проблемы с сервисом Ollama

Если после перезагрузки Steam Deck команда `sudo systemctl start ollama` не работает:

```bash
cd ~/disco_coop
./install.sh --clean
```

**Команда исправляет:**
- ❌ Отсутствующий файл `ollama.service`  
- ❌ Неправильные права доступа
- ❌ Неверный путь к исполняемому файлу
- ❌ Проблемы с автозапуском

#### Проблемы с сервисом бота

Если бот не запускается как сервис или работает нестабильно:

```bash
cd ~/disco_coop  
./install.sh --clean
```

**Команда исправляет:**
- ❌ Отсутствующий файл `disco-coop.service`
- ❌ Поврежденное виртуальное окружение
- ❌ Отсутствующие зависимости Python
- ❌ Неправильные пути в сервисе
- ❌ Проблемы с конфигурацией

#### Проблемы с keyring и скриншотами

Если при установке появляются ошибки `keyring is not writable`, `required key missing from keyring`, или не работают скриншоты:

```bash
cd ~/disco_coop
./install.sh --test
```

**Команда проверяет и исправляет:**
- ❌ Испорченный keyring pacman
- ❌ Отсутствующие PGP ключи SteamOS
- ❌ Неправильные права доступа к keyring
- ❌ Проблемы с подписями пакетов
- ❌ Проблемы со скриншотами

#### Проблемы со скриншотами

Если команда `/describe` выдает ошибки или не работает:

```bash
cd ~/disco_coop
./install.sh --test
```

**Команда проверяет и исправляет:**
- ❌ Проблемы с инструментами скриншотов
- ❌ Права доступа к X сессии
- ❌ Конфигурацию системы скриншотов
- ❌ Все зависимости проекта

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