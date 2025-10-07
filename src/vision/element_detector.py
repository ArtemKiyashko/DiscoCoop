"""
Основной детектор игровых элементов
"""
import cv2
import numpy as np
from PIL import Image
from typing import List, Optional
import time

from .models import GameElement
from .ocr_detector import OCRDetector  
from .ui_detector import UIDetector


class GameElementDetector:
    """Главный детектор игровых элементов"""
    
    def __init__(self):
        self.ocr_detector = OCRDetector()
        self.ui_detector = UIDetector()
    
    def find_element(self, screenshot: Image.Image, target: str) -> Optional[GameElement]:
        """Поиск элемента на скриншоте"""
        start_time = time.time()
        
        # Конвертируем в OpenCV формат
        cv_image = cv2.cvtColor(np.array(screenshot), cv2.COLOR_RGB2BGR)
        
        candidates = []
        
        # OCR поиск
        if self.ocr_detector.available:
            ocr_candidates = self.ocr_detector.find_text_elements(cv_image, target)
            candidates.extend(ocr_candidates)
        
        # UI поиск
        ui_candidates = self.ui_detector.find_ui_elements(cv_image, target)
        candidates.extend(ui_candidates)
        
        if not candidates:
            return None
        
        # Выбираем лучший кандидат
        best = self._select_best_candidate(candidates, target)
        
        elapsed = time.time() - start_time
        return best
    
    def find_elements(self, screenshot_path: str, target: str) -> List[GameElement]:
        """Поиск всех подходящих элементов (для совместимости)"""
        screenshot = Image.open(screenshot_path)
        element = self.find_element(screenshot, target)
        return [element] if element else []
    
    def _select_best_candidate(self, candidates: List[GameElement], target: str) -> GameElement:
        """Выбор лучшего кандидата"""
        if len(candidates) == 1:
            return candidates[0]
        
        # Приоритет методам
        method_priority = {
            "ocr_exact": 10,
            "ocr_partial": 8,
            "ui_button": 6,
            "ui_contour": 4
        }
        
        # Сортируем по приоритету метода и уверенности
        candidates.sort(key=lambda x: (
            method_priority.get(x.method, 0),
            x.confidence
        ), reverse=True)
        
        return candidates[0]