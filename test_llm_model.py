#!/usr/bin/env python3
"""
Тест работы LLM модели в Ollama
"""
import asyncio
import sys
import os

# Добавляем путь к корню проекта для импортов
project_root = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, project_root)

from src.utils.config import Config
from src.llm.agent import LLMAgent


async def test_llm():
    """Тестирование LLM модели"""
    
    print("🔍 Тестирование LLM модели...")
    
    try:
        # Загружаем конфигурацию
        config = Config.load()
        print(f"📋 Конфигурация загружена")
        print(f"🔗 Ollama URL: {config.llm.base_url}")
        print(f"🤖 Модель: {config.llm.model}")
        
        # Создаем агента
        agent = LLMAgent(config)
        
        # 1. Проверяем доступность Ollama
        print(f"\n1️⃣ Проверяем доступность Ollama...")
        if not await agent.is_available():
            print("❌ Ollama недоступен или модель не загружена")
            return False
        
        # 2. Тестируем модель простым запросом
        print(f"\n2️⃣ Тестируем модель коротким запросом (может занять ~30-60с)...")
        if not await agent.test_model():
            print("❌ Тест модели неудачен")
            return False
        
        # 3. Тестируем более сложный запрос
        print(f"\n3️⃣ Тестируем игровую команду (может занять ~30-60с)...")
        test_command = "открой дверь"
        result = await agent.process_command(test_command)
        
        if result:
            print(f"✅ Обработка команды успешна:")
            print(f"   Действия: {result.get('actions', [])}")  
            print(f"   Описание: {result.get('description', '')}")
        else:
            print("❌ Обработка команды неудачна")
            return False
        
        print(f"\n🎉 Все тесты пройдены! Модель работает корректно.")
        return True
        
    except Exception as e:
        print(f"❌ Ошибка тестирования: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    finally:
        if 'agent' in locals():
            await agent.close()


async def main():
    """Главная функция"""
    print("🧪 Тест модели LLM для Disco Coop")
    print("=" * 50)
    
    success = await test_llm()
    
    print("=" * 50)
    if success:
        print("✅ LLM модель готова к работе!")
        sys.exit(0)
    else:
        print("❌ LLM модель не работает корректно")
        print("\n💡 Возможные решения:")
        print("   1. Проверьте что Ollama запущен: systemctl --user status ollama")
        print("   2. Загрузите модель: ollama pull llama3.1:8b")
        print("   3. Попробуйте более легкую модель: ollama pull llama3.2:1b")
        print("   4. Увеличьте swap если не хватает памяти")
        sys.exit(1)


if __name__ == "__main__":
    asyncio.run(main())