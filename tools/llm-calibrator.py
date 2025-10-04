#!/usr/bin/env python3
"""
Автоматическая калибровка коррекции координат LLM
Помогает найти оптимальные значения коррекции
"""
import os
import sys
import asyncio
import json
from typing import Optional, Tuple
from PIL import Image, ImageDraw, ImageFont

# Добавляем путь к модулям проекта
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from src.vision.screen_analyzer import ScreenAnalyzer
from src.llm.agent import LLMAgent
from src.utils.config import Config

class LLMCalibrator:
    """Калибратор координат LLM"""
    
    def __init__(self, config_path: str = 'config/config.example.yaml'):
        self.config = Config.load(config_path)
        self.screen_analyzer = ScreenAnalyzer(self.config)
        self.llm_agent = LLMAgent(self.config)
        self.calibration_results = []
    
    async def calibrate_element(self, element_name: str, real_x: int, real_y: int) -> Optional[Tuple[int, int]]:
        """
        Калибрует одну кнопку/элемент
        
        Args:
            element_name: Название элемента для поиска
            real_x, real_y: Реальные координаты центра элемента
            
        Returns:
            Tuple (offset_x, offset_y) или None при ошибке
        """
        print(f"\n🎯 Калибровка элемента: {element_name}")
        print(f"   Реальные координаты: ({real_x}, {real_y})")
        
        try:
            # Получаем скриншот
            screenshot = await self.screen_analyzer.take_screenshot()
            if not screenshot:
                print("❌ Не удалось получить скриншот")
                return None
            
            # Оптимизируем как в системе
            optimized = self.screen_analyzer._optimize_screenshot(screenshot)
            
            # Создаем промт для LLM
            test_prompt = f"""
Найди на скриншоте элемент: "{element_name}"

Отвечай ТОЛЬКО JSON в формате:
{{"actions": [{{"type": "click", "x": X, "y": Y}}], "description": "Описание", "confidence": "высокая/средняя/низкая"}}

Где X, Y - точные координаты ЦЕНТРА элемента на изображении {optimized.size[0]}x{optimized.size[1]}.
"""
            
            print("🚀 Отправляем запрос к LLM...")
            response_data = await self.llm_agent._query_vision_llm(test_prompt, optimized)
            
            if not response_data:
                print("❌ Нет ответа от LLM")
                return None
            
            response_text = response_data.get('response', '')
            print(f"🔍 Ответ LLM: {response_text}")
            
            # Парсим ответ
            try:
                llm_data = json.loads(response_text)
                actions = llm_data.get('actions', [])
                
                if not actions or actions[0].get('type') != 'click':
                    print("❌ Нет действия клика в ответе")
                    return None
                
                llm_x = actions[0].get('x', 0)
                llm_y = actions[0].get('y', 0)
                confidence = llm_data.get('confidence', 'неизвестно')
                
                print(f"🧠 LLM видит элемент в: ({llm_x}, {llm_y})")
                print(f"🎯 Реальное положение: ({real_x}, {real_y})")
                
                # Вычисляем смещение
                offset_x = real_x - llm_x
                offset_y = real_y - llm_y
                
                print(f"📐 Требуемая коррекция: ({offset_x:+d}, {offset_y:+d})")
                print(f"🎲 Уверенность LLM: {confidence}")
                
                # Сохраняем результат
                result = {
                    'element': element_name,
                    'real_coords': (real_x, real_y),
                    'llm_coords': (llm_x, llm_y),
                    'correction': (offset_x, offset_y),
                    'confidence': confidence
                }
                self.calibration_results.append(result)
                
                # Создаем визуализацию
                await self._create_calibration_visualization(
                    optimized, element_name, real_x, real_y, llm_x, llm_y, offset_x, offset_y
                )
                
                return (offset_x, offset_y)
                
            except json.JSONDecodeError as e:
                print(f"❌ Ошибка парсинга JSON: {e}")
                return None
                
        except Exception as e:
            print(f"❌ Ошибка калибровки: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    async def _create_calibration_visualization(
        self, screenshot: Image.Image, element_name: str,
        real_x: int, real_y: int, llm_x: int, llm_y: int,
        offset_x: int, offset_y: int
    ):
        """Создает визуализацию калибровки"""
        vis_image = screenshot.copy()
        draw = ImageDraw.Draw(vis_image)
        
        # Пытаемся загрузить шрифт
        try:
            font = ImageFont.load_default()
        except:
            font = None
        
        # Рисуем реальную позицию (зеленый)
        cross_size = 20
        draw.line([(real_x-cross_size, real_y), (real_x+cross_size, real_y)], fill='green', width=3)
        draw.line([(real_x, real_y-cross_size), (real_x, real_y+cross_size)], fill='green', width=3)
        draw.ellipse([(real_x-25, real_y-25), (real_x+25, real_y+25)], outline='green', width=2)
        
        # Рисуем позицию LLM (красный)
        draw.line([(llm_x-cross_size, llm_y), (llm_x+cross_size, llm_y)], fill='red', width=3)
        draw.line([(llm_x, llm_y-cross_size), (llm_x, llm_y+cross_size)], fill='red', width=3)
        draw.ellipse([(llm_x-25, llm_y-25), (llm_x+25, llm_y+25)], outline='red', width=2)
        
        # Рисуем стрелку от LLM к реальной позиции
        draw.line([(llm_x, llm_y), (real_x, real_y)], fill='yellow', width=2)
        
        # Добавляем подписи
        if font:
            draw.text((real_x+30, real_y-10), f"Реально ({real_x},{real_y})", fill='green', font=font)
            draw.text((llm_x+30, llm_y+10), f"LLM ({llm_x},{llm_y})", fill='red', font=font)
        
        # Информация в углу
        info_lines = [
            f"Элемент: {element_name}",
            f"Реально: ({real_x}, {real_y})",
            f"LLM: ({llm_x}, {llm_y})",
            f"Коррекция: ({offset_x:+d}, {offset_y:+d})"
        ]
        
        # Фон для информации
        info_height = len(info_lines) * 20 + 20
        draw.rectangle([(10, 10), (350, info_height)], fill='black', outline='white')
        
        for i, line in enumerate(info_lines):
            draw.text((15, 15 + i * 20), line, fill='white', font=font)
        
        # Сохраняем
        filename = f"calibration_{element_name.replace(' ', '_').replace("'", '')}.png"
        vis_image.save(filename)
        print(f"💾 Визуализация сохранена: {filename}")
    
    def calculate_average_correction(self) -> Tuple[int, int]:
        """Вычисляет среднюю коррекцию по всем результатам"""
        if not self.calibration_results:
            return (0, 0)
        
        total_x = sum(result['correction'][0] for result in self.calibration_results)
        total_y = sum(result['correction'][1] for result in self.calibration_results)
        
        avg_x = round(total_x / len(self.calibration_results))
        avg_y = round(total_y / len(self.calibration_results))
        
        return (avg_x, avg_y)
    
    def print_calibration_report(self):
        """Выводит отчет по калибровке"""
        if not self.calibration_results:
            print("❌ Нет результатов калибровки")
            return
        
        print("\n" + "="*60)
        print("📊 ОТЧЕТ ПО КАЛИБРОВКЕ")
        print("="*60)
        
        for result in self.calibration_results:
            print(f"🎯 {result['element']}:")
            print(f"   Реально: {result['real_coords']}")
            print(f"   LLM: {result['llm_coords']}")
            print(f"   Коррекция: {result['correction']} (уверенность: {result['confidence']})")
        
        avg_correction = self.calculate_average_correction()
        print(f"\n🎯 РЕКОМЕНДУЕМАЯ КОРРЕКЦИЯ: {avg_correction}")
        print(f"   В config.yaml:")
        print(f"   llm_coordinate_correction:")
        print(f"     x: {avg_correction[0]}")
        print(f"     y: {avg_correction[1]}")

