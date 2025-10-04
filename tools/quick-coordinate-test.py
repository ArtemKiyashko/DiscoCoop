#!/usr/bin/env python3
"""
Быстрый тест координат LLM
Делает скриншот, показывает размеры и позволяет протестировать конкретные координаты
"""
import os
import sys
import asyncio
from PIL import Image, ImageDraw

# Добавляем путь к модулям проекта
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.vision.screen_analyzer import ScreenAnalyzer
from src.utils.config import Config

async def quick_coordinate_test():
    """Быстрый тест координат"""
    print("🎯 Быстрый тест координат LLM")
    print("="*50)
    
    try:
        # Загружаем конфигурацию
        config = Config.load('config/config.example.yaml')
        screen_analyzer = ScreenAnalyzer(config)
        
        # Делаем скриншот
        print("📸 Делаем скриншот...")
        screenshot = await screen_analyzer.take_screenshot()
        
        if not screenshot:
            print("❌ Не удалось получить скриншот")
            return
        
        print(f"📐 Размер оригинального скриншота: {screenshot.size}")
        
        # Оптимизируем как в системе
        optimized = screen_analyzer._optimize_screenshot(screenshot)
        print(f"🔧 Размер после оптимизации: {optimized.size}")
        
        # Сохраняем текущий скриншот для анализа
        optimized.save("current_screenshot.png")
        print("💾 Скриншот сохранен как: current_screenshot.png")
        
        # Получаем реальное разрешение игры
        game_resolution = screen_analyzer.get_game_resolution()
        print(f"🎮 Реальное разрешение игры: {game_resolution}")
        
        print("\n" + "="*50)
        print("📋 Полезная информация:")
        print(f"  • LLM видит изображение: {optimized.size}")
        print(f"  • Реальная игра работает: {game_resolution}")
        print(f"  • Файл для анализа: current_screenshot.png")
        print("\n💡 Откройте current_screenshot.png и посмотрите где реально находятся элементы")
        print("   Сравните с координатами, которые возвращает LLM")
        
        # Интерактивный тест координат
        while True:
            print("\n" + "-"*30)
            test_coords = input("Введите координаты для проверки (x,y) или 'q' для выхода: ").strip()
            
            if test_coords.lower() == 'q':
                break
                
            try:
                x_str, y_str = test_coords.split(',')
                x = int(x_str.strip())
                y = int(y_str.strip())
                
                # Проверяем границы координат
                max_x, max_y = optimized.size
                if x < 0 or x >= max_x or y < 0 or y >= max_y:
                    print(f"⚠️  Координаты ({x}, {y}) выходят за границы изображения {optimized.size}")
                
                # Создаем изображение с отмеченной точкой
                test_image = optimized.copy()
                draw = ImageDraw.Draw(test_image)
                
                print(f"🎯 Рисуем крестик точно в координатах ({x}, {y})")
                
                # Рисуем крестик (точные координаты)
                cross_size = 15
                draw.line([(x-cross_size, y), (x+cross_size, y)], fill='red', width=3)
                draw.line([(x, y-cross_size), (x, y+cross_size)], fill='red', width=3)
                
                # Добавляем точку в центре для точности
                dot_size = 2
                draw.ellipse([
                    (x-dot_size, y-dot_size), 
                    (x+dot_size, y+dot_size)
                ], fill='blue', outline='blue')
                
                # Рисуем круг
                circle_radius = 25
                draw.ellipse([
                    (x-circle_radius, y-circle_radius), 
                    (x+circle_radius, y+circle_radius)
                ], outline='red', width=2)
                
                # Добавляем подпись с координатами
                try:
                    from PIL import ImageFont
                    font = ImageFont.load_default()
                    coord_text = f"({x},{y})"
                    draw.text((x+30, y-10), coord_text, fill='white', font=font)
                    draw.text((x+31, y-9), coord_text, fill='red', font=font)  # Тень для читаемости
                except:
                    pass
                
                test_filename = f"test_coords_{x}_{y}.png"
                test_image.save(test_filename)
                
                print(f"✅ Точка ({x}, {y}) отмечена в файле: {test_filename}")
                print(f"   Откройте файл чтобы увидеть где точно находится эта координата")
                
            except ValueError:
                print("❌ Неверный формат. Используйте: x,y (например: 500,400)")
                
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(quick_coordinate_test())