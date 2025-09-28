#!/bin/bash

# Скрипт для исправления установки Ollama на Steam Deck
# Решает проблему с правами доступа к /usr/local

set -e

echo "🔧 Исправление установки Ollama на Steam Deck..."

# Создаем пользовательские директории
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.ollama"

# Определяем архитектуру
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    OLLAMA_URL="https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64"
else
    echo "❌ Неподдерживаемая архитектура: $ARCH"
    exit 1
fi

# Скачиваем Ollama напрямую
echo "📥 Загрузка Ollama..."
if curl -L "$OLLAMA_URL" -o "$HOME/.local/bin/ollama"; then
    # Проверяем, что скачался правильный файл
    if file "$HOME/.local/bin/ollama" | grep -q "ELF.*executable"; then
        chmod +x "$HOME/.local/bin/ollama"
        echo "✅ Ollama установлен в $HOME/.local/bin/ollama"
    else
        echo "❌ Скачанный файл поврежден или не является исполняемым"
        echo "🔍 Проверяем содержимое:"
        file "$HOME/.local/bin/ollama"
        echo "📄 Первые строки файла:"
        head -5 "$HOME/.local/bin/ollama"
        
        # Удаляем поврежденный файл
        rm -f "$HOME/.local/bin/ollama"
        
        # Пробуем альтернативный URL
        echo "🔄 Пробуем альтернативный метод загрузки..."
        OLLAMA_ALT_URL="https://github.com/ollama/ollama/releases/download/v0.3.12/ollama-linux-amd64"
        
        if curl -L "$OLLAMA_ALT_URL" -o "$HOME/.local/bin/ollama"; then
            if file "$HOME/.local/bin/ollama" | grep -q "ELF.*executable"; then
                chmod +x "$HOME/.local/bin/ollama"
                echo "✅ Ollama установлен (альтернативный метод)"
            else
                echo "❌ Альтернативная загрузка также не удалась"
                rm -f "$HOME/.local/bin/ollama"
                exit 1
            fi
        else
            echo "❌ Альтернативная загрузка не удалась"
            exit 1
        fi
    fi
else
    echo "❌ Не удалось загрузить Ollama"
    exit 1
fi

# Обновляем PATH
export PATH="$HOME/.local/bin:$PATH"

# Добавляем в bashrc если еще не добавлено
if ! grep -q "export PATH.*\.local/bin" ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "✅ PATH обновлен в ~/.bashrc"
fi

# Создаем символическую ссылку в текущей директории для удобства
if [ ! -f "./ollama" ]; then
    ln -s "$HOME/.local/bin/ollama" ./ollama
    echo "✅ Создана символическая ссылка ./ollama"
fi

# Проверяем установку
if "$HOME/.local/bin/ollama" --version; then
    echo "✅ Ollama успешно установлен!"
    echo "🚀 Для запуска используйте: $HOME/.local/bin/ollama serve"
    echo "📁 Или просто: ./ollama serve (в этой директории)"
else
    echo "❌ Проблема с установкой Ollama"
    exit 1
fi

echo "🎉 Исправление завершено!"