async def main():
    """Интерактивная калибровка"""
    print("🎯 Калибратор координат LLM")
    print("Поможет найти оптимальные значения коррекции")
    print("="*60)
    
    calibrator = LLMCalibrator()
    
    print("Инструкция:")
    print("1. Запустите Disco Elysium")
    print("2. Откройте экран с кнопками (главное меню)")
    print("3. Для каждой кнопки укажите её реальные координаты")
    print("4. Система сравнит с тем, что видит LLM")
    print("5. В конце получите рекомендуемую коррекцию")
    
    # Предложенные элементы для калибровки
    suggested_elements = [
        ("кнопка 'Новая игра'", "Кнопка запуска новой игры"),
        ("кнопка 'Загрузить'", "Кнопка загрузки сохранения"),
        ("кнопка 'Настройки'", "Кнопка настроек игры"),
        ("кнопка 'Выход'", "Кнопка выхода из игры")
    ]
    
    try:
        while True:
            print("\n" + "-"*40)
            print("Доступные действия:")
            print("1. Калибровать элемент")
            print("2. Показать отчет")
            print("3. Выйти")
            
            choice = input("Выберите действие (1-3): ").strip()
            
            if choice == "1":
                print("\nПредложенные элементы:")
                for i, (element, desc) in enumerate(suggested_elements, 1):
                    print(f"  {i}. {desc}")
                print("  0. Свой вариант")
                
                elem_choice = input("Выберите элемент (0-4): ").strip()
                
                if elem_choice == "0":
                    element_name = input("Введите название элемента: ").strip()
                elif elem_choice in ["1", "2", "3", "4"]:
                    element_name = suggested_elements[int(elem_choice)-1][0]
                else:
                    print("❌ Неверный выбор")
                    continue
                
                try:
                    real_coords = input(f"Введите реальные координаты центра '{element_name}' (x,y): ").strip()
                    real_x, real_y = map(int, real_coords.split(','))
                    
                    await calibrator.calibrate_element(element_name, real_x, real_y)
                    
                except ValueError:
                    print("❌ Неверный формат координат. Используйте: x,y")
                except Exception as e:
                    print(f"❌ Ошибка: {e}")
            
            elif choice == "2":
                calibrator.print_calibration_report()
            
            elif choice == "3":
                break
            
            else:
                print("❌ Неверный выбор")
    
    except KeyboardInterrupt:
        print("\n🛑 Калибровка прервана")
    
    # Финальный отчет
    calibrator.print_calibration_report()

if __name__ == "__main__":
    asyncio.run(main())