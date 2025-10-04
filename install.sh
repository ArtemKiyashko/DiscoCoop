#!/bin/bash

# Disco Coop - Установочный скрипт для Steam Deck
# Полностью автономная установка без использования pacman

set -e  # Остановка при ошибках

# Переменные
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_DIR="$HOME/python"
OLLAMA_DIR="$HOME/.local/share/ollama"
LOCAL_BIN="$HOME/.local/bin"

# Функции логирования
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️  $1"
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1" 
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1" >&2
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1" >&2
}

# Скачивание проекта с GitHub
download_project() {
    log_info "📥 Скачивание проекта DiscoCoop..."
    
    # Проверяем есть ли уже проект
    if [ -f "main.py" ] && [ -f "config/config.example.yaml" ]; then
        log_info "Проект уже существует, пропускаем скачивание"
        return 0
    fi
    
    # Клонируем репозиторий (создастся директория DiscoCoop)
    local repo_url="https://github.com/ArtemKiyashko/DiscoCoop.git"
    
    log_info "Клонируем репозиторий..."
    if ! git clone "$repo_url"; then
        log_error "Не удалось клонировать репозиторий с GitHub"
        exit 1
    fi
    
    # Переходим в директорию проекта
    cd DiscoCoop
    
    log_success "Проект скачан, перешли в директорию DiscoCoop"
}

# Проверка установленного Python
is_python_installed() {
    [ -x "$PYTHON_DIR/bin/python3" ] && return 0 || return 1
}

# Установка переносимого Python
install_python() {
    if is_python_installed; then
        log_success "Python уже установлен: $($PYTHON_DIR/bin/python3 --version)"
        return 0
    fi
    
    log_info "📥 Загрузка переносимого Python..."
    cd /tmp
    
    if curl -L "https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz" -o python.tar.gz; then
        log_info "📂 Распаковка Python..."
        tar -xzf python.tar.gz -C "$HOME"
        
        # Создаем симлинки
        ln -sf "$PYTHON_DIR/bin/python3" "$PYTHON_DIR/bin/python" 2>/dev/null || true
        
        # Добавляем в PATH
        mkdir -p "$LOCAL_BIN"
        export PATH="$PYTHON_DIR/bin:$LOCAL_BIN:$PATH"
        
        # Обновляем shell конфигурации  
        for config in ~/.bashrc ~/.profile ~/.zshrc; do
            if [ -f "$config" ] && ! grep -q "disco-coop Python" "$config"; then
                echo "" >> "$config"
                echo "# Added by disco-coop installer" >> "$config" 
                echo "export PATH=\"$PYTHON_DIR/bin:$LOCAL_BIN:\$PATH\"" >> "$config"
            fi
        done
        
        log_success "Python установлен: $($PYTHON_DIR/bin/python3 --version)"
        rm -f python.tar.gz
    else
        log_error "Не удалось загрузить Python"
        exit 1
    fi
}

# Создание инструментов для работы с изображениями  
create_image_tools() {
    log_info "🖼️  Настройка инструментов для изображений (Steam Deck)..."
    
    mkdir -p "$LOCAL_BIN"
    
    # Проверяем необходимые инструменты для Steam Deck
    local missing_tools=()
    
    if ! command -v spectacle &> /dev/null; then
        missing_tools+=("spectacle")
    else
        log_success "✅ Spectacle найден"
    fi
    
    if ! command -v xdotool &> /dev/null; then
        missing_tools+=("xdotool")
    else
        log_success "✅ xdotool найден"
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        log_warning "❌ Отсутствуют инструменты: ${missing_tools[*]}"
        log_info "💡 Установите: sudo pacman -S ${missing_tools[*]}"
    fi
    
    # Копируем готовые инструменты из папки tools/
    echo "🔧 Копируем инструменты для работы с изображениями..."
    
    if [ -f "tools/screenshot-tool" ]; then
        cp "tools/screenshot-tool" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/screenshot-tool"
        echo "✅ screenshot-tool установлен"
    else
        log_error "❌ Файл tools/screenshot-tool не найден"
        return 1
    fi
    
    if [ -f "tools/image-convert" ]; then
        cp "tools/image-convert" "$LOCAL_BIN/"
        chmod +x "$LOCAL_BIN/image-convert"
        echo "✅ image-convert установлен"
    else
        log_error "❌ Файл tools/image-convert не найден"
        return 1
    fi
    
    log_success "Инструменты для изображений настроены"
}

