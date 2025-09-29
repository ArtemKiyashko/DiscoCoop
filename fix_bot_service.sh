#!/bin/bash

# Скрипт для исправления сервиса Disco Coop бота на Steam Deck

set -e

echo "🤖 Исправление сервиса Disco Coop бота"
echo "======================================"

# Определяем директорию проекта
PROJECT_DIR="$HOME/disco_coop"

if [ ! -d "$PROJECT_DIR" ]; then
    echo "❌ Директория проекта не найдена: $PROJECT_DIR"
    echo "Сначала установите Disco Coop:"
    echo "curl -fsSL https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh | bash"
    exit 1
fi

cd "$PROJECT_DIR"
echo "✅ Рабочая директория: $PROJECT_DIR"

# Проверяем виртуальное окружение
VENV_PYTHON="$PROJECT_DIR/venv/bin/python"
if [ ! -f "$VENV_PYTHON" ]; then
    echo "❌ Виртуальное окружение не найдено: $VENV_PYTHON"
    echo "Пересоздаем виртуальное окружение..."
    
    rm -rf venv
    python3 -m venv venv --system-site-packages
    
    # Устанавливаем зависимости
    echo "📦 Установка зависимостей..."
    "$VENV_PYTHON" -m pip install --upgrade pip
    "$VENV_PYTHON" -m pip install -r requirements.txt
fi

echo "✅ Виртуальное окружение готово"

# Проверяем main.py
MAIN_SCRIPT="$PROJECT_DIR/main.py"
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "❌ Основной скрипт не найден: $MAIN_SCRIPT"
    exit 1
fi

echo "✅ Основной скрипт найден"

# Проверяем конфигурацию
CONFIG_FILE="$PROJECT_DIR/config/config.yaml"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  Файл конфигурации не найден: $CONFIG_FILE"
    if [ -f "$PROJECT_DIR/config/config.example.yaml" ]; then
        echo "📝 Создаем config.yaml из примера..."
        cp "$PROJECT_DIR/config/config.example.yaml" "$CONFIG_FILE"
        echo "❗ ВАЖНО: Отредактируйте $CONFIG_FILE с вашими настройками!"
    else
        echo "❌ Файл примера конфигурации не найден!"
        exit 1
    fi
fi

echo "✅ Конфигурация найдена"

# Проверяем зависимости
echo "🔍 Проверка зависимостей Python..."
if ! "$VENV_PYTHON" -c "import telegram, asyncio, yaml, loguru" 2>/dev/null; then
    echo "📦 Переустановка зависимостей..."
    "$VENV_PYTHON" -m pip install -r requirements.txt
fi

echo "✅ Зависимости Python готовы"

# Останавливаем существующий сервис если он есть
if systemctl is-active --quiet disco-coop.service; then
    echo "🛑 Останавливаем существующий сервис..."
    sudo systemctl stop disco-coop.service
fi

# Удаляем старый сервис если есть
if [ -f "/etc/systemd/system/disco-coop.service" ]; then
    echo "🗑️  Удаляем старый сервис..."
    sudo rm -f /etc/systemd/system/disco-coop.service
fi

# Создаем новый systemd сервис
echo "📝 Создание systemd сервиса для Disco Coop..."
sudo tee /etc/systemd/system/disco-coop.service > /dev/null << EOF
[Unit]
Description=Disco Coop Telegram Bot
After=network-online.target ollama.service
Wants=network-online.target
Requires=ollama.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=deck
Group=deck
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin
Environment=HOME=/home/deck
ExecStart=$VENV_PYTHON main.py
Restart=always
RestartSec=15
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Проверяем что файл создан
if [ ! -f "/etc/systemd/system/disco-coop.service" ]; then
    echo "❌ Не удалось создать файл сервиса!"
    exit 1
fi

echo "✅ Файл сервиса создан: /etc/systemd/system/disco-coop.service"

# Устанавливаем правильные права
sudo chmod 644 /etc/systemd/system/disco-coop.service
sudo chown root:root /etc/systemd/system/disco-coop.service

# Перезагружаем systemd
echo "🔄 Перезагрузка systemd..."
sudo systemctl daemon-reload

# Включаем автозапуск
echo "🚀 Включение автозапуска..."
sudo systemctl enable disco-coop.service

# Проверяем что Ollama работает
echo "🔍 Проверка зависимости Ollama..."
if ! systemctl is-active --quiet ollama.service; then
    echo "⚠️  Сервис Ollama не запущен, пытаемся запустить..."
    if sudo systemctl start ollama.service; then
        echo "✅ Ollama запущен"
        sleep 5
    else
        echo "❌ Не удалось запустить Ollama"
        echo "Запустите сначала: ./fix_ollama_service.sh"
        exit 1
    fi
fi

# Запускаем сервис бота
echo "▶️  Запуск сервиса бота..."
sudo systemctl start disco-coop.service

# Проверяем статус
echo "📊 Проверка статуса сервиса..."
sleep 5

if systemctl is-active --quiet disco-coop.service; then
    echo "✅ Сервис Disco Coop запущен успешно!"
    
    # Показываем последние логи
    echo ""
    echo "📋 Последние логи:"
    journalctl -u disco-coop.service -n 10 --no-pager
    
    echo ""
    echo "🎉 Сервис бота настроен!"
    echo "📋 Полезные команды:"
    echo "   sudo systemctl status disco-coop    # Проверить статус"
    echo "   sudo systemctl restart disco-coop   # Перезапустить"
    echo "   journalctl -u disco-coop -f         # Посмотреть логи"
    echo "   ./start.sh                          # Запуск в консоли (для отладки)"
    
else
    echo "❌ Не удалось запустить сервис!"
    echo "📋 Диагностика:"
    sudo systemctl status disco-coop.service --no-pager
    echo ""
    echo "📝 Попробуйте посмотреть логи:"
    echo "   journalctl -u disco-coop -n 20"
    echo ""
    echo "🛠️  Или запустите бота в консоли для отладки:"
    echo "   ./start.sh"
    exit 1
fi