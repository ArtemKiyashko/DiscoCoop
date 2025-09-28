"""
Конфигурационный модуль для загрузки настроек
"""
import os
import yaml
from typing import Dict, List, Any
from dataclasses import dataclass
from pathlib import Path


@dataclass
class TelegramConfig:
    """Конфигурация Telegram бота"""
    bot_token: str
    allowed_chats: List[int]
    admin_users: List[int]


@dataclass 
class LLMConfig:
    """Конфигурация LLM"""
    provider: str
    model: str
    vision_model: str
    base_url: str
    max_tokens: int
    temperature: float
    system_prompt: str


@dataclass
class GameConfig:
    """Конфигурация игры"""
    window_title: str
    screenshot_interval: float
    action_delay: float
    screen_resolution: Dict[str, int]


@dataclass
class VisionConfig:
    """Конфигурация модуля зрения"""
    describe_prompt: str


@dataclass
class LoggingConfig:
    """Конфигурация логирования"""
    level: str
    file: str
    max_size: str
    backup_count: int


@dataclass
class SecurityConfig:
    """Конфигурация безопасности"""
    rate_limit: int
    emergency_stop_command: str
    max_session_time: int


@dataclass
class Config:
    """Основная конфигурация"""
    telegram: TelegramConfig
    llm: LLMConfig
    game: GameConfig
    vision: VisionConfig
    logging: LoggingConfig
    security: SecurityConfig
    
    @classmethod
    def load(cls, config_path: str = None) -> 'Config':
        """Загрузка конфигурации из файла"""
        if config_path is None:
            # Ищем config.yaml в папке config
            base_dir = Path(__file__).parent.parent.parent
            config_path = base_dir / "config" / "config.yaml"
            
            # Если нет config.yaml, используем example
            if not config_path.exists():
                config_path = base_dir / "config" / "config.example.yaml"
        
        if not os.path.exists(config_path):
            raise FileNotFoundError(f"Config file not found: {config_path}")
        
        with open(config_path, 'r', encoding='utf-8') as f:
            data = yaml.safe_load(f)
        
        return cls._from_dict(data)
    
    @classmethod
    def _from_dict(cls, data: Dict[str, Any]) -> 'Config':
        """Создание конфигурации из словаря"""
        return cls(
            telegram=TelegramConfig(**data['telegram']),
            llm=LLMConfig(**data['llm']),
            game=GameConfig(**data['game']),
            vision=VisionConfig(**data['vision']),
            logging=LoggingConfig(**data['logging']),
            security=SecurityConfig(**data['security'])
        )
    
    def validate(self) -> bool:
        """Валидация конфигурации"""
        errors = []
        
        # Проверка токена
        if not self.telegram.bot_token or self.telegram.bot_token == "YOUR_BOT_TOKEN_HERE":
            errors.append("Telegram bot token not configured")
        
        # Проверка чатов
        if not self.telegram.allowed_chats:
            errors.append("No allowed chats configured")
        
        # Проверка админов
        if not self.telegram.admin_users:
            errors.append("No admin users configured")
        
        if errors:
            raise ValueError("Configuration errors: " + ", ".join(errors))
        
        return True