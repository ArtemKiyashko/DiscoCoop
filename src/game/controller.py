"""
Контроллер для управления игрой через эмуляцию ввода
"""
import asyncio
import platform
import time
from typing import List, Dict, Any, Optional
import pyautogui
from pynput import mouse, keyboard
from pynput.mouse import Button, Listener as MouseListener
from pynput.keyboard import Key, Listener as KeyboardListener

from ..utils.config import Config


class GameController:
    """Контроллер для управления игрой через эмуляцию клавиатуры и мыши"""
    
    def __init__(self, config: Config):
        self.config = config
        self.window_title = config.game.window_title
        self.action_delay = config.game.action_delay
        self.is_active = False
        self.emergency_stop = False
        
        # Настройки PyAutoGUI
        pyautogui.PAUSE = config.game.action_delay
        pyautogui.FAILSAFE = True  # Перемещение мыши в угол останавливает выполнение
        
        # Маппинг клавиш
        self.key_mapping = {
            'space': ' ',
            'enter': '\n',
            'tab': '\t',
            'escape': Key.esc,
            'up': Key.up,
            'down': Key.down,
            'left': Key.left,
            'right': Key.right,
            'f1': Key.f1,
            'f2': Key.f2,
            'f3': Key.f3,
            'f4': Key.f4,
            'f5': Key.f5,
            'ctrl': Key.ctrl,
            'alt': Key.alt,
            'shift': Key.shift,
        }
    
    def is_game_running(self) -> bool:
        """
        Проверка запущена ли игра
        
        Returns:
            True если игра найдена и запущена
        """
        try:
            if platform.system() == "Linux":
                return self._is_game_running_linux()
            elif platform.system() == "Darwin":
                return self._is_game_running_macos()
            else:  # Windows
                return self._is_game_running_windows()
                
        except Exception as e:
            print(f"Error checking game status: {e}")
            return False
    
    def _is_game_running_linux(self) -> bool:
        """Проверка игры в Linux"""
        import subprocess
        
        try:
            # Ищем процесс игры
            cmd = f"pgrep -f '{self.window_title.lower()}'"
            result = subprocess.run(cmd, shell=True, capture_output=True)
            
            if result.returncode == 0:
                return True
            
            # Альтернативный поиск через xdotool
            cmd = f"xdotool search --name '{self.window_title}'"
            result = subprocess.run(cmd, shell=True, capture_output=True)
            
            return result.returncode == 0 and result.stdout.strip()
            
        except Exception:
            return False
    
    def _is_game_running_macos(self) -> bool:
        """Проверка игры в macOS"""
        import subprocess
        
        try:
            cmd = f"pgrep -i '{self.window_title}'"
            result = subprocess.run(cmd, shell=True, capture_output=True)
            return result.returncode == 0
            
        except Exception:
            return False
    
    def _is_game_running_windows(self) -> bool:
        """Проверка игры в Windows"""
        try:
            import win32gui
            
            def enum_windows_callback(hwnd, windows):
                if win32gui.IsWindowVisible(hwnd):
                    window_text = win32gui.GetWindowText(hwnd)
                    if self.window_title.lower() in window_text.lower():
                        windows.append(hwnd)
                return True
            
            windows = []
            win32gui.EnumWindows(enum_windows_callback, windows)
            
            return len(windows) > 0
            
        except Exception:
            return False
    
    async def execute_actions(self, actions: List[Dict[str, Any]]) -> bool:
        """
        Выполнение списка действий
        
        Args:
            actions: Список действий для выполнения
            
        Returns:
            True если все действия выполнены успешно
        """
        if not actions:
            return False
        
        if self.emergency_stop:
            print("Emergency stop is active, skipping actions")
            return False
        
        if not self.is_game_running():
            print("Game is not running")
            return False
        
        self.is_active = True
        success_count = 0
        
        try:
            for action in actions:
                if self.emergency_stop:
                    break
                
                success = await self._execute_single_action(action)
                if success:
                    success_count += 1
                
                # Задержка между действиями
                await asyncio.sleep(self.action_delay)
            
            return success_count == len(actions)
            
        except Exception as e:
            print(f"Error executing actions: {e}")
            return False
        
        finally:
            self.is_active = False
    
    async def _execute_single_action(self, action: Dict[str, Any]) -> bool:
        """Выполнение одного действия"""
        try:
            action_type = action.get('type', '').lower()
            
            if action_type == 'click':
                return await self._action_click(action)
            elif action_type == 'move_mouse':
                return await self._action_move_mouse(action)
            elif action_type == 'key_press':
                return await self._action_key_press(action)
            elif action_type == 'type_text':
                return await self._action_type_text(action)
            elif action_type == 'scroll':
                return await self._action_scroll(action)
            elif action_type == 'drag':
                return await self._action_drag(action)
            elif action_type == 'key_combination':
                return await self._action_key_combination(action)
            else:
                print(f"Unknown action type: {action_type}")
                return False
        
        except Exception as e:
            print(f"Error executing action {action}: {e}")
            return False
    
    async def _action_click(self, action: Dict[str, Any]) -> bool:
        """Выполнение клика мышью"""
        x = action.get('x', 0)
        y = action.get('y', 0)
        button = action.get('button', 'left')
        clicks = action.get('clicks', 1)
        
        try:
            # Фокусируемся на игровом окне
            await self._focus_game_window()
            
            # Выполняем клик
            if button == 'right':
                pyautogui.rightClick(x, y, clicks=clicks)
            else:
                pyautogui.leftClick(x, y, clicks=clicks)
            
            return True
            
        except Exception as e:
            print(f"Click action failed: {e}")
            return False
    
    async def _action_move_mouse(self, action: Dict[str, Any]) -> bool:
        """Перемещение мыши"""
        x = action.get('x', 0)
        y = action.get('y', 0)
        duration = action.get('duration', 0.5)
        
        try:
            pyautogui.moveTo(x, y, duration=duration)
            return True
            
        except Exception as e:
            print(f"Move mouse action failed: {e}")
            return False
    
    async def _action_key_press(self, action: Dict[str, Any]) -> bool:
        """Нажатие клавиши"""
        key = action.get('key', '')
        
        try:
            # Преобразуем ключ
            mapped_key = self.key_mapping.get(key.lower(), key)
            
            # Фокусируемся на игре
            await self._focus_game_window()
            
            if isinstance(mapped_key, str):
                pyautogui.press(mapped_key)
            else:
                # Для специальных клавиш используем pynput
                keyboard_controller = keyboard.Controller()
                keyboard_controller.press(mapped_key)
                keyboard_controller.release(mapped_key)
            
            return True
            
        except Exception as e:
            print(f"Key press action failed: {e}")
            return False
    
    async def _action_type_text(self, action: Dict[str, Any]) -> bool:
        """Ввод текста"""
        text = action.get('text', '')
        interval = action.get('interval', 0.05)
        
        try:
            await self._focus_game_window()
            pyautogui.typewrite(text, interval=interval)
            return True
            
        except Exception as e:
            print(f"Type text action failed: {e}")
            return False
    
    async def _action_scroll(self, action: Dict[str, Any]) -> bool:
        """Прокрутка"""
        direction = action.get('direction', 'up')
        amount = action.get('amount', 3)
        x = action.get('x')
        y = action.get('y')
        
        try:
            # Если указаны координаты, перемещаемся туда
            if x is not None and y is not None:
                pyautogui.moveTo(x, y)
            
            scroll_amount = amount if direction == 'up' else -amount
            pyautogui.scroll(scroll_amount)
            
            return True
            
        except Exception as e:
            print(f"Scroll action failed: {e}")
            return False
    
    async def _action_drag(self, action: Dict[str, Any]) -> bool:
        """Перетаскивание"""
        from_x = action.get('from_x', 0)
        from_y = action.get('from_y', 0)
        to_x = action.get('to_x', 0)
        to_y = action.get('to_y', 0)
        duration = action.get('duration', 1.0)
        
        try:
            await self._focus_game_window()
            pyautogui.dragTo(to_x, to_y, duration=duration, button='left')
            return True
            
        except Exception as e:
            print(f"Drag action failed: {e}")
            return False
    
    async def _action_key_combination(self, action: Dict[str, Any]) -> bool:
        """Комбинация клавиш"""
        keys = action.get('keys', [])
        
        if not keys:
            return False
        
        try:
            await self._focus_game_window()
            
            # Преобразуем клавиши
            mapped_keys = []
            for key in keys:
                mapped_key = self.key_mapping.get(key.lower(), key)
                mapped_keys.append(mapped_key)
            
            # Используем pyautogui для простых комбинаций
            if len(mapped_keys) <= 3:
                pyautogui.hotkey(*mapped_keys)
            
            return True
            
        except Exception as e:
            print(f"Key combination action failed: {e}")
            return False
    
    async def _focus_game_window(self) -> bool:
        """Фокусировка на окне игры"""
        try:
            if platform.system() == "Linux":
                return await self._focus_window_linux()
            elif platform.system() == "Darwin":
                return await self._focus_window_macos()
            else:  # Windows
                return await self._focus_window_windows()
                
        except Exception as e:
            print(f"Error focusing game window: {e}")
            return False
    
    async def _focus_window_linux(self) -> bool:
        """Фокусировка окна в Linux"""
        import subprocess
        
        try:
            # Находим ID окна
            cmd = f"xdotool search --name '{self.window_title}'"
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode == 0 and result.stdout.strip():
                window_id = result.stdout.strip().split('\n')[0]
                
                # Активируем окно
                subprocess.run(f"xdotool windowactivate {window_id}", shell=True)
                
                # Небольшая задержка для активации
                await asyncio.sleep(0.1)
                
                return True
            
            return False
            
        except Exception:
            return False
    
    async def _focus_window_macos(self) -> bool:
        """Фокусировка окна в macOS"""
        # В macOS фокусировка сложнее, пока просто возвращаем True
        return True
    
    async def _focus_window_windows(self) -> bool:
        """Фокусировка окна в Windows"""
        try:
            import win32gui
            import win32con
            
            def enum_windows_callback(hwnd, windows):
                if win32gui.IsWindowVisible(hwnd):
                    window_text = win32gui.GetWindowText(hwnd)
                    if self.window_title.lower() in window_text.lower():
                        windows.append(hwnd)
                return True
            
            windows = []
            win32gui.EnumWindows(enum_windows_callback, windows)
            
            if windows:
                hwnd = windows[0]
                
                # Активируем окно
                win32gui.SetForegroundWindow(hwnd)
                win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
                
                await asyncio.sleep(0.1)
                return True
            
            return False
            
        except Exception:
            return False
    
    async def stop_all_actions(self):
        """Экстренная остановка всех действий"""
        self.emergency_stop = True
        self.is_active = False
        
        print("Emergency stop activated - all game actions stopped")
        
        # Ждем завершения текущих действий
        await asyncio.sleep(0.5)
        
        # Сбрасываем флаг через некоторое время
        await asyncio.sleep(2)
        self.emergency_stop = False
    
    def get_screen_size(self) -> tuple:
        """Получение размера экрана"""
        return pyautogui.size()
    
    def get_mouse_position(self) -> tuple:
        """Получение текущей позиции мыши"""
        return pyautogui.position()