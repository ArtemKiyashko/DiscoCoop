# Конфигурации для быстрых LLM API

## DeepSeek (Рекомендуется для Steam Deck)

**Преимущества:**
- 🚀 Очень быстро (2-3 секунды вместо 30-60)
- 💰 Дешево ($0.14 за 1M токенов) 
- 🧠 Качественные ответы

**Конфигурация:**
```yaml
llm:
  provider: "deepseek"
  model: "deepseek-chat"
  vision_model: "gpt-4o"  # Для vision используем OpenAI
  base_url: "https://api.deepseek.com"
  api_key: "sk-your-deepseek-key-here"
  max_tokens: 2048
  temperature: 0.7
```

**Получение ключа:**
1. Регистрация: https://platform.deepseek.com/
2. Получите API ключ
3. Пополните баланс на $5-10

---

## OpenAI (Премиум качество)

**Преимущества:**
- 🚀 Очень быстро
- 👁️ Отличная vision модель
- 🎯 Высокое качество ответов

**Конфигурация:**
```yaml
llm:
  provider: "openai"
  model: "gpt-4o-mini"      # Быстрая и дешевая
  vision_model: "gpt-4o"    # Лучшая vision модель
  base_url: "https://api.openai.com"
  api_key: "sk-your-openai-key-here"
  max_tokens: 2048
  temperature: 0.7
```

**Получение ключа:**
1. Регистрация: https://platform.openai.com/
2. API Keys → Create new secret key
3. Пополните баланс

---

## Стоимость (примерно):

**DeepSeek:**
- Текст: $0.14 за 1M токенов (~$0.10 за день активного использования)
- Vision: Через OpenAI ($3 за 1K изображений)

**OpenAI:**
- gpt-4o-mini: $0.15 за 1M input токенов
- gpt-4o vision: $2.50 за 1K изображений

---

## Настройка:

1. **Скопируйте config.example.yaml в config.yaml**
2. **Выберите провайдера и настройте**
3. **Добавьте API ключ**
4. **Перезапустите бота**

## Результат на Steam Deck:

- **Ollama**: 30-60 секунд на запрос ⏳
- **DeepSeek/OpenAI**: 2-5 секунд на запрос ⚡

Рекомендация: **DeepSeek** для оптимального соотношения скорость/цена/качество!