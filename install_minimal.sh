#!/bin/bash

# Минимальный скрипт для самых проблемных Steam Deck

echo "🎮 Disco Coop - Минимальная установка"
echo "===================================="
echo "📅 $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

REPOSITORY_URL="https://github.com/ArtemKiyashko/DiscoCoop.git"
PROJECT_DIR="$HOME/disco_coop"

# Клонируем репозиторий
echo "📥 Клонирование репозитория..."
if [ -d "$PROJECT_DIR" ]; then
    cd "$PROJECT_DIR"
    git pull || true
else
    cd "$HOME"
    git clone "$REPOSITORY_URL" disco_coop
    cd disco_coop
fi

# Используем только переносимый Python
echo "🐍 Установка переносимого Python..."
cd /tmp

if [ ! -d "$HOME/python" ]; then
    echo "📥 Загрузка Python..."
    curl -L https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz -o python.tar.gz
    tar -xzf python.tar.gz -C "$HOME"
    rm python.tar.gz
fi

cd "$PROJECT_DIR"

# Настройка путей
export PATH="$HOME/python/bin:$PATH"
echo 'export PATH="$HOME/python/bin:$PATH"' >> ~/.bashrc

# Создание venv
echo "🐍 Создание виртуальной среды..."
"$HOME/python/bin/python3" -m venv venv
source venv/bin/activate

# Установка только критически важных пакетов
echo "📦 Установка основных пакетов..."
pip install --upgrade pip
pip install python-telegram-bot==20.7
pip install aiohttp==3.9.1  
pip install pyyaml==6.0.1
pip install loguru==0.7.2
pip install Pillow==10.1.0

echo "🤖 Проверка Ollama..."
if ! command -v ollama &> /dev/null; then
    echo "📥 Установка Ollama..."
    curl -fsSL https://ollama.ai/install.sh | sh
fi

# Запуск Ollama в фоне
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "🚀 Запуск Ollama..."
    nohup ollama serve > /dev/null 2>&1 &
    sleep 5
fi

# Конфигурация
echo "⚙️  Настройка..."
if [ ! -f "config/config.yaml" ]; then
    cp config/config.example.yaml config/config.yaml
fi

mkdir -p logs

# Скрипт запуска
cat > run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
export PATH="$HOME/python/bin:$PATH"
source venv/bin/activate

# Запуск Ollama если не запущен
if ! pgrep -f "ollama serve" > /dev/null; then
    nohup ollama serve > /dev/null 2>&1 &
    sleep 3
fi

python main.py
EOF
chmod +x run.sh

echo ""
echo "✅ Минимальная установка завершена!"
echo ""
echo "📝 Что нужно сделать:"
echo "1. Отредактируйте config/config.yaml"
echo "2. Запустите: ./run.sh"
echo ""
echo "📥 Загрузка моделей (выполните вручную):"
echo "ollama pull llama3.1:8b"
echo "ollama pull llava:7b"
echo ""
echo "🎮 Не забудьте запустить Disco Elysium!"