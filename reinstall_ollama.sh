#!/bin/bash

# Скрипт для очистки и переустановки Ollama на Steam Deck

echo "🧹 Очистка поврежденной установки Ollama..."

# Удаляем старые файлы
rm -f "$HOME/.local/bin/ollama"
rm -rf "$HOME/.ollama"

# Создаем директории заново
mkdir -p "$HOME/.local/bin"
mkdir -p "$HOME/.ollama"

echo "📥 Переустановка Ollama..."

# Определяем архитектуру
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    # Актуальные URL для загрузки Ollama
    OLLAMA_VERSION="v0.12.3"
    OLLAMA_URL="https://github.com/ollama/ollama/releases/download/${OLLAMA_VERSION}/ollama-linux-amd64.tgz"
else
    echo "❌ Неподдерживаемая архитектура: $ARCH"
    exit 1
fi

# Скачиваем и распаковываем Ollama
echo "🔄 Загружаем Ollama ${OLLAMA_VERSION}..."

if curl -L --fail --silent --show-error "$OLLAMA_URL" -o "/tmp/ollama.tgz"; then
    echo "� Распаковываем архив..."
    
    # Распаковываем в временную директорию
    mkdir -p /tmp/ollama_extract
    if tar -xzf /tmp/ollama.tgz -C /tmp/ollama_extract; then
        # Ищем исполняемый файл ollama
        if [ -f "/tmp/ollama_extract/bin/ollama" ]; then
            cp "/tmp/ollama_extract/bin/ollama" "$HOME/.local/bin/ollama"
        elif [ -f "/tmp/ollama_extract/ollama" ]; then
            cp "/tmp/ollama_extract/ollama" "$HOME/.local/bin/ollama"
        else
            echo "❌ Не найден исполняемый файл ollama в архиве"
            ls -la /tmp/ollama_extract/
            exit 1
        fi
        
        # Проверяем, что файл корректный
        if file "$HOME/.local/bin/ollama" | grep -q "ELF.*executable"; then
            chmod +x "$HOME/.local/bin/ollama"
            echo "✅ Ollama успешно установлен!"
        else
            echo "❌ Файл не является исполняемым"
            file "$HOME/.local/bin/ollama"
            exit 1
        fi
        
        # Очищаем временные файлы
        rm -rf /tmp/ollama_extract /tmp/ollama.tgz
    else
        echo "❌ Не удалось распаковать архив"
        exit 1
    fi
else
    echo "❌ Не удалось загрузить Ollama"
    exit 1
fi

# Финальная проверка
if [ ! -f "$HOME/.local/bin/ollama" ]; then
    echo "❌ Не удалось загрузить Ollama ни с одного URL"
    exit 1
fi

# Проверяем тип файла
echo "🔍 Проверка загруженного файла:"
file "$HOME/.local/bin/ollama"

# Проверяем размер файла (должен быть больше 1MB)
size=$(stat -f%z "$HOME/.local/bin/ollama" 2>/dev/null || stat -c%s "$HOME/.local/bin/ollama" 2>/dev/null)
if [ "$size" -lt 1048576 ]; then
    echo "❌ Файл слишком маленький ($size байт), возможно загрузилась страница ошибки"
    echo "📄 Содержимое файла:"
    head -10 "$HOME/.local/bin/ollama"
    exit 1
fi

echo "✅ Размер файла: $size байт"

# Обновляем PATH
export PATH="$HOME/.local/bin:$PATH"

# Добавляем в bashrc если еще не добавлено
if ! grep -q "export PATH.*\.local/bin" ~/.bashrc; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
    echo "✅ PATH обновлен в ~/.bashrc"
fi

# Создаем символическую ссылку в текущей директории
if [ ! -f "./ollama" ]; then
    ln -sf "$HOME/.local/bin/ollama" ./ollama
    echo "✅ Создана символическая ссылка ./ollama"
fi

# Тестируем работу
echo "🧪 Тестирование Ollama..."
if "$HOME/.local/bin/ollama" --version; then
    echo "✅ Ollama работает корректно!"
    
    # Пробуем запустить сервер
    echo "🚀 Запуск тестового сервера..."
    timeout 10s "$HOME/.local/bin/ollama" serve &
    sleep 3
    
    # Проверяем, что сервер запустился
    if curl -s http://localhost:11434/api/tags >/dev/null; then
        echo "✅ Сервер Ollama запустился успешно!"
        pkill -f "ollama serve" 2>/dev/null || true
    else
        echo "⚠️  Сервер не отвечает, но бинарный файл корректный"
    fi
    
    echo "🎉 Переустановка Ollama завершена успешно!"
    echo "📝 Теперь вы можете использовать:"
    echo "   $HOME/.local/bin/ollama serve"
    echo "   ./ollama serve"
else
    echo "❌ Ollama не работает"
    exit 1
fi