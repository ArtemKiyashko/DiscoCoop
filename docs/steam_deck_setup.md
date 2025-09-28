# Установка и настройка на Steam Deck

Подробное руководство по установке и настройке Disco Coop на Steam Deck.

## Предварительные требования

### 1. Подготовка Steam Deck

1. **Включите режим разработчика:**
   - Зайдите в Desktop Mode (режим рабочего стола)
   - Установите пароль для пользователя d# 5. Используйте упрощенный скрипт (обходит проблемы с pacman)
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install_simple.sh" | bash

# 6. Используйте специальный скрипт для получения свежих версий
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/get_fresh_scripts.sh" | bash

# 7. Очистите локальный кэш curl (если есть)
rm -rf ~/.cache/curl* 2>/dev/null || true`passwd`

2. **Установите Python и зависимости:**
   
   **⚠️ Важно**: SteamOS имеет read-only файловую систему. Нужно разблокировать её:
   ```bash
   # Переключаем файловую систему в режим записи
   sudo steamos-readonly disable
   
   # Инициализируем keyring для pacman
   sudo pacman-key --init
   sudo pacman-key --populate archlinux
   
   # Обновляем базу данных пакетов (без обновления системы)
   sudo pacman -Sy
   
   # Устанавливаем Python и pip
   sudo pacman -S python python-pip git
   
   # Устанавливаем дополнительные зависимости для GUI
   sudo pacman -S tk xdotool imagemagick
   
   # Возвращаем файловую систему в read-only режим (рекомендуется)
   sudo steamos-readonly enable
   ```
   
   **Альтернативный способ (если pacman не работает):**
   ```bash
   # Используем Flatpak для установки Python (если доступно)
   flatpak install flathub org.freedesktop.Platform.Runtime//22.08
   
   # Или загружаем Python напрямую
   curl -L https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz -o python.tar.gz
   tar -xzf python.tar.gz -C ~/
   export PATH="$HOME/python/bin:$PATH"
   ```

### 2. Установка Ollama

```bash
```bash
### 1. **Быстрый старт на Steam Deck:**
```bash
# Автоматическая установка (с обходом кэша)
curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" \
  "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh?$(date +%s)" | bash

# Альтернативный способ (если кэш всё ещё мешает):
wget -O - --no-cache --no-cookies \
  "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash

# Или скачать и запустить локально:
curl -O "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh"
chmod +x install.sh
./install.sh

# Если получаете ошибки PGP подписей, сначала исправьте pacman:
curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" \
  "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/fix_steamdeck_pacman.sh?$(date +%s)" | bash
```
```

# Запускаем Ollama как сервис
sudo systemctl enable ollama
sudo systemctl start ollama

# Загружаем необходимые модели
ollama pull llama3.1:8b        # Основная модель для команд
ollama pull llava:7b           # Модель для анализа изображений
```

### 3. Настройка Telegram бота

1. **Создание бота:**
   - Откройте Telegram и найдите @BotFather
   - Отправьте `/newbot`
   - Следуйте инструкциям и получите токен

2. **Получение ID чата:**
   - Добавьте бота в групповой чат
   - Отправьте сообщение в чат
   - Перейдите по ссылке: `https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates`
   - Найдите `chat.id` в ответе (будет отрицательное число для групп)

## Установка Disco Coop

### 1. Клонирование репозитория

```bash
cd ~
git clone https://github.com/ArtemKiyashko/DiscoCoop.git disco_coop
cd disco_coop
```

### 2. Создание виртуального окружения

```bash
python -m venv venv
source venv/bin/activate
```

### 3. Установка зависимостей

```bash
# Обновляем pip
pip install --upgrade pip

# Устанавливаем зависимости
pip install -r requirements.txt

# Если возникают проблемы с некоторыми пакетами, устанавливаем их отдельно
pip install --user python-telegram-bot pillow pyyaml loguru aiohttp

# Для Steam Deck может потребоваться установка через --user
pip install --user -r requirements.txt
```

