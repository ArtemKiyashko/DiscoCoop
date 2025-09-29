#!/usr/bin/env python3
"""Тест настройки окружения"""

import sys
import os

def test_imports():
    """Тестируем импорты"""
    try:
        import telegram
        print(f"✅ python-telegram-bot: {telegram.__version__}")
    except ImportError as e:
        print(f"❌ python-telegram-bot: {e}")
        return False
    
    try:
        import aiohttp
        print("✅ aiohttp: OK")
    except ImportError as e:
        print(f"❌ aiohttp: {e}")
        return False
        
    try:
        from PIL import Image
        print("✅ Pillow: OK")
    except ImportError as e:
        print(f"❌ Pillow: {e}")
        return False
        
    return True

def test_ollama():
    """Тестируем Ollama"""
    ollama_path = os.path.expanduser("~/.local/share/ollama/bin/ollama")
    if os.path.exists(ollama_path):
        print(f"✅ Ollama найден: {ollama_path}")
        return True
    else:
        print(f"❌ Ollama не найден: {ollama_path}")
        return False

def test_tools():
    """Тестируем инструменты"""
    tools_ok = True
    
    for tool in ["xwd", "convert", "import"]:
        tool_path = os.path.expanduser(f"~/.local/bin/{tool}")
        if os.path.exists(tool_path):
            print(f"✅ {tool}: {tool_path}")
        else:
            print(f"❌ {tool}: не найден")
            tools_ok = False
            
    return tools_ok

if __name__ == "__main__":
    print("🧪 Тестирование настройки...")
    print("\n📦 Python пакеты:")
    imports_ok = test_imports()
    
    print("\n🤖 Ollama:")
    ollama_ok = test_ollama()
    
    print("\n🛠️  Инструменты:")
    tools_ok = test_tools()
    
    print("\n" + "="*50)
    if imports_ok and ollama_ok and tools_ok:
        print("🎉 Все компоненты готовы!")
        sys.exit(0)
    else:
        print("⚠️  Некоторые компоненты требуют внимания")
        sys.exit(1)