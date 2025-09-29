#!/bin/bash

# Скрипт быстрой установки Disc    echo "🔓 Разблокировка файловой     # Обновляем базу данных пакетов с retry логикой
    echo "📥 Обновление базы данных п    echo "🔓 Разблокировка файловой системы Steam Deck..."
    sudo steamos-readonly disable 2>/dev/null || true
    
    # Сначала пробуем обычное обновление
    echo "📥 Проверка базы пакетов..."
    if ! sudo pacman -Sy --noconfirm 2>/dev/null; then
        echo "❌ Проблема с базой данных пакетов"
        
        # Проверяем, связано ли это с keyring
        if sudo pacman -Sy 2>&1 | grep -i "keyring\|key.*missing\|signature"; then
            echo "🔐 Обнаружена проблема с keyring, исправляем..."
            fix_keyring
            
            # Пробуем еще раз после исправления keyring
            echo "📥 Повторная попытка обновления базы данных..."
            if ! sudo pacman -Sy --noconfirm; then
                echo "❌ Не удалось обновить базу данных даже после исправления keyring"
                PACMAN_FAILED=true
            else
                echo "✅ База данных пакетов обновлена после исправления keyring"
            fi
        else
            echo "⚠️  Другая проблема с pacman"
            PACMAN_FAILED=true
        fi
    else
        echo "✅ База данных пакетов в порядке"
    fi for i in {1..3}; do
        if sudo pacman -Sy --noconfirm; then
            echo "✅ База данных пакетов обновлена"
            break
        else
            echo "   Попытка $i/3 обновления базы данных..."
            if [ $i -eq 3 ]; then
                echo "❌ Не удалось обновить базу данных пакетов"
                PACMAN_FAILED=true
                break
            fi
            sleep 3
        fi
    done
    
    if [ "$PACMAN_FAILED" = false ]; then
        echo "📦 Установка пакетов..."
        
        # Сначала очищаем поврежденные пакеты автоматически
        echo "🧹 Очистка поврежденного кэша пакетов..."
        sudo find /var/cache/pacman/pkg/ -name "*.pkg.tar.zst" -type f -delete 2>/dev/null || true
        
        # Полная очистка кэша
        printf "y\ny\n" | sudo pacman -Scc 2>/dev/null || true
    fiam Deck..."
    sudo steamos-readonly disable 2>/dev/null || true
    
    # Исправляем права доступа к keyring
    echo "🔧 Исправление прав доступа к keyring..."
    sudo chown -R root:root /etc/pacman.d/gnupg/ 2>/dev/null || true
    sudo chmod -R 755 /etc/pacman.d/gnupg/ 2>/dev/null || true
    
    # Очищаем и пересоздаем keyring
    echo "🔑 Настройка keyring для SteamOS..."
    sudo rm -rf /etc/pacman.d/gnupg 2>/dev/null || true
    sudo pacman-key --init
    sudo pacman-key --populate archlinux
    
    # Добавляем ключи SteamOS с retry логикой
    echo "🔐 Добавление ключей SteamOS..."
    for i in {1..3}; do
        if sudo pacman-key --recv-keys 3056513887B78AEB 2>/dev/null; then
            sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
            break
        else
            echo "   Попытка $i/3 получения ключей..."
            sleep 2
        fi
    doneteam Deck

set -e  # Остановка при ошибке

# URL репозитория
REPOSITORY_URL="https://github.com/ArtemKiyashko/DiscoCoop.git"

