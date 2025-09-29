#!/bin/bash

# Скрипт для исправления проблем со скриншотами на Steam Deck

set -e

echo "🖼️  Исправление системы скриншотов"
echo "================================="

# Проверяем наличие необходимых команд
echo "🔍 Проверка необходимых команд..."

MISSING_COMMANDS=""

# Проверяем convert (ImageMagick)
if ! command -v convert &> /dev/null; then
    echo "❌ convert (ImageMagick) не найден"
    MISSING_COMMANDS="$MISSING_COMMANDS imagemagick"
else
    echo "✅ convert (ImageMagick) найден"
fi

# Проверяем xwd
if ! command -v xwd &> /dev/null; then
    echo "❌ xwd не найден"  
    MISSING_COMMANDS="$MISSING_COMMANDS xorg-xwd"
else
    echo "✅ xwd найден"
fi

# Проверяем xdotool (полезно для работы с окнами)
if ! command -v xdotool &> /dev/null; then
    echo "❌ xdotool не найден"
    MISSING_COMMANDS="$MISSING_COMMANDS xdotool"
else
    echo "✅ xdotool найден"
fi

# Устанавливаем недостающие пакеты
if [ ! -z "$MISSING_COMMANDS" ]; then
    echo ""
    echo "📦 Установка недостающих пакетов: $MISSING_COMMANDS"
    
    # Разблокируем файловую систему
    echo "🔓 Разблокировка файловой системы Steam Deck..."
    sudo steamos-readonly disable 2>/dev/null || true
    
    # Обновляем базу пакетов
    echo "📥 Обновление базы пакетов..."
    sudo pacman -Sy --noconfirm 2>/dev/null || true
    
    # Устанавливаем пакеты
    echo "📦 Установка пакетов..."
    if timeout 300 bash -c "yes 'y' | sudo pacman -S --needed $MISSING_COMMANDS"; then
        echo "✅ Пакеты установлены успешно"
    else
        echo "❌ Не удалось установить пакеты через pacman"
        echo ""
        echo "🛠️  Альтернативные решения:"
        echo "1. Попробуйте запустить команды вручную:"
        echo "   sudo steamos-readonly disable"
        echo "   sudo pacman -Sy"
        echo "   sudo pacman -S imagemagick xorg-xwd xdotool"
        echo "   sudo steamos-readonly enable"
        echo ""
        echo "2. Или используйте Flatpak версию ImageMagick:"
        echo "   flatpak install --user flathub org.imagemagick.ImageMagick"
        echo ""
        echo "3. Если проблемы с правами, попробуйте:"
        echo "   sudo passwd deck  # Установите пароль для пользователя deck"
        
        # Возвращаем файловую систему в read-only
        sudo steamos-readonly enable 2>/dev/null || true
        exit 1
    fi
    
    # Возвращаем файловую систему в read-only
    echo "🔒 Возвращение файловой системы в read-only режим..."
    sudo steamos-readonly enable 2>/dev/null || true
    
else
    echo "✅ Все необходимые команды найдены"
fi

echo ""
echo "🧪 Тестирование системы скриншотов..."

# Проверяем X11 сессию
if [ -z "$DISPLAY" ]; then
    echo "❌ Переменная DISPLAY не установлена"
    echo "💡 Убедитесь что вы в Desktop Mode с графической сессией"
    exit 1
else
    echo "✅ DISPLAY установлен: $DISPLAY"
fi

# Проверяем доступность X сервера
if ! xdpyinfo &>/dev/null; then
    echo "❌ X сервер недоступен"
    echo "💡 Убедитесь что вы в Desktop Mode"
    exit 1
else
    echo "✅ X сервер доступен"
fi

# Тестируем создание скриншота
echo "📸 Тестирование создания скриншота..."
TEMP_FILE="/tmp/screenshot_test_$(date +%s).png"

# Пробуем метод с xwd + convert
if command -v xwd &>/dev/null && command -v convert &>/dev/null; then
    echo "🔄 Пробуем метод xwd + convert..."
    if timeout 10 bash -c "xwd -root | convert xwd:- '$TEMP_FILE'" 2>/dev/null; then
        if [ -f "$TEMP_FILE" ] && [ -s "$TEMP_FILE" ]; then
            echo "✅ Скриншот создан успешно: $TEMP_FILE"
            echo "📏 Размер файла: $(du -h "$TEMP_FILE" | cut -f1)"
            
            # Проверяем что это действительно изображение
            if command -v file &>/dev/null; then
                FILE_TYPE=$(file "$TEMP_FILE")
                echo "📋 Тип файла: $FILE_TYPE"
            fi
            
            # Удаляем тестовый файл
            rm -f "$TEMP_FILE"
        else
            echo "❌ Файл скриншота пуст или не создан"
        fi
    else
        echo "❌ Не удалось создать скриншот методом xwd + convert"
    fi
else
    echo "❌ Команды xwd или convert недоступны"
fi

# Проверяем альтернативные методы
echo ""
echo "🔍 Проверка альтернативных методов скриншотов..."

# gnome-screenshot
if command -v gnome-screenshot &>/dev/null; then
    echo "✅ gnome-screenshot доступен"
elif command -v spectacle &>/dev/null; then
    echo "✅ spectacle (KDE) доступен"
elif command -v scrot &>/dev/null; then
    echo "✅ scrot доступен"
else
    echo "⚠️  Альтернативные инструменты скриншотов не найдены"
fi

# Проверяем Python пакеты для скриншотов
echo ""
echo "🐍 Проверка Python пакетов для скриншотов..."

# Активируем виртуальное окружение если есть
if [ -f "$HOME/disco_coop/venv/bin/activate" ]; then
    source "$HOME/disco_coop/venv/bin/activate"
    echo "✅ Виртуальное окружение активировано"
fi

# Проверяем пакеты
python3 -c "
import sys
try:
    from PIL import ImageGrab
    print('✅ PIL.ImageGrab доступен')
except ImportError:
    print('❌ PIL.ImageGrab недоступен')

try:
    import pyautogui
    print('✅ pyautogui доступен')
except ImportError:
    print('❌ pyautogui недоступен')

try:
    import pyscreenshot
    print('✅ pyscreenshot доступен')  
except ImportError:
    print('⚠️  pyscreenshot недоступен (можно установить)')
" 2>/dev/null

echo ""
echo "🎉 Диагностика завершена!"
echo ""
echo "📋 Следующие шаги:"
echo "=================="

if [ -z "$MISSING_COMMANDS" ]; then
    echo "✅ Все системные команды установлены"
    echo "✅ Попробуйте запустить бота еще раз"
    echo ""
    echo "Если проблемы продолжаются:"
    echo "1. Убедитесь что вы в Desktop Mode"
    echo "2. Проверьте что Disco Elysium запущен"
    echo "3. Попробуйте команду: ./start.sh"
else
    echo "❌ Некоторые команды отсутствуют"
    echo "💡 Запустите этот скрипт еще раз с правами администратора"
fi

echo ""
echo "🛠️  Полезные команды для отладки:"
echo "   echo \$DISPLAY                    # Проверить DISPLAY"
echo "   xdpyinfo | head                  # Информация о X сервере"
echo "   xwd -root | convert xwd:- test.png # Тест скриншота"
echo "   python3 -c \"from PIL import ImageGrab; ImageGrab.grab().save('test.png')\" # Тест Python"