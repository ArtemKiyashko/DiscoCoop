"""
Telegram Bot для управления игрой Disco Elysium (версия для python-telegram-bot 13.15)
"""
import json
import time
import threading
from typing import Dict, List, Optional
from datetime import datetime, timedelta

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Updater,
    CommandHandler, 
    MessageHandler, 
    CallbackQueryHandler,
    Filters,
    CallbackContext
)
from loguru import logger

from ..utils.config import Config
from ..llm.agent import LLMAgent
from ..vision.screen_analyzer import ScreenAnalyzer
from ..game.controller import GameController


class DiscoCoopBot:
    """Основной класс Telegram бота для Disco Coop (версия для python-telegram-bot 13.15)"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm_agent = LLMAgent(config)
        self.screen_analyzer = ScreenAnalyzer(config)
        self.game_controller = GameController(config)
        
        # Статистика и контроль доступа
        self.chat_last_command: Dict[int, datetime] = {}
        self.chat_command_count: Dict[int, int] = {}
        self.active_sessions: Dict[int, datetime] = {}
        
        # Создаем updater
        self.updater = Updater(token=config.telegram.bot_token, use_context=True)
        self.dispatcher = self.updater.dispatcher
        
        self._setup_handlers()
        
        # Запускаем фоновую задачу очистки сессий
        self.cleanup_timer = None
        self._start_cleanup_timer()
    
    def _setup_handlers(self):
        """Настройка обработчиков команд"""
        # Команды
        self.dispatcher.add_handler(CommandHandler("start", self.start_command))
        self.dispatcher.add_handler(CommandHandler("help", self.help_command))
        self.dispatcher.add_handler(CommandHandler("describe", self.describe_command))
        self.dispatcher.add_handler(CommandHandler("status", self.status_command))
        self.dispatcher.add_handler(CommandHandler("stop_game", self.emergency_stop))
        
        # Обработка текстовых сообщений как игровых команд
        self.dispatcher.add_handler(
            MessageHandler(Filters.text & ~Filters.command, self.handle_game_command)
        )
        
        # Обработка callback-ов от inline клавиатуры
        self.dispatcher.add_handler(CallbackQueryHandler(self.button_callback))
    
    def _is_authorized_chat(self, chat_id: int) -> bool:
        """Проверка авторизации чата"""
        return chat_id in self.config.telegram.allowed_chats
    
    def _check_rate_limit(self, chat_id: int) -> bool:
        """Проверка лимита команд"""
        now = datetime.now()
        
        # Сброс счетчика каждую минуту
        if chat_id not in self.chat_last_command or \
           (now - self.chat_last_command[chat_id]).total_seconds() > 60:
            self.chat_command_count[chat_id] = 0
            self.chat_last_command[chat_id] = now
        
        # Проверка лимита
        if self.chat_command_count[chat_id] >= self.config.security.rate_limit:
            return False
        
        self.chat_command_count[chat_id] += 1
        return True

    def start_command(self, update: Update, context: CallbackContext):
        """Команда /start"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            update.message.reply_text(
                "❌ Доступ запрещен. Этот чат не авторизован для использования бота."
            )
            return
        
        welcome_text = """
🎮 **Добро пожаловать в Disco Coop!**

Я бот для совместной игры в Disco Elysium. Вы можете:

• Писать команды обычным языком (например: "подойти к двери", "поговорить с барменом")
• Использовать `/describe` чтобы узнать что происходит на экране
• Использовать `/help` для получения справки

⚠️ **Внимание:** Игра должна быть запущена и активна для корректной работы бота.
        """
        
        keyboard = [
            [InlineKeyboardButton("📖 Описать экран", callback_data="describe")],
            [InlineKeyboardButton("📊 Статус игры", callback_data="status")],
            [InlineKeyboardButton("❓ Помощь", callback_data="help")]
        ]
        reply_markup = InlineKeyboardMarkup(keyboard)
        
        update.message.reply_text(
            welcome_text, 
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
        
        # Запускаем сессию
        self.active_sessions[chat_id] = datetime.now()
        logger.info(f"Новая сессия запущена для чата {chat_id}")

    def help_command(self, update: Update, context: CallbackContext):
        """Команда /help"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            update.message.reply_text("❌ Доступ запрещен.")
            return
        
        if not self._check_rate_limit(chat_id):
            update.message.reply_text("⚠️ Слишком много команд. Подождите минуту.")
            return
        
        help_text = """
📖 **Справка по Disco Coop Bot**

**Основные команды:**
• `/start` - Запустить бота
• `/describe` - Описать что происходит на экране
• `/status` - Показать статус игры и бота
• `/help` - Показать эту справку

**Игровые команды:**
Пишите команды обычным текстом, например:
• "подойти к двери"
• "поговорить с барменом" 
• "осмотреть комнату"
• "использовать предмет"

**Ограничения:**
• Максимум команд в минуту: 10
• Сессия автоматически завершается через 30 минут бездействия

⚡ **Совет:** Чем более конкретно вы опишете действие, тем лучше будет результат!
        """
        
        update.message.reply_text(help_text, parse_mode='Markdown')

    def describe_command(self, update: Update, context: CallbackContext):
        """Команда /describe - описание экрана"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            update.message.reply_text("❌ Доступ запрещен.")
            return
        
        if not self._check_rate_limit(chat_id):
            update.message.reply_text("⚠️ Слишком много команд. Подождите минуту.")
            return
        
        try:
            # Получаем скриншот и анализируем
            update.message.reply_text("📸 Анализирую экран...")
            
            screenshot_path = self.screen_analyzer.capture_screenshot()
            description = self.screen_analyzer.analyze_screenshot(screenshot_path)
            
            update.message.reply_text(f"📖 **Описание экрана:**\n\n{description}", parse_mode='Markdown')
            
        except Exception as e:
            logger.error(f"Ошибка при анализе экрана: {e}")
            update.message.reply_text("❌ Ошибка при анализе экрана. Убедитесь, что игра запущена.")

    def status_command(self, update: Update, context: CallbackContext):
        """Команда /status - статус системы"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            update.message.reply_text("❌ Доступ запрещен.")
            return
        
        try:
            # Проверяем компоненты системы
            llm_status = "✅ Работает" if self.llm_agent.is_available() else "❌ Недоступен"
            vision_status = "✅ Работает" if self.screen_analyzer.is_available() else "❌ Недоступен"
            controller_status = "✅ Работает" if self.game_controller.is_available() else "❌ Недоступен"
            
            # Статистика сессии
            session_start = self.active_sessions.get(chat_id)
            session_duration = "Неактивна"
            if session_start:
                duration = datetime.now() - session_start
                session_duration = f"{duration.seconds // 60} мин"
            
            commands_used = self.chat_command_count.get(chat_id, 0)
            
            status_text = f"""
📊 **Статус системы Disco Coop**

**Компоnenты:**
• LLM агент: {llm_status}
• Анализ экрана: {vision_status}  
• Управление игрой: {controller_status}

**Сессия:**
• Продолжительность: {session_duration}
• Команд использовано: {commands_used}/10 в минуту

**Конфигурация:**
• Модель LLM: {self.config.llm.model_name}
• Разрешение экрана: {self.config.vision.screenshot_resolution}
            """
            
            update.message.reply_text(status_text, parse_mode='Markdown')
            
        except Exception as e:
            logger.error(f"Ошибка при получении статуса: {e}")
            update.message.reply_text("❌ Ошибка при получении статуса системы.")

    def handle_game_command(self, update: Update, context: CallbackContext):
        """Обработка игровых команд"""
        chat_id = update.effective_chat.id
        user_command = update.message.text
        
        if not self._is_authorized_chat(chat_id):
            update.message.reply_text("❌ Доступ запрещен.")
            return
        
        if not self._check_rate_limit(chat_id):
            update.message.reply_text("⚠️ Слишком много команд. Подождите минуту.")
            return
        
        try:
            # Обновляем активность сессии
            self.active_sessions[chat_id] = datetime.now()
            
            # Показываем что обрабатываем команду
            update.message.reply_text("🎮 Выполняю команду...")
            
            # Получаем текущее состояние экрана
            screenshot_path = self.screen_analyzer.capture_screenshot()
            screen_context = self.screen_analyzer.analyze_screenshot(screenshot_path)
            
            # Получаем план действий от LLM
            action_plan = self.llm_agent.process_command(user_command, screen_context)
            
            # Выполняем действия
            result = self.game_controller.execute_actions(action_plan)
            
            # Формируем ответ
            response = f"✅ **Выполнено:** {user_command}\n\n📋 **Результат:** {result}"
            
            # Добавляем клавиатуру для быстрых действий
            keyboard = [
                [InlineKeyboardButton("📖 Описать экран", callback_data="describe")],
                [InlineKeyboardButton("📊 Статус", callback_data="status")]
            ]
            reply_markup = InlineKeyboardMarkup(keyboard)
            
            update.message.reply_text(
                response, 
                reply_markup=reply_markup,
                parse_mode='Markdown'
            )
            
        except Exception as e:
            logger.error(f"Ошибка при выполнении игровой команды: {e}")
            update.message.reply_text(
                f"❌ Ошибка при выполнении команды: {str(e)}\n\n"
                "Убедитесь, что игра запущена и активна."
            )

    def button_callback(self, update: Update, context: CallbackContext):
        """Обработка нажатий inline кнопок"""
        query = update.callback_query
        chat_id = query.message.chat_id
        
        if not self._is_authorized_chat(chat_id):
            query.answer("❌ Доступ запрещен.")
            return
        
        query.answer()  # Убираем индикатор загрузки
        
        # Обрабатываем команду
        if query.data == "describe":
            self.describe_command(update, context)
        elif query.data == "status":
            self.status_command(update, context)
        elif query.data == "help":
            self.help_command(update, context)

    def emergency_stop(self, update: Update, context: CallbackContext):
        """Экстренная остановка игры"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            update.message.reply_text("❌ Доступ запрещен.")
            return
        
        try:
            # Останавливаем все действия
            self.game_controller.emergency_stop()
            
            # Завершаем сессию
            if chat_id in self.active_sessions:
                del self.active_sessions[chat_id]
            
            update.message.reply_text("🛑 **Экстренная остановка выполнена!**\n\nВсе действия прерваны.")
            
        except Exception as e:
            logger.error(f"Ошибка при экстренной остановке: {e}")
            update.message.reply_text("❌ Ошибка при экстренной остановке.")

    def _cleanup_sessions(self):
        """Очистка неактивных сессий"""
        try:
            now = datetime.now()
            inactive_sessions = []
            
            for chat_id, last_activity in self.active_sessions.items():
                if (now - last_activity).total_seconds() > 1800:  # 30 минут
                    inactive_sessions.append(chat_id)
            
            for chat_id in inactive_sessions:
                del self.active_sessions[chat_id]
                logger.info(f"Сессия {chat_id} завершена по таймауту")
                
        except Exception as e:
            logger.error(f"Ошибка при очистке сессий: {e}")

    def _start_cleanup_timer(self):
        """Запуск таймера очистки сессий"""
        self._cleanup_sessions()
        self.cleanup_timer = threading.Timer(300.0, self._start_cleanup_timer)  # каждые 5 минут
        self.cleanup_timer.daemon = True
        self.cleanup_timer.start()

    def run(self):
        """Запуск бота"""
        try:
            logger.info("🚀 Запуск Disco Coop Bot...")
            logger.info(f"📡 Авторизованные чаты: {self.config.telegram.allowed_chats}")
            
            # Запускаем polling
            self.updater.start_polling()
            logger.info("✅ Бот запущен успешно!")
            
            # Ждем остановки
            self.updater.idle()
            
        except Exception as e:
            logger.error(f"❌ Ошибка при запуске бота: {e}")
            raise
        finally:
            if self.cleanup_timer:
                self.cleanup_timer.cancel()
            logger.info("🛑 Disco Coop Bot остановлен")

    def stop(self):
        """Остановка бота"""
        if self.cleanup_timer:
            self.cleanup_timer.cancel()
        self.updater.stop()