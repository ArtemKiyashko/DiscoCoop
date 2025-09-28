#!/bin/bash

# Скрипт запуска Disco Coop Bot
# Совместимость с python-telegram-bot 22.x

set -e

echo "🎮 Запуск Disco Coop Bot..."

# Переходим в директорию проекта
cd "$(dirname "$0")"

# Проверяем наличие конфигурации
if [ ! -f "config.yaml" ]; then
    echo "❌ Файл config.yaml не найден!"
    echo "📝 Скопируйте config.yaml.example в config.yaml и настройте его"
    exit 1
fi

# Проверяем наличие Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 не найден!"
    echo "📦 Установите Python 3.8+ для работы бота"
    exit 1
fi

# Проверяем установленные пакеты
echo "🔍 Проверка зависимостей..."
python3 -c "
import sys
try:
    import telegram
    from loguru import logger
    from src.bot.disco_bot import DiscoCoopBot
    print('✅ Основные зависимости найдены')
except ImportError as e:
    print(f'❌ Отсутствует зависимость: {e}')
    print('📦 Запустите: pip install -r requirements.txt')
    sys.exit(1)
"

if [ $? -ne 0 ]; then
    echo "💡 Попробуйте запустить: ./install.sh"
    exit 1
fi

# Проверяем версию python-telegram-bot
echo "🔍 Проверка версии python-telegram-bot..."
python3 -c "
import telegram
version = telegram.__version__
print(f'📦 Версия python-telegram-bot: {version}')
major_version = int(version.split('.')[0])
if major_version < 22:
    print('')
    print('❌ КРИТИЧЕСКАЯ ОШИБКА: Устаревшая версия python-telegram-bot!')
    print(f'   Ожидается: 22.x, найдена: {version}')
    print('')
    print('🔧 Для исправления запустите:')
    print('   pip install \"python-telegram-bot>=22.0,<23.0\" --upgrade')
    print('')
    import sys
    sys.exit(1)
else:
    print(f'✅ Версия telegram бота корректная: {version}')
"

if [ $? -ne 0 ]; then
    exit 1
fi

# Проверяем опциональные зависимости (для игрового контроллера)
echo "🔍 Проверка игрового контроллера..."
python3 -c "
try:
    from src.game.controller import GameController
    print('✅ GameController доступен')
except ImportError as e:
    print(f'⚠️  GameController недоступен: {e}')
    print('💡 Для полной функциональности установите: pip install pyautogui pynput')
    print('💡 Или запустите: ./fix_pynput.sh')
" || true

echo ""
echo "🚀 Запускаем бота..."
echo "🛑 Для остановки нажмите Ctrl+C"
echo ""

# Запускаем бота
python3 main.py