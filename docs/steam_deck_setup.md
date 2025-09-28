# Установка и настройка на Steam Deck

Подробное руководство по установке и настройке Disco Coop на Steam Deck.

## Предварительные требования

### 1. Подготовка Steam Deck

1. **Включите режим разработчика:**
   - Зайдите в Desktop Mode (режим рабочего стола)
   - Установите пароль для пользователя deck: `passwd`

2. **Установите Python и зависимости:**
   ```bash
   # Обновляем систему
   sudo pacman -Syu
   
   # Устанавливаем Python и pip
   sudo pacman -S python python-pip git
   
   # Устанавливаем дополнительные зависимости для GUI
   sudo pacman -S tk xdotool imagemagick
   ```

### 2. Установка Ollama

```bash
# Скачиваем и устанавливаем Ollama
curl -fsSL https://ollama.ai/install.sh | sh

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
git clone <repository-url> disco_coop
cd disco_coop
```

### 2. Создание виртуального окружения

```bash
python -m venv venv
source venv/bin/activate
```

### 3. Установка зависимостей

```bash
pip install -r requirements.txt
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