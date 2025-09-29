#!/bin/bash

# Disco Coop - Установочный скрипт для Steam Deck
# Полностью автономная установка без использования pacman

set -e  # Остановка при ошибках

# Переменные
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/disco-coop"
PYTHON_DIR="$HOME/python"
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
    local screenshot_tool=""
    for tool in gnome-screenshot spectacle scrot flameshot; do
        if command -v "$tool" &> /dev/null; then
            screenshot_tool="$tool"
            log_info "Найден инструмент скриншотов: $tool"
            break
        fi
    done
    
    # Создаем wrapper для xwd
    cat > "$LOCAL_BIN/xwd" << 'EOF'
#!/bin/bash
# xwd replacement for Steam Deck

OUTPUT="${*: -1}"
[ -z "$OUTPUT" ] && OUTPUT="screenshot.png"

# Ensure .png extension
case "$OUTPUT" in
    *.png) ;;
    *.xwd) OUTPUT="${OUTPUT%.xwd}.png" ;;
    *) OUTPUT="$OUTPUT.png" ;;
esac

# Try available screenshot tools
if command -v gnome-screenshot &> /dev/null; then
    gnome-screenshot -f "$OUTPUT"
elif command -v spectacle &> /dev/null; then
    spectacle -b -n -o "$OUTPUT"  
elif command -v scrot &> /dev/null; then
    scrot "$OUTPUT"
elif command -v flameshot &> /dev/null; then
    flameshot full -p "$(dirname "$OUTPUT")" -f "$(basename "$OUTPUT")"
else
    echo "⚠️  Нет доступных инструментов для скриншотов" >&2
    echo "💡 Создается заглушка..." >&2
    # Create a simple 1x1 PNG as fallback
    python3 -c "
import struct
def create_png():
    # Minimal 1x1 red PNG
    data = b'\\x89PNG\\r\\n\\x1a\\n\\x00\\x00\\x00\\rIHDR\\x00\\x00\\x00\\x01\\x00\\x00\\x00\\x01\\x08\\x02\\x00\\x00\\x00\\x90wS\\xde\\x00\\x00\\x00\\x0cIDATx\\x9cc\\xf8\\x0f\\x00\\x00\\x01\\x00\\x01\\x00\\x18\\xdd\\x8d\\xb4\\x00\\x00\\x00\\x00IEND\\xaeB\`\\x82'
    return data
with open('$OUTPUT', 'wb') as f:
    f.write(create_png())
"
fi
EOF
    chmod +x "$LOCAL_BIN/xwd"
    
    # Создаем wrapper для convert  
    cat > "$LOCAL_BIN/convert" << 'EOF'
#!/bin/bash
# ImageMagick convert replacement

# Simple convert functionality using Python
if [[ "$*" == *"-size"* && "$*" == *"xc:"* ]]; then
    # Handle: convert -size 100x100 xc:red output.png
    OUTPUT="${*: -1}"
    python3 -c "
import struct
def create_png():
    # Minimal 1x1 PNG
    data = b'\\x89PNG\\r\\n\\x1a\\n\\x00\\x00\\x00\\rIHDR\\x00\\x00\\x00\\x01\\x00\\x00\\x00\\x01\\x08\\x02\\x00\\x00\\x00\\x90wS\\xde\\x00\\x00\\x00\\x0cIDATx\\x9cc\\xf8\\x0f\\x00\\x00\\x01\\x00\\x01\\x00\\x18\\xdd\\x8d\\xb4\\x00\\x00\\x00\\x00IEND\\xaeB\`\\x82'
    return data
with open('$OUTPUT', 'wb') as f:
    f.write(create_png())
