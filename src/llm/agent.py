"""
LLM Agent для обработки команд и взаимодействия с Ollama
"""
import json
import asyncio
import aiohttp
from typing import Dict, List, Optional, Any
from PIL import Image
import io
import base64

from ..utils.config import Config


class LLMAgent:
    """Агент для работы с локальной LLM через Ollama"""
    
    def __init__(self, config: Config):
        self.config = config
        self.base_url = config.llm.base_url
        self.model = config.llm.model
        self.vision_model = config.llm.vision_model
        self.session = None
    
    async def _get_session(self) -> aiohttp.ClientSession:
        """Получение HTTP сессии"""
        if self.session is None or self.session.closed:
            self.session = aiohttp.ClientSession(
                timeout=aiohttp.ClientTimeout(total=180)  # 3 минуты для Steam Deck с учетом медленной модели
            )
        return self.session
    
    async def is_available(self) -> bool:
        """Проверка доступности LLM сервиса"""
        provider = self.config.llm.provider.lower()
        
        if provider == "ollama":
            return await self._check_ollama_availability()
        elif provider in ["openai", "deepseek", "anthropic"]:
            return await self._check_external_api_availability()
        else:
            print(f"❌ Неизвестный провайдер: {provider}")
            return False
    
    async def _check_ollama_availability(self) -> bool:
        """Проверка доступности Ollama"""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/tags") as response:
                if response.status == 200:
                    models_data = await response.json()
                    available_models = [model['name'] for model in models_data.get('models', [])]
                    print(f"🤖 Доступные Ollama модели: {available_models}")
                    
                    if self.model not in available_models:
                        print(f"❌ Модель {self.model} не найдена!")
                        print(f"💡 Загрузите модель: ollama pull {self.model}")
                        return False
                    
                    return True
                return False
        except Exception as e:
            print(f"❌ Ошибка проверки Ollama: {e}")
            print(f"💡 Попробуйте внешний API для ускорения работы")
            return False
    
    async def _check_external_api_availability(self) -> bool:
        """Проверка доступности внешнего API"""
        try:
            api_key = getattr(self.config.llm, 'api_key', None)
            if not api_key:
                print(f"❌ API ключ не найден для {self.config.llm.provider}")
                print(f"💡 Добавьте api_key в конфигурацию")
                return False
            
            print(f"✅ {self.config.llm.provider} API настроен")
            print(f"🤖 Модель: {self.model}")
            print(f"👁️ Vision модель: {self.vision_model}")
            return True
            
        except Exception as e:
            print(f"❌ Ошибка проверки {self.config.llm.provider} API: {e}")
            return False
    
    async def test_model(self) -> bool:
        """Простое тестирование модели с коротким запросом"""
        try:
            print(f"🧪 Тестируем модель {self.model} простым запросом...")
            
            session = await self._get_session()
            test_payload = {
                "model": self.model,
                "prompt": "Привет! Ответь одним словом: работает?",
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "num_predict": 10  # Ограничиваем короткий ответ
                }
            }
            
            import time
            start_time = time.time()
            
            async with session.post(f"{self.base_url}/api/generate", json=test_payload) as response:
                elapsed = time.time() - start_time
                
                if response.status == 200:
                    result = await response.json()
                    response_text = result.get('response', '').strip()
                    print(f"✅ Модель отвечает за {elapsed:.1f}с: '{response_text}'")
                    return True
                else:
                    error_text = await response.text()
                    print(f"❌ Тест модели неудачен {response.status}: {error_text}")
                    return False
                    
        except Exception as e:
            error_type = type(e).__name__
            if "Timeout" in error_type:
                print(f"❌ Таймаут при тестировании модели (>180s)")
                print(f"💡 Модель {self.model} работает слишком медленно для Steam Deck")
                print(f"💡 Попробуйте более легкую модель: ollama pull llama3.2:1b")
            else:
                print(f"❌ Ошибка тестирования модели: {e}")
            return False
    
    async def process_command(self, user_command: str, screenshot: Optional[Image.Image] = None) -> Optional[Dict[str, Any]]:
        """
        Обработка команды пользователя с использованием гибридного подхода
        
        Args:
            user_command: Команда пользователя на естественном языке
            screenshot: Скриншот экрана для контекста
            
        Returns:
            Словарь с действиями и точными координатами или None при ошибке
        """
        try:
            # Используем только прямой анализ LLM (без гибридного детектора здесь)
            # Гибридный анализатор должен вызываться из bot.py с переданным скриншотом
            
            # Формируем промпт с контекстом
            context_prompt = self._build_command_prompt(user_command, screenshot)
            
            # Отправляем запрос к LLM
            response = await self._query_llm(context_prompt, screenshot)
            
            if not response:
                return None
            
            # Парсим ответ
            result = self._parse_llm_response(response)
            if result:
                result['method'] = 'llm_fallback'
            
            return result
            
        except Exception as e:
            print(f"Error processing command: {e}")
            return None
    
    async def analyze_for_elements(self, screenshot: Image.Image, command: str) -> Optional[Dict[str, Any]]:
        """
        Анализ экрана для поиска элементов (используется гибридным анализатором)
        
        Args:
            screenshot: Скриншот для анализа
            command: Команда пользователя
            
        Returns:
            Словарь с анализом и поисковыми целями
        """
        try:
            width, height = screenshot.size
            
            analysis_prompt = f"""
Команда пользователя: "{command}"

ЗАДАЧА: Проанализируй скриншот игры Disco Elysium ({width}x{height} пикселей) и определи что нужно найти для выполнения команды.

НЕ ГЕНЕРИРУЙ ДЕЙСТВИЯ! Только определи что искать на экране.

Верни JSON со следующими полями:
{{
    "analysis": "краткое описание что видно на экране",
    "search_targets": [
        {{
            "text": "текст для поиска на экране",
            "type": "button|text|dialogue|menu",
            "description": "описание элемента"
        }}
    ],
    "reasoning": "объяснение логики поиска"
}}

ПРИМЕРЫ поисковых целей:
- Для "новая игра" → {{"text": "Новая игра", "type": "button"}}
- Для "продолжить" → {{"text": "Продолжить", "type": "button"}}  
- Для выбора диалога → {{"text": "текст варианта", "type": "dialogue"}}
"""
            
            response = await self._query_vision_llm(analysis_prompt, screenshot)
            
            if not response:
                return None
            
            # Парсим ответ (ожидаем JSON)
            response_text = response.get('response', '') if 'response' in response else str(response)
            
            try:
                result = json.loads(response_text)
                result['success'] = True
                return result
            except (json.JSONDecodeError, ValueError):
                print(f"Ошибка парсинга JSON от LLM: {response_text}")
                return {
                    'analysis': 'JSON parsing failed',
                    'search_targets': [],
                    'reasoning': f'LLM response: {response_text}',
                    'success': False
                }
                
        except Exception as e:
            print(f"Error analyzing for elements: {e}")
            return None

    async def describe_screen(self, screenshot: Image.Image) -> Optional[str]:
        """
        Описание содержимого экрана
        
        Args:
            screenshot: Скриншот для анализа
            
        Returns:
            Текстовое описание экрана или None при ошибке
        """
        try:
            prompt = self.config.vision.describe_prompt
            
            # Используем только vision модель для анализа изображений
            response = await self._query_vision_llm(prompt, screenshot)
            
            if not response:
                print("❌ Vision модель недоступна или не может обработать изображение")
                return None
            
            # Отладочная информация
            if response:
                print(f"🔍 Vision LLM response keys: {list(response.keys())}")
                print(f"🔍 Vision LLM response: {response}")
            
            # Ollama API возвращает структуру: {"response": "текст ответа", ...}
            if response and 'response' in response:
                return response['response']
            elif response and 'message' in response:
                return response['message']['content']
            
            print("❌ Неожиданная структура ответа от Vision LLM")
            return None
            
        except Exception as e:
            print(f"Error describing screen: {e}")
            return None
    
    def _build_command_prompt(self, user_command: str, screenshot: Optional[Image.Image] = None) -> str:
        """Построение промпта для обработки команды"""
        base_prompt = self.config.llm.system_prompt
        
        context = ""
        if screenshot:
            width, height = screenshot.size
            context = f"\n\nНа экране сейчас видно игровое окно Disco Elysium размером {width}x{height} пикселей. ВНИМАТЕЛЬНО изучи изображение и найди нужные элементы интерфейса."
        
        user_prompt = f"""
Команда пользователя: "{user_command}"
{context}

ВНИМАТЕЛЬНО изучи предоставленное изображение экрана игры Disco Elysium.

ИНСТРУКЦИИ ПО ОПРЕДЕЛЕНИЮ КООРДИНАТ:
1. Найди нужный элемент интерфейса (кнопку, текст, объект)
2. Определи его точные границы на изображении
3. Вычисли геометрический центр элемента
4. Используй эти координаты для клика

ПРИМЕРЫ АНАЛИЗА:
- Если ищешь кнопку "Новая игра" - она обычно в центральной части экрана
- Если ищешь вариант диалога - они слева, в вертикальном списке
- Если ищешь элемент инвентаря - определи его позицию в сетке

Проанализируй команду и сгенерируй соответствующие игровые действия с ТОЧНЫМИ координатами.
Ответь строго в JSON формате без дополнительного текста.
        """
        
        return base_prompt + user_prompt
    
    async def _query_llm(self, prompt: str, screenshot: Optional[Image.Image] = None) -> Optional[Dict[str, Any]]:
        """Запрос к текстовой LLM"""
        provider = self.config.llm.provider.lower()
        
        if provider == "openai" or provider == "deepseek" or provider == "anthropic":
            return await self._query_openai_api(prompt)
        else:
            return await self._query_ollama_api(prompt)
    
    async def _query_ollama_api(self, prompt: str) -> Optional[Dict[str, Any]]:
        """Запрос к локальной Ollama"""
        try:
            session = await self._get_session()
            
            print(f"🤖 Отправляем запрос к Ollama модели: {self.model}")
            
            payload = {
                "model": self.model,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": self.config.llm.temperature,
                    "num_predict": self.config.llm.max_tokens
                }
            }
            
            async with session.post(f"{self.base_url}/api/generate", json=payload) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    print(f"Ollama API error {response.status}: {error_text}")
                    
        except Exception as e:
            error_type = type(e).__name__
            if "ClientConnectorError" in error_type:
                print(f"❌ Не удается подключиться к Ollama серверу ({self.base_url})")
                print(f"💡 Проверьте что Ollama запущен: systemctl --user status ollama")
            elif "Timeout" in error_type:
                print(f"❌ Таймаут при запросе к Ollama: {e}")
                print(f"💡 Попробуйте внешний API: provider: 'openai' или 'deepseek'")
            else:
                print(f"❌ Error querying Ollama: {e}")
                import traceback
                traceback.print_exc()
        
        return None
    
    async def _query_openai_api(self, prompt: str) -> Optional[Dict[str, Any]]:
        """Запрос к OpenAI-совместимому API (OpenAI, DeepSeek, etc.)"""
        try:
            session = await self._get_session()
            
            print(f"🚀 Отправляем запрос к {self.config.llm.provider} модели: {self.model}")
            
            # Получаем API ключ и URL
            api_key = getattr(self.config.llm, 'api_key', None)
            if not api_key:
                print(f"❌ API ключ не найден для {self.config.llm.provider}")
                return None
            
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            
            # Формируем payload в формате OpenAI
            payload = {
                "model": self.model,
                "messages": [
                    {"role": "user", "content": prompt}
                ],
                "temperature": self.config.llm.temperature,
                "max_tokens": self.config.llm.max_tokens
            }
            
            async with session.post(f"{self.base_url}/v1/chat/completions", 
                                  json=payload, headers=headers) as response:
                if response.status == 200:
                    result = await response.json()
                    # Преобразуем в формат Ollama для совместимости
                    if 'choices' in result and len(result['choices']) > 0:
                        content = result['choices'][0]['message']['content']
                        return {"response": content}
                    return None
                else:
                    error_text = await response.text()
                    print(f"{self.config.llm.provider} API error {response.status}: {error_text}")
                    
        except Exception as e:
            print(f"❌ Error querying {self.config.llm.provider} API: {e}")
            import traceback
            traceback.print_exc()
        
        return None
    
    async def _query_vision_llm(self, prompt: str, screenshot: Image.Image) -> Optional[Dict[str, Any]]:
        """Запрос к vision LLM для анализа изображений"""
        provider = self.config.llm.provider.lower()
        
        if provider == "openai":
            return await self._query_openai_vision_api(prompt, screenshot)
        else:
            return await self._query_ollama_vision_api(prompt, screenshot)
    
    async def _query_ollama_vision_api(self, prompt: str, screenshot: Image.Image) -> Optional[Dict[str, Any]]:
        """Запрос к локальной Ollama vision модели"""
        try:
            # Конвертируем изображение в base64
            print(f"🖼️  Конвертируем изображение {screenshot.size} в base64...")
            img_buffer = io.BytesIO()
            screenshot.save(img_buffer, format='PNG')
            img_data = img_buffer.getvalue()
            img_base64 = base64.b64encode(img_data).decode('utf-8')
            
            print(f"📏 Размер изображения: {len(img_data)} байт, base64: {len(img_base64)} символов")
            
            session = await self._get_session()
            
            payload = {
                "model": self.vision_model,
                "prompt": prompt,
                "images": [img_base64],
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "num_predict": 500
                }
            }
            
            async with session.post(f"{self.base_url}/api/generate", json=payload) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    print(f"Ollama Vision API error {response.status}: {error_text}")
                    
        except Exception as e:
            error_type = type(e).__name__
            if "Timeout" in error_type:
                print(f"❌ Таймаут при запросе к Ollama vision модели")
                print(f"💡 Попробуйте внешний API: provider: 'openai'")
            else:
                print(f"Error querying Ollama vision: {e}")
                import traceback
                traceback.print_exc()
        
        return None
    
    async def _query_openai_vision_api(self, prompt: str, screenshot: Image.Image) -> Optional[Dict[str, Any]]:
        """Запрос к OpenAI Vision API"""
        try:
            # Конвертируем изображение в base64
            print(f"🖼️  Конвертируем изображение {screenshot.size} в base64...")
            
            img_buffer = io.BytesIO()
            screenshot.save(img_buffer, format='PNG')  # PNG поддерживает RGBA и лучше по качеству
            img_data = img_buffer.getvalue()
            img_base64 = base64.b64encode(img_data).decode('utf-8')
            
            print(f"📏 Размер изображения: {len(img_data)} байт")
            
            session = await self._get_session()
            
            api_key = getattr(self.config.llm, 'api_key', None)
            if not api_key:
                print("❌ API ключ не найден для OpenAI")
                return None
            
            headers = {
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json"
            }
            
            # Формируем payload для vision API
            payload = {
                "model": self.vision_model,
                "messages": [
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": prompt},
                            {
                                "type": "image_url",
                                "image_url": {
                                    "url": f"data:image/png;base64,{img_base64}"
                                }
                            }
                        ]
                    }
                ],
                "temperature": 0.1,
                "max_tokens": 500
            }
            
            print(f"🚀 Отправляем запрос к OpenAI Vision API...")
            
            async with session.post(f"{self.base_url}/v1/chat/completions", 
                                  json=payload, headers=headers) as response:
                if response.status == 200:
                    result = await response.json()
                    if 'choices' in result and len(result['choices']) > 0:
                        content = result['choices'][0]['message']['content']
                        return {"response": content}
                    return None
                else:
                    error_text = await response.text()
                    print(f"OpenAI Vision API error {response.status}: {error_text}")
                    
        except Exception as e:
            print(f"❌ Error querying OpenAI Vision API: {e}")
            import traceback
            traceback.print_exc()
        
        return None
    
    def _parse_llm_response(self, response: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Парсинг ответа LLM"""
        try:
            print(f"🔍 Получен ответ от LLM: {response}")
            
            if 'response' not in response:
                print("❌ Ключ 'response' не найден в ответе LLM")
                return None
            
            response_text = response['response'].strip()
            print(f"🔍 Текст ответа: {response_text[:200]}...")
            
            # Пытаемся распарсить JSON
            if response_text.startswith('{') and response_text.endswith('}'):
                return json.loads(response_text)
            
            # Ищем JSON в тексте
            json_start = response_text.find('{')
            json_end = response_text.rfind('}')
            
            if json_start >= 0 and json_end > json_start:
                json_str = response_text[json_start:json_end + 1]
                return json.loads(json_str)
            
            # Если JSON не найден, создаем базовую структуру
            return {
                "actions": [],
                "description": "Не удалось понять команду"
            }
            
        except json.JSONDecodeError:
            print(f"Failed to parse JSON from LLM response: {response.get('response', '')}")
            return None
        except Exception as e:
            print(f"Error parsing LLM response: {e}")
            return None
    
    async def close(self):
        """Закрытие HTTP сессии"""
        if self.session and not self.session.closed:
            await self.session.close()