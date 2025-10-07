"""
Модуль для анализа экрана и захвата скриншотов
"""
import asyncio
import platform
from typing import Optional, Tuple, Dict, Any
from PIL import Image, ImageGrab
import cv2
import numpy as np

from ..utils.config import Config
from ..llm.agent import LLMAgent


class ScreenAnalyzer:
    """Анализатор экрана для захвата и обработки скриншотов игры"""
    
    def __init__(self, config: Config):
        self.config = config
        self.llm_agent = LLMAgent(config)
        self.window_title = config.game.window_title
        self.last_screenshot = None
        self.last_screenshot_time = 0
        
        # Инициализируем детектор элементов
        try:
            from .element_detector import GameElementDetector
            self.element_detector = GameElementDetector()
            print("✅ Детектор элементов инициализирован в ScreenAnalyzer")
        except Exception as e:
            print(f"⚠️ Детектор элементов недоступен в ScreenAnalyzer: {e}")
            self.element_detector = None
    
    async def take_screenshot(self) -> Optional[Image.Image]:
        """
        Захват скриншота игрового окна (только для Steam Deck/Linux)
        
        Returns:
            PIL Image или None при ошибке
        """
        try:
            # Только для Steam Deck (Linux)
            if platform.system() != "Linux":
                print("❌ Этот проект поддерживает только Steam Deck (Linux)")
                return None
                
            return await self._take_screenshot_linux()
                
        except Exception as e:
            print(f"Error taking screenshot: {e}")
            return None
    
    async def _take_screenshot_linux(self) -> Optional[Image.Image]:
        """Захват скриншота в Linux (Steam Deck)"""
        try:
            # Используем системную команду для захвата окна
            import subprocess
            import tempfile
            import os
            
            # Используем упрощенный инструмент для Steam Deck
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_file:
                cmd_screenshot = f"screenshot-tool {tmp_file.name} '{self.window_title}'"
                print(f"📸 Создаем скриншот: {cmd_screenshot}")
                
                result = subprocess.run(
                    cmd_screenshot, 
                    shell=True, 
                    check=True, 
                    capture_output=True, 
                    text=True,
                    timeout=10  # Увеличили таймаут
                )
                
                print(f"✅ Скриншот создан: {tmp_file.name}")
                if result.stdout:
                    print(f"📝 Вывод: {result.stdout.strip()}")
                
                screenshot = Image.open(tmp_file.name)
                print(f"🖼️  Размер изображения: {screenshot.size}")
                os.unlink(tmp_file.name)
                return screenshot
                
        except Exception as e:
            error_msg = str(e)
            print(f"Linux screenshot error: {error_msg}")
            
            # Проверяем на конкретные ошибки и даем советы
            if "screenshot-tool" in error_msg or "convert" in error_msg or "xwd" in error_msg:
                print("💡 Проблема с инструментами для скриншотов.")
                print("   Запустите: ./install.sh --reinstall")
                print("   Или установите вручную: sudo pacman -S grim (для Wayland) или scrot (для X11)")
            
            # Fallback на обычный скриншот экрана
            try:
                return ImageGrab.grab()
            except Exception as fallback_e:
                print(f"Fallback screenshot also failed: {fallback_e}")
                return None
    

    async def describe_screen(self, screenshot: Optional[Image.Image] = None) -> Optional[str]:
        """
        Получение описания того, что происходит на экране
        
        Args:
            screenshot: Готовый скриншот (если None, будет создан новый)
        
        Returns:
            Текстовое описание экрана или None при ошибке
        """
        try:
            if screenshot is None:
                screenshot = await self.take_screenshot()
            
            if not screenshot:
                return "Не удалось получить скриншот экрана"
            
            # Оптимизируем размер изображения для отправки в LLM
            screenshot = self._optimize_screenshot(screenshot)
            
            # Сохраняем для других методов
            self.last_screenshot = screenshot
            
            # Отправляем на анализ в LLM
            description = await self.llm_agent.describe_screen(screenshot)
            
            return description
            
        except Exception as e:
            print(f"Error describing screen: {e}")
            return None
    
    def _optimize_screenshot(self, screenshot: Image.Image) -> Image.Image:
        """
        Подготовка скриншота для отправки в LLM
        Скриншот передается без изменения размера для точного позиционирования
        
        Args:
            screenshot: Исходный скриншот
            
        Returns:
            Скриншот в формате RGB без изменения размера
        """
        print(f"📷 Обработка скриншота: {screenshot.size}")
        
        # Конвертируем в RGB если нужно
        if screenshot.mode != 'RGB':
            screenshot = screenshot.convert('RGB')
        
        return screenshot
    
    def _get_game_window_size(self) -> Optional[tuple]:
        """
        Получает размер окна игры через xdotool для точного позиционирования
        
        Returns:
            Кортеж (width, height) или None если окно не найдено
        """
        if platform.system() != 'Linux':
            print("⚠️  Автоматическое определение размера окна доступно только на Linux")
            return None
            
        try:
            import subprocess
            
            # Поиск окна Disco Elysium
            search_patterns = ['Disco', 'disco', 'Elysium']
            
            for pattern in search_patterns:
                try:
                    result = subprocess.run(
                        ['xdotool', 'search', '--name', pattern],
                        capture_output=True, text=True, timeout=5
                    )
                    
                    if result.returncode == 0 and result.stdout.strip():
                        window_ids = result.stdout.strip().split('\n')
                        
                        for window_id in window_ids:
                            try:
                                # Получаем геометрию окна
                                geometry_result = subprocess.run(
                                    ['xdotool', 'getwindowgeometry', window_id],
                                    capture_output=True, text=True, timeout=2
                                )
                                
                                if geometry_result.returncode == 0:
                                    # Парсим размеры из вывода xdotool
                                    # Формат: "Geometry: 1280x800+0+0"
                                    for line in geometry_result.stdout.split('\n'):
                                        if 'Geometry:' in line:
                                            # Извлекаем размеры
                                            geometry = line.split('Geometry:')[1].strip()
                                            size_part = geometry.split('+')[0]  # "1280x800"
                                            width, height = map(int, size_part.split('x'))
                                            print(f"🎮 Определен размер окна игры: {width}x{height}")
                                            return (width, height)
                            except (subprocess.TimeoutExpired, ValueError, IndexError):
                                continue
                                
                except subprocess.TimeoutExpired:
                    continue
                    
        except Exception as e:
            print(f"❌ Ошибка при получении размера окна игры: {e}")
            
        print("⚠️  Окно игры не найдено, будет использован размер скриншота")
        return None
    
    def get_game_resolution(self) -> Tuple[int, int]:
        """
        Получает текущее разрешение игры для точного позиционирования
        
        Returns:
            Кортеж (width, height) - реальное разрешение окна игры
        """
        # Пытаемся получить реальный размер окна игры
        game_window_size = self._get_game_window_size()
        if game_window_size:
            return game_window_size
            
        # Если не удалось определить размер окна, используем размер последнего скриншота
        if self.last_screenshot:
            width, height = self.last_screenshot.size
            print(f"📐 Используем размер скриншота: {width}x{height}")
            return (width, height)
            
        # Fallback - типичное разрешение для Steam Deck
        print("⚠️  Не удалось определить разрешение игры, используем 1280x800")
        return (1280, 800)
    
    def find_ui_elements(self, screenshot: Optional[Image.Image] = None) -> dict:
        """
        Поиск UI элементов на экране используя компьютерное зрение
        
        Args:
            screenshot: Скриншот для анализа (если None, берется последний)
            
        Returns:
            Словарь с найденными элементами UI
        """
        if screenshot is None:
            screenshot = self.last_screenshot
        
        if not screenshot:
            return {}
        
        try:
            # Конвертируем в OpenCV формат
            cv_image = cv2.cvtColor(np.array(screenshot), cv2.COLOR_RGB2BGR)
            
            elements = {}
            
            # Поиск кнопок и интерактивных элементов
            elements['buttons'] = self._find_buttons(cv_image)
            
            # Поиск текстовых областей
            elements['text_areas'] = self._find_text_areas(cv_image)
            
            # Поиск диалоговых окон
            elements['dialogs'] = self._find_dialogs(cv_image)
            
            return elements
            
        except Exception as e:
            print(f"Error finding UI elements: {e}")
            return {}
    
    def _find_buttons(self, cv_image) -> list:
        """Поиск кнопок на экране"""
        buttons = []
        
        # Конвертируем в градации серого
        gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)
        
        # Поиск прямоугольников (потенциальных кнопок)
        edges = cv2.Canny(gray, 50, 150)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            # Фильтруем по размеру
            area = cv2.contourArea(contour)
            if 500 < area < 10000:  # Разумный размер для кнопки
                x, y, w, h = cv2.boundingRect(contour)
                
                # Проверяем пропорции (кнопки обычно не слишком вытянутые)
                aspect_ratio = w / h
                if 0.3 < aspect_ratio < 4:
                    buttons.append({
                        'x': x + w // 2,
                        'y': y + h // 2,
                        'width': w,
                        'height': h,
                        'confidence': min(area / 1000, 1.0)
                    })
        
        return buttons
    
    def _find_text_areas(self, cv_image) -> list:
        """Поиск текстовых областей"""
        text_areas = []
        
        # Здесь можно добавить OCR для поиска текста
        # Пока возвращаем пустой список
        
        return text_areas
    
    def _find_dialogs(self, cv_image) -> list:
        """Поиск диалоговых окон"""
        dialogs = []
        
        # Поиск больших прямоугольных областей (диалоги)
        gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 30, 100)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            area = cv2.contourArea(contour)
            if area > 20000:  # Большие области
                x, y, w, h = cv2.boundingRect(contour)
                
                # Проверяем что это похоже на диалог
                aspect_ratio = w / h
                if 0.5 < aspect_ratio < 3:
                    dialogs.append({
                        'x': x,
                        'y': y,
                        'width': w,
                        'height': h,
                        'center_x': x + w // 2,
                        'center_y': y + h // 2
                    })
        
        return dialogs
    
    async def find_element_precise(self, target: str) -> Optional[Dict[str, Any]]:
        """
        Поиск элемента с точными координатами через детектор
        
        Args:
            target: Название элемента для поиска
            
        Returns:
            Информация об элементе с точными координатами
        """
        if not self.element_detector:
            print("⚠️ Детектор элементов недоступен")
            return None
        
        try:
            # Делаем скриншот
            screenshot = await self.take_screenshot()
            if not screenshot:
                return None
            
            # Используем детектор для поиска
            element = self.element_detector.find_element(screenshot, target)
            
            if element:
                return {
                    'coordinates': (element.center_x, element.center_y),
                    'description': f"Элемент {target}",
                    'method': element.method,
                    'confidence': element.confidence
                }
            
            return None
            
        except Exception as e:
            print(f"❌ Ошибка поиска элемента '{target}': {e}")
            return None
    
    async def close(self):
        """Закрытие ресурсов"""
        if hasattr(self, 'llm_agent'):
            await self.llm_agent.close()