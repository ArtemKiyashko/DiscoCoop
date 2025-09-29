#!/bin/bash

# Disco Coop - Установочный скрипт для Steam Deck
# Полностью автономная установка без использования pacman

set -e  # Остановка при ошибках

# Переменные
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/disco-coop"
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

# Скачивание шаблонов для удаленной установки
download_templates() {
    log_info "📥 Скачивание шаблонов..."
    
    local base_url="https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/templates"
    local templates=(
        "ollama.service"
        "disco-coop-bot.service" 
        "ollama-config.json"
        "xwd-wrapper.sh"
        "convert-wrapper.sh"
        "import-wrapper.sh"
        "test_setup.py"
    )
    
    mkdir -p templates
    
    for template in "${templates[@]}"; do
        if curl -fsSL "$base_url/$template" -o "templates/$template"; then
            log_info "✅ Скачан: $template"
        else
            log_warning "⚠️  Не удалось скачать: $template"
        fi
    done
    
    # Делаем скрипты исполняемыми
    chmod +x templates/*.sh templates/test_setup.py 2>/dev/null || true
    
    log_success "Шаблоны скачаны"
}

# Очистка временных шаблонов
cleanup_templates() {
    if [ "$SCRIPT_DIR" != "$(pwd)" ]; then
        # Удаляем только если мы не в исходной директории проекта
        rm -rf templates
        log_info "Временные шаблоны удалены"
    fi
}

# Проверка идемпотентности - можно запускать многократно
check_installation() {
    local component="$1"
    case "$component" in
        "python")
            [ -x "$PYTHON_DIR/bin/python3" ] && return 0 || return 1
            ;;
        "ollama")  
            command -v ollama &> /dev/null && return 0 || return 1
            ;;
        "project")
            [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/main.py" ] && return 0 || return 1
            ;;
    esac
}

# Установка переносимого Python
install_python() {
    if check_installation "python"; then
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

# Создание альтернатив для ImageMagick и xwd
create_image_tools() {
    log_info "🖼️  Настройка инструментов для скриншотов..."
    
    mkdir -p "$LOCAL_BIN"
    
    # Проверяем доступные системные инструменты
    for tool in gnome-screenshot spectacle scrot flameshot; do
        if command -v "$tool" &> /dev/null; then
            log_info "Найден инструмент скриншотов: $tool"
            break
        fi
    done
    
    # Копируем wrapper скрипты из шаблонов
    for wrapper in xwd convert import; do
        if [ -f "templates/${wrapper}-wrapper.sh" ]; then
            cp "templates/${wrapper}-wrapper.sh" "$LOCAL_BIN/$wrapper"
            chmod +x "$LOCAL_BIN/$wrapper"
        else
            log_error "Шаблон ${wrapper}-wrapper.sh не найден"
            exit 1
        fi
    done
    
    log_success "Инструменты скриншотов настроены"
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
    
    # Обновляем pip
    log_info "Обновляем pip..."
    $PYTHON_DIR/bin/python3 -m pip install --upgrade pip --user
    
    # Устанавливаем зависимости Python
    if [ -f "requirements.txt" ]; then
        log_info "Устанавливаем зависимости из requirements.txt..."
        $PYTHON_DIR/bin/python3 -m pip install -r requirements.txt --user
    else
        log_info "Устанавливаем базовые зависимости..."
        $PYTHON_DIR/bin/python3 -m pip install --user \
            "python-telegram-bot>=20.0" \
            "python-dotenv" \
            "aiohttp" \
            "pillow" \
            "requests"
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
    
    # Проверяем Ollama
    if [ -f "$OLLAMA_DIR/bin/ollama" ]; then
        log_success "Ollama: готов"
    else
        log_error "Ollama: не найден"
        all_ok=false
    fi
    
    # Проверяем инструменты
    for tool in xwd convert import; do
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
    
    # Проверяем наличие curl
    if ! command -v curl &> /dev/null; then
        log_error "curl не найден. Установите curl для продолжения."
        exit 1
    fi
    
    # Создаем необходимые директории
    mkdir -p "$PYTHON_DIR" "$OLLAMA_DIR" "$LOCAL_BIN"
    
    # Добавляем в PATH
    export PATH="$PYTHON_DIR/bin:$OLLAMA_DIR/bin:$LOCAL_BIN:$PATH"
    
    # Скачиваем шаблоны если их нет
    if [ ! -d "templates" ]; then
        download_templates
    fi
    
    # Выполняем установку по этапам
    log_info "🚀 Начинаем установку..."
    
    install_python
    create_image_tools  
    install_ollama
    install_project
    setup_services
    
    # Финальная проверка
    final_check
    
    # Очищаем временные шаблоны
    cleanup_templates
    
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
