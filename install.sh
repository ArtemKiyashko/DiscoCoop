#!/bin/bash

# Скрипт быстрой установки Disco Coop на Steam Deck

set -e  # Остановка при ошибке

# URL репозитория
REPOSITORY_URL="https://github.com/ArtemKiyashko/DiscoCoop.git"

echo "🎮 Disco Coop - Установка на Steam Deck"
echo "========================================"

# Проверка что мы в Desktop Mode
if [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    echo "⚠️  Пожалуйста, переключитесь в Desktop Mode для установки"
    exit 1
fi

# Создание директории проекта
PROJECT_DIR="$HOME/disco_coop"
echo "📁 Создание директории проекта в $PROJECT_DIR"

if [ -d "$PROJECT_DIR" ]; then
    echo "⚠️  Директория уже существует. Обновляем..."
    cd "$PROJECT_DIR"
    git pull
else
    echo "📥 Клонирование репозитория..."
    cd "$HOME"
    git clone "$REPOSITORY_URL" disco_coop
    cd disco_coop
fi

# Установка системных зависимостей
echo "📦 Установка системных зависимостей..."
sudo pacman -S --needed python python-pip git tk xdotool imagemagick

# Создание виртуального окружения
echo "🐍 Создание виртуального окружения..."
python -m venv venv
source venv/bin/activate

# Установка Python зависимостей
echo "📚 Установка Python пакетов..."
pip install --upgrade pip
pip install -r requirements.txt

# Установка и настройка Ollama
echo "🤖 Установка Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Настройка systemd сервиса для Ollama
    sudo systemctl enable ollama
    sudo systemctl start ollama
    
    # Ждем запуска Ollama
    echo "⏳ Ожидание запуска Ollama..."
    sleep 10
    
    # Загрузка моделей
    echo "📥 Загрузка моделей ИИ (это может занять некоторое время)..."
    ollama pull llama3.1:8b
    ollama pull llava:7b
else
    echo "✅ Ollama уже установлен"
fi

# Создание конфигурации
echo "⚙️  Настройка конфигурации..."
if [ ! -f "config/config.yaml" ]; then
    cp config/config.example.yaml config/config.yaml
    echo "📝 Создан файл конфигурации config/config.yaml"
    echo "❗ ВАЖНО: Отредактируйте config/config.yaml с вашими настройками!"
fi

# Создание systemd сервиса
echo "🔧 Создание systemd сервиса..."
sudo tee /etc/systemd/system/disco-coop.service > /dev/null << EOF
[Unit]
Description=Disco Coop Telegram Bot
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=deck
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin
ExecStart=$PROJECT_DIR/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и включение сервиса
sudo systemctl daemon-reload
sudo systemctl enable disco-coop.service

# Создание папки для логов
mkdir -p logs

# Создание скрипта запуска
echo "📜 Создание скрипта запуска..."
cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
python main.py
EOF
chmod +x start.sh

# Создание скрипта для ручного тестирования
cat > test.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate

echo "🧪 Тестирование компонентов..."

echo "1. Проверка конфигурации..."
python -c "from src.utils.config import Config; c = Config.load(); c.validate(); print('✅ Конфигурация OK')"

echo "2. Проверка Ollama..."
curl -s http://localhost:11434/api/tags > /dev/null && echo "✅ Ollama доступен" || echo "❌ Ollama недоступен"

echo "3. Проверка моделей..."
ollama list | grep -q "llama3.1:8b" && echo "✅ Модель llama3.1:8b загружена" || echo "❌ Модель llama3.1:8b не найдена"
ollama list | grep -q "llava:7b" && echo "✅ Модель llava:7b загружена" || echo "❌ Модель llava:7b не найдена"

echo "4. Проверка зависимостей..."
python -c "import telegram, PIL, cv2, pyautogui; print('✅ Все зависимости установлены')" 2>/dev/null || echo "❌ Некоторые зависимости отсутствуют"

echo "Тестирование завершено!"
EOF
chmod +x test.sh

echo ""
echo "🎉 Установка завершена!"
echo ""
echo "📋 Следующие шаги:"
echo "1. Отредактируйте config/config.yaml с вашими настройками Telegram"
echo "2. Запустите тест: ./test.sh"
echo "3. Запустите бота: ./start.sh или sudo systemctl start disco-coop.service"
echo ""
echo "📖 Документация:"
echo "- Настройка: docs/steam_deck_setup.md"
echo "- Примеры использования: docs/usage_examples.md"
echo ""
echo "🔍 Полезные команды:"
echo "- Просмотр логов: sudo journalctl -u disco-coop.service -f"
echo "- Статус сервиса: sudo systemctl status disco-coop.service"
echo "- Перезапуск: sudo systemctl restart disco-coop.service"
echo ""
echo "❗ Не забудьте:"
echo "- Настроить Telegram бота (@BotFather)"
echo "- Добавить bot token и chat IDs в config.yaml"
echo "- Запустить Disco Elysium перед использованием"