# Переменные состояния
PACMAN_FAILED=false

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
    sudo rm -rf /var/cache/pacman/pkg/*
    
    echo "🔧 Исправление прав доступа..."
    sudo mkdir -p /etc/pacman.d/gnupg
    sudo chown -R root:root /etc/pacman.d/gnupg/
    sudo chmod -R 755 /etc/pacman.d/gnupg/
    
    echo "🔑 Инициализация нового keyring..."
    sudo pacman-key --init
    
    echo "📦 Заполнение ключами Arch Linux..."
    sudo pacman-key --populate archlinux
    
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
echo "📁 Работа с директорией проекта в $PROJECT_DIR"

if [ -d "$PROJECT_DIR" ]; then
    echo "✅ Директория уже существует. Обновляем репозиторий..."
    cd "$PROJECT_DIR"
    
    # Проверяем, что это git репозиторий
    if [ -d ".git" ]; then
        # Сохраняем локальные изменения
        git stash push -m "Auto-stash before update $(date)" 2>/dev/null || true
        git pull --rebase origin main 2>/dev/null || git pull origin main || echo "⚠️  Не удалось обновить репозиторий, продолжаем с текущей версией"
        git stash pop 2>/dev/null || true
    else
        echo "⚠️  Директория существует, но не является git репозиторием"
        echo "   Продолжаем работу с существующими файлами"
    fi
else
    echo "📥 Клонирование репозитория..."
    cd "$HOME"
    if ! git clone "$REPOSITORY_URL" disco_coop; then
        echo "❌ Не удалось клонировать репозиторий"
        echo "💡 Проверьте подключение к интернету и попробуйте еще раз"
        exit 1
    fi
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
    
    # Сначала очищаем поврежденные пакеты автоматически
    echo "🧹 Очистка поврежденного кэша пакетов..."
    sudo find /var/cache/pacman/pkg/ -name "*.pkg.tar.zst" -type f -delete 2>/dev/null || true
    
    # Полная очистка кэша
    printf "y\ny\n" | sudo pacman -Scc 2>/dev/null || true
    
    # Пробуем установить базовые пакеты с автоматическими ответами
    echo "📥 Попытка установки Python и базовых пакетов..."
    
    # Используем timeout и yes для автоматических ответов
    if [ "$PACMAN_FAILED" = false ]; then
        echo "📥 Установка базовых пакетов (Python, pip, git)..."
        
        # Захватываем вывод для анализа keyring ошибок  
        BASIC_OUTPUT=$(timeout 300 bash -c 'yes "y" | sudo pacman -S --needed python python-pip git' 2>&1)
        BASIC_EXIT_CODE=$?
        
        if [ $BASIC_EXIT_CODE -eq 0 ]; then
            echo "✅ Базовые пакеты установлены"
        else
            # Проверяем, связана ли ошибка с keyring
            if echo "$BASIC_OUTPUT" | grep -i "keyring\|key.*missing\|signature"; then
                echo "🔐 Обнаружена проблема с keyring при установке базовых пакетов"
                fix_keyring
                
                # Пробуем установить пакеты еще раз
                echo "📥 Повторная попытка установки базовых пакетов..."
                if timeout 300 bash -c 'yes "y" | sudo pacman -S --needed python python-pip git'; then
                    echo "✅ Базовые пакеты установлены после исправления keyring"
                else
                    echo "❌ Не удалось установить базовые пакеты даже после исправления keyring"
                    PACMAN_FAILED=true
                fi
            else
                echo "❌ Не удалось установить базовые пакеты по другой причине"
                PACMAN_FAILED=true
            fi
        fi
    fi
    
    if [ "$PACMAN_FAILED" = false ]; then
        
        # Пробуем установить дополнительные пакеты
        echo "📦 Установка дополнительных пакетов..."
        
        # Критичные пакеты для скриншотов
        echo "🖼️  Установка пакетов для скриншотов..."
        
        # Захватываем вывод для анализа keyring ошибок
        SCREENSHOT_OUTPUT=$(timeout 180 bash -c 'yes "y" | sudo pacman -S --needed imagemagick xorg-xwd' 2>&1)
        SCREENSHOT_EXIT_CODE=$?
        
        if [ $SCREENSHOT_EXIT_CODE -eq 0 ]; then
            echo "✅ Пакеты для скриншотов установлены"
        else
            # Проверяем, связана ли ошибка с keyring
            if echo "$SCREENSHOT_OUTPUT" | grep -i "keyring\|key.*missing\|signature"; then
                echo "🔐 Обнаружена проблема с keyring при установке пакетов для скриншотов"
                fix_keyring
                
                # Пробуем установить пакеты еще раз
                echo "🖼️  Повторная попытка установки пакетов для скриншотов..."
                if timeout 180 bash -c 'yes "y" | sudo pacman -S --needed imagemagick xorg-xwd'; then
                    echo "✅ Пакеты для скриншотов установлены после исправления keyring"
                else
                    echo "⚠️  Пакеты для скриншотов не установлены даже после исправления keyring"
                fi
            else
                echo "⚠️  Пакеты для скриншотов не установлены - требуется ручная установка"
            fi
        fi
        
        # Дополнительные пакеты
        timeout 180 bash -c 'yes "y" | sudo pacman -S --needed tk xdotool 2>/dev/null' || {
            echo "⚠️  Дополнительные пакеты не установлены, но это не критично"
        }
    else
        echo "❌ Не удается установить через pacman"
        
        # Проверяем, не связано ли это с keyring
        if pacman -Sy 2>&1 | grep -i "keyring\|key\|signature"; then
            echo "🔐 Обнаружена проблема с keyring!"
            echo "💡 Запустите: ./fix_screenshots.sh"
            echo "   Скрипт исправит keyring и установит пакеты для скриншотов"
            echo "   Затем перезапустите установку"
            exit 1
        else
            echo "   Используем альтернативный метод..."
            PACMAN_FAILED=true
        fi
    fi
    
    echo "🔒 Возвращение файловой системы в read-only режим..."
    sudo steamos-readonly enable 2>/dev/null || true
else
    echo "⚠️  pacman недоступен, используем альтернативные методы..."
    PACMAN_FAILED=true
fi

# Проверяем наличие Python независимо от успеха pacman
if [ "$PACMAN_FAILED" = true ] || ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
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



# Создание виртуального окружения (обязательно для Steam Deck)
echo "🐍 Настройка виртуального окружения..."

# Определяем какой Python использовать
if command -v python3 &> /dev/null; then
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_CMD="python"
elif [ -f "$HOME/python/bin/python3" ]; then
    PYTHON_CMD="$HOME/python/bin/python3"
    export PATH="$HOME/python/bin:$PATH"
else
    echo "❌ Python не найден!"
    exit 1
fi

echo "🔧 Используем: $PYTHON_CMD"

# Проверяем существующее виртуальное окружение
if [ -d "venv" ]; then
    echo "✅ Виртуальное окружение уже существует"
    
    # Проверяем, что оно работает
    if [ -f "venv/bin/activate" ] && [ -f "venv/bin/python" ]; then
        echo "✅ Виртуальное окружение корректно настроено"
        source venv/bin/activate
        
        # Проверяем версию Python в venv
        VENV_PYTHON_VERSION=$(python --version 2>&1)
        echo "🐍 Версия Python в venv: $VENV_PYTHON_VERSION"
    else
        echo "⚠️  Виртуальное окружение повреждено, пересоздаем..."
        rm -rf venv
        if ! $PYTHON_CMD -m venv venv; then
            echo "❌ Не удалось создать виртуальное окружение"
            exit 1
        fi
        source venv/bin/activate
    fi
else
    echo "📦 Создание нового виртуального окружения..."
    if ! $PYTHON_CMD -m venv venv; then
        echo "❌ Не удалось создать виртуальное окружение"
        exit 1
    fi
    source venv/bin/activate
fi

# Обновляем pip и устанавливаем инструменты сборки
echo "📚 Обновление pip и установка инструментов сборки..."
python -m pip install --upgrade pip
python -m pip install --upgrade setuptools wheel build

# Устанавливаем системные зависимости для сборки пакетов, если нужно
if [ "$PACMAN_FAILED" = false ] && command -v pacman &> /dev/null; then
    echo "🔧 Установка дополнительных инструментов сборки..."
    sudo steamos-readonly disable 2>/dev/null || true
    timeout 120 bash -c 'yes "y" | sudo pacman -S --needed --noconfirm gcc python-devel libffi-devel openssl-devel' 2>/dev/null || echo "⚠️  Дополнительные инструменты не установлены"
    sudo steamos-readonly enable 2>/dev/null || true
fi

# Установка Python зависимостей
echo "🔄 Установка Python пакетов..."

# Функция для надежной установки пакетов
install_package() {
    local package="$1"
    local backup_package="$2"
    local is_critical="$3"
    
    echo "  Установка $package..."
    
    if pip install "$package" --no-cache-dir; then
        echo "  ✅ $package установлен"
        return 0
    elif [ ! -z "$backup_package" ]; then
        echo "  ⚠️  Пробуем альтернативную версию: $backup_package"
        if pip install "$backup_package" --no-cache-dir; then
            echo "  ✅ $backup_package установлен"
            return 0
        fi
    fi
    
    if [ "$is_critical" = "true" ]; then
        echo "  ❌ Не удалось установить критичный пакет $package"
        return 1
    else
        echo "  ⚠️  $package пропущен (не критично)"
        return 0
    fi
}

# Установка критичных зависимостей с fallback версиями
echo "📦 Установка критичных зависимостей..."

install_package "python-telegram-bot>=22.0,<23.0" "python-telegram-bot>=22.0,<23.0" "true"
install_package "aiohttp==3.9.1" "aiohttp>=3.8.0" "true"
install_package "pyyaml==6.0.1" "pyyaml>=6.0" "true"
install_package "loguru==0.7.2" "loguru>=0.7.0" "true"
install_package "Pillow==10.1.0" "Pillow>=9.0.0" "true"
install_package "requests==2.31.0" "requests>=2.28.0" "true"

# Устанавливаем базовые зависимости для pynput
install_package "six" "" "false"

# Установка дополнительных зависимостей (более мягко)
echo "📦 Установка дополнительных зависимостей..."

# OpenCV - пробуем разные варианты
if ! pip install opencv-python-headless --no-cache-dir; then
    if ! pip install opencv-python --no-cache-dir; then
        echo "  ⚠️  OpenCV пропущен (не критично)"
    fi
fi

# PyAutoGUI - часто проблемы на Steam Deck
if ! pip install PyAutoGUI --no-cache-dir; then
    echo "  ⚠️  PyAutoGUI пропущен (не критично - можно установить позже)"
fi

# pynput - проблемы с evdev на Steam Deck, пробуем разные варианты
echo "  Установка pynput..."
if pip install pynput --no-cache-dir; then
    echo "  ✅ pynput установлен"
elif pip install six --no-cache-dir && pip install pynput --no-deps --no-cache-dir; then
    echo "  ✅ pynput установлен (с минимальными зависимостями)"
else
    echo "  ⚠️  pynput пропущен (проблемы с evdev на Steam Deck - не критично)"
fi

# numpy - обычно устанавливается без проблем
install_package "numpy" "" "false"

echo "📦 Проверка установки базовых зависимостей..."
python -c "
import sys
failed = []
try:
    import telegram
    print('✅ telegram импортируется')
except ImportError:
    failed.append('python-telegram-bot')
    print('❌ telegram не импортируется')

try:
    import aiohttp
    print('✅ aiohttp импортируется')
except ImportError:
    failed.append('aiohttp')
    print('❌ aiohttp не импортируется')

try:
    from PIL import Image
    print('✅ Pillow импортируется')
except ImportError:
    failed.append('Pillow')
    print('❌ Pillow не импортируется')

try:
    import yaml
    print('✅ yaml импортируется')
except ImportError:
    failed.append('pyyaml')
    print('❌ yaml не импортируется')

try:
    import loguru
    print('✅ loguru импортируется')
except ImportError:
    failed.append('loguru')
    print('❌ loguru не импортируется')

if failed:
    print(f'⚠️  Некоторые критичные пакеты не установились: {failed}')
    print('🔄 Пробуем установить через requirements.txt...')
    sys.exit(2)  # Сигнал для bash скрипта
else:
    print('✅ Все критичные зависимости установлены успешно!')
"

# Если проверка не прошла, пробуем установить через requirements.txt
if [ $? -eq 2 ]; then
    echo "🔄 Пробуем альтернативный метод через requirements.txt..."
    if pip install -r requirements.txt --no-cache-dir; then
        echo "✅ Зависимости установлены через requirements.txt"
    else
        echo "⚠️  Проблемы с установкой некоторых пакетов, но продолжаем..."
    fi
fi

# Проверка и установка Ollama
echo "🤖 Проверка Ollama..."

OLLAMA_INSTALLED=false
OLLAMA_WORKING=false

# Проверяем наличие ollama в разных местах
if command -v ollama &> /dev/null; then
    OLLAMA_INSTALLED=true
    echo "✅ Ollama найден в системе"
elif [ -f "$HOME/.local/bin/ollama" ]; then
    OLLAMA_INSTALLED=true
    export PATH="$HOME/.local/bin:$PATH"
    echo "✅ Ollama найден в ~/.local/bin"
fi

# Если Ollama установлен, проверяем его работоспособность
if [ "$OLLAMA_INSTALLED" = true ]; then
    if ollama --version &> /dev/null; then
        OLLAMA_WORKING=true
        echo "✅ Ollama работает корректно"
    else
        echo "⚠️  Ollama установлен, но не работает"
        OLLAMA_WORKING=false
    fi
fi

# Устанавливаем Ollama если нужно
if [ "$OLLAMA_INSTALLED" = false ] || [ "$OLLAMA_WORKING" = false ]; then
    echo "📥 Установка Ollama..."
    
    # Пробуем стандартную установку
    if curl -fsSL https://ollama.ai/install.sh | sh 2>/dev/null; then
        echo "✅ Ollama установлен через официальный скрипт"
    else
        # Если не удалось, устанавливаем в пользовательскую директорию
        echo "⚠️  Официальная установка не удалась, устанавливаем локально..."
        
        mkdir -p "$HOME/.local/bin"
        OLLAMA_VERSION="v0.12.3"
        OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tgz"
        
        if curl -L "$OLLAMA_URL" -o "/tmp/ollama.tgz"; then
            mkdir -p /tmp/ollama_extract
            
            if tar -xzf /tmp/ollama.tgz -C /tmp/ollama_extract; then
                # Ищем исполняемый файл
                if [ -f "/tmp/ollama_extract/bin/ollama" ]; then
                    cp "/tmp/ollama_extract/bin/ollama" "$HOME/.local/bin/ollama"
                elif [ -f "/tmp/ollama_extract/ollama" ]; then
                    cp "/tmp/ollama_extract/ollama" "$HOME/.local/bin/ollama"
                fi
                
                chmod +x "$HOME/.local/bin/ollama"
                export PATH="$HOME/.local/bin:$PATH"
                
                # Добавляем в bashrc если еще не добавлено
                if ! grep -q "export PATH.*\.local/bin" ~/.bashrc; then
                    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
                fi
                
                echo "✅ Ollama установлен в ~/.local/bin"
                
                # Очищаем временные файлы
                rm -rf /tmp/ollama_extract /tmp/ollama.tgz
            else
                echo "❌ Не удалось распаковать Ollama"
                exit 1
            fi
        else
            echo "❌ Не удалось загрузить Ollama"
            exit 1
        fi
    fi
fi

# Настройка и запуск Ollama как systemd сервис
echo "🚀 Настройка сервиса Ollama..."

# Определяем путь к исполняемому файлу Ollama
OLLAMA_EXEC=""
if command -v ollama &> /dev/null; then
    OLLAMA_EXEC=$(which ollama)
elif [ -f "$HOME/.local/bin/ollama" ]; then
    OLLAMA_EXEC="$HOME/.local/bin/ollama"
fi

if [ ! -z "$OLLAMA_EXEC" ]; then
    # Создаем systemd сервис для Ollama
    echo "📝 Создание systemd сервиса для Ollama..."
    sudo tee /etc/systemd/system/ollama.service > /dev/null << EOF
[Unit]
Description=Ollama Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=deck
ExecStart=$OLLAMA_EXEC serve
Restart=always
RestartSec=5
Environment=OLLAMA_ORIGINS=*
WorkingDirectory=/home/deck

[Install]
WantedBy=multi-user.target
EOF

    # Перезагружаем systemd и включаем сервис
    sudo systemctl daemon-reload
    sudo systemctl enable ollama.service
    
    # Проверяем, запущен ли уже сервис
    if ! systemctl is-active --quiet ollama.service; then
        echo "🔄 Запуск сервиса Ollama..."
        sudo systemctl start ollama.service
        
        # Ждем запуска сервера
        echo "⏳ Ожидание запуска сервера..."
        for i in {1..30}; do
            if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
                echo "✅ Сервер Ollama запущен как сервис"
                break
            fi
            sleep 1
            if [ $i -eq 30 ]; then
                echo "⚠️  Сервер Ollama не отвечает, пробуем ручной запуск..."
                # Fallback к ручному запуску
                nohup "$OLLAMA_EXEC" serve > /dev/null 2>&1 &
                sleep 5
            fi
        done
    else
        echo "✅ Сервис Ollama уже запущен"
    fi
else
    echo "❌ Не найден исполняемый файл Ollama"
    exit 1
fi

# Проверка и загрузка моделей
echo "🧠 Проверка моделей ИИ..."

# Функция для проверки модели
check_model() {
    local model_name="$1"
    if ollama list | grep -q "$model_name"; then
        echo "✅ Модель $model_name уже загружена"
        return 0
    else
        echo "📥 Загрузка модели $model_name..."
        if ollama pull "$model_name"; then
            echo "✅ Модель $model_name загружена"
            return 0
        else
            echo "❌ Не удалось загрузить модель $model_name"
            return 1
        fi
    fi
}

# Проверяем основные модели
check_model "llama3.1:8b" || echo "⚠️  Модель llama3.1:8b не загружена"
check_model "llava:7b" || echo "⚠️  Модель llava:7b не загружена"

# Создание конфигурации
echo "⚙️  Настройка конфигурации..."
if [ ! -f "config/config.yaml" ]; then
    if [ -f "config/config.example.yaml" ]; then
        cp config/config.example.yaml config/config.yaml
        echo "📝 Создан файл конфигурации config/config.yaml"
        echo "❗ ВАЖНО: Отредактируйте config/config.yaml с вашими настройками!"
    else
        echo "⚠️  Файл config.example.yaml не найден, пропускаем создание конфигурации"
        echo "💡 Вы можете создать config/config.yaml вручную позже"
    fi
else
    echo "✅ Файл конфигурации уже существует"
    echo "💡 Проверьте, что настройки актуальны в config/config.yaml"
fi

# Создание systemd сервиса для Disco Coop
echo "🔧 Настройка systemd сервиса Disco Coop..."
if [ -f "/etc/systemd/system/disco-coop.service" ]; then
    echo "✅ Сервис disco-coop.service уже существует, обновляем..."
else
    echo "📝 Создание нового сервиса disco-coop.service..."
fi

sudo tee /etc/systemd/system/disco-coop.service > /dev/null << EOF
[Unit]
Description=Disco Coop Telegram Bot
After=network-online.target ollama.service
Wants=network-online.target
Requires=ollama.service

[Service]
Type=simple
User=deck
WorkingDirectory=$PROJECT_DIR
Environment=PATH=$PROJECT_DIR/venv/bin:/usr/local/bin:/usr/bin:/bin
ExecStart=$PROJECT_DIR/venv/bin/python main.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Перезагрузка systemd и включение сервиса
sudo systemctl daemon-reload
sudo systemctl enable disco-coop.service

echo "✅ Сервисы настроены для автоматического запуска"

# Создание папки для логов
mkdir -p logs

# Создание скрипта запуска
echo "📜 Создание/обновление скриптов управления..."

# Создаем или обновляем start.sh
echo "   📄 start.sh"
cat > start.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

# Проверяем, что Ollama сервис запущен
echo "🤖 Проверка сервиса Ollama..."
if ! systemctl is-active --quiet ollama.service; then
    echo "🚀 Запуск сервиса Ollama..."
    sudo systemctl start ollama.service
    sleep 5
fi

# Ждем, пока Ollama станет доступен
echo "⏳ Ожидание Ollama API..."
for i in {1..30}; do
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "✅ Ollama готов"
        break
    fi
    sleep 1
    if [ $i -eq 30 ]; then
        echo "⚠️  Ollama не отвечает, но продолжаем..."
    fi
done

# Активируем виртуальное окружение и запускаем бота
source venv/bin/activate
echo "🚀 Запуск Disco Coop бота..."
python main.py
EOF
chmod +x start.sh

# Создание дополнительных скриптов управления
echo "📜 Создание скриптов управления..."

cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 Остановка сервисов..."
sudo systemctl stop disco-coop.service
sudo systemctl stop ollama.service
echo "✅ Сервисы остановлены"
EOF
chmod +x stop.sh

cat > restart.sh << 'EOF'
#!/bin/bash
echo "🔄 Перезапуск сервисов..."
sudo systemctl restart ollama.service
sleep 5
sudo systemctl restart disco-coop.service
echo "✅ Сервисы перезапущены"
EOF
chmod +x restart.sh

cat > status.sh << 'EOF'
#!/bin/bash
echo "📊 Статус сервисов:"
echo "=================="
echo "🤖 Ollama:"
sudo systemctl status ollama.service --no-pager -l
echo ""
echo "🎮 Disco Coop:"
sudo systemctl status disco-coop.service --no-pager -l
echo ""
echo "🌐 API Ollama:"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Доступно"
else
    echo "❌ Недоступно"
fi
EOF
chmod +x status.sh

# Финальная проверка системы
echo ""
echo "🔍 Финальная проверка системы..."
echo "================================"

# Активируем виртуальное окружение для проверок
source venv/bin/activate

# Проверка Python зависимостей
echo "1. 📦 Проверка Python зависимостей..."
MISSING_DEPS=""

check_python_package() {
    if python -c "import $1" 2>/dev/null; then
        echo "   ✅ $1"
    else
        echo "   ❌ $1 отсутствует"
        MISSING_DEPS="$MISSING_DEPS $1"
    fi
}

check_python_package "telegram"
check_python_package "PIL"
check_python_package "aiohttp"
check_python_package "yaml"
check_python_package "loguru"

# Дополнительные пакеты (не критичные)
python -c "import cv2" 2>/dev/null && echo "   ✅ cv2 (opencv)" || echo "   ⚠️  cv2 отсутствует (не критично)"
python -c "import pyautogui" 2>/dev/null && echo "   ✅ pyautogui" || echo "   ⚠️  pyautogui отсутствует (не критично)"
python -c "import pynput" 2>/dev/null && echo "   ✅ pynput" || echo "   ⚠️  pynput отсутствует (не критично)"

# Установка недостающих критичных зависимостей
if [ ! -z "$MISSING_DEPS" ]; then
    echo "📦 Доустановка недостающих зависимостей..."
    for dep in $MISSING_DEPS; do
        case $dep in
            "telegram")
                pip install python-telegram-bot>=22.0,<23.0 --no-cache-dir || \
                pip install python-telegram-bot --no-cache-dir || \
                echo "❌ Не удалось установить python-telegram-bot"
                ;;
            "PIL")
                pip install Pillow>=9.0.0 --no-cache-dir || \
                pip install Pillow --no-cache-dir || \
                echo "❌ Не удалось установить Pillow"
                ;;
            "aiohttp")
                pip install aiohttp>=3.8.0 --no-cache-dir || \
                pip install aiohttp --no-cache-dir || \
                echo "❌ Не удалось установить aiohttp"
                ;;
            "yaml")
                pip install pyyaml>=6.0 --no-cache-dir || \
                pip install pyyaml --no-cache-dir || \
                echo "❌ Не удалось установить pyyaml"
                ;;
            "loguru")
                pip install loguru>=0.7.0 --no-cache-dir || \
                pip install loguru --no-cache-dir || \
                echo "❌ Не удалось установить loguru"
                ;;
        esac
    done
fi

# Проверка конфигурации
echo "2. ⚙️  Проверка конфигурации..."
if [ -f "config/config.yaml" ]; then
    if python -c "from src.utils.config import Config; c = Config.load(); c.validate(); print('   ✅ Конфигурация корректна')" 2>/dev/null; then
        echo "   ✅ Конфигурация валидна"
    else
        echo "   ⚠️  Конфигурация требует настройки"
    fi
else
    echo "   ⚠️  Файл конфигурации не найден"
fi

# Проверка Ollama и моделей
echo "3. 🤖 Проверка Ollama и моделей..."
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "   ✅ Сервер Ollama доступен"
    
    # Проверяем модели
    if ollama list | grep -q "llama3.1:8b"; then
        echo "   ✅ Модель llama3.1:8b загружена"
    else
        echo "   ❌ Модель llama3.1:8b не найдена"
    fi
    
    if ollama list | grep -q "llava:7b"; then
        echo "   ✅ Модель llava:7b загружена"
    else
        echo "   ❌ Модель llava:7b не найдена"
    fi
else
    echo "   ❌ Сервер Ollama недоступен"
fi

# Создание упрощенного скрипта тестирования
cat > test.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
source venv/bin/activate

echo "🧪 Быстрая проверка системы..."

# Проверка основных компонентов
python -c "
try:
    from src.utils.config import Config
    print('✅ Конфигурация загружается')
except Exception as e:
    print(f'❌ Проблема с конфигурацией: {e}')

try:
    import telegram, PIL, aiohttp, yaml, loguru
    print('✅ Основные зависимости установлены')
except ImportError as e:
    print(f'❌ Отсутствуют зависимости: {e}')

# Проверяем дополнительные зависимости
try:
    import pynput
    print('✅ pynput доступен')
except ImportError as e:
    print(f'⚠️  pynput недоступен: {e}')
    
try:
    import pyautogui
    print('✅ pyautogui доступен')
except ImportError as e:
    print(f'⚠️  pyautogui недоступен: {e}')

# Проверяем импорт GameController
try:
    from src.game.controller import GameController
    print('✅ GameController импортируется')
except ImportError as e:
    print(f'❌ Ошибка импорта GameController: {e}')
    print('💡 Попробуйте запустить: ./fix_pynput.sh')
"

# Проверка Ollama
if systemctl is-active --quiet ollama.service; then
    echo "✅ Сервис Ollama активен"
    if curl -s http://localhost:11434/api/tags > /dev/null; then
        echo "✅ API Ollama доступно"
    else
        echo "⚠️  API Ollama недоступно"
    fi
else
    echo "❌ Сервис Ollama неактивен - запустите: sudo systemctl start ollama.service"
fi

echo "Проверка завершена!"
EOF
chmod +x test.sh

echo ""
echo "🎉 Установка завершена!"
echo ""

# Финальная сводка
echo "� Состояние системы:"
echo "================================"

# Проверяем Python
if command -v python &> /dev/null; then
    echo "✅ Python: $(python --version)"
else
    echo "❌ Python не найден"
fi

# Проверяем виртуальное окружение
if [ -d "venv" ]; then
    echo "✅ Виртуальное окружение создано"
else
    echo "❌ Виртуальное окружение отсутствует"
fi

# Проверяем Ollama
if command -v ollama &> /dev/null || [ -f "$HOME/.local/bin/ollama" ]; then
    echo "✅ Ollama установлен"
    
    # Проверяем статус сервиса
    if systemctl is-active --quiet ollama.service; then
        echo "✅ Сервис Ollama активен"
    elif pgrep -f "ollama serve" > /dev/null; then
        echo "✅ Сервер Ollama запущен (ручной режим)"
    else
        echo "⚠️  Сервер Ollama не запущен"
    fi
    
    # Проверяем доступность API
    if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ API Ollama доступно"
    else
        echo "⚠️  API Ollama недоступно"
    fi
else
    echo "❌ Ollama не установлен"
fi

# Проверяем конфигурацию
if [ -f "config/config.yaml" ]; then
    echo "✅ Файл конфигурации создан"
else
    echo "❌ Файл конфигурации отсутствует"
fi

echo ""
echo "� Следующие шаги:"
echo "================================"
echo "1. 📝 Настройте config/config.yaml:"
echo "   - Добавьте Telegram bot token"
echo "   - Укажите разрешенные chat IDs"
echo ""
echo "2. 🧪 Запустите проверку: ./test.sh"
echo ""
echo "3. � Запустите бота:"
echo "   - Вручную: ./start.sh"
echo "   - Как сервис: sudo systemctl start disco-coop.service"
echo ""
echo "🔧 Полезные команды:"
echo "- Статус бота: sudo systemctl status disco-coop.service"
echo "- Статус Ollama: sudo systemctl status ollama.service"
echo "- Логи бота: sudo journalctl -u disco-coop.service -f"
echo "- Логи Ollama: sudo journalctl -u ollama.service -f"
echo "- Перезапуск бота: sudo systemctl restart disco-coop.service"
echo "- Перезапуск Ollama: sudo systemctl restart ollama.service"
echo ""
echo "❗ Важно:"
echo "- Создайте Telegram бота через @BotFather"
echo "- Запустите Disco Elysium перед использованием"
echo "- Скрипт можно запускать многократно для обновлений и исправлений"
echo ""
echo "🔄 При проблемах:"
echo "- Keyring/пакеты: ./fix_screenshots.sh"
echo "- Переустановка: curl -fsSL https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh | bash"
echo "- Повторный запуск: ./install.sh (безопасно для существующей установки)"