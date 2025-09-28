#!/bin/bash

# Скрипт для проверки актуальности установочных файлов

echo "🔍 Проверка актуальности скриптов Disco Coop"
echo "============================================"

REPO_URL="https://api.github.com/repos/ArtemKiyashko/DiscoCoop"
INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/install.sh"
FIX_SCRIPT_URL="https://raw.githubusercontent.com/ArtemKiyashko/DiscoCoop/main/fix_steamdeck_pacman.sh"

echo "📡 Получение информации о последнем коммите..."
if command -v curl &> /dev/null; then
    LAST_COMMIT=$(curl -s "$REPO_URL/commits/main" | grep '"sha"' | head -1 | cut -d'"' -f4 | cut -c1-7)
    LAST_COMMIT_DATE=$(curl -s "$REPO_URL/commits/main" | grep '"date"' | head -1 | cut -d'"' -f4)
    
    echo "✅ Последний коммит: $LAST_COMMIT"
    echo "📅 Дата: $LAST_COMMIT_DATE"
else
    echo "❌ curl не найден, невозможно проверить актуальность"
    exit 1
fi

echo ""
echo "🔄 Загрузка свежих версий скриптов..."

echo "📥 Скачивание install.sh..."
curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" \
  "$INSTALL_SCRIPT_URL?$(date +%s)" -o install_fresh.sh

echo "📥 Скачивание fix_steamdeck_pacman.sh..."
curl -fsSL -H "Cache-Control: no-cache" -H "Pragma: no-cache" \
  "$FIX_SCRIPT_URL?$(date +%s)" -o fix_fresh.sh

chmod +x install_fresh.sh fix_fresh.sh

echo ""
echo "✅ Свежие версии скриптов загружены:"
echo "  - install_fresh.sh"
echo "  - fix_fresh.sh"
echo ""
echo "🚀 Для запуска установки используйте:"
echo "  ./install_fresh.sh"
echo ""
echo "🛠️  Для исправления pacman используйте:"
echo "  ./fix_fresh.sh"