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
    chmod +x "$HOME/.local/bin/ollama"
    echo "✅ Ollama установлен в $HOME/.local/bin/ollama"
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