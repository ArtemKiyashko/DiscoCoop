# API Reference - Disco Coop

## Основные интерфейсы системы

### LLMAgent API

#### `analyze_for_elements(screenshot, command)`
Анализирует скриншот и команду пользователя для определения поисковых целей.

**Параметры**:
- `screenshot: PIL.Image` - Скриншот игрового экрана
- `command: str` - Команда пользователя на естественном языке

**Возвращает**:
```python
{
    "analysis": str,           # Описание того, что видно на экране
    "search_targets": [        # Массив объектов для поиска
        {
            "text": str,       # Текст для поиска
            "type": str,       # Тип элемента: button|text|dialogue|menu
            "description": str # Описание элемента
        }
    ],
    "action_description": str, # Литературное описание действия
    "success": bool           # Флаг успешного анализа
}
```

**Пример**:
```python
result = await llm_agent.analyze_for_elements(screenshot, "новая игра")
# result = {
#     "analysis": "На экране главное меню Disco Elysium",
#     "search_targets": [{"text": "Новая игра", "type": "button", "description": "кнопка начала новой игры"}],
#     "action_description": "Начал новую игру в Disco Elysium",
#     "success": True
# }
```

#### `describe_screen(screenshot)`
Возвращает текстовое описание содержимого экрана.

**Параметры**:
- `screenshot: PIL.Image` - Скриншот для анализа

**Возвращает**:
- `str` - Описание экрана на русском языке

### HybridAnalyzer API

#### `analyze_and_find_element(screenshot, command)`
Главный метод для анализа команды и поиска элементов.

**Параметры**:
- `screenshot: PIL.Image` - Скриншот игрового экрана  
- `command: str` - Команда пользователя

**Возвращает**:
```python
{
    "method": str,            # Метод поиска: "hybrid", "llm_fallback", "failed"
    "analysis": dict,         # Результат анализа от LLM
    "coordinates": tuple,     # Координаты (x, y) или None
    "action_description": str,# Описание выполненного действия
    "success": bool          # Флаг успеха
}
```

### ElementDetector API

#### `find_element(screenshot, text)`
Ищет текстовый элемент на скриншоте и возвращает его координаты.

**Параметры**:
- `screenshot: PIL.Image` - Изображение для поиска
- `text: str` - Текст для поиска

**Возвращает**:
```python
DetectedElement {
    "center_x": int,     # X координата центра элемента
    "center_y": int,     # Y координата центра элемента  
    "confidence": float, # Уверенность распознавания (0.0-1.0)
    "bounds": tuple     # Границы элемента (x1, y1, x2, y2)
}
```

### GameController API

#### `execute_actions(actions)`
Выполняет массив игровых действий.

**Параметры**:
- `actions: List[Dict]` - Список действий для выполнения

**Поддерживаемые действия**:
```python
# Клик мышью
{"type": "click", "x": 400, "y": 300}

# Нажатие клавиши
{"type": "key_press", "key": "space"}

# Ввод текста
{"type": "type_text", "text": "Hello World"}

# Прокрутка
{"type": "scroll", "direction": "up", "amount": 3}

# Перемещение мыши
{"type": "move_mouse", "x": 400, "y": 300}
```

**Возвращает**:
- `bool` - True если все действия выполнены успешно

## Конфигурация провайдеров

### OpenAI
```yaml
llm:
  provider: "openai"
  model: "gpt-4o-mini"
  vision_model: "gpt-4o"
  base_url: "https://api.openai.com/v1"
  api_key: "sk-your-openai-key"
  max_tokens: 2048
  temperature: 0.1
```

### Anthropic Claude
```yaml
llm:
  provider: "anthropic"
  model: "claude-3-5-sonnet-20241022"
  vision_model: "claude-3-5-sonnet-20241022"
  base_url: "https://api.anthropic.com"
  api_key: "sk-ant-your-key"
  max_tokens: 2048
  temperature: 0.1
```

