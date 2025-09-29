# Альтернативные методы установки для Steam Deck

Если `pacman` не работает или блокируется, используйте эти альтернативные методы:

## 🚀 Быстрая установка инструментов скриншотов

```bash
./install_screenshot_tools.sh
```

Этот скрипт автоматически попробует все доступные методы.

## 📦 Метод 1: Flatpak (рекомендуемый)

ImageMagick через Flatpak:
```bash
flatpak install --user flathub org.imagemagick.ImageMagick
```

Создать wrapper для `convert`:
```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/convert << 'EOF'
#!/bin/bash
exec flatpak run org.imagemagick.ImageMagick convert "$@"
EOF
chmod +x ~/.local/bin/convert
```

## 🔧 Метод 2: Статические бинарники

ImageMagick:
```bash
mkdir -p ~/.local/bin
curl -L "https://github.com/SoftCreatR/imei/releases/latest/download/imei-linux-x86_64" -o ~/.local/bin/convert
chmod +x ~/.local/bin/convert
```

## 🖼️ Метод 3: Wrapper для xwd

Создать универсальный wrapper:
```bash
cat > ~/.local/bin/xwd << 'EOF'
#!/bin/bash
if command -v import &> /dev/null; then
    exec import "$@"
elif command -v gnome-screenshot &> /dev/null; then
    OUTPUT="${@: -1}"
    if [[ "$OUTPUT" == *".xwd" ]]; then
        OUTPUT="${OUTPUT%.xwd}.png"
    fi
    exec gnome-screenshot -f "$OUTPUT"
else
    echo "❌ Нет доступных инструментов для скриншотов" >&2
    exit 1
fi
EOF
chmod +x ~/.local/bin/xwd
```

## 🛠️ Метод 4: Через Discover (GUI)

1. Откройте Discover (магазин приложений)
2. Найдите "ImageMagick"  
3. Установите

## ⚙️ Добавление в PATH

После установки добавьте в PATH:
```bash
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

## 🧪 Проверка

Проверьте доступность команд:
```bash
which convert
which xwd
convert --version
```

## 🔄 Если ничего не помогает

1. **Перезагрузите Steam Deck**
2. **Попробуйте в Desktop Mode**
3. **Установите пароль для пользователя deck:**
   ```bash
   sudo passwd deck
   ```
4. **Или используйте встроенные инструменты:**
   ```bash
   # Через gnome-screenshot
   gnome-screenshot -f screenshot.png
   
   # Через spectacle (если доступен)
   spectacle -f screenshot.png
   ```

## 📝 Примечания

- Flatpak версии могут работать медленнее
- Статические бинарники не всегда поддерживают все форматы
- Для полной функциональности лучше использовать нативные пакеты через pacman
- В Gaming Mode некоторые команды могут быть недоступны

## 🆘 Решение проблем

### Keyring ошибки:
```bash
./fix_screenshots.sh
```

### Права доступа:
```bash
sudo steamos-readonly disable
sudo pacman -S imagemagick xorg-xwd
sudo steamos-readonly enable
```

### Альтернативы для Gaming Mode:
- Используйте Steam Screenshot (Steam + R1)
- Переключитесь в Desktop Mode для полной функциональности