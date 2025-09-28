#!/bin/bash

# Скрипт запуска Disco Coop Bot
# Совместимость с python-telegram-bot 13.15

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
if not version.startswith('13.'):
    print('')
    print('❌ КРИТИЧЕСКАЯ ОШИБКА: Неправильная версия python-telegram-bot!')
    print('   Ожидается: 13.15, найдена:', version)
    print('')
    print('� Для исправления запустите:')
    print('   ./fix_pynput.sh')
    print('')
    import sys
    sys.exit(1)
else:
    print('✅ Версия telegram бота корректная')
"

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