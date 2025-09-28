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
                timeout=aiohttp.ClientTimeout(total=30)
            )
        return self.session
    
    async def is_available(self) -> bool:
        """Проверка доступности Ollama"""
        try:
            session = await self._get_session()
            async with session.get(f"{self.base_url}/api/tags") as response:
                return response.status == 200
        except Exception:
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
            
            if response and 'message' in response:
                return response['message']['content']
            
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
                
        except Exception as e:
            print(f"Error querying LLM: {e}")
        
        return None
    
    async def _query_vision_llm(self, prompt: str, screenshot: Image.Image) -> Optional[Dict[str, Any]]:
        """Запрос к vision LLM для анализа изображений"""
        try:
            # Конвертируем изображение в base64
            img_buffer = io.BytesIO()
            screenshot.save(img_buffer, format='PNG')
            img_base64 = base64.b64encode(img_buffer.getvalue()).decode('utf-8')
            
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
                
        except Exception as e:
            print(f"Error querying vision LLM: {e}")
        
        return None
    
    def _parse_llm_response(self, response: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Парсинг ответа LLM"""
        try:
            if 'response' not in response:
                return None
            
            response_text = response['response'].strip()
            
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