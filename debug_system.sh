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

echo -e "\n3. Проверяем инструменты для Steam Deck:"
for tool in spectacle xdotool; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool найден"
    else
        echo "❌ $tool не найден - требуется для работы"
    fi
done

echo -e "\n3.1. Дополнительные инструменты:"
for tool in grim scrot; do
    if command -v "$tool" &> /dev/null; then
        echo "✅ $tool найден (fallback)"
    else
        echo "⚪ $tool не найден (не обязательно)"
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

echo -e "\n5. Тестируем поиск окна игры:"
if command -v xdotool &> /dev/null; then
    DISCO_WINDOWS=$(xdotool search --name "Disco Elysium" 2>/dev/null || true)
    if [ -n "$DISCO_WINDOWS" ]; then
        echo "✅ Найдено окно Disco Elysium: $DISCO_WINDOWS"
    else
        echo "⚪ Окно Disco Elysium не найдено (это нормально если игра не запущена)"
    fi
else
    echo "❌ xdotool не установлен - не сможем найти окно игры"
fi

echo -e "\n6. Тестируем создание скриншота:"
if [ -f "$HOME/.local/bin/screenshot-tool" ]; then
    echo "🕒 Запускаем screenshot-tool (таймаут 10 сек)..."
    if timeout 10 "$HOME/.local/bin/screenshot-tool" /tmp/test_screenshot.png "Disco Elysium" 2>&1; then
        if [ -f "/tmp/test_screenshot.png" ]; then
            echo "✅ Скриншот создан успешно"
            ls -lh /tmp/test_screenshot.png
            rm -f /tmp/test_screenshot.png
        else
            echo "❌ Файл скриншота не создан"
        fi
    else
        echo "❌ Команда screenshot-tool завершилась с ошибкой или превысила таймаут"
        echo "💡 Попробуйте вручную: screenshot-tool /tmp/manual_test.png"
    fi
else
    echo "❌ screenshot-tool не найден"
fi

echo -e "\n7. Тестируем LLM модель:"
if [ -f "test_llm_model.py" ]; then
    echo "🧪 Запускаем тест модели (может занять до 2 минут)..."
    if python3 test_llm_model.py; then
        echo "✅ LLM модель работает корректно"
    else
        echo "❌ Проблемы с LLM моделью"
        echo "💡 Попробуйте более легкую модель: ollama pull llama3.2:1b"
    fi
else
    echo "❌ test_llm_model.py не найден"
fi