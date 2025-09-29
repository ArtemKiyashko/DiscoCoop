#!/bin/bash

# Скрипт для установки инструментов скриншотов альтернативными методами
# Специально для Steam Deck

echo "🖼️  Установка инструментов для скриншотов - Steam Deck"
echo "=================================================="

# Проверяем что уже доступно
echo "🔍 Проверка доступных команд..."
MISSING=""
for cmd in convert xwd import; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING="$MISSING $cmd"
        echo "❌ $cmd не найден"
    else
        echo "✅ $cmd доступен"
    fi
done

if [ -z "$MISSING" ]; then
    echo "🎉 Все инструменты уже установлены!"
    exit 0
fi

# Создаем директорию для локальных бинарников
mkdir -p "$HOME/.local/bin"

echo ""
echo "📦 Установка альтернативными методами..."

# Метод 1: Flatpak (рекомендуемый для Steam Deck)
if command -v flatpak &> /dev/null; then
    echo "🔧 Метод 1: Flatpak"
    
    if echo "$MISSING" | grep -q "convert\|import"; then
        echo "  📥 Установка ImageMagick через Flatpak..."
        if flatpak install --user -y flathub org.imagemagick.ImageMagick; then
            echo "  ✅ ImageMagick установлен через Flatpak"
            
            # Создаем wrappers
            cat > "$HOME/.local/bin/convert" << 'EOF'
#!/bin/bash
exec flatpak run org.imagemagick.ImageMagick convert "$@"
EOF
            
            cat > "$HOME/.local/bin/import" << 'EOF'
#!/bin/bash
exec flatpak run org.imagemagick.ImageMagick import "$@"
EOF
            
            chmod +x "$HOME/.local/bin/convert"
            chmod +x "$HOME/.local/bin/import"
            echo "  ✅ Wrappers созданы"
        else
            echo "  ❌ Ошибка установки через Flatpak"
        fi
    fi
else
    echo "⚠️  Flatpak недоступен"
fi

# Метод 2: Статические бинарники
echo ""
echo "🔧 Метод 2: Статические бинарники"

# ImageMagick статический
if echo "$MISSING" | grep -q "convert" && ! command -v convert &> /dev/null; then
    echo "  📥 Загрузка ImageMagick..."
    cd /tmp
    if curl -L --progress-bar "https://github.com/SoftCreatR/imei/releases/latest/download/imei-linux-x86_64" -o convert; then
        chmod +x convert
        mv convert "$HOME/.local/bin/convert"
        echo "  ✅ ImageMagick (convert) установлен"
    else
        echo "  ❌ Не удалось загрузить ImageMagick"
    fi
fi

# xwd wrapper (использует доступные инструменты)
if echo "$MISSING" | grep -q "xwd" && ! command -v xwd &> /dev/null; then
    echo "  🔧 Создание wrapper для xwd..."
    cat > "$HOME/.local/bin/xwd" << 'EOF'
#!/bin/bash
# xwd wrapper для Steam Deck

# Проверяем доступные инструменты
if command -v import &> /dev/null; then
    # Используем ImageMagick import
    exec import "$@"
elif command -v gnome-screenshot &> /dev/null; then
    # Используем gnome-screenshot
    OUTPUT="${@: -1}"
    if [[ "$OUTPUT" == *".xwd" ]]; then
        OUTPUT="${OUTPUT%.xwd}.png"
    fi
    exec gnome-screenshot -f "$OUTPUT"
elif command -v scrot &> /dev/null; then
    # Используем scrot
    exec scrot "$@"
else
    echo "❌ Нет доступных инструментов для скриншотов" >&2
    echo "💡 Установите: sudo pacman -S imagemagick xorg-xwd" >&2
    exit 1
fi
EOF
    chmod +x "$HOME/.local/bin/xwd"
    echo "  ✅ xwd wrapper создан"
fi

# Добавляем в PATH
if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
    export PATH="$HOME/.local/bin:$PATH"
    
    # Добавляем в shell configs
    for config in ~/.bashrc ~/.profile ~/.zshrc; do
        if [ -f "$config" ]; then
            if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$config"; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$config"
            fi
        fi
    done
    echo "✅ PATH обновлен"
fi

echo ""
echo "🧪 Проверка установки..."

# Финальная проверка
ALL_OK=true
for cmd in convert xwd import; do
    if command -v "$cmd" &> /dev/null; then
        echo "✅ $cmd доступен"
    else
        echo "❌ $cmd все еще недоступен"
        ALL_OK=false
    fi
done

echo ""
if [ "$ALL_OK" = true ]; then
    echo "🎉 Успешно! Все инструменты установлены"
    echo "💡 Перезайдите в терминал или выполните: source ~/.bashrc"
else
    echo "⚠️  Не все инструменты установлены"
    echo "💡 Возможные решения:"
    echo "   1. Перезагрузите Steam Deck"
    echo "   2. Попробуйте: sudo pacman -S imagemagick xorg-xwd"
    echo "   3. Или установите через Discover: ImageMagick"
fi

echo ""
echo "📋 Информация:"
echo "   Локальные бинарники: $HOME/.local/bin"
echo "   Конфигурация PATH: ~/.bashrc, ~/.profile"