#!/usr/bin/env python3
"""
Тестовый скрипт для проверки мультидисплея на Steam Deck
"""
import subprocess
import sys
import os

def test_display_detection():
    """Тестирование определения дисплеев"""
    print("🖥️  Тестирование определения дисплеев...")
    
    try:
        # Получаем информацию о дисплеях
        result = subprocess.run(['xrandr', '--listmonitors'], 
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✅ xrandr доступен")
            print("📋 Найденные дисплеи:")
            
            displays = []
            for line in result.stdout.split('\n')[1:]:  # Пропускаем заголовок
                if line.strip():
                    parts = line.strip().split()
                    if len(parts) >= 4:
                        display_name = parts[-1]
                        geometry = parts[2]
                        primary = '*' in line
                        print(f"  - {display_name}: {geometry} {'(основной)' if primary else ''}")
                        
                        # Парсим геометрию
                        if 'x' in geometry and '+' in geometry:
                            try:
                                size_part = geometry.split('+')[0]
                                offset_parts = geometry.split('+')[1:]
                                
                                if '/' in size_part:
                                    width_part = size_part.split('x')[0]
                                    height_part = size_part.split('x')[1]
                                    width = int(width_part.split('/')[0])
                                    height = int(height_part.split('/')[0])
                                    
                                    # Очищаем offset от дополнительной информации
                                    x_offset_str = offset_parts[0].split()[0]  # "0" из "0 (screen: 0)"
                                    y_offset_str = offset_parts[1].split()[0] if len(offset_parts) > 1 else "0"
                                    x_offset = int(x_offset_str)
                                    y_offset = int(y_offset_str)
                                    
                                    displays.append({
                                        'name': display_name,
                                        'width': width,
                                        'height': height,
                                        'x': x_offset,
                                        'y': y_offset,
                                        'primary': primary
                                    })
                            except (ValueError, IndexError) as e:
                                print(f"  ⚠️  Не удалось парсить геометрию {geometry}: {e}")
            
            return displays
        else:
            print("❌ xrandr недоступен")
            return []
            
    except FileNotFoundError:
        print("❌ xrandr не найден")
        return []

def test_window_detection():
    """Тестирование поиска окна игры"""
    print("\n🎮 Тестирование поиска окна игры...")
    
    window_titles = ["Disco Elysium", "Disco"]
    
    for title in window_titles:
        try:
            result = subprocess.run(['xdotool', 'search', '--name', title], 
                                  capture_output=True, text=True)
            
            if result.returncode == 0 and result.stdout.strip():
                window_ids = result.stdout.strip().split('\n')
                print(f"✅ Найдены окна для '{title}': {window_ids}")
                
                for window_id in window_ids:
                    # Получаем информацию об окне
                    geom_result = subprocess.run(['xdotool', 'getwindowgeometry', window_id],
                                               capture_output=True, text=True)
                    
                    if geom_result.returncode == 0:
                        print(f"📐 Окно {window_id}:")
                        for line in geom_result.stdout.split('\n'):
                            if line.strip():
                                print(f"     {line.strip()}")
                
                return window_ids[0]
            else:
                print(f"❌ Окна для '{title}' не найдены")
                
        except FileNotFoundError:
            print("❌ xdotool не найден")
            break
    
    return None

def test_coordinate_mapping(displays, window_id):
    """Тестирование маппинга координат"""
    print(f"\n🗺️  Тестирование маппинга координат...")
    
    if not window_id:
        print("❌ Окно игры не найдено, пропускаем тест координат")
        return
    
    try:
        # Получаем позицию окна
        result = subprocess.run(['xdotool', 'getwindowgeometry', window_id],
                              capture_output=True, text=True)
        
        if result.returncode == 0:
            window_x = window_y = None
            for line in result.stdout.split('\n'):
                if 'Position:' in line:
                    pos_str = line.split('Position:')[1].strip()
                    if ',' in pos_str:
                        window_x = int(pos_str.split(',')[0])
                        window_y = int(pos_str.split(',')[1])
                        break
            
            if window_x is not None and window_y is not None:
                print(f"🪟 Позиция окна: ({window_x}, {window_y})")
                
                # Определяем на каком дисплее находится окно
                for display in displays:
                    if (display['x'] <= window_x < display['x'] + display['width'] and
                        display['y'] <= window_y < display['y'] + display['height']):
                        print(f"✅ Окно находится на дисплее: {display['name']}")
                        print(f"   Смещение дисплея: +{display['x']}+{display['y']}")
                        print(f"   Размер дисплея: {display['width']}x{display['height']}")
                        
                        # Примеры маппинга координат
                        print(f"\n📊 Примеры маппинга координат:")
                        test_coords = [(100, 100), (400, 300), (800, 600)]
                        
                        for orig_x, orig_y in test_coords:
                            mapped_x = orig_x + display['x']
                            mapped_y = orig_y + display['y']
                            print(f"   ({orig_x}, {orig_y}) -> ({mapped_x}, {mapped_y})")
                        
                        return
                
                print("❌ Не удалось определить дисплей для окна")
            else:
                print("❌ Не удалось получить позицию окна")
                
    except Exception as e:
        print(f"❌ Ошибка при тестировании координат: {e}")

def main():
    """Основная функция тестирования"""
    print("🧪 Тестирование поддержки мультидисплея для Steam Deck")
    print("=" * 60)
    
    # Проверяем наличие необходимых инструментов
    tools = ['xrandr', 'xdotool']
    missing_tools = []
    
    for tool in tools:
        try:
            subprocess.run([tool, '--version'], capture_output=True)
            print(f"✅ {tool} доступен")
        except FileNotFoundError:
            print(f"❌ {tool} не найден")
            missing_tools.append(tool)
    
    if missing_tools:
        print(f"\n⚠️  Отсутствуют инструменты: {', '.join(missing_tools)}")
        print("💡 Установите: sudo pacman -S xorg-xrandr xorg-xdotool")
        return
    
    print()
    
    # Тестируем определение дисплеев
    displays = test_display_detection()
    
    # Тестируем поиск окна игры
    window_id = test_window_detection()
    
    # Тестируем маппинг координат
    if displays:
        test_coordinate_mapping(displays, window_id)
    
    print(f"\n✨ Тестирование завершено!")
    
    # Рекомендации
    if len(displays) > 1:
        print(f"\n💡 Рекомендации для мультидисплея:")
        print(f"   - Обнаружено {len(displays)} дисплея(ов)")
        print(f"   - Убедитесь что игра запущена в правильном разрешении")
        print(f"   - Проверьте настройки auto_detect_game_screen в config.yaml")
    elif len(displays) == 1:
        print(f"\n💡 Один дисплей - координаты должны работать корректно")
    else:
        print(f"\n⚠️  Дисплеи не обнаружены - возможны проблемы с координатами")

if __name__ == "__main__":
    main()