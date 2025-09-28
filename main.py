#!/usr/bin/env python3
"""
Основной файл запуска Disco Coop Bot
"""
import asyncio
import sys
import os
from pathlib import Path
from loguru import logger

# Добавляем src в путь Python
sys.path.insert(0, str(Path(__file__).parent / "src"))

from src.utils.config import Config
from src.bot.disco_bot import DiscoCoopBot


def main():
    """Основная функция"""
    print("🎮 Disco Coop - Кооперативная игра в Disco Elysium через Telegram")
    print("=" * 60)
    
    try:
        # Загружаем конфигурацию
        print("📋 Загрузка конфигурации...")
        config = Config.load()
        config.validate()
        
        # Настраиваем логирование
        logger.remove()  # Удаляем стандартный обработчик
        
        # Создаем папку для логов
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        
        # Добавляем файловое логирование
        logger.add(
            config.logging.file,
            level=config.logging.level,
            rotation=config.logging.max_size,
            retention=config.logging.backup_count,
            format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {name}:{function}:{line} | {message}"
        )
        
        # Добавляем консольное логирование
        logger.add(
            sys.stdout,
            level=config.logging.level,
            format="<green>{time:HH:mm:ss}</green> | <level>{level}</level> | {message}"
        )
        
        logger.info("Configuration loaded successfully")
        
        # Создаем и запускаем бота
        print("🤖 Инициализация бота...")
        bot = DiscoCoopBot(config)
        
        print("🚀 Запуск бота...")
        print(f"📱 Авторизованные чаты: {config.telegram.allowed_chats}")
        print(f"👑 Администраторы: {config.telegram.admin_users}")
        print("✅ Бот запущен! Нажмите Ctrl+C для остановки.")
        
        # Запускаем бота (run_polling управляет event loop самостоятельно)
        bot.run()
        
    except FileNotFoundError as e:
        print(f"❌ Файл конфигурации не найден: {e}")
        print("💡 Скопируйте config/config.example.yaml в config/config.yaml и настройте его")
        sys.exit(1)
        
    except ValueError as e:
        print(f"❌ Ошибка конфигурации: {e}")
        sys.exit(1)
        
    except KeyboardInterrupt:
        print("\n👋 Завершение работы бота...")
        
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        print(f"❌ Неожиданная ошибка: {e}")
        sys.exit(1)


if __name__ == "__main__":
    # Проверяем Python версию
    if sys.version_info < (3, 8):
        print("❌ Требуется Python 3.8 или выше")
        sys.exit(1)
    
    # Запускаем основную функцию
    try:
        main()
    except KeyboardInterrupt:
        print("\n👋 До свидания!")
    except Exception as e:
        print(f"❌ Критическая ошибка: {e}")
        sys.exit(1)