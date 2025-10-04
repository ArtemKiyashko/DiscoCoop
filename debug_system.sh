#!/bin/bash

echo "🔍 Диагностика Ollama и LLM..."

# Проверяем запущен ли Ollama
echo "1. Проверяем Ollama сервер:"
if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
    echo "✅ Ollama сервер доступен"
    
    echo -e "\n2. Список доступных моделей:"
    curl -s http://localhost:11434/api/tags | python3 -m json.tool
    
else
    echo "❌ Ollama сервер недоступен"
    echo "💡 Попробуйте:"
    echo "   systemctl --user start ollama"
    echo "   или"  
    echo "   ~/.local/share/ollama/bin/ollama serve &"
fi

echo -e "\n3. Проверяем инструменты для скриншотов:"
for tool in grim gnome-screenshot spectacle scrot flameshot; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool найден"
    else
        echo "❌ $tool не найден"
    fi
done

echo -e "\n4. Проверяем наши инструменты:"
for tool in screenshot-tool image-convert; do
    if [ -f "$HOME/.local/bin/$tool" ]; then
        echo "✅ $tool готов"
    else
        echo "❌ $tool не найден"
    fi
done

echo -e "\n5. Тестируем создание скриншота:"
if [ -f "$HOME/.local/bin/screenshot-tool" ]; then
    if timeout 5 "$HOME/.local/bin/screenshot-tool" /tmp/test_screenshot.png; then
        if [ -f "/tmp/test_screenshot.png" ]; then
            echo "✅ Скриншот создан успешно"
            ls -lh /tmp/test_screenshot.png
            rm -f /tmp/test_screenshot.png
        else
            echo "❌ Файл скриншота не создан"
        fi
    else
        echo "❌ Команда screenshot-tool завершилась с ошибкой"
    fi
else
    echo "❌ screenshot-tool не найден"
fi