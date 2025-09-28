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

echo "🤖 Установка Ollama..."
if ! command -v ollama &> /dev/null; then
    echo "📥 Установка Ollama в пользовательскую директорию..."
    
    # Создаем директорию для Ollama
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.ollama"
    
    # Определяем архитектуру и версию
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        OLLAMA_VERSION="v0.12.3"
        OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tgz"
    else
        echo "❌ Неподдерживаемая архитектура: $ARCH"
        exit 1
    fi
    
    # Скачиваем и устанавливаем Ollama
    echo "📥 Загрузка Ollama ${OLLAMA_VERSION}..."
    if curl -L "$OLLAMA_URL" -o "/tmp/ollama.tgz"; then
        echo "📦 Распаковка архива..."
        
        # Создаем временную директорию
        mkdir -p /tmp/ollama_extract
        
        if tar -xzf /tmp/ollama.tgz -C /tmp/ollama_extract; then
            # Ищем исполняемый файл
            if [ -f "/tmp/ollama_extract/bin/ollama" ]; then
                cp "/tmp/ollama_extract/bin/ollama" "$HOME/.local/bin/ollama"
            elif [ -f "/tmp/ollama_extract/ollama" ]; then
                cp "/tmp/ollama_extract/ollama" "$HOME/.local/bin/ollama"
            else
                echo "❌ Не найден исполняемый файл в архиве"
                rm -rf /tmp/ollama_extract /tmp/ollama.tgz
                exit 1
            fi
            
            # Проверяем корректность файла
            if file "$HOME/.local/bin/ollama" | grep -q "ELF.*executable"; then
                chmod +x "$HOME/.local/bin/ollama"
                
                # Добавляем в PATH
                export PATH="$HOME/.local/bin:$PATH"
                if ! grep -q "export PATH.*\.local/bin" ~/.bashrc; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                fi
                
                echo "✅ Ollama установлен в $HOME/.local/bin/ollama"
            else
                echo "❌ Файл не является исполняемым"
                rm -f "$HOME/.local/bin/ollama"
                exit 1
            fi
            
            # Очищаем временные файлы
            rm -rf /tmp/ollama_extract /tmp/ollama.tgz
        else
            echo "❌ Не удалось распаковать архив"
            rm -f /tmp/ollama.tgz
            exit 1
        fi
    else
        echo "❌ Не удалось загрузить Ollama"
        exit 1
    fi
else
    echo "✅ Ollama уже установлен"
fi

# Запуск Ollama в фоне
if ! pgrep -f "ollama serve" > /dev/null; then
    echo "🚀 Запуск Ollama..."
    # Проверяем, что Ollama доступна
    if command -v ollama &> /dev/null; then
        nohup ollama serve > /dev/null 2>&1 &
    elif [ -f "$HOME/.local/bin/ollama" ]; then
        export PATH="$HOME/.local/bin:$PATH"
        nohup "$HOME/.local/bin/ollama" serve > /dev/null 2>&1 &
    else
        echo "❌ Ollama не найдена"
        exit 1
    fi
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
    if command -v ollama &> /dev/null; then
        nohup ollama serve > /dev/null 2>&1 &
    elif [ -f "$HOME/.local/bin/ollama" ]; then
        export PATH="$HOME/.local/bin:$PATH"
        nohup "$HOME/.local/bin/ollama" serve > /dev/null 2>&1 &
    fi
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