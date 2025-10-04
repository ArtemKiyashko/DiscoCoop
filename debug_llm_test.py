#!/usr/bin/env python3
"""
Тест для диагностики проблем со скриншотами и LLM
"""
import sys
import os
import asyncio
from pathlib import Path

# Добавляем src в путь
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.utils.config import Config
from src.llm.agent import DiscoLLMAgent
from src.vision.screen_analyzer import ScreenAnalyzer

async def test_screenshot_and_llm():
    """Тест создания скриншота и отправки в LLM"""
    print("🧪 Тестируем скриншоты и LLM...")
    
    try:
        # Загружаем конфигурацию
        config = Config.load()
        
        # Создаем агенты
        llm_agent = DiscoLLMAgent(config)
        screen_analyzer = ScreenAnalyzer(config, llm_agent)
        
        print("📸 Создаем скриншот...")
        screenshot = await screen_analyzer.take_screenshot()
        
        if not screenshot:
            print("❌ Не удалось создать скриншот")
            return
            
        print(f"✅ Скриншот создан: {screenshot.size}")
        
        # Сохраняем скриншот для проверки
        screenshot.save("debug_screenshot.png")
        print("💾 Скриншот сохранен как: debug_screenshot.png")
        
        print("🤖 Отправляем в LLM...")
        description = await llm_agent.describe_screen(screenshot)
        
        if description:
            print(f"✅ Описание получено: {description}")
        else:
            print("❌ Описание не получено")
            
    except Exception as e:
        print(f"❌ Ошибка в тесте: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(test_screenshot_and_llm())