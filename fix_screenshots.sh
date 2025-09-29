#!/bin/bash

# Комплексный скрипт для исправления проблем со скриншотами на Steam Deck
# Включает исправление keyring и установку всех необходимых пакетов

# Убираем set -e, чтобы скрипт не падал на первой ошибке
# set -e

# Функция для логирования с timestamp
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

# Функция для безопасного выполнения команд
safe_run() {
    local cmd="$1"
    local description="$2"
    
    log "Выполняем: $description"
    if eval "$cmd"; then
        log "✅ Успешно: $description"
        return 0
    else
        local exit_code=$?
        log "❌ Ошибка ($exit_code): $description"
        return $exit_code
    fi
}

echo "🖼️  Комплексное исправление скриншотов"
echo "======================================"
echo "🕐 $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Проверяем, что мы на Steam Deck
if [ -f "/etc/steamos-release" ] && [ "$XDG_CURRENT_DESKTOP" != "KDE" ]; then
    echo "⚠️  Пожалуйста, переключитесь в Desktop Mode для выполнения этого скрипта"
    exit 1
fi

# Показываем информацию о системе для отладки
echo "🔍 Информация о системе:"
echo "   Desktop: ${XDG_CURRENT_DESKTOP:-не установлен}"
echo "   User: $(whoami)"
echo "   PWD: $(pwd)"
echo ""

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

