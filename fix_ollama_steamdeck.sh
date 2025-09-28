#!/bin/bash

# Скрипт для исправления установки Ollama на Steam Deck
# Решает проблему с правами доступа к /usr/local

set -e

echo "🔧 Исправление установки Ollama на Steam Deck..."

# Создаем пользовательские директории
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.ollama"

# Определяем архитектуру и URL
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    OLLAMA_VERSION="v0.12.3"
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tgz"
else
    echo "❌ Неподдерживаемая архитектура: $ARCH"
    exit 1
fi

# Скачиваем и устанавливаем Ollama
echo "📥 Загрузка Ollama ${OLLAMA_VERSION}..."
if curl -L "$OLLAMA_URL" -o "/tmp/ollama.tgz"; then
    echo "📦 Распаковка архива..."
    
    # Создаем временную директорию
    mkdir -p /tmp/ollama_extract
    
    if tar -xzf /tmp/ollama.tgz -C /tmp/ollama_extract; then
        # Ищем исполняемый файл
        if [ -f "/tmp/ollama_extract/bin/ollama" ]; then
            cp "/tmp/ollama_extract/bin/ollama" "$HOME/.local/bin/ollama"
        elif [ -f "/tmp/ollama_extract/ollama" ]; then
            cp "/tmp/ollama_extract/ollama" "$HOME/.local/bin/ollama"
        else
            echo "❌ Не найден исполняемый файл в архиве"
            echo "� Содержимое архива:"
            find /tmp/ollama_extract -type f
            rm -rf /tmp/ollama_extract /tmp/ollama.tgz
            exit 1
        fi
        
        # Проверяем корректность файла
        if file "$HOME/.local/bin/ollama" | grep -q "ELF.*executable"; then
            chmod +x "$HOME/.local/bin/ollama"
            echo "✅ Ollama установлен в $HOME/.local/bin/ollama"
        else
            echo "❌ Файл не является исполняемым"
            file "$HOME/.local/bin/ollama"
            rm -f "$HOME/.local/bin/ollama"
            exit 1
        fi
        
        # Очищаем временные файлы
        rm -rf /tmp/ollama_extract /tmp/ollama.tgz
    else
        echo "❌ Не удалось распаковать архив"
        rm -f /tmp/ollama.tgz
        exit 1
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