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
        """Проверка доступности Ollama"""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/tags") as response:
                if response.status == 200:
                    # Проверяем доступные модели
                    models_data = await response.json()
                    available_models = [model['name'] for model in models_data.get('models', [])]
                    print(f"🤖 Доступные модели: {available_models}")
                    
                    if self.model not in available_models:
                        print(f"❌ Модель {self.model} не найдена!")
                        print(f"💡 Загрузите модель: ollama pull {self.model}")
                        return False
                    
                    return True
                return False
        except Exception as e:
            print(f"❌ Ошибка проверки Ollama: {e}")
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
        Обработка команды пользователя и генерация игровых действий
        
        Args:
            user_command: Команда пользователя на естественном языке
            screenshot: Скриншот экрана для контекста
            
        Returns:
            Словарь с действиями и описанием или None при ошибке
        """
        try:
            # Формируем промпт с контекстом
            context_prompt = self._build_command_prompt(user_command, screenshot)
            
            # Отправляем запрос к LLM
            response = await self._query_llm(context_prompt, screenshot)
            
            if not response:
                return None
            
            # Парсим ответ
            return self._parse_llm_response(response)
            
        except Exception as e:
            print(f"Error processing command: {e}")
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
            
            response = await self._query_vision_llm(prompt, screenshot)
            
            # Отладочная информация
            if response:
                print(f"🔍 LLM response keys: {list(response.keys())}")
                print(f"🔍 LLM response: {response}")
            
            # Ollama API возвращает структуру: {"response": "текст ответа", ...}
            if response and 'response' in response:
                return response['response']
            elif response and 'message' in response:
                return response['message']['content']
            
            print("❌ Неожиданная структура ответа LLM")
            return None
            
        except Exception as e:
            print(f"Error describing screen: {e}")
            return None
    
    def _build_command_prompt(self, user_command: str, screenshot: Optional[Image.Image] = None) -> str:
        """Построение промпта для обработки команды"""
        base_prompt = self.config.llm.system_prompt
        
        context = ""
        if screenshot:
            context = "\n\nНа экране сейчас видно игровое окно Disco Elysium. Учти контекст изображения при генерации действий."
        
        user_prompt = f"""
Команда пользователя: "{user_command}"
{context}

Проанализируй команду и сгенерируй соответствующие игровые действия.
Ответь строго в JSON формате без дополнительного текста.
        """
        
        return base_prompt + user_prompt
    
    async def _query_llm(self, prompt: str, screenshot: Optional[Image.Image] = None) -> Optional[Dict[str, Any]]:
        """Запрос к текстовой LLM"""
        try:
            session = await self._get_session()
            
            # Проверяем доступность модели
            print(f"🤖 Отправляем запрос к модели: {self.model}")
            
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
                    print(f"LLM API error {response.status}: {error_text}")
                    
        except Exception as e:
            error_type = type(e).__name__
            if "ClientConnectorError" in error_type:
                print(f"❌ Не удается подключиться к Ollama серверу ({self.base_url})")
                print(f"💡 Проверьте что Ollama запущен: systemctl --user status ollama")
            elif "Timeout" in error_type:
                print(f"❌ Таймаут при запросе к LLM: {e}")
                print(f"💡 Попробуйте увеличить таймаут или проверить модель {self.model}")
            elif "JSONDecodeError" in error_type:
                print(f"❌ Ошибка декодирования JSON ответа: {e}")
            else:
                print(f"❌ Error querying LLM: {e}")
                print(f"🔍 URL: {self.base_url}/api/generate")
                print(f"🔍 Model: {self.model}")
                import traceback
                traceback.print_exc()
        
        return None
    
    async def _query_vision_llm(self, prompt: str, screenshot: Image.Image) -> Optional[Dict[str, Any]]:
        """Запрос к vision LLM для анализа изображений"""
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
                    "temperature": 0.1,  # Низкая температура для более точного описания
                    "num_predict": 500
                }
            }
            
            async with session.post(f"{self.base_url}/api/generate", json=payload) as response:
                if response.status == 200:
                    return await response.json()
                else:
                    error_text = await response.text()
                    print(f"Vision LLM API error {response.status}: {error_text}")
                    
        except Exception as e:
            error_type = type(e).__name__
            if "ClientConnectorError" in error_type:
                print(f"❌ Не удается подключиться к Ollama серверу для vision модели")
                print(f"💡 Убедитесь что модель {self.vision_model} загружена: ollama pull {self.vision_model}")
            else:
                print(f"Error querying vision LLM: {e}")
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