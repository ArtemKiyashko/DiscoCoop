#!/usr/bin/env python3
"""
Инструмент для тестирования координат LLM
Помогает визуализировать что именно "видит" LLM на скриншоте
"""
import os
import sys
import asyncio
from typing import Optional, List, Dict, Any
from PIL import Image, ImageDraw, ImageFont
import json

# Добавляем путь к модулям проекта
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.vision.screen_analyzer import ScreenAnalyzer
from src.llm.agent import LLMAgent
from src.utils.config import Config

class LLMCoordinateTester:
    """Тестер координат LLM"""
    
    def __init__(self, config_path: str = 'config/config.example.yaml'):
        self.config = Config.load(config_path)
        self.screen_analyzer = ScreenAnalyzer(self.config)
        self.llm_agent = LLMAgent(self.config)
    
    async def test_coordinates(self, test_prompt: str = "найди кнопку 'Новая игра'") -> Optional[str]:
        """
        Тестирует координаты LLM с визуализацией
        
        Args:
            test_prompt: Промт для тестирования
            
        Returns:
            Путь к созданному изображению с визуализацией
        """
        print(f"🧪 Тестирование координат для: '{test_prompt}'")
        
        try:
            # Делаем скриншот
            print("📸 Делаем скриншот...")
            screenshot = await self.screen_analyzer.take_screenshot()
            
            if not screenshot:
                print("❌ Не удалось получить скриншот")
                return None
            
            # Оптимизируем скриншот (как это делает система)
            optimized_screenshot = self.screen_analyzer._optimize_screenshot(screenshot)
            print(f"🖼  Размер оригинального скриншота: {screenshot.size}")
            print(f"🔧 Размер оптимизированного скриншота: {optimized_screenshot.size}")
            
            # Отправляем специальный промт для получения координат
            test_system_prompt = f"""
Ты помощник для игры Disco Elysium. Найди на скриншоте элемент: "{test_prompt}"

Отвечай ТОЛЬКО JSON в формате:
{{"actions": [{{"type": "click", "x": X, "y": Y}}], "description": "Описание элемента", "confidence": "высокая/средняя/низкая"}}

Где X, Y - точные координаты элемента на изображении размером {optimized_screenshot.size[0]}x{optimized_screenshot.size[1]}.
"""
            
            print("🚀 Отправляем запрос к LLM...")
            response_data = await self.llm_agent._query_vision_llm(
                test_system_prompt,
                optimized_screenshot
            )
            
            # Извлекаем текст ответа
            response = response_data.get('response', '') if response_data else None
            
            if not response:
                print("❌ Нет ответа от LLM")
                return None
            
            print(f"🔍 Ответ LLM: {response}")
            
            # Парсим JSON ответ
            try:
                llm_data = json.loads(response)
                actions = llm_data.get('actions', [])
                description = llm_data.get('description', 'Нет описания')
                confidence = llm_data.get('confidence', 'неизвестно')
                
                print(f"📝 Описание: {description}")
                print(f"🎯 Уверенность: {confidence}")
                
                if not actions:
                    print("⚠️  Нет действий в ответе")
                    return None
                
                # Создаем визуализацию
                visualization_path = await self._create_visualization(
                    optimized_screenshot, actions, description, confidence, test_prompt
                )
                
                return visualization_path
                
            except json.JSONDecodeError as e:
                print(f"❌ Ошибка парсинга JSON: {e}")
                print(f"   Сырой ответ: {response}")
                return None
                
        except Exception as e:
            print(f"❌ Ошибка тестирования: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    async def _create_visualization(
        self, 
        screenshot: Image.Image, 
        actions: List[Dict[str, Any]], 
        description: str, 
        confidence: str, 
        test_prompt: str
    ) -> str:
        """Создает визуализацию с отмеченными координатами"""
        
        # Создаем копию изображения для рисования
        vis_image = screenshot.copy()
        draw = ImageDraw.Draw(vis_image)
        
        # Пытаемся загрузить шрифт
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 16)
            small_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 12)
        except:
            try:
                font = ImageFont.load_default()
                small_font = ImageFont.load_default()
            except:
                font = None
                small_font = None
        
        # Рисуем координаты для каждого действия
        for i, action in enumerate(actions):
            if action.get('type') == 'click':
                x = action.get('x', 0)
                y = action.get('y', 0)
                
                print(f"🎯 Координата {i+1}: ({x}, {y})")
                
                # Рисуем крестик в указанной точке
                cross_size = 20
                line_width = 3
                
                # Красный крестик
                draw.line(
                    [(x - cross_size, y), (x + cross_size, y)], 
                    fill='red', width=line_width
                )
                draw.line(
                    [(x, y - cross_size), (x, y + cross_size)], 
                    fill='red', width=line_width
                )
                
                # Круг вокруг точки
                circle_radius = 30
                draw.ellipse(
                    [(x - circle_radius, y - circle_radius), 
                     (x + circle_radius, y + circle_radius)],
                    outline='red', width=2
                )
                
                # Подпись с координатами
                coord_text = f"({x}, {y})"
                if font:
                    bbox = draw.textbbox((0, 0), coord_text, font=font)
                    text_width = bbox[2] - bbox[0]
                    text_height = bbox[3] - bbox[1]
                else:
                    text_width, text_height = 100, 20
                
                # Рисуем фон для текста
                text_x = x + 35
                text_y = y - 10
                draw.rectangle(
                    [(text_x - 2, text_y - 2), 
                     (text_x + text_width + 2, text_y + text_height + 2)],
                    fill='white', outline='red'
                )
                
                # Рисуем текст
                draw.text((text_x, text_y), coord_text, fill='red', font=font)
        
        # Добавляем информацию в верхний левый угол
        info_lines = [
            f"Поиск: {test_prompt}",
            f"Размер: {screenshot.size[0]}x{screenshot.size[1]}",
            f"Описание: {description}",
            f"Уверенность: {confidence}",
            f"Найдено точек: {len([a for a in actions if a.get('type') == 'click'])}"
        ]
        
        # Рисуем фон для информации
        info_height = len(info_lines) * 20 + 20
        draw.rectangle([(10, 10), (400, info_height)], fill='black', outline='white')
        
        # Рисуем информацию
        for i, line in enumerate(info_lines):
            draw.text((15, 15 + i * 20), line, fill='white', font=small_font)
        
        # Сохраняем результат
        output_path = f"llm_coordinate_test_{test_prompt.replace(' ', '_').replace("'", '')}.png"
        vis_image.save(output_path)
        
        print(f"💾 Визуализация сохранена: {output_path}")
        return output_path
    
    async def batch_test(self, test_cases: List[str]) -> None:
        """Тестирует несколько случаев подряд"""
        print(f"🧪 Запуск пакетного тестирования ({len(test_cases)} тестов)")
        
        results = []
        for i, test_case in enumerate(test_cases, 1):
            print(f"\n{'='*60}")
            print(f"Тест {i}/{len(test_cases)}: {test_case}")
            print('='*60)
            
            result_path = await self.test_coordinates(test_case)
            results.append((test_case, result_path))
            
            # Небольшая пауза между тестами
            await asyncio.sleep(1)
        
        print(f"\n{'='*60}")
        print("📊 РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ:")
        print('='*60)
        
        for test_case, result_path in results:
            status = "✅" if result_path else "❌"
            print(f"{status} {test_case}")
            if result_path:
                print(f"   📁 {result_path}")