"
elif command -v ffmpeg &> /dev/null && [ $# -ge 2 ]; then
    # Use ffmpeg for actual conversions
    INPUT=""
    OUTPUT=""
    for arg in "$@"; do
        if [[ -f "$arg" ]]; then
            INPUT="$arg"
        elif [[ "$arg" == *"."* && "$arg" != "-"* ]]; then
            OUTPUT="$arg" 
        fi
    done
    
    if [[ -n "$INPUT" && -n "$OUTPUT" ]]; then
        ffmpeg -y -i "$INPUT" "$OUTPUT" 2>/dev/null
    else
        echo "⚠️  Упрощенная поддержка convert" >&2
    fi
else
    echo "⚠️  convert: базовая поддержка" >&2
    echo "💡 Для полной поддержки установите ffmpeg" >&2
fi
EOF
    chmod +x "$LOCAL_BIN/convert"
    
    # Wrapper для import
    cat > "$LOCAL_BIN/import" << 'EOF'
#!/bin/bash  
# ImageMagick import replacement
exec "$HOME/.local/bin/xwd" "$@"
EOF
    chmod +x "$LOCAL_BIN/import"
    
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
    
    # Создаем конфигурационный файл
    mkdir -p "$HOME/.ollama"
    cat > "$HOME/.ollama/config.json" << EOF
{
  "origins": ["*"],
  "models_path": "$HOME/.ollama/models"
}
EOF
    
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
    
    # Создаем простой тестовый скрипт
    cat > test_setup.py << 'EOF'
#!/usr/bin/env python3
"""Тест настройки окружения"""

import sys
import os

def test_imports():
    """Тестируем импорты"""
    try:
        import telegram
        print(f"✅ python-telegram-bot: {telegram.__version__}")
    except ImportError as e:
        print(f"❌ python-telegram-bot: {e}")
        return False
    
    try:
        import dotenv
        print("✅ python-dotenv: OK")
    except ImportError as e:
        print(f"❌ python-dotenv: {e}")
        return False
        
    try:
        import aiohttp
        print("✅ aiohttp: OK")
    except ImportError as e:
        print(f"❌ aiohttp: {e}")
        return False
        
    try:
        from PIL import Image
        print("✅ Pillow: OK")
    except ImportError as e:
        print(f"❌ Pillow: {e}")
        return False
        
    return True

def test_ollama():
    """Тестируем Ollama"""
    ollama_path = os.path.expanduser("~/.local/share/ollama/bin/ollama")
    if os.path.exists(ollama_path):
        print(f"✅ Ollama найден: {ollama_path}")
        return True
    else:
        print(f"❌ Ollama не найден: {ollama_path}")
        return False

def test_tools():
    """Тестируем инструменты"""
    tools_ok = True
    
    for tool in ["xwd", "convert", "import"]:
        tool_path = os.path.expanduser(f"~/.local/bin/{tool}")
        if os.path.exists(tool_path):
            print(f"✅ {tool}: {tool_path}")
        else:
            print(f"❌ {tool}: не найден")
            tools_ok = False
            
    return tools_ok

if __name__ == "__main__":
    print("🧪 Тестирование настройки...")
    print("\n📦 Python пакеты:")
    imports_ok = test_imports()
    
    print("\n🤖 Ollama:")
    ollama_ok = test_ollama()
    
    print("\n🛠️  Инструменты:")
    tools_ok = test_tools()
    
    print("\n" + "="*50)
    if imports_ok and ollama_ok and tools_ok:
        print("🎉 Все компоненты готовы!")
        sys.exit(0)
    else:
        print("⚠️  Некоторые компоненты требуют внимания")
        sys.exit(1)
EOF
    
    chmod +x test_setup.py
    
    log_success "Проект настроен"
}

# Настройка systemd сервисов
setup_services() {
    log_info "🔧 Настройка сервисов..."
    
    local current_dir="$(pwd)"
    local user_service_dir="$HOME/.config/systemd/user"
    
    mkdir -p "$user_service_dir"
    
    # Сервис Ollama
    cat > "$user_service_dir/ollama.service" << EOF
[Unit]
Description=Ollama Server
After=network.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=$OLLAMA_DIR/bin/ollama serve
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=HOME=$HOME
WorkingDirectory=$HOME
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

    # Сервис бота
    cat > "$user_service_dir/disco-coop-bot.service" << EOF
[Unit]
Description=Disco Coop Telegram Bot
After=ollama.service
Requires=ollama.service

[Service]
Type=simple
ExecStart=$PYTHON_DIR/bin/python3 $current_dir/main.py
Environment=PATH=$PYTHON_DIR/bin:$LOCAL_BIN:\$PATH
Environment=HOME=$HOME
WorkingDirectory=$current_dir
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF

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
    
    # Выполняем установку по этапам
    log_info "🚀 Начинаем установку..."
    
    if ! check_installation; then
        log_info "Выполняем полную установку..."
        
        install_python
        create_image_tools  
        install_ollama
        install_project
        setup_services
        
        # Помечаем как установленную
        touch "$INSTALL_MARKER"
        echo "$(date '+%Y-%m-%d %H:%M:%S')" > "$INSTALL_MARKER"
    else
        log_info "Система уже установлена. Обновляем компоненты..."
        
        # При повторном запуске только обновляем проект
        install_project
        setup_services
    fi
    
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
        rm -f "$INSTALL_MARKER" test_setup.py
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
        rm -f "$INSTALL_MARKER"
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