# Установка Ollama
install_ollama() {
    log_info "🤖 Установка Ollama..."
    
    if [ -f "$OLLAMA_DIR/bin/ollama" ]; then
        log_info "Ollama уже установлен"
        return 0
    fi
    
    mkdir -p "$OLLAMA_DIR/bin"
    
    # Определяем архитектуру
    local arch
    case "$(uname -m)" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) 
            log_error "Неподдерживаемая архитектура: $(uname -m)"
            exit 1
            ;;
    esac
    
    log_info "Загружаем Ollama для $arch..."
    
    # Загружаем бинарник Ollama
    if curl -L "https://github.com/ollama/ollama/releases/latest/download/ollama-linux-$arch" -o "$OLLAMA_DIR/bin/ollama"; then
        chmod +x "$OLLAMA_DIR/bin/ollama"
        log_success "Ollama установлен: $($OLLAMA_DIR/bin/ollama --version 2>/dev/null | head -1 || echo 'готов к запуску')"
    else
        log_error "Не удалось загрузить Ollama"
        exit 1
    fi
    
    # Создаем конфигурационный файл из шаблона
    mkdir -p "$HOME/.ollama"
    if [ -f "templates/ollama-config.json" ]; then
        sed "s|HOME_PLACEHOLDER|$HOME|g" templates/ollama-config.json > "$HOME/.ollama/config.json"
    else
        log_error "Шаблон ollama-config.json не найден"
        exit 1
    fi
    
    log_success "Ollama настроен"
}

# Установка проекта
install_project() {
    log_info "📦 Настройка проекта..."
    
    # Проверяем наличие основных файлов
    if [ ! -f "main.py" ]; then
        log_error "Файл main.py не найден. Убедитесь, что вы находитесь в правильной директории."
        exit 1
    fi
    
    export PATH="$PYTHON_DIR/bin:$PATH"
    
    # Создаем виртуальное окружение
    local venv_dir="venv"
    if [ ! -d "$venv_dir" ]; then
        log_info "Создаем виртуальное окружение..."
        $PYTHON_DIR/bin/python3 -m venv "$venv_dir"
    fi
    
    # Активируем виртуальное окружение
    log_info "Активируем виртуальное окружение..."
    source "$venv_dir/bin/activate"
    
    # Обновляем pip в виртуальном окружении
    log_info "Обновляем pip..."
    python -m pip install --upgrade pip
    
    # Устанавливаем зависимости Python
    if [ -f "requirements.txt" ]; then
        log_info "Устанавливаем основные зависимости из requirements.txt..."
        # Сначала устанавливаем основные пакеты без проблемных
        pip install \
            "python-telegram-bot>=22.0" \
            "aiohttp>=3.8.0" \
            "pyyaml>=6.0" \
            "loguru>=0.7.0" \
            "Pillow>=9.0.0" \
            "requests>=2.28.0" \
            "opencv-python-headless>=4.5.0" \
            "numpy>=1.20.0" \
            "six>=1.16.0"
            
        # Пытаемся установить проблемные пакеты отдельно
        log_info "Устанавливаем игровые контроллеры..."
        
        # Устанавливаем базовые зависимости для PyAutoGUI
        pip install "pillow" "python3-xlib" || true
        
        # Устанавливаем PyAutoGUI без evdev (только базовые зависимости)
        if pip install --no-deps "PyAutoGUI>=0.9.50"; then
            log_success "PyAutoGUI установлен (без evdev)"
        else
            log_warning "PyAutoGUI не удалось установить - игровой ввод будет недоступен"
        fi
        
        if pip install "pynput>=1.7.0"; then
            log_success "pynput установлен"
        else
            log_warning "pynput не удалось установить - некоторые функции будут недоступны"
        fi
    else
        log_info "Устанавливаем базовые зависимости..."
        pip install \
            "python-telegram-bot>=22.0" \
            "aiohttp" \
            "pillow" \
            "requests" \
            "loguru" \
            "pyyaml"
            
        # Пытаемся установить проблемные пакеты отдельно
        log_info "Устанавливаем игровые контроллеры..."
        pip install "python3-xlib" || true
        pip install --no-deps "PyAutoGUI" || log_warning "PyAutoGUI не удалось установить"
        pip install "pynput" || log_warning "pynput не удалось установить"
    fi
    
    # Создаем конфигурационный файл если его нет
    if [ ! -f "config/config.yaml" ]; then
        log_info "Создаем config/config.yaml..."
        if [ -f "config/config.example.yaml" ]; then
            cp config/config.example.yaml config/config.yaml
            log_warning "⚠️  Настройте config/config.yaml с вашими параметрами!"
        else
            log_error "config/config.example.yaml не найден!"
            exit 1
        fi
    fi
    
    # Создаем директории
    mkdir -p screenshots logs
    
    # Копируем тестовый скрипт из шаблона
    if [ -f "templates/test_setup.py" ]; then
        cp templates/test_setup.py .
        chmod +x test_setup.py
    else
        log_warning "Шаблон test_setup.py не найден, тест недоступен"
    fi
    
    log_success "Проект настроен"
}

