#!/bin/bash

# Упрощенный скрипт установки Disco Coop для проблемных Steam Deck

set -e

echo "🎮 Disco Coop - Упрощенная установка для Steam Deck"
echo "================================================="
echo "📅 Версия скрипта: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# URL репозитория
REPOSITORY_URL="https://github.com/ArtemKiyashko/DiscoCoop.git"

# Проверка Desktop Mode
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
    git pull || echo "⚠️  Не удалось обновить, продолжаем..."
else
    echo "📥 Клонирование репозитория..."
    cd "$HOME"
    git clone "$REPOSITORY_URL" disco_coop
    cd disco_coop
fi

echo "🐍 Установка переносимой версии Python..."

# Пропускаем pacman полностью и сразу устанавливаем Python
if ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
    echo "📥 Загрузка Python 3.11..."
    cd /tmp
    
    if curl -L https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz -o python.tar.gz; then
        echo "📂 Распаковка Python..."
        tar -xzf python.tar.gz -C "$HOME"
        
        # Создаем симлинки
        ln -sf "$HOME/python/bin/python3" "$HOME/python/bin/python" 2>/dev/null || true
        
        export PATH="$HOME/python/bin:$PATH"
        
        # Добавляем в shell профили
        echo 'export PATH="$HOME/python/bin:$PATH"' >> ~/.bashrc
        echo 'export PATH="$HOME/python/bin:$PATH"' >> ~/.profile
        
        cd "$PROJECT_DIR"
        echo "✅ Python установлен в $HOME/python"
    else
        echo "❌ Не удалось загрузить Python. Проверьте подключение к интернету."
        exit 1
    fi
else
    echo "✅ Python уже установлен"
fi

# Проверяем pip
if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
    echo "📦 Установка pip..."
    if command -v python3 &> /dev/null; then
        python3 -m ensurepip --default-pip --user
    elif command -v python &> /dev/null; then
        python -m ensurepip --default-pip --user
    fi
fi

# Создание виртуального окружения
echo "🐍 Создание виртуального окружения..."
python3 -m venv venv || python -m venv venv
source venv/bin/activate

# Установка Python зависимостей
echo "📚 Установка Python пакетов..."
pip install --upgrade pip

# Используем минимальные зависимости
echo "🔄 Установка минимальных зависимостей..."
if pip install -r requirements-minimal.txt; then
    echo "✅ Минимальные зависимости установлены"
else
    echo "📦 Установка пакетов по одному..."
    pip install python-telegram-bot aiohttp pyyaml loguru Pillow requests
fi

# Установка и настройка Ollama
echo "🤖 Установка Ollama..."
if ! command -v ollama &> /dev/null; then
    curl -fsSL https://ollama.ai/install.sh | sh
    
    # Запускаем Ollama в фоне
    nohup ollama serve > /dev/null 2>&1 &
    
    # Ждем запуска
    echo "⏳ Ожидание запуска Ollama..."
    sleep 10
    
    # Загрузка моделей
    echo "📥 Загрузка моделей ИИ..."
    ollama pull llama3.1:8b &
    ollama pull llava:7b &
    wait
else
    echo "✅ Ollama уже установлен"
fi

# Создание конфигурации
echo "⚙️  Настройка конфигурации..."
if [ ! -f "config/config.yaml" ]; then
    cp config/config.example.yaml config/config.yaml
    echo "📝 Создан файл конфигурации config/config.yaml"
fi

# Создание папки для логов
mkdir -p logs

# Создание скрипта запуска
echo "📜 Создание скрипта запуска..."
cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate
export PATH="$HOME/python/bin:$PATH"
python main.py
EOF
chmod +x start.sh

echo ""
echo "🎉 Упрощенная установка завершена!"
echo ""
echo "📋 Следующие шаги:"
echo "1. Отредактируйте config/config.yaml с вашими настройками Telegram"
echo "2. Запустите: ./start.sh"
echo ""
echo "❗ Важно:"
echo "- Настройте Telegram бота (@BotFather)"
echo "- Добавьте bot token и chat IDs в config.yaml"
echo "- Запустите Disco Elysium перед использованием"
echo ""
echo "📖 Документация: docs/steam_deck_setup.md"