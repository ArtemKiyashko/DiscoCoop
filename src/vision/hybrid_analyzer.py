"""
Гибридный анализатор экрана: LLM для анализа + детектор для координат
"""
import asyncio
import os
from typing import Optional, Tuple, Dict, Any, List
from PIL import Image
import time

from ..utils.config import Config
from ..llm.agent import LLMAgent
from .element_detector import GameElementDetector


class HybridScreenAnalyzer:
    """Гибридный анализатор: LLM анализирует скриншот, детектор находит точные координаты"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm_agent = LLMAgent(config)
        self.element_detector = GameElementDetector()
        
    async def analyze_and_find_element(self, screenshot: Image.Image, command: str) -> Dict[str, Any]:
        """
        Главный метод: LLM анализирует скриншот, детектор ищет точные координаты
        
        Args:
            screenshot: PIL Image скриншота
            command: Команда для анализа
            
        Returns:
            Dict с результатами анализа и координатами
        """
        # 1. LLM анализирует скриншот и определяет что искать
        screen_analysis = await self._analyze_screen_elements(screenshot, command)
        
        # 2. Если есть объекты для поиска
        if screen_analysis.get('search_targets'):
            # Используем детектор для поиска точных координат
            precise_coords = await self._find_precise_coordinates(
                screenshot, 
                screen_analysis['search_targets']
            )
            
            if precise_coords:
                return {
                    'method': 'hybrid',
                    'analysis': screen_analysis,
                    'coordinates': precise_coords,
                    'success': True
                }
        
        # 3. Fallback: используем координаты от LLM
        llm_coords = screen_analysis.get('coordinates')
        if llm_coords:
            return {
                'method': 'llm_fallback',
                'analysis': screen_analysis,
                'coordinates': llm_coords,
                'success': True
            }
        
        # 4. Ничего не найдено
        return {
            'method': 'failed',
            'analysis': screen_analysis,
            'coordinates': None,
            'success': False
        }
    
    async def _analyze_screen_elements(self, screenshot: Image.Image, command: str) -> Dict[str, Any]:
        """LLM анализирует скриншот и определяет объекты для поиска"""
        # Используем специальный метод для анализа элементов
        result = await self.llm_agent.analyze_for_elements(screenshot, command)
        
        # Обрабатываем результат
        if result and result.get('success'):
            return {
                'analysis': result.get('analysis', ''),
                'search_targets': result.get('search_targets', []),
                'coordinates': None  # LLM больше не возвращает координаты
            }
        
        return {'analysis': 'LLM analysis failed', 'search_targets': [], 'coordinates': None}
    

    
    async def _find_precise_coordinates(self, screenshot: Image.Image, search_targets: List[Dict[str, Any]]) -> Optional[Tuple[int, int]]:
        """Использует детектор для поиска точных координат"""
        # Ищем каждую цель
        for target in search_targets:
            text_to_find = target.get('text', '')
            
            if text_to_find:
                # Используем детектор элементов
                element = self.element_detector.find_element(screenshot, text_to_find)
                
                if element:
                    # Возвращаем координаты найденного элемента
                    return (element.center_x, element.center_y)
        
        return None
    
    async def close(self):
        """Освобождение ресурсов"""
        if hasattr(self.llm_agent, 'close'):
            await self.llm_agent.close()