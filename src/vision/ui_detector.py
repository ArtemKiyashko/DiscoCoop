"""
Детектор UI элементов на основе компьютерного зрения
"""
import cv2
import numpy as np
from typing import List
from .models import GameElement


class UIDetector:
    """Детектор UI элементов"""
    
    def find_ui_elements(self, cv_image: np.ndarray, target: str) -> List[GameElement]:
        """Поиск UI элементов (кнопки, поля и т.д.)"""
        candidates = []
        
        # Конвертируем в серый для анализа
        gray = cv2.cvtColor(cv_image, cv2.COLOR_BGR2GRAY)
        
        # Поиск прямоугольных элементов (кнопки)
        button_candidates = self._find_buttons(gray, target)
        candidates.extend(button_candidates)
        
        # Поиск контуров
        contour_candidates = self._find_contours(gray, target)
        candidates.extend(contour_candidates)
        
        return candidates
    
    def _find_buttons(self, gray: np.ndarray, target: str) -> List[GameElement]:
        """Поиск кнопочных элементов"""
        candidates = []
        
        # Определяем типичные размеры кнопок для Steam Deck
        min_width, max_width = 50, 400
        min_height, max_height = 20, 100
        
        # Поиск прямоугольников
        edges = cv2.Canny(gray, 50, 150)
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            # Аппроксимируем контур
            epsilon = 0.02 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)
            
            # Ищем прямоугольные формы
            if len(approx) >= 4:
                x, y, w, h = cv2.boundingRect(contour)
                
                # Фильтруем по размеру
                if min_width <= w <= max_width and min_height <= h <= max_height:
                    # Проверяем aspect ratio (кнопки обычно шире чем выше)
                    aspect_ratio = w / h
                    if 1.5 <= aspect_ratio <= 8.0:
                        center_x = x + w // 2
                        center_y = y + h // 2
                        
                        candidates.append(GameElement(
                            name=f"button_{len(candidates)}",
                            center_x=center_x,
                            center_y=center_y,
                            width=w,
                            height=h,
                            confidence=0.6,
                            method="ui_button",
                            bbox=(x, y, x + w, y + h)
                        ))
        
        return candidates
    
    def _find_contours(self, gray: np.ndarray, target: str) -> List[GameElement]:
        """Поиск контурных элементов"""
        candidates = []
        
        # Адаптивная пороговая обработка
        thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                       cv2.THRESH_BINARY, 11, 2)
        
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        for contour in contours:
            area = cv2.contourArea(contour)
            
            # Фильтруем по площади
            if 500 <= area <= 10000:  # Разумные размеры для UI элементов
                x, y, w, h = cv2.boundingRect(contour)
                center_x = x + w // 2
                center_y = y + h // 2
                
                candidates.append(GameElement(
                    name=f"contour_{len(candidates)}",
                    center_x=center_x,
                    center_y=center_y,
                    width=w,
                    height=h,
                    confidence=0.5,
                    method="ui_contour",
                    bbox=(x, y, x + w, y + h)
                ))
        
        return candidates