# Настройка systemd сервисов
setup_services() {
    log_info "🔧 Настройка сервисов..."
    
    local current_dir="$(pwd)"
    local user_service_dir="$HOME/.config/systemd/user"
    
    mkdir -p "$user_service_dir"
    
    # Создаем сервис Ollama из шаблона
    if [ -f "templates/ollama.service" ]; then
        sed -e "s|OLLAMA_DIR_PLACEHOLDER|$OLLAMA_DIR|g" \
            -e "s|HOME_PLACEHOLDER|$HOME|g" \
            templates/ollama.service > "$user_service_dir/ollama.service"
    else
        log_error "Шаблон ollama.service не найден"
        exit 1
    fi

    # Создаем сервис бота из шаблона
    if [ -f "templates/disco-coop-bot.service" ]; then
        sed -e "s|PYTHON_DIR_PLACEHOLDER|$PYTHON_DIR|g" \
            -e "s|CURRENT_DIR_PLACEHOLDER|$current_dir|g" \
            -e "s|LOCAL_BIN_PLACEHOLDER|$LOCAL_BIN|g" \
            -e "s|HOME_PLACEHOLDER|$HOME|g" \
            templates/disco-coop-bot.service > "$user_service_dir/disco-coop-bot.service"
    else
        log_error "Шаблон disco-coop-bot.service не найден"
        exit 1
    fi

    # Перезагружаем systemd
    systemctl --user daemon-reload
    
    log_success "Сервисы настроены"
    log_info "Для запуска используйте:"
    log_info "  systemctl --user enable --now ollama"
    log_info "  systemctl --user enable --now disco-coop-bot"
}

# Финальная проверка
final_check() {
    log_info "🔍 Финальная проверка..."
    
    local all_ok=true
    
    # Проверяем Python
    if [ -f "$PYTHON_DIR/bin/python3" ]; then
        log_success "Python: готов"
    else
        log_error "Python: не найден"
        all_ok=false
    fi
    
    # Проверяем виртуальное окружение
    if [ -f "venv/bin/python" ]; then
        log_success "Виртуальное окружение: готово"
    else
        log_error "Виртуальное окружение: не найдено"
        all_ok=false
    fi
    
    # Проверяем Ollama
    if [ -f "$OLLAMA_DIR/bin/ollama" ]; then
        log_success "Ollama: готов"
    else
        log_error "Ollama: не найден"
        all_ok=false
    fi
    
    # Проверяем инструменты
    for tool in screenshot-tool image-convert; do
        if [ -f "$LOCAL_BIN/$tool" ]; then
            log_success "$tool: готов"
        else
            log_error "$tool: не найден"
            all_ok=false
        fi
    done
    
    # Проверяем файлы проекта
    for file in main.py config/config.yaml; do
        if [ -f "$file" ]; then
            log_success "$file: найден"
        else
            log_warning "$file: требует настройки"
        fi
    done
    
    if $all_ok; then
        log_success "🎉 Установка завершена успешно!"
        echo
        echo "📝 Следующие шаги:"
        echo "1. Настройте config/config.yaml с токеном бота"
        echo "2. Запустите тест: ./test_setup.py"
        echo "3. Запустите сервисы:"
        echo "   systemctl --user enable --now ollama"
        echo "   systemctl --user enable --now disco-coop-bot"
        echo "4. Проверьте статус: systemctl --user status ollama disco-coop-bot"
        echo
    else
        log_error "⚠️  Установка завершена с ошибками"
        return 1
    fi
}