# Функция для исправления keyring
fix_keyring() {
    echo ""
    echo "🔧 ==============================="
    echo "🔧 Исправление keyring pacman"
    echo "🔧 ==============================="
    echo ""
    
    echo "🛑 Остановка сервисов..."
    sudo systemctl stop pacman-init.service 2>/dev/null || true
    
    echo "🧹 Очистка поврежденного keyring..."
    sudo rm -rf /etc/pacman.d/gnupg
    sudo rm -rf /var/lib/pacman/sync/*
    
    # Также очищаем кэш пакетов
    sudo rm -rf /var/cache/pacman/pkg/*
    
    echo "🔧 Исправление прав доступа..."
    sudo mkdir -p /etc/pacman.d/gnupg
    sudo chown -R root:root /etc/pacman.d/gnupg/
    sudo chmod -R 755 /etc/pacman.d/gnupg/
    
    echo "🔑 Инициализация нового keyring..."
    if ! sudo pacman-key --init; then
        echo "❌ Не удалось инициализировать keyring"
        return 1
    fi
    
    echo "📦 Заполнение ключами Arch Linux..."
    if ! sudo pacman-key --populate archlinux; then
        echo "❌ Не удалось заполнить keyring ключами Arch Linux"
        return 1
    fi
    
    echo "🔐 Добавление ключей SteamOS..."
    # Пробуем несколько серверов ключей
    KEY_SERVERS=(
        "hkps://keys.openpgp.org"
        "hkps://keyserver.ubuntu.com"
        "hkps://pgp.mit.edu"
    )
    
    STEAMOS_KEY="3056513887B78AEB"
    
    for server in "${KEY_SERVERS[@]}"; do
        echo "   Пробуем сервер: $server"
        if sudo pacman-key --keyserver "$server" --recv-keys "$STEAMOS_KEY" 2>/dev/null; then
            echo "   ✅ Ключ получен с $server"
            sudo pacman-key --lsign-key "$STEAMOS_KEY"
            break
        else
            echo "   ❌ Не удалось получить ключ с $server"
        fi
    done
    
    # Дополнительные ключи для Steam Deck
    echo "🔐 Добавление дополнительных ключей..."
    ADDITIONAL_KEYS=(
        "991F6E3F0765CF6295888586139B09DA5BF0D338"  # SteamOS signing key
        "AB19265E5D7D20687D303246BA1DFB64FFF979E7"  # SteamOS package signing
    )
    
    for key in "${ADDITIONAL_KEYS[@]}"; do
        for server in "${KEY_SERVERS[@]}"; do
            if sudo pacman-key --keyserver "$server" --recv-keys "$key" 2>/dev/null; then
                sudo pacman-key --lsign-key "$key" 2>/dev/null || true
                echo "   ✅ Ключ $key добавлен"
                break
            fi
        done
    done
    
    echo "🔄 Обновление доверия к ключам..."
    sudo pacman-key --updatedb
    
    echo ""
    echo "✅ ==============================="
    echo "✅ Keyring успешно исправлен!"
    echo "✅ ==============================="
    echo ""
}

# Устанавливаем недостающие пакеты
if [ ! -z "$MISSING_COMMANDS" ]; then
    echo ""
    echo "📦 Установка недостающих пакетов: $MISSING_COMMANDS"
    
    # Разблокируем файловую систему
    echo "🔓 Разблокировка файловой системы Steam Deck..."
    sudo steamos-readonly disable 2>/dev/null || true
    
    # Проверяем и исправляем keyring при необходимости
    echo "📥 Проверка базы пакетов..."
    if ! sudo pacman -Sy --noconfirm 2>/dev/null; then
        echo "❌ Проблема с базой данных пакетов, возможно keyring поврежден"
        
        # Проверяем специфические ошибки keyring
        if sudo pacman -Sy 2>&1 | grep -i "keyring\|key\|signature"; then
            echo "🔐 Обнаружена проблема с keyring, исправляем..."
            fix_keyring
            
            # Пробуем еще раз после исправления keyring
            echo "📥 Повторная попытка обновления базы данных..."
            sudo pacman -Sy --noconfirm
        else
            echo "⚠️  Другая проблема с pacman, продолжаем..."
        fi
    else
        echo "✅ База данных пакетов в порядке"
    fi
    
    # Устанавливаем пакеты
    echo "📦 Установка пакетов..."
    
    # Захватываем вывод команды установки
    log "Попытка установки: $MISSING_COMMANDS"
    log "Это может занять несколько минут..."
    
    # Используем более надежный способ выполнения команды
    {
        timeout 300 bash -c "yes 'y' | sudo pacman -S --needed $MISSING_COMMANDS"
        INSTALL_EXIT_CODE=$?
    } > >(tee /tmp/install_output.log) 2>&1 || INSTALL_EXIT_CODE=$?
    
    INSTALL_OUTPUT=$(cat /tmp/install_output.log 2>/dev/null || echo "Не удалось прочитать лог")
    
    log "Код выхода установки: $INSTALL_EXIT_CODE"
    
    if [ $INSTALL_EXIT_CODE -eq 0 ]; then
        echo "✅ Пакеты установлены успешно"
    elif [ $INSTALL_EXIT_CODE -eq 124 ]; then
        echo "⏱️  Время ожидания истекло (timeout), возможно установка длится слишком долго"
        echo "💡 Попробуйте запустить установку вручную:"
        echo "   sudo steamos-readonly disable"
        echo "   sudo pacman -S --needed $MISSING_COMMANDS"
        echo "   sudo steamos-readonly enable"
    else
        echo "❌ Не удалось установить пакеты (код ошибки: $INSTALL_EXIT_CODE)"
        
        # Проверяем, связана ли ошибка с keyring
        if echo "$INSTALL_OUTPUT" | grep -i "keyring\|key.*missing\|signature"; then
            echo "🔐 Обнаружена проблема с keyring при установке, исправляем..."
            fix_keyring
            
            # Пробуем установить пакеты еще раз после исправления keyring
            echo "📦 Повторная попытка установки пакетов..."
            
            RETRY_OUTPUT=$(timeout 300 bash -c "yes 'y' | sudo pacman -S --needed $MISSING_COMMANDS" 2>&1 || true)
            RETRY_EXIT_CODE=$?
            
            if [ $RETRY_EXIT_CODE -eq 0 ]; then
                echo "✅ Пакеты установлены успешно после исправления keyring"
            elif [ $RETRY_EXIT_CODE -eq 124 ]; then
                echo "⏱️  Время ожидания истекло при повторной попытке"
                echo "💡 Установка может продолжаться в фоне, проверьте позже"
            else
                echo "❌ Не удалось установить пакеты даже после исправления keyring"
                echo "📄 Вывод ошибки:"
                echo "$RETRY_OUTPUT" | tail -10  # Показываем последние 10 строк ошибки
                echo ""
                echo "🛠️  Дополнительные решения:"
                echo "1. Перезагрузите Steam Deck и попробуйте еще раз"
                echo "2. Или используйте Flatpak версию ImageMagick:"
                echo "   flatpak install --user flathub org.imagemagick.ImageMagick"
            fi
        else
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
        fi
    fi
    
    # Возвращаем файловую систему в read-only режим
    echo "🔒 Возвращение файловой системы в read-only режим..."
    sudo steamos-readonly enable 2>/dev/null || true
    
else
    echo "✅ Все необходимые команды найдены"
fi

# Если pacman не сработал, пробуем альтернативные методы
if [ -n "$MISSING_COMMANDS" ]; then
    echo ""
    echo "🔄 Попытка установки альтернативными методами..."
    
    # Метод 1: Flatpak
    if command -v flatpak &> /dev/null; then
        echo "📦 Попытка установки через Flatpak..."
        
        if echo "$MISSING_COMMANDS" | grep -q "convert\|imagemagick"; then
            echo "  Установка ImageMagick через Flatpak..."
            if flatpak install --user -y flathub org.imagemagick.ImageMagick 2>/dev/null; then
                echo "✅ ImageMagick установлен через Flatpak"
                # Создаем wrapper
                mkdir -p "$HOME/.local/bin"
                cat > "$HOME/.local/bin/convert" << 'EOF'
#!/bin/bash
exec flatpak run org.imagemagick.ImageMagick convert "$@"
EOF
                chmod +x "$HOME/.local/bin/convert"
                export PATH="$HOME/.local/bin:$PATH"
            else
                echo "❌ Не удалось установить через Flatpak"
            fi
        fi
    fi
    
    # Метод 2: Статические бинарники
    echo "📥 Попытка загрузки статических бинарников..."
    mkdir -p "$HOME/.local/bin"
    
    # ImageMagick
    if echo "$MISSING_COMMANDS" | grep -q "convert\|imagemagick" && ! command -v convert &> /dev/null; then
        echo "  Загрузка ImageMagick..."
        if curl -L "https://github.com/SoftCreatR/imei/releases/latest/download/imei-linux-x86_64" -o /tmp/convert 2>/dev/null; then
            chmod +x /tmp/convert
            mv /tmp/convert "$HOME/.local/bin/convert"
            echo "✅ ImageMagick установлен"
        else
            echo "❌ Не удалось загрузить ImageMagick"
        fi
    fi
    
    # xwd wrapper
    if echo "$MISSING_COMMANDS" | grep -q "xwd" && ! command -v xwd &> /dev/null; then
        echo "  Создание wrapper для xwd..."
        cat > "$HOME/.local/bin/xwd" << 'EOF'
#!/bin/bash
# Wrapper для xwd
if command -v import &> /dev/null; then
    import "$@"
elif command -v gnome-screenshot &> /dev/null; then
    gnome-screenshot -f "${@: -1}"
else
    echo "❌ Нет доступных инструментов для скриншотов" >&2
    exit 1
fi
EOF
        chmod +x "$HOME/.local/bin/xwd"
        echo "✅ Wrapper для xwd создан"
    fi
    
    # Добавляем в PATH
    export PATH="$HOME/.local/bin:$PATH"
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc 2>/dev/null || true
    
    # Перепроверяем команды
    MISSING_COMMANDS=""
    for cmd in convert xwd xdotool import; do
        if ! command -v "$cmd" &> /dev/null; then
            MISSING_COMMANDS="$MISSING_COMMANDS $cmd"
        fi
    done
    
    if [ -n "$MISSING_COMMANDS" ]; then
        echo "⚠️  Не удалось установить:$MISSING_COMMANDS"
        echo "💡 Но система может работать с ограниченной функциональностью"
    else
        echo "✅ Все команды теперь доступны!"
    fi
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
echo "🎉 Исправление завершено!"
echo ""

# Финальная проверка
echo "� Финальная проверка команд..."
FINAL_MISSING=""

if ! command -v convert &> /dev/null; then
    echo "❌ convert всё ещё отсутствует"
    FINAL_MISSING="$FINAL_MISSING convert"
else
    echo "✅ convert найден"
fi

if ! command -v xwd &> /dev/null; then
    echo "❌ xwd всё ещё отсутствует"
    FINAL_MISSING="$FINAL_MISSING xwd"
else
    echo "✅ xwd найден"
fi

echo ""
echo "📋 Результат:"
echo "=============="

if [ -z "$FINAL_MISSING" ]; then
    echo "🎉 ВСЕ КОМАНДЫ УСТАНОВЛЕНЫ УСПЕШНО!"
    echo "✅ Скриншоты должны работать"
    echo ""
    echo "💡 Теперь можете:"
    echo "   1. Запустить бота: ./start.sh"
    echo "   2. Попробовать команду /describe в Telegram"
    echo "   3. Проверить что Disco Elysium запущен"
else
    echo "❌ Некоторые команды всё ещё отсутствуют:$FINAL_MISSING"
    echo ""
    echo "💡 Возможные решения:"
    echo "   1. Перезагрузите Steam Deck"
    echo "   2. Запустите скрипт повторно"
    echo "   3. Попробуйте ручную установку"
fi

echo ""
echo "🛠️  Полезные команды для отладки:"
echo "   echo \$DISPLAY                    # Проверить DISPLAY"
echo "   xdpyinfo | head                  # Информация о X сервере"
echo "   xwd -root | convert xwd:- test.png # Тест скриншота"
echo "   python3 -c \"from PIL import ImageGrab; ImageGrab.grab().save('test.png')\" # Тест Python"