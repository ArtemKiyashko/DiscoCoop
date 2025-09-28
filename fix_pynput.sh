#!/bin/bash
# Скрипт для исправления проблем с зависимостями на Steam Deck

cd "$(dirname "$0")"

echo "🔧 Исправление проблем с зависимостями..."

# Исправляем версию python-telegram-bot
echo "📦 Исправление версии python-telegram-bot..."
pip uninstall -y python-telegram-bot
pip install python-telegram-bot==13.15

# Устанавливаем отсутствующие зависимости
echo "📦 Установка зависимости 'six'..."
pip install six --no-cache-dir

echo "📦 Проверка pynput..."
if python -c "import pynput; print('✅ pynput работает')"; then
    echo "✅ Проблема исправлена!"
else
    echo "⚠️  Переустанавливаем pynput..."
    pip uninstall pynput -y
    pip install pynput --no-cache-dir || echo "❌ Не удалось переустановить pynput"
fi

echo "🧪 Тестирование импорта..."
python -c "
try:
    from src.game.controller import GameController
    print('✅ GameController импортируется успешно')
except ImportError as e:
    print(f'❌ Ошибка импорта: {e}')
except Exception as e:
    print(f'⚠️  Другая ошибка: {e}')
"

echo "✅ Исправление завершено!"
