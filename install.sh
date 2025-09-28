#!/bin/bash

# Скрипт быстрой установки Disco Coop на Steam Deck

set -e  # Остановка при ошибке

# URL репозитория
REPOSITORY_URL="https://github.com/ArtemKiyashko/DiscoCoop.git"

echo "🎮 Disco Coop - Установка на Steam Deck"
echo "========================================"
echo "📅 Версия скрипта: $(date '+%Y-%m-%d %H:%M:%S')"
echo "🔗 Репозиторий: $REPOSITORY_URL"
echo ""

# Проверка что мы в Desktop Mode (только для Steam Deck)
if [ -f "/etc/steamos-release" ] && [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
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

# Проверяем, работает ли pacman
if command -v pacman &> /dev/null; then
    echo "🔓 Разблокировка файловой системы Steam Deck..."
    sudo steamos-readonly disable 2>/dev/null || true
    
    echo "🔑 Настройка keyring для SteamOS..."
    sudo pacman-key --init 2>/dev/null || true
    sudo pacman-key --populate archlinux 2>/dev/null || true
    
    # Добавляем ключи SteamOS
    echo "� Добавление ключей SteamOS..."
    sudo pacman-key --recv-keys 3056513887B78AEB 2>/dev/null || true
    sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
    
    echo "�📥 Обновление базы данных пакетов..."
    sudo pacman -Sy --noconfirm
    
    echo "📦 Установка пакетов..."
    # Пробуем установить с игнорированием подписей для SteamOS пакетов
    if ! sudo pacman -S --needed --noconfirm python python-pip git tk xdotool imagemagick 2>/dev/null; then
        echo "⚠️  Обычная установка не удалась, пробуем без проверки подписей..."
        sudo pacman -S --needed --noconfirm --disable-download-timeout python python-pip git 2>/dev/null || {
            echo "❌ Не удается установить через pacman, переходим к альтернативному методу..."
            return 1
        }
    fi
    
    echo "🔒 Возвращение файловой системы в read-only режим..."
    sudo steamos-readonly enable 2>/dev/null || true
else
    echo "⚠️  pacman недоступен или не работает, используем альтернативные методы..."
fi

# Проверяем наличие Python независимо от успеха pacman
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo "� Python не найден, устанавливаем переносимую версию..."
    cd /tmp
    
    # Загружаем переносимую версию Python
    echo "📥 Загрузка Python 3.11..."
    if curl -L https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz -o python.tar.gz; then
        echo "📂 Распаковка Python..."
        tar -xzf python.tar.gz -C "$HOME"
        
        # Создаем симлинки для удобства
        ln -sf "$HOME/python/bin/python3" "$HOME/python/bin/python" 2>/dev/null || true
        
        export PATH="$HOME/python/bin:$PATH"
        
        # Добавляем в bashrc и profile
        echo 'export PATH="$HOME/python/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/python/bin:$PATH"' >> ~/.profile
        
        cd "$PROJECT_DIR"
        echo "✅ Python установлен в $HOME/python"
    else
        echo "❌ Не удалось загрузить Python. Проверьте подключение к интернету."
        exit 1
    fi
fi

# Проверяем pip
if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
    echo "📦 pip не найден, устанавливаем..."
    if command -v python3 &> /dev/null; then
        python3 -m ensurepip --default-pip --user
    elif command -v python &> /dev/null; then
        python -m ensurepip --default-pip --user
    else
        # Загружаем get-pip.py
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python3 get-pip.py --user || python get-pip.py --user
        rm get-pip.py
    fi
fi

# Создание виртуального окружения
echo "🐍 Создание виртуального окружения..."
python -m venv venv
source venv/bin/activate

# Установка Python зависимостей
echo "📚 Установка Python пакетов..."
pip install --upgrade pip

# Проверяем, работает ли полная установка
echo "🔄 Попытка установки всех зависимостей..."
if pip install -r requirements.txt; then
    echo "✅ Все зависимости установлены успешно"
else
    echo "⚠️  Ошибка при установке полных зависимостей, используем минимальный набор..."
    pip install -r requirements-minimal.txt
    
    echo "📦 Попытка установки дополнительных зависимостей..."
    pip install --user opencv-python-headless || echo "⚠️  OpenCV пропущен"
    pip install --user PyAutoGUI || echo "⚠️  PyAutoGUI пропущен"
    pip install --user pynput || echo "⚠️  pynput пропущен"
    pip install --user numpy || echo "⚠️  numpy пропущен"
fi

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