### 4. Настройка конфигурации

```bash
# Копируем пример конфигурации
cp config/config.example.yaml config/config.yaml

# Редактируем конфигурацию
nano config/config.yaml
```

**Основные настройки:**

```yaml
telegram:
  bot_token: "YOUR_BOT_TOKEN_HERE"  # Токен от @BotFather
  allowed_chats:
    - -1001234567890  # ID вашего группового чата
  admin_users:
    - 123456789  # Ваш Telegram user ID

llm:
  base_url: "http://localhost:11434"  # URL Ollama
  model: "llama3.1:8b"
  vision_model: "llava:7b"
```

## Настройка автозапуска

### 1. Создание systemd сервиса

```bash
sudo nano /etc/systemd/system/disco-coop.service
```

Содержимое файла:

```ini
[Unit]
Description=Disco Coop Telegram Bot
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=deck
WorkingDirectory=/home/deck/disco_coop
Environment=PATH=/home/deck/disco_coop/venv/bin
ExecStart=/home/deck/disco_coop/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### 2. Активация сервиса

```bash
sudo systemctl daemon-reload
sudo systemctl enable disco-coop.service
sudo systemctl start disco-coop.service

# Проверка статуса
sudo systemctl status disco-coop.service
```

## Настройка OBS для стриминга

### 1. Установка OBS

```bash
# В Desktop Mode
sudo pacman -S obs-studio
```

### 2. Настройка стрима в Telegram

1. **Создайте видеочат в группе:**
   - Откройте групповой чат в Telegram
   - Нажмите на кнопку видеозвонка
   - Выберите "Поделиться экраном"

2. **Настройка OBS:**
   - Добавьте источник "Захват экрана"
   - Выберите экран с игрой
   - Настройте разрешение 1280x800 для оптимальной производительности

3. **Подключение к Telegram:**
   - В настройках OBS выберите "Настройки стрима"
   - Выберите "Пользовательский RTMP сервер"
   - Используйте ссылку RTMP из Telegram видеочата

## Запуск и тестирование

1. **Запуск Disco Elysium:**
   ```bash
   # Переключитесь в Gaming Mode
   # Запустите Disco Elysium через Steam
   ```

2. **Проверка бота:**
   - Отправьте `/start` в Telegram чат
   - Попробуйте команду `/describe`
   - Отправьте игровую команду: "подойти к двери"

3. **Мониторинг логов:**
   ```bash
   # Просмотр логов сервиса
   sudo journalctl -u disco-coop.service -f
   
   # Просмотр логов приложения
   tail -f logs/disco_coop.log
   ```

## Оптимизация производительности

### 1. Настройки Steam Deck

- **Ограничение FPS:** Установите 30-40 FPS для экономии батареи
- **TDP лимит:** Используйте 10-12W для длительной игры
- **Разрешение:** 1280x800 для оптимальной производительности

### 2. Настройки Ollama

```bash
# Оптимизация для Steam Deck
echo 'OLLAMA_NUM_PARALLEL=1' | sudo tee -a /etc/environment
echo 'OLLAMA_MAX_LOADED_MODELS=2' | sudo tee -a /etc/environment
```

### 3. Настройки игры

В `config/config.yaml`:

```yaml
game:
  screenshot_interval: 2.0  # Увеличиваем интервал
  action_delay: 1.0         # Больше задержка между действиями

llm:
  max_tokens: 1024          # Меньше токенов для быстрого ответа
  temperature: 0.5          # Меньше креативности, больше предсказуемости
```

## Решение проблем

### Проблема: Получение старой версии скрипта установки

**Симптомы:**
- Скрипт не содержит последних исправлений
- Повторяются уже исправленные ошибки
- GitHub показывает обновления, но скрипт их не содержит

**Причина:** Кэширование на стороне curl или CDN GitHub

**Решения:**
```bash
# 1. Используйте команду с обходом кэша
curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" \
  "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh?$(date +%s)" | bash

