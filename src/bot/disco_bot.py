"""
Telegram Bot для управления игрой Disco Elysium
"""
import asyncio
import json
import time
from typing import Dict, List, Optional
from datetime import datetime, timedelta

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup, InlineQueryResultArticle, InputTextMessageContent
from telegram.ext import (
    Application, 
    CommandHandler, 
    MessageHandler, 
    CallbackQueryHandler,
    InlineQueryHandler,
    filters,
    ContextTypes
)
from loguru import logger

from ..utils.config import Config
from ..llm.agent import LLMAgent
from ..vision.screen_analyzer import ScreenAnalyzer
from ..game.controller import GameController


class DiscoCoopBot:
    """Основной класс Telegram бота для Disco Coop"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm_agent = LLMAgent(config)
        self.screen_analyzer = ScreenAnalyzer(config)
        self.game_controller = GameController(config)
        
        # Статистика и контроль доступа
        self.chat_last_command: Dict[int, datetime] = {}
        self.chat_command_count: Dict[int, int] = {}
        self.active_sessions: Dict[int, datetime] = {}
        
        # Создаем приложение
        self.application = Application.builder().token(
            config.telegram.bot_token
        ).build()
        
        self._setup_handlers()
    
    def _setup_handlers(self):
        """Настройка обработчиков команд и сообщений"""
        # Команда /start
        self.application.add_handler(CommandHandler("start", self.start_command))
        
        # Команда /game для игровых действий (работает в группах)
        self.application.add_handler(CommandHandler("game", self.game_command))
        
        # Обработчик для личных сообщений (все текстовые)
        self.application.add_handler(MessageHandler(
            filters.ChatType.PRIVATE & filters.TEXT & ~filters.COMMAND,
            self.handle_private_message
        ))
        
        # Обработчик для групп - все текстовые сообщения (фильтруем внутри функции)
        self.application.add_handler(MessageHandler(
            (filters.ChatType.GROUP | filters.ChatType.SUPERGROUP) & filters.TEXT,
            self.handle_group_message
        ))
        
        # Inline обработчик для групп
        self.application.add_handler(InlineQueryHandler(self.handle_inline_query))
        
        # Обработка callback-ов от inline клавиатуры
        self.application.add_handler(CallbackQueryHandler(self.button_callback))
    
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
    
    async def start_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Команда /start"""
        chat_id = update.effective_chat.id
        chat_type = update.effective_chat.type
        chat_title = getattr(update.effective_chat, 'title', 'Private Chat')
        user_name = update.effective_user.username or update.effective_user.first_name
        
        # Логируем все попытки запуска
        logger.info(f"📨 Команда /start получена:")
        logger.info(f"   Chat ID: {chat_id}")
        logger.info(f"   Chat Type: {chat_type}")
        logger.info(f"   Chat Title: {chat_title}")
        logger.info(f"   User: {user_name} (ID: {update.effective_user.id})")
        
        if not self._is_authorized_chat(chat_id):
            logger.warning(f"🚫 Доступ запрещен для чата {chat_id} ({chat_title})")
            await update.message.reply_text("❌ Доступ к боту запрещен.")
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
        
        await update.message.reply_text(
            welcome_text, 
            reply_markup=reply_markup,
            parse_mode='Markdown'
        )
        
        # Запускаем сессию
        self.active_sessions[chat_id] = datetime.now()
        logger.info(f"Started session for chat {chat_id}")
    
    async def help_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Команда /help"""
        help_text = """
🎮 **Disco Coop - Справка**

**Основные команды:**
• `/start` - Начать работу с ботом
• `/describe` - Описать что происходит на экране
• `/status` - Показать статус игры и бота
• `/help` - Показать эту справку

**Игровые команды (примеры):**
• "подойти к двери"
• "поговорить с бармен"
• "открыть инвентарь"
• "прочитать книгу"
• "выбрать первый вариант диалога"
• "сохранить игру"

**Правила:**
• Максимум {} команд в минуту на чат
• Сессия автоматически завершается через {} минут
• Экстренная остановка: `{}`

