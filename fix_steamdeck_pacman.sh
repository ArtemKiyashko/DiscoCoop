#!/bin/bash

# Скрипт исправления проблем с pacman на Steam Deck

echo "🛠️  Исправление проблем с pacman на Steam Deck"
echo "=============================================="
echo "📅 Версия скрипта: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Проверяем, что мы на Steam Deck
if [ ! -f "/etc/steamos-release" ] && [ ! -d "/home/deck" ]; then
    echo "⚠️  Этот скрипт предназначен для Steam Deck. Выходим..."
    exit 1
fi

echo "🔓 Разблокировка файловой системы..."
sudo steamos-readonly disable

echo "🧹 Очистка старых ключей..."
sudo rm -rf /etc/pacman.d/gnupg

echo "🔑 Инициализация новых ключей..."
sudo pacman-key --init

echo "📋 Заполнение ключей Arch Linux..."
sudo pacman-key --populate archlinux

echo "🔐 Добавление ключей SteamOS..."
sudo pacman-key --recv-keys 3056513887B78AEB 2>/dev/null || true
sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true

echo "🧹 Очистка кеша пакетов..."
# Автоматически отвечаем "yes" на все вопросы об удалении поврежденных пакетов
echo -e "y\ny" | sudo pacman -Scc 2>/dev/null || true

echo "🗑️  Удаление поврежденных пакетов из кеша..."
sudo find /var/cache/pacman/pkg/ -name "*.pkg.tar.zst" -type f -delete 2>/dev/null || true

echo "📥 Обновление базы данных пакетов..."
sudo pacman -Sy

echo "🧪 Тестирование установки пакета..."
if sudo pacman -S --needed --noconfirm python; then
    echo "✅ pacman работает корректно!"
    
    echo "🔒 Возвращение файловой системы в read-only режим..."
    sudo steamos-readonly enable
    
    echo "🎉 Исправление завершено успешно!"
    echo "Теперь можно запустить install.sh"
else
    echo "❌ pacman всё ещё не работает корректно"
    echo "💡 Рекомендации:"
    echo "1. Перезагрузите Steam Deck"
    echo "2. Попробуйте запустить этот скрипт снова"
    echo "3. Используйте альтернативную установку Python"
    
    echo ""
    echo "🐍 Альтернативная установка Python:"
    echo "cd /tmp"
    echo "curl -L https://github.com/indygreg/python-build-standalone/releases/download/20231002/cpython-3.11.6+20231002-x86_64-unknown-linux-gnu-install_only.tar.gz -o python.tar.gz"
    echo "tar -xzf python.tar.gz -C ~/"
    echo "echo 'export PATH=\"\$HOME/python/bin:\$PATH\"' >> ~/.bashrc"
    echo "source ~/.bashrc"
    
    sudo steamos-readonly enable
    exit 1
fi