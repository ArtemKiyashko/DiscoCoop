"""
Модуль для анализа экрана и захвата скриншотов
"""
import asyncio
import platform
from typing import Optional, Tuple
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
    
    async def take_screenshot(self) -> Optional[Image.Image]:
        """
        Захват скриншота игрового окна
        
        Returns:
            PIL Image или None при ошибке
        """
        try:
            # Для Steam Deck (Linux) и общий случай
            if platform.system() == "Linux":
                return await self._take_screenshot_linux()
            elif platform.system() == "Darwin":  # macOS
                return await self._take_screenshot_macos()
            else:  # Windows
                return await self._take_screenshot_windows()
                
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
            
            # Пытаемся найти окно игры
            cmd_find = f"xdotool search --name '{self.window_title}'"
            result = subprocess.run(cmd_find, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0 or not result.stdout.strip():
                # Если окно не найдено, делаем скриншот всего экрана
                screenshot = ImageGrab.grab()
                return screenshot
            
            # Получаем ID окна
            window_id = result.stdout.strip().split('\n')[0]
            
            # Делаем скриншот конкретного окна
            with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as tmp_file:
                # Пытаемся использовать наш универсальный инструмент
                cmd_screenshot = f"screenshot-tool {tmp_file.name}"
                print(f"📸 Выполняем команду: {cmd_screenshot}")
                try:
                    result = subprocess.run(cmd_screenshot, shell=True, check=True, capture_output=True, text=True)
                    print(f"✅ Скриншот создан: {tmp_file.name}")
                    screenshot = Image.open(tmp_file.name)
                    print(f"🖼️  Размер изображения: {screenshot.size}")
                    os.unlink(tmp_file.name)
                    return screenshot
                except:
                    # Fallback на старый метод если есть
                    if subprocess.run("which xwd", shell=True, capture_output=True).returncode == 0:
                        cmd_screenshot = f"xwd -id {window_id} | convert xwd:- {tmp_file.name}"
                        subprocess.run(cmd_screenshot, shell=True, check=True)
                        screenshot = Image.open(tmp_file.name)
                        os.unlink(tmp_file.name)
                        return screenshot
                    else:
                        raise
                
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
    
    async def _take_screenshot_macos(self) -> Optional[Image.Image]:
        """Захват скриншота в macOS"""
        try:
            # В macOS используем общий захват экрана
            screenshot = ImageGrab.grab()
            return screenshot
            
        except Exception as e:
            print(f"macOS screenshot error: {e}")
            return None
    
    async def _take_screenshot_windows(self) -> Optional[Image.Image]:
        """Захват скриншота в Windows"""
        try:
            import win32gui
            import win32ui
            import win32con
            
            # Ищем окно игры
            hwnd = win32gui.FindWindow(None, self.window_title)
            
            if hwnd == 0:
                # Если точное название не найдено, ищем по части названия
                def enum_windows_callback(hwnd, windows):
                    if win32gui.IsWindowVisible(hwnd):
                        window_text = win32gui.GetWindowText(hwnd)
                        if self.window_title.lower() in window_text.lower():
                            windows.append(hwnd)
                    return True
                
                windows = []
                win32gui.EnumWindows(enum_windows_callback, windows)
                
                if not windows:
                    # Fallback на скриншот всего экрана
                    return ImageGrab.grab()
                
                hwnd = windows[0]
            
            # Получаем размеры окна
            rect = win32gui.GetWindowRect(hwnd)
            width = rect[2] - rect[0]
            height = rect[3] - rect[1]
            
            # Создаем контекст устройства
            hwndDC = win32gui.GetWindowDC(hwnd)
            mfcDC = win32ui.CreateDCFromHandle(hwndDC)
            saveDC = mfcDC.CreateCompatibleDC()
            
            # Создаем bitmap
            saveBitMap = win32ui.CreateBitmap()
            saveBitMap.CreateCompatibleBitmap(mfcDC, width, height)
            saveDC.SelectObject(saveBitMap)
            
            # Копируем содержимое окна
            saveDC.BitBlt((0, 0), (width, height), mfcDC, (0, 0), win32con.SRCCOPY)
            
            # Конвертируем в PIL Image
            bmpinfo = saveBitMap.GetInfo()
            bmpstr = saveBitMap.GetBitmapBits(True)
            screenshot = Image.frombuffer(
                'RGB',
                (bmpinfo['bmWidth'], bmpinfo['bmHeight']),
                bmpstr, 'raw', 'BGRX', 0, 1
            )
            
            # Освобождаем ресурсы
            win32gui.DeleteObject(saveBitMap.GetHandle())
            saveDC.DeleteDC()
            mfcDC.DeleteDC()
            win32gui.ReleaseDC(hwnd, hwndDC)
            
            return screenshot
            
        except Exception as e:
            print(f"Windows screenshot error: {e}")
            # Fallback на скриншот всего экрана
            return ImageGrab.grab()
    
    async def describe_screen(self) -> Optional[str]:
        """
        Получение описания того, что происходит на экране
        
        Returns:
            Текстовое описание экрана или None при ошибке
        """
        try:
            screenshot = await self.take_screenshot()
            
            if not screenshot:
                return "Не удалось получить скриншот экрана"
            
            # Оптимизируем размер изображения для отправки в LLM
            screenshot = self._optimize_screenshot(screenshot)
            
            # Кешируем скриншот
            self.last_screenshot = screenshot
            
            # Отправляем на анализ в LLM
            description = await self.llm_agent.describe_screen(screenshot)
            
            return description
            
        except Exception as e:
            print(f"Error describing screen: {e}")
            return None
    
    def _optimize_screenshot(self, screenshot: Image.Image) -> Image.Image:
        """
        Оптимизация скриншота для отправки в LLM
        
        Args:
            screenshot: Исходный скриншот
            
        Returns:
            Оптимизированный скриншот
        """
        # Получаем целевое разрешение из конфига
        target_width = self.config.game.screen_resolution['width']
        target_height = self.config.game.screen_resolution['height']
        
        # Изменяем размер, сохраняя пропорции
        screenshot.thumbnail((target_width, target_height), Image.Resampling.LANCZOS)
        
        # Конвертируем в RGB если нужно
        if screenshot.mode != 'RGB':
            screenshot = screenshot.convert('RGB')
        
        return screenshot
    
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
    
    async def close(self):
        """Закрытие ресурсов"""
        if hasattr(self, 'llm_agent'):
            await self.llm_agent.close()