# Основная логика
main() {
    echo "🎮 Disco Coop - Установка для Steam Deck"
    echo "=========================================="
    echo
    
    # Проверяем права
    if [ "$EUID" -eq 0 ]; then
        log_error "Не запускайте от root! Используйте обычного пользователя."
        exit 1
    fi
    
    # Проверяем наличие необходимых инструментов
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден. Установите curl для продолжения."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        log_error "git не найден. Установите git для продолжения."
        exit 1
    fi
    
    # Проверяем системные зависимости для PyAutoGUI на Steam Deck
    if [ -f "/etc/steamos-release" ] || [ -f "/etc/holo-release" ]; then
        log_info "Обнаружен Steam Deck. Проверяем системные зависимости..."
        if ! pkg-config --exists x11 xext xtst; then
            log_warning "⚠️  Отсутствуют системные библиотеки для PyAutoGUI"
            log_info "💡 Для полной функциональности установите:"
            log_info "   sudo steamos-readonly disable"
            log_info "   sudo pacman -S libx11 libxext libxtst python-dev"
            log_info "   sudo steamos-readonly enable"
        fi
    fi
    
    # Создаем необходимые директории
    mkdir -p "$PYTHON_DIR" "$OLLAMA_DIR" "$LOCAL_BIN"
    
    # Добавляем в PATH
    export PATH="$PYTHON_DIR/bin:$OLLAMA_DIR/bin:$LOCAL_BIN:$PATH"
    
    # Скачиваем проект если его нет
    download_project
    
    # Выполняем установку по этапам
    log_info "🚀 Начинаем установку..."
    
    install_python
    create_image_tools  
    install_ollama
    install_project
    setup_services
    
    # Финальная проверка
    final_check
    
    echo
    log_success "✨ Готово! Теперь настройте config/config.yaml и запустите сервисы."
}

# Обработка аргументов командной строки
case "${1:-}" in
    --help|-h)
        echo "Использование: $0 [опции]"
        echo
        echo "Опции:"
        echo "  --help, -h     Показать эту справку"
        echo "  --test         Запустить тест окружения"
        echo "  --clean        Очистить установку"
        echo "  --reinstall    Переустановить все компоненты"
        echo
        exit 0
        ;;
    --test)
        if [ -f "test_setup.py" ]; then
            exec "$PYTHON_DIR/bin/python3" test_setup.py
        else
            log_error "test_setup.py не найден. Сначала выполните установку."
            exit 1
        fi
        ;;
    --clean)
        log_info "🗑️  Очистка установки..."
        rm -rf "$PYTHON_DIR" "$OLLAMA_DIR" "$LOCAL_BIN"
        rm -f test_setup.py
        rm -rf templates  # Удаляем временные шаблоны
        systemctl --user stop ollama disco-coop-bot 2>/dev/null || true
        systemctl --user disable ollama disco-coop-bot 2>/dev/null || true
        rm -f "$HOME/.config/systemd/user/ollama.service"
        rm -f "$HOME/.config/systemd/user/disco-coop-bot.service"
        systemctl --user daemon-reload
        log_success "Очистка завершена"
        exit 0
        ;;
    --reinstall)
        log_info "� Переустановка..."
        main
        exit $?
        ;;
    "")
        main
        exit $?
        ;;
    *)
        log_error "Неизвестная опция: $1"
        log_info "Используйте --help для справки"
        exit 1
        ;;
esac
