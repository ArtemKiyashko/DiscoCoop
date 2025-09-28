# API Reference

Документация по API и внутренним интерфейсам Disco Coop.

## Основные классы

### Config

Класс для управления конфигурацией приложения.

```python
from src.utils.config import Config

# Загрузка конфигурации
config = Config.load()  # Автоматически ищет config.yaml
config = Config.load("path/to/config.yaml")  # Указание конкретного файла

# Валидация
config.validate()  # Выбрасывает ValueError при ошибках
```

### DiscoCoopBot

Основной класс Telegram бота.

```python
from src.bot.disco_bot import DiscoCoopBot
from src.utils.config import Config

config = Config.load()
bot = DiscoCoopBot(config)

# Запуск
await bot.run()
```

### LLMAgent

Класс для работы с локальной LLM через Ollama.

```python
from src.llm.agent import LLMAgent

agent = LLMAgent(config)

# Проверка доступности
is_available = await agent.is_available()

# Обработка команды пользователя
result = await agent.process_command("подойти к двери", screenshot)

# Описание экрана
description = await agent.describe_screen(screenshot)
```

### ScreenAnalyzer

Класс для захвата и анализа скриншотов.

```python
from src.vision.screen_analyzer import ScreenAnalyzer

analyzer = ScreenAnalyzer(config)

# Захват скриншота
screenshot = await analyzer.take_screenshot()

# Описание экрана
description = await analyzer.describe_screen()

# Поиск UI элементов
elements = analyzer.find_ui_elements(screenshot)
```

### GameController

Класс для управления игрой через эмуляцию ввода.

```python
from src.game.controller import GameController

controller = GameController(config)

# Проверка запуска игры
is_running = controller.is_game_running()

# Выполнение действий
actions = [
    {"type": "click", "x": 400, "y": 300},
    {"type": "key_press", "key": "space"}
]
success = await controller.execute_actions(actions)
```

## Форматы данных

### Игровые действия

Действия передаются в виде списка словарей. Каждое действие имеет тип и параметры.

#### Клик мышью
```python
{
    "type": "click",
    "x": 400,
    "y": 300,
    "button": "left",  # "left", "right"
    "clicks": 1
}
```

#### Перемещение мыши
```python
{
    "type": "move_mouse",
    "x": 400,
    "y": 300,
    "duration": 0.5
}
```

#### Нажатие клавиши
```python
{
    "type": "key_press",
    "key": "space"  # Название клавиши
}
```

#### Ввод текста
```python
{
    "type": "type_text",
    "text": "Hello World",
    "interval": 0.05
}
```

#### Прокрутка
```python
{
    "type": "scroll",
    "direction": "up",  # "up", "down"
    "amount": 3,
    "x": 400,  # Опционально
    "y": 300   # Опционально
}
```

#### Перетаскивание
```python
{
    "type": "drag",
    "from_x": 100,
    "from_y": 100,
    "to_x": 200,
    "to_y": 200,
    "duration": 1.0
}
```

#### Комбинация клавиш
```python
{
    "type": "key_combination",
    "keys": ["ctrl", "s"]  # Ctrl+S
}
```

### Ответ LLM

LLM должна возвращать JSON в следующем формате:

```python
{
    "actions": [
        # Список действий
    ],
    "description": "Описание того, что будет выполнено"
}
```

### UI элементы

Результат поиска UI элементов:

```python
{
    "buttons": [
        {
            "x": 400,
            "y": 300,
            "width": 100,
            "height": 30,
            "confidence": 0.8
        }
    ],
    "text_areas": [
        # Текстовые области
    ],
    "dialogs": [
        {
            "x": 100,
            "y": 100,
            "width": 400,
            "height": 200,
            "center_x": 300,
            "center_y": 200
        }
    ]
}
```

## Конфигурация

### Структура конфигурационного файла

```yaml
telegram:
  bot_token: str
  allowed_chats: List[int]
  admin_users: List[int]

llm:
  provider: str
  model: str
  vision_model: str
  base_url: str
  max_tokens: int
  temperature: float
  system_prompt: str

game:
  window_title: str
  screenshot_interval: float
  action_delay: float
  screen_resolution:
    width: int
    height: int

vision:
  describe_prompt: str

logging:
  level: str
  file: str
  max_size: str
  backup_count: int

security:
  rate_limit: int
  emergency_stop_command: str
  max_session_time: int
```

## События и хуки

### Telegram события

- `start_command` - Команда /start
- `help_command` - Команда /help
- `describe_command` - Команда /describe
- `status_command` - Команда /status
- `handle_game_command` - Обработка игровых команд
- `emergency_stop` - Экстренная остановка

### Игровые события

- `execute_actions` - Выполнение списка действий
- `focus_game_window` - Фокусировка на окне игры
- `stop_all_actions` - Остановка всех действий

## Обработка ошибок

### Типы ошибок

- `ConfigurationError` - Ошибки конфигурации
- `LLMError` - Ошибки LLM
- `GameControlError` - Ошибки управления игрой
- `ScreenCaptureError` - Ошибки захвата экрана

### Логирование

Используется библиотека `loguru` с уровнями:
- `DEBUG` - Детальная отладочная информация
- `INFO` - Общая информация о работе
- `WARNING` - Предупреждения
- `ERROR` - Ошибки
- `CRITICAL` - Критические ошибки

## Расширение функциональности

### Добавление новых типов действий

1. Добавьте новый тип в `GameController._execute_single_action()`
2. Реализуйте метод `_action_<название>()`
3. Обновите системный промпт LLM
4. Добавьте документацию

### Добавление новых команд бота

1. Создайте метод-обработчик в `DiscoCoopBot`
2. Зарегистрируйте обработчик в `_setup_handlers()`
3. Обновите справку в `help_command()`

### Интеграция с другими LLM

1. Создайте новый класс-провайдер в `src/llm/`
2. Реализуйте интерфейс `LLMAgent`
3. Добавьте поддержку в конфигурацию
4. Обновите фабрику создания агентов