# 2. Используйте wget вместо curl
wget -O - --no-cache --no-cookies \
  "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh" | bash

# 3. Скачайте файл отдельно и запустите
curl -O "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh"
chmod +x install.sh
./install.sh

# 4. Клонируйте репозиторий напрямую
git clone https://github.com/ArtemKiyashko/DiscoCoop.git
cd DiscoCoop
./install.sh

# 5. Используйте специальный скрипт для получения свежих версий
curl -fsSL "https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/get_fresh_scripts.sh" | bash

# 6. Очистите локальный кэш curl (если есть)
rm -rf ~/.cache/curl* 2>/dev/null || true
```

### Проблема: Ошибки PGP подписей в pacman (Steam Deck)

**Симптомы:** 
- `signature from "GitLab CI Package Builder" is unknown trust`
- `invalid or corrupted package (PGP signature)`

**Решение:**
```bash
# 1. Разблокируем файловую систему
sudo steamos-readonly disable

# 2. Очищаем и переинициализируем keyring
sudo rm -rf /etc/pacman.d/gnupg
sudo pacman-key --init
sudo pacman-key --populate archlinux

# 3. Добавляем ключи SteamOS
sudo pacman-key --recv-keys 3056513887B78AEB
sudo pacman-key --lsign-key 3056513887B78AEB

# 4. Очищаем кеш пакетов
sudo pacman -Scc --noconfirm

# 5. Обновляем базу данных
sudo pacman -Sy

# 6. Пробуем установить пакеты
sudo pacman -S --needed python python-pip git

# 7. Если всё ещё не работает, полностью игнорируем проверку подписей
sudo pacman -S --needed --disable-download-timeout python python-pip git
```

**Альтернативное решение (если pacman совсем не работает):**
```bash
# Используем переносимую версию Python без системных пакетов
cd /tmp
curl -L https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz -o python.tar.gz
tar -xzf python.tar.gz -C ~/
echo 'export PATH="$HOME/python/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Проверяем установку
python3 --version
pip3 --version
```

### Проблема: "steamos-readonly command not found"
Если команда недоступна, значит у вас другой дистрибутив Linux:
```bash
# Используйте обычные команды Linux
sudo apt update && sudo apt install python3 python3-pip git  # Ubuntu/Debian
sudo dnf install python3 python3-pip git  # Fedora
```

### Проблема: Бот не отвечает
```bash
# Проверка статуса
sudo systemctl status disco-coop.service

# Перезапуск
sudo systemctl restart disco-coop.service
```

### Проблема: Ollama недоступен
```bash
# Проверка Ollama
ollama list
ollama serve

# Проверка портов
netstat -tlnp | grep 11434
```

### Проблема: Игра не найдена
- Убедитесь что Disco Elysium запущен
- Проверьте название окна в процессах: `ps aux | grep -i disco`
- Измените `window_title` в конфигурации

### Проблема: Скриншоты не работают
```bash
# Проверка xdotool
xdotool search --name "Disco"

# Права доступа к экрану
xhost +local:
```

## Безопасность

1. **Настройте firewall:**
   ```bash
   sudo ufw enable
   sudo ufw allow from 192.168.1.0/24 to any port 11434  # Только локальная сеть
   ```

2. **Ограничьте доступ к боту:**
   - Используйте белый список чатов
   - Настройте лимиты команд
   - Регулярно проверяйте логи

3. **Резервное копирование:**
   ```bash
   # Создание бэкапа конфигурации
   tar -czf disco_coop_backup.tar.gz config/ logs/
   ```

## Полезные команды

```bash
# Просмотр процессов
htop

# Мониторинг ресурсов
watch -n 1 'free -h && df -h'

# Проверка температуры
sensors

# Управление сервисами
sudo systemctl start/stop/restart disco-coop.service
sudo systemctl start/stop/restart ollama.service
```