### DeepSeek
```yaml
llm:
  provider: "deepseek"
  model: "deepseek-chat"
  vision_model: "gpt-4o"  # DeepSeek не поддерживает vision
  base_url: "https://api.deepseek.com"
  api_key: "sk-your-deepseek-key"
  max_tokens: 2048
  temperature: 0.1
```

### Ollama (локально)
```yaml
llm:
  provider: "ollama"
  model: "llama3.1:8b"
  vision_model: "llava:7b"
  base_url: "http://localhost:11434"
  api_key: ""
  max_tokens: 2048
  temperature: 0.1
```

## События и коллбэки

### Telegram Bot Events

#### Команды
```python
# Стандартные команды
/start          # Приветствие и инструкции
/help           # Справка по командам
/status         # Статус системы
/screenshot     # Снимок экрана
/describe       # Описание экрана

# Админские команды
/stop_game      # Экстренная остановка
/reload_config  # Перезагрузка конфигурации
```

#### Обработчики сообщений
```python
async def handle_game_command(update, context):
    """Обработка игровых команд"""
    pass

async def button_callback(update, context):
    """Обработка inline кнопок"""
    pass
```

## Расширение системы

### Добавление нового провайдера LLM

1. **Расширить LLMAgent**:
```python
async def _query_your_provider_api(self, prompt: str) -> Optional[Dict]:
    # Реализация запроса к вашему API
    pass
```

2. **Добавить проверку доступности**:
```python
async def _check_your_provider_availability(self) -> bool:
    # Проверка доступности API
    pass
```

3. **Обновить конфигурацию**:
```yaml
llm:
  provider: "your_provider"
  # ... остальные параметры
```

### Добавление нового типа действий

1. **Расширить GameController**:
```python
async def _execute_your_action(self, action: Dict) -> bool:
    # Реализация нового действия
    pass
```

2. **Обновить промпт**:
```yaml
analysis_prompt: |
  Доступные типы действий:
  - your_action: описание нового действия
```

### Интеграция с другой игрой

1. **Изменить конфигурацию**:
```yaml
game:
  window_title: "Your Game Title"
```

2. **Адаптировать промпты**:
```yaml
analysis_prompt: |
  Проанализируй скриншот игры Your Game...
```

3. **Настроить детектор** (если нужно):
```python
# Специфичные для игры настройки OCR или поиска
```

## Мониторинг и метрики

### Логирование
Система использует структурированное логирование с эмодзи для удобства:

```python
🧠 LLM команда: описание действия
🔍 Поисковые цели: список целей  
🎯 Найдены координаты: (x, y)
❌ Элементы не найдены: список
⚠️ Предупреждение: описание
✅ Успех: описание
```

### Доступные метрики
- Время отклика LLM провайдеров
- Процент успешных распознаваний элементов
- Статистика использования команд
- Частота ошибок по компонентам

## Отладка и диагностика

### Включение расширенного логирования
```yaml
logging:
  level: "DEBUG"  # INFO, DEBUG, WARNING, ERROR
```

### Тестирование компонентов

#### Тест LLM подключения:
```python
agent = LLMAgent(config)
available = await agent.is_available()
test_result = await agent.test_model()
```

#### Тест детектора элементов:
```python
detector = GameElementDetector()
result = detector.find_element(screenshot, "Новая игра")
```

#### Тест гибридного анализатора:
```python
analyzer = HybridAnalyzer(config)
result = await analyzer.analyze_and_find_element(screenshot, "новая игра")
```

## Ошибки и их решение

### Частые проблемы

#### LLM недоступен
```
❌ Не удается подключиться к OpenAI API
```
**Решение**: Проверить API ключ и подключение к интернету

#### Игра не найдена
```
❌ Игра не запущена или не найдена
```
**Решение**: Запустить игру в оконном режиме, проверить window_title

#### Элементы не найдены
```
❌ Элементы не найдены на экране
```
**Решение**: Улучшить описание в команде, проверить качество скриншота

### Коды ошибок
- `E001`: Ошибка конфигурации
- `E002`: LLM недоступен  
- `E003`: Игровое окно не найдено
- `E004`: Ошибка создания скриншота
- `E005`: Ошибка выполнения действий