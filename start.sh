#!/bin/bash

# Скрипт запуска Disco Coop Bot
# Совместимость с новой архитектурой install.sh

set -e

echo "🎮 Запуск Disco Coop Bot..."

# Переходим в директорию проекта
cd "$(dirname "$0")"

# Переменные путей (совместимо с install.sh)
PYTHON_DIR="$HOME/python"
OLLAMA_DIR="$HOME/.local/share/ollama"
LOCAL_BIN="$HOME/.local/bin"

# Функции для логирования
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1"
}

# Проверяем наличие конфигурации
if [ ! -f "config/config.yaml" ]; then
    log_error "Файл config/config.yaml не найден!"
    echo "📝 Создайте конфигурацию:"
    echo "   cp config/config.example.yaml config/config.yaml"
    echo "   nano config/config.yaml  # настройте Telegram bot token и chat IDs"
    exit 1
fi

# Определяем Python
PYTHON_CMD=""
if [ -x "$PYTHON_DIR/bin/python3" ]; then
    PYTHON_CMD="$PYTHON_DIR/bin/python3"
    export PATH="$PYTHON_DIR/bin:$LOCAL_BIN:$PATH"
    log_info "Используем портативный Python: $PYTHON_CMD"
elif command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
    log_info "Используем системный Python: $PYTHON_CMD"
else
    log_error "Python не найден!"
    echo "� Запустите установку: ./install.sh"
    exit 1
fi

# Проверяем Ollama
log_info "Проверка Ollama сервера..."
if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    log_error "Ollama сервер недоступен!"
    echo "🚀 Запустите Ollama:"
    if [ -x "$OLLAMA_DIR/bin/ollama" ]; then
        echo "   $OLLAMA_DIR/bin/ollama serve &"
    elif command -v ollama &> /dev/null; then
        echo "   ollama serve &" 
    else
        echo "� Запустите установку: ./install.sh"
        exit 1
    fi
    echo "   Или как сервис: systemctl --user start ollama"
    exit 1
else
    log_success "Ollama сервер доступен"
fi

# Проверяем установленные пакеты
log_info "Проверка зависимостей..."
$PYTHON_CMD -c "
import sys
try:
    import telegram
    print('✅ python-telegram-bot найден')
    
    # Проверяем версию
    version = telegram.__version__
    major_version = int(version.split('.')[0])
    if major_version < 20:
        print(f'❌ Устаревшая версия telegram: {version}')
        sys.exit(1)
    else:
        print(f'✅ Версия telegram корректная: {version}')
        
except ImportError as e:
    print(f'❌ Отсутствует telegram: {e}')
    sys.exit(1)

try:
    import aiohttp
    print('✅ aiohttp найден')
except ImportError:
    print('❌ Отсутствует aiohttp')
    sys.exit(1)

try:
    from PIL import Image
    print('✅ Pillow найден')
except ImportError:
    print('❌ Отсутствует Pillow')
    sys.exit(1)

try:
    import dotenv
    print('✅ python-dotenv найден')
except ImportError:
    print('❌ Отсутствует python-dotenv')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    log_error "Не хватает зависимостей!"
    echo "💡 Запустите установку: ./install.sh"
    exit 1
fi

# Проверяем опциональные зависимости
log_info "Проверка игрового контроллера..."
$PYTHON_CMD -c "
try:
    import pyautogui
    import pynput
    print('✅ Игровой контроллер доступен')
except ImportError as e:
    print(f'⚠️  Игровой контроллер недоступен: {e}')
    print('💡 Для полной функциональности запустите: ./install.sh')
" || true

echo ""
log_success "Все проверки пройдены! Запускаем бота..."
echo "🛑 Для остановки нажмите Ctrl+C"
echo ""

# Запускаем бота
exec $PYTHON_CMD main.py