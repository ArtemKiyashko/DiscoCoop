"""
Контроллер для управления игрой через эмуляцию ввода
"""
import asyncio
import platform
import time
from typing import List, Dict, Any, Optional

# Пытаемся импортировать пакеты управления вводом
try:
    import pyautogui
    PYAUTOGUI_AVAILABLE = True
except ImportError:
    PYAUTOGUI_AVAILABLE = False
    pyautogui = None

try:
    from pynput import mouse, keyboard
    from pynput.mouse import Button, Listener as MouseListener  
    from pynput.keyboard import Key, Listener as KeyboardListener
    PYNPUT_AVAILABLE = True
except ImportError:
    PYNPUT_AVAILABLE = False
    mouse = keyboard = Button = MouseListener = Key = KeyboardListener = None

from ..utils.config import Config


class GameController:
    """Контроллер для управления игрой через эмуляцию клавиатуры и мыши"""
    
    def __init__(self, config: Config):
        self.config = config
        self.window_title = config.game.window_title
        self.action_delay = config.game.action_delay
        self.is_active = False
        self.emergency_stop = False
        
        # Настройки мультидисплея
        self.multi_display_config = config.game.multi_display
        self.game_screen_offset = None  # Будет определен автоматически
        self.game_display_info = None
        
        # Проверяем доступность библиотек
        if not PYAUTOGUI_AVAILABLE:
            raise ImportError("PyAutoGUI не установлен. Установите его командой: pip install PyAutoGUI")
        
        if not PYNPUT_AVAILABLE:
            print("⚠️  Внимание: pynput недоступен. Некоторые функции могут не работать.")
        
        # Настройки PyAutoGUI
        pyautogui.PAUSE = config.game.action_delay
        pyautogui.FAILSAFE = True  # Перемещение мыши в угол останавливает выполнение
        
        # Маппинг клавиш (только если pynput доступен)
        if PYNPUT_AVAILABLE:
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
        else:
            self.key_mapping = {}
    
    def is_game_running(self) -> bool:
        """
        Проверка запущена ли игра
        
        Returns:
            True если игра найдена и запущена
        """
        try:
            # Только для Steam Deck (Linux)
            if platform.system() != "Linux":
                print("❌ Этот проект поддерживает только Steam Deck (Linux)")
                return False
                
            return self._is_game_running_linux()
                
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
            # Корректируем координаты для мультидисплея
            adjusted_x, adjusted_y = self.adjust_coordinates(x, y)
            
            print(f"🖱️  Клик: исходные координаты ({x}, {y}) -> скорректированные ({adjusted_x}, {adjusted_y})")
            
            # Фокусируемся на игровом окне
            await self._focus_game_window()
            
            # Выполняем клик
            if button == 'right':
                pyautogui.rightClick(adjusted_x, adjusted_y)
                # Для дополнительных кликов
                for _ in range(clicks - 1):
                    pyautogui.rightClick(adjusted_x, adjusted_y)
            else:
                pyautogui.leftClick(adjusted_x, adjusted_y)
                # Для дополнительных кликов
                for _ in range(clicks - 1):
                    pyautogui.leftClick(adjusted_x, adjusted_y)
            
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
            # Корректируем координаты для мультидисплея
            adjusted_x, adjusted_y = self.adjust_coordinates(x, y)
            pyautogui.moveTo(adjusted_x, adjusted_y, duration=duration)
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
            # Только для Steam Deck (Linux)
            if platform.system() != "Linux":
                print("❌ Этот проект поддерживает только Steam Deck (Linux)")
                return False
                
            return await self._focus_window_linux()
                
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
    
    def detect_game_display(self) -> Optional[Dict[str, Any]]:
        """
        Автоматическое определение дисплея где запущена игра
        
        Returns:
            Информация о дисплее с игрой или None
        """
        try:
            if not self.multi_display_config.auto_detect_game_screen:
                return None
            
            # Только для Steam Deck (Linux)
            if platform.system() != "Linux":
                print("❌ Этот проект поддерживает только Steam Deck (Linux)")
                return None
                
            return self._detect_game_display_linux()
                
        except Exception as e:
            print(f"❌ Ошибка определения дисплея игры: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def _detect_game_display_linux(self) -> Optional[Dict[str, Any]]:
        """Определение дисплея с игрой в Linux"""
        import subprocess
        
        try:
            # Получаем информацию о всех дисплеях
            displays_cmd = "xrandr --listmonitors"
            result = subprocess.run(displays_cmd, shell=True, capture_output=True, text=True)
            
            if result.returncode != 0:
                print(f"❌ Команда xrandr вернула ошибку: {result.stderr}")
                return None
            
            print(f"🖥️  Вывод xrandr --listmonitors:")
            print(result.stdout)
            
            displays = []
            for line in result.stdout.split('\n')[1:]:  # Пропускаем заголовок
                if line.strip():
                    try:
                        print(f"🔍 Парсим строку: '{line.strip()}'")
                        parts = line.strip().split()
                        if len(parts) >= 4:
                            # Парсим строку вида: "0: +*eDP-1 1280/309x800/193+0+0  eDP-1"
                            geometry = parts[2]  # например "1280/309x800/193+0+0"
                            print(f"  Геометрия: {geometry}")
                            
                            if 'x' in geometry and '+' in geometry:
                                size_part = geometry.split('+')[0]  # "1280/309x800/193"
                                offset_parts = geometry.split('+')[1:]  # ["0", "0"]
                                print(f"  Размер: {size_part}, Смещения: {offset_parts}")
                                
                                if '/' in size_part:
                                    width_part = size_part.split('x')[0]  # "1280/309"
                                    height_part = size_part.split('x')[1]  # "800/193"
                                    width = int(width_part.split('/')[0])
                                    height = int(height_part.split('/')[0])
                                    
                                    # Очищаем offset от дополнительной информации
                                    x_offset_str = offset_parts[0].split()[0]  # "0" из "0 (screen: 0)"
                                    y_offset_str = offset_parts[1].split()[0] if len(offset_parts) > 1 else "0"
                                    x_offset = int(x_offset_str)
                                    y_offset = int(y_offset_str)
                                    
                                    display_info = {
                                        'name': parts[-1],
                                        'width': width,
                                        'height': height,
                                        'x': x_offset,
                                        'y': y_offset,
                                        'primary': '*' in line
                                    }
                                    displays.append(display_info)
                                    print(f"  ✅ Добавлен дисплей: {display_info}")
                    except Exception as e:
                        print(f"  ❌ Ошибка парсинга строки '{line.strip()}': {e}")
            
            # Ищем окно игры и определяем на каком дисплее оно находится
            window_cmd = f"xdotool search --name '{self.window_title}'"
            window_result = subprocess.run(window_cmd, shell=True, capture_output=True, text=True)
            
            if window_result.returncode == 0 and window_result.stdout.strip():
                window_id = window_result.stdout.strip().split('\n')[0]
                
                # Получаем позицию окна
                geometry_cmd = f"xdotool getwindowgeometry {window_id}"
                geom_result = subprocess.run(geometry_cmd, shell=True, capture_output=True, text=True)
                
                if geom_result.returncode == 0:
                    print(f"🔍 Вывод xdotool getwindowgeometry:")
                    print(geom_result.stdout)
                    
                    # Парсим вывод getwindowgeometry
                    for line in geom_result.stdout.split('\n'):
                        if 'Position:' in line:
                            pos_str = line.split('Position:')[1].strip()
                            print(f"  Позиция строка: '{pos_str}'")
                            
                            if ',' in pos_str:
                                # Очищаем координаты от дополнительной информации типа "(screen: 0)"
                                x_str = pos_str.split(',')[0].strip().split()[0]  # "0" из "0 (screen: 0)"
                                y_str = pos_str.split(',')[1].strip().split()[0]  # "0" из "0 (screen: 0)"
                                window_x = int(x_str)
                                window_y = int(y_str)
                                print(f"  Позиция окна: ({window_x}, {window_y})")
                                
                                # Определяем на каком дисплее находится окно
                                for display in displays:
                                    if (display['x'] <= window_x < display['x'] + display['width'] and
                                        display['y'] <= window_y < display['y'] + display['height']):
                                        
                                        print(f"🎮 Игра найдена на дисплее {display['name']}: {display['width']}x{display['height']} +{display['x']}+{display['y']}")
                                        return display
            
            # Если не удалось найти окно, используем fallback логику
            if self.multi_display_config.prefer_external_display and len(displays) > 1:
                # Ищем внешний дисплей (не eDP)
                external_display = next((d for d in displays if 'eDP' not in d['name'] and not d['name'].startswith('eDP')), None)
                if external_display:
                    print(f"🖥️  Используем предпочтительный внешний дисплей: {external_display['name']} ({external_display['width']}x{external_display['height']} +{external_display['x']}+{external_display['y']})")
                    return external_display
            
            # Возвращаем основной дисплей
            primary_display = next((d for d in displays if d.get('primary')), displays[0] if displays else None)
            if primary_display:
                print(f"🖥️  Используем основной дисплей: {primary_display['name']}")
            
            return primary_display
            
        except Exception as e:
            print(f"Error detecting Linux display: {e}")
            return None
    

    def adjust_coordinates(self, x: int, y: int) -> tuple:
        """
        Корректировка координат с учетом мультидисплея
        
        Args:
            x, y: Исходные координаты (относительно игрового окна)
            
        Returns:
            Скорректированные координаты для конкретного дисплея
        """
        original_x, original_y = x, y
        
        # Если автоопределение включено, получаем информацию о дисплее
        if self.multi_display_config.auto_detect_game_screen:
            if self.game_display_info is None:
                print("🔍 Определяем дисплей с игрой...")
                self.game_display_info = self.detect_game_display()
                if self.game_display_info:
                    print(f"🎮 Игра найдена на дисплее: {self.game_display_info['name']} "
                          f"({self.game_display_info['width']}x{self.game_display_info['height']} "
                          f"+{self.game_display_info['x']}+{self.game_display_info['y']})")
                else:
                    print("⚠️  Не удалось определить дисплей с игрой")
            
            if self.game_display_info:
                # Добавляем смещение дисплея
                x += self.game_display_info['x']
                y += self.game_display_info['y']
                print(f"📐 Добавлено смещение дисплея: +{self.game_display_info['x']}+{self.game_display_info['y']}")
        
        # Применяем ручное смещение из конфигурации
        manual_offset_x = self.multi_display_config.coordinate_offset['x']
        manual_offset_y = self.multi_display_config.coordinate_offset['y']
        if manual_offset_x != 0 or manual_offset_y != 0:
            x += manual_offset_x
            y += manual_offset_y
            print(f"📐 Добавлено ручное смещение: +{manual_offset_x}+{manual_offset_y}")
        
        # Применяем масштабирование
        if self.multi_display_config.display_scaling != 1.0:
            x = int(x * self.multi_display_config.display_scaling)
            y = int(y * self.multi_display_config.display_scaling)
            print(f"🔍 Применено масштабирование: x{self.multi_display_config.display_scaling}")
        
        print(f"🎯 Координаты: ({original_x}, {original_y}) → ({x}, {y})")
        
        return x, y