async def main():
    """Основная функция"""
    print("🧪 LLM Coordinate Tester")
    print("Инструмент для тестирования точности координат LLM")
    print("="*60)
    
    tester = LLMCoordinateTester()
    
    # Тестовые случаи для Disco Elysium
    test_cases = [
        "кнопка 'Новая игра'",
        "кнопка 'Загрузить'", 
        "кнопка 'Настройки'",
        "кнопка 'Выход'",
        "главное меню",
        "любая интерактивная кнопка"
    ]
    
    print("Доступные режимы:")
    print("1. Одиночный тест")
    print("2. Пакетное тестирование")
    
    try:
        choice = input("\nВыберите режим (1/2): ").strip()
        
        if choice == "1":
            test_prompt = input("Введите что искать (или Enter для 'Новая игра'): ").strip()
            if not test_prompt:
                test_prompt = "кнопку 'Новая игра'"
            
            result = await tester.test_coordinates(test_prompt)
            if result:
                print(f"\n✅ Готово! Откройте файл: {result}")
            else:
                print("\n❌ Тест не удался")
                
        elif choice == "2":
            await tester.batch_test(test_cases)
        else:
            print("❌ Неверный выбор")
            
    except KeyboardInterrupt:
        print("\n🛑 Тестирование прервано пользователем")
    except Exception as e:
        print(f"\n❌ Ошибка: {e}")

if __name__ == "__main__":
    asyncio.run(main())