**Статус бота:** {}
        """.format(
            self.config.security.rate_limit,
            self.config.security.max_session_time,
            self.config.security.emergency_stop_command,
            "🟢 Активен" if self.game_controller.is_game_running() else "🔴 Игра не найдена"
        )
        
        await update.message.reply_text(help_text, parse_mode='Markdown')
    
    async def describe_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Команда /describe - описать экран"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            await update.message.reply_text("❌ Доступ запрещен.")
            return
        
        if not self._check_rate_limit(chat_id):
            await update.message.reply_text("⏳ Превышен лимит команд. Подождите минуту.")
            return
        
        # Показываем, что бот работает
        await update.message.reply_text("📸 Анализирую экран...")
        
        try:
            # Делаем скриншот и анализируем
            description = await self.screen_analyzer.describe_screen()
            
            if description:
                await update.message.reply_text(f"👁️ **На экране:**\n{description}", parse_mode='Markdown')
            else:
                await update.message.reply_text("❌ Не удалось проанализировать экран. Убедитесь, что игра запущена.")
        
        except Exception as e:
            logger.error(f"Error in describe_command: {e}")
            await update.message.reply_text("❌ Ошибка при анализе экрана.")
    
    async def status_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Команда /status"""
        chat_id = update.effective_chat.id
        
        if not self._is_authorized_chat(chat_id):
            await update.message.reply_text("❌ Доступ запрещен.")
            return
        
        game_status = "🟢 Запущена" if self.game_controller.is_game_running() else "🔴 Не найдена"
        llm_status = "🟢 Подключена" if await self.llm_agent.is_available() else "🔴 Недоступна"
        
        session_time = ""
        if chat_id in self.active_sessions:
            elapsed = datetime.now() - self.active_sessions[chat_id]
            session_time = f"⏱️ Время сессии: {elapsed.seconds // 60} мин"
        
        status_text = f"""
📊 **Статус системы**

🎮 Игра: {game_status}
🤖 LLM: {llm_status}
💬 Чат: {"🟢 Авторизован" if self._is_authorized_chat(chat_id) else "🔴 Не авторизован"}
{session_time}

📋 Команд выполнено: {self.chat_command_count.get(chat_id, 0)}
⏳ Лимит: {self.config.security.rate_limit}/мин
        """
        
        await update.message.reply_text(status_text, parse_mode='Markdown')
    
    async def handle_private_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик личных сообщений"""
        await self.handle_game_command(update, context)
    
    async def handle_group_message(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик сообщений в группах (фильтруем упоминания и команды)"""
        chat_id = update.effective_chat.id
        chat_title = getattr(update.effective_chat, 'title', 'Group')
        message_text = update.message.text or ""
        user_name = update.effective_user.username or update.effective_user.first_name
        
        # ВСЕГДА логируем все входящие сообщения в группах для диагностики
        logger.info(f"📩 ГРУППА {chat_title} (ID: {chat_id})")
        logger.info(f"   От: {user_name} (ID: {update.effective_user.id})")
        logger.info(f"   Текст: '{message_text}'")
        
        # Получаем информацию о боте
        bot_info = await context.bot.get_me()
        bot_username = bot_info.username
        
        # Проверяем что сообщение адресовано боту
        is_mention = f'@{bot_username}' in message_text
        is_reply_to_bot = (update.message.reply_to_message and 
                         update.message.reply_to_message.from_user.id == bot_info.id)
        is_command = message_text.startswith('/')
        
        logger.info(f"   Бот: @{bot_username}")
        logger.info(f"   Упоминание: {is_mention}")
        logger.info(f"   Ответ на бота: {is_reply_to_bot}")
        logger.info(f"   Команда: {is_command}")
        
        # Обрабатываем только если сообщение адресовано боту
        if is_mention or is_reply_to_bot:
            logger.info(f"✅ ОБРАБАТЫВАЕМ сообщение в группе")
            await self.handle_game_command(update, context)
        elif is_command:
            logger.info(f"📋 КОМАНДА в группе - обрабатывается отдельным CommandHandler")
        else:
            logger.info(f"❌ ИГНОРИРУЕМ сообщение в группе - не адресовано боту")
    
    async def game_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Команда /game для игровых действий в группах"""
        command_args = " ".join(context.args) if context.args else "описать экран"
        
        logger.info(f"🎮 Команда /game: {command_args}")
        
        # Обрабатываем команду напрямую
        await self.process_game_action(update, context, command_args)
    
    async def handle_inline_query(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработчик inline запросов для групп"""
        query = update.inline_query.query.strip()
        
        # Игнорируем слишком короткие запросы (пока пользователь еще печатает)
        if len(query) < 3:
            await update.inline_query.answer([])
            return
        
        if not query:
            query = "описать экран"
        
        logger.info(f"🔍 Inline запрос: {query}")
        
        results = [
            InlineQueryResultArticle(
                id="game_action",
                title=f"🎮 Выполнить: {query}",
                description="Нажмите чтобы выполнить игровое действие",
                input_message_content=InputTextMessageContent(
                    message_text=f"/game {query}"
                )
            )
        ]
        
        await update.inline_query.answer(results)
    
    async def process_game_action(self, update: Update, context: ContextTypes.DEFAULT_TYPE, user_command: str):
        """Общая логика обработки игровых действий"""
        chat_id = update.effective_chat.id
        chat_type = update.effective_chat.type
        chat_title = getattr(update.effective_chat, 'title', 'Private Chat')
        user_name = update.effective_user.username or update.effective_user.first_name
        
        # Логируем команду
        logger.info(f"🎮 Обработка игрового действия:")
        logger.info(f"   Chat ID: {chat_id}")
        logger.info(f"   Chat Type: {chat_type}")
        logger.info(f"   Chat Title: {chat_title}")
        logger.info(f"   User: {user_name} (ID: {update.effective_user.id})")
        logger.info(f"   Command: {user_command}")
        
        if not self._is_authorized_chat(chat_id):
            logger.warning(f"🚫 Доступ запрещен для чата {chat_id} ({chat_title})")
            await update.message.reply_text("❌ Доступ к боту запрещен.")
            return
        
        if not self._check_rate_limit(chat_id):
            await update.message.reply_text("⏳ Превышен лимит команд. Подождите минуту.")
            return
        
        if not self.game_controller.is_game_running():
            await update.message.reply_text("❌ Игра не запущена или не найдена.")
            return
        
        # Показываем, что обрабатываем команду
        processing_msg = await update.message.reply_text("🎮 Выполняю команду...")
        
        try:
            # Получаем текущий скриншот для контекста
            screenshot = await self.screen_analyzer.take_screenshot()
            
            # Обрабатываем команду через LLM
            result = await self.llm_agent.process_command(user_command, screenshot)
            
            if result and result.get('actions'):
                # Выполняем действия в игре
                success = await self.game_controller.execute_actions(result['actions'])
                
                if success:
                    response = f"✅ {result.get('description', 'Команда выполнена')}"
                else:
                    response = "⚠️ Команда выполнена частично или с ошибками"
            else:
                response = "❓ Не удалось понять команду. Попробуйте переформулировать."
            
            # Обновляем сообщение с результатом
            await processing_msg.edit_text(response)
            
        except Exception as e:
            logger.error(f"Error processing command '{user_command}': {e}")
            await processing_msg.edit_text("❌ Ошибка при выполнении команды.")
    
    async def handle_game_command(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработка игровых команд из обычных сообщений"""
        user_command = update.message.text
        chat_type = update.effective_chat.type
        
        # В группах очищаем упоминание бота из команды
        if chat_type in ['group', 'supergroup']:
            # Получаем информацию о боте
            bot_info = await context.bot.get_me()
            bot_username = bot_info.username
            
            # Убираем упоминание бота из начала сообщения
            if user_command.startswith(f'@{bot_username}'):
                user_command = user_command[len(f'@{bot_username}'):].strip()
                logger.info(f"   Очищенная команда: {user_command}")
            
            # Если сообщение было пустым после удаления упоминания, используем дефолтную команду
            if not user_command:
                user_command = "описать экран"
        
        # Передаем в общую функцию обработки
        await self.process_game_action(update, context, user_command)
    
    async def button_callback(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Обработка нажатий inline кнопок"""
        query = update.callback_query
        await query.answer()
        
        if query.data == "describe":
            await self.describe_command(update, context)
        elif query.data == "status":
            await self.status_command(update, context)
        elif query.data == "help":
            await self.help_command(update, context)
    
    async def emergency_stop(self, update: Update, context: ContextTypes.DEFAULT_TYPE):
        """Экстренная остановка"""
        user_id = update.effective_user.id
        
        if user_id not in self.config.telegram.admin_users:
            await update.message.reply_text("❌ Недостаточно прав.")
            return
        
        # Останавливаем все активные действия
        await self.game_controller.stop_all_actions()
        
        # Очищаем активные сессии
        self.active_sessions.clear()
        
        await update.message.reply_text("🛑 Экстренная остановка выполнена. Все действия остановлены.")
        logger.warning(f"Emergency stop triggered by user {user_id}")
    
    async def cleanup_sessions(self):
        """Очистка устаревших сессий"""
        now = datetime.now()
        max_time = timedelta(minutes=self.config.security.max_session_time)
        
        expired_sessions = [
            chat_id for chat_id, start_time in self.active_sessions.items()
            if now - start_time > max_time
        ]
        
        for chat_id in expired_sessions:
            del self.active_sessions[chat_id]
            logger.info(f"Session expired for chat {chat_id}")
    
    def run(self):
        """Запуск бота (синхронный метод)"""
        logger.info("🚀 Запуск Disco Coop Bot...")
        logger.info(f"📡 Авторизованные чаты: {self.config.telegram.allowed_chats}")
        
        # Добавляем callback для запуска фоновых задач
        async def post_init(application):
            """Callback после инициализации приложения"""
            # Запускаем фоновую задачу очистки сессий
            asyncio.create_task(self._cleanup_task())
        
        # Регистрируем callback
        self.application.post_init = post_init
        
        # Запускаем бота (run_polling сам управляет event loop)
        self.application.run_polling(drop_pending_updates=True)
    
    async def _cleanup_task(self):
        """Фоновая задача очистки сессий"""
        while True:
            await asyncio.sleep(300)  # Каждые 5 минут
            await self.cleanup_sessions()