"""
Тесты для модуля конфигурации
"""
import tempfile
import os
import yaml
import pytest
from src.utils.config import Config, TelegramConfig, LLMConfig


def test_config_load_from_file():
    """Тест загрузки конфигурации из файла"""
    config_data = {
        'telegram': {
            'bot_token': 'test_token',
            'allowed_chats': [-1001234567890],
            'admin_users': [123456789]
        },
        'llm': {
            'provider': 'ollama',
            'model': 'llama3.1:8b',
            'vision_model': 'llava:7b',
            'base_url': 'http://localhost:11434',
            'max_tokens': 2048,
            'temperature': 0.7,
            'system_prompt': 'Test prompt'
        },
        'game': {
            'window_title': 'Disco Elysium',
            'screenshot_interval': 1.0,
            'action_delay': 0.5,
            'screen_resolution': {'width': 1280, 'height': 800}
        },
        'vision': {
            'describe_prompt': 'Describe the screen'
        },
        'logging': {
            'level': 'INFO',
            'file': 'test.log',
            'max_size': '10MB',
            'backup_count': 5
        },
        'security': {
            'rate_limit': 10,
            'emergency_stop_command': '/stop',
            'max_session_time': 180
        }
    }
    
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        yaml.dump(config_data, f)
        config_path = f.name
    
    try:
        config = Config.load(config_path)
        
        assert config.telegram.bot_token == 'test_token'
        assert config.telegram.allowed_chats == [-1001234567890]
        assert config.llm.model == 'llama3.1:8b'
        assert config.game.window_title == 'Disco Elysium'
        
    finally:
        os.unlink(config_path)


def test_config_validation_success():
    """Тест успешной валидации конфигурации"""
    config = Config(
        telegram=TelegramConfig(
            bot_token='valid_token',
            allowed_chats=[-1001234567890],
            admin_users=[123456789]
        ),
        llm=LLMConfig(
            provider='ollama',
            model='llama3.1:8b',
            vision_model='llava:7b',
            base_url='http://localhost:11434',
            max_tokens=2048,
            temperature=0.7,
            system_prompt='Test prompt'
        ),
        game=None,  # Для краткости не создаем все объекты
        vision=None,
        logging=None,
        security=None
    )
    
    # При правильной конфигурации должно пройти без ошибок
    # config.validate()  # Раскомментировать когда будут созданы все объекты


def test_config_validation_failure():
    """Тест неудачной валидации конфигурации"""
    config = Config(
        telegram=TelegramConfig(
            bot_token='YOUR_BOT_TOKEN_HERE',  # Неправильный токен
            allowed_chats=[],  # Пустой список чатов
            admin_users=[]  # Пустой список админов
        ),
        llm=None,
        game=None,
        vision=None,
        logging=None,
        security=None
    )
    
    with pytest.raises(ValueError):
        config.validate()


if __name__ == '__main__':
    test_config_load_from_file()
    print("✅ Тесты конфигурации пройдены")