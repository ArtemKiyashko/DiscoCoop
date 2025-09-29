#!/bin/bash

# Скрипт для исправления сервиса Ollama на Steam Deck

set -e

echo "🔧 Исправление сервиса Ollama"
echo "============================="

# Определяем путь к исполняемому файлу Ollama
OLLAMA_EXEC=""
if command -v ollama &> /dev/null; then
    OLLAMA_EXEC=$(which ollama)
    echo "✅ Ollama найден в системе: $OLLAMA_EXEC"
elif [ -f "$HOME/.local/bin/ollama" ]; then
    OLLAMA_EXEC="$HOME/.local/bin/ollama"
    echo "✅ Ollama найден локально: $OLLAMA_EXEC"
elif [ -f "/usr/local/bin/ollama" ]; then
    OLLAMA_EXEC="/usr/local/bin/ollama"
    echo "✅ Ollama найден в /usr/local/bin: $OLLAMA_EXEC"
else
    echo "❌ Ollama не найден! Сначала установите Ollama:"
    echo "   curl -fsSL https://ollama.ai/install.sh | sh"
    exit 1
fi

# Проверяем что исполняемый файл работает
if ! "$OLLAMA_EXEC" --version &> /dev/null; then
    echo "❌ Ollama найден, но не работает: $OLLAMA_EXEC"
    exit 1
fi

echo "✅ Ollama работает корректно"

# Останавливаем существующий сервис если он есть
if systemctl is-active --quiet ollama.service; then
    echo "🛑 Останавливаем существующий сервис..."
    sudo systemctl stop ollama.service
fi

# Удаляем старый сервис если есть
if [ -f "/etc/systemd/system/ollama.service" ]; then
    echo "🗑️  Удаляем старый сервис..."
    sudo rm -f /etc/systemd/system/ollama.service
fi

# Создаем новый systemd сервис
echo "📝 Создание systemd сервиса для Ollama..."
sudo tee /etc/systemd/system/ollama.service > /dev/null << EOF
[Unit]
Description=Ollama Service
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=deck
Group=deck
ExecStart=$OLLAMA_EXEC serve
Restart=always
RestartSec=10
Environment=OLLAMA_ORIGINS=*
Environment=HOME=/home/deck
WorkingDirectory=/home/deck
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Проверяем что файл создан
if [ ! -f "/etc/systemd/system/ollama.service" ]; then
    echo "❌ Не удалось создать файл сервиса!"
    exit 1
fi

echo "✅ Файл сервиса создан: /etc/systemd/system/ollama.service"

# Устанавливаем правильные права
sudo chmod 644 /etc/systemd/system/ollama.service
sudo chown root:root /etc/systemd/system/ollama.service

# Перезагружаем systemd
echo "🔄 Перезагрузка systemd..."
sudo systemctl daemon-reload

# Включаем автозапуск
echo "🚀 Включение автозапуска..."
sudo systemctl enable ollama.service

# Запускаем сервис
echo "▶️  Запуск сервиса..."
sudo systemctl start ollama.service

# Проверяем статус
echo "📊 Проверка статуса сервиса..."
sleep 3

if systemctl is-active --quiet ollama.service; then
    echo "✅ Сервис Ollama запущен успешно!"
    
    # Проверяем что API отвечает
    echo "🔍 Проверка API..."
    for i in {1..10}; do
        if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo "✅ API Ollama работает!"
            break
        fi
        echo "⏳ Ожидание API... ($i/10)"
        sleep 2
        if [ $i -eq 10 ]; then
            echo "⚠️  API не отвечает, но сервис запущен"
        fi
    done
    
    echo ""
    echo "🎉 Сервис Ollama настроен!"
    echo "📋 Полезные команды:"
    echo "   sudo systemctl status ollama    # Проверить статус"
    echo "   sudo systemctl restart ollama   # Перезапустить"
    echo "   journalctl -u ollama -f         # Посмотреть логи"
    
else
    echo "❌ Не удалось запустить сервис!"
    echo "📋 Диагностика:"
    sudo systemctl status ollama.service
    echo ""
    echo "📝 Попробуйте посмотреть логи:"
    echo "   journalctl -u ollama -n 20"
    exit 1
fi