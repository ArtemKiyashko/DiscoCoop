"""
OCR компонент для распознавания текста
"""
import time
from typing import List, Optional
import numpy as np
from .models import GameElement

try:
    import easyocr
    OCR_AVAILABLE = True
except ImportError:
    OCR_AVAILABLE = False


class OCRDetector:
    """Детектор текста на основе OCR"""
    
    def __init__(self):
        self.reader = None
        self.cache = {}
        
        if OCR_AVAILABLE:
            self.reader = easyocr.Reader(['en', 'ru'], gpu=False)
    
    @property
    def available(self) -> bool:
        """Проверка доступности OCR"""
        return self.reader is not None
    
    def find_text_elements(self, cv_image: np.ndarray, target: str) -> List[GameElement]:
        """Поиск текстовых элементов"""
        if not self.available:
            return []
        
        candidates = []
        
        # Кэшируем OCR результаты
        img_hash = hash(cv_image.tobytes())
        if img_hash in self.cache:
            ocr_results = self.cache[img_hash]
        else:
            ocr_results = self.reader.readtext(cv_image)
            self.cache[img_hash] = ocr_results
        
        target_lower = target.lower()
        
        for (bbox, text, confidence) in ocr_results:
            if confidence < 0.3:
                continue
                
            text_lower = text.lower().strip()
            
            # Точное совпадение
            if target_lower == text_lower:
                element = self._create_element_from_ocr(bbox, text, confidence, "ocr_exact")
                candidates.append(element)
            # Частичное совпадение
            elif target_lower in text_lower or text_lower in target_lower:
                element = self._create_element_from_ocr(bbox, text, confidence, "ocr_partial")
                candidates.append(element)
        
        return candidates
    
    def _create_element_from_ocr(self, bbox, text: str, confidence: float, method: str) -> GameElement:
        """Создание элемента из OCR результата"""
        # Вычисляем центр из bbox
        points = np.array(bbox)
        center_x = int(np.mean(points[:, 0]))
        center_y = int(np.mean(points[:, 1]))
        
        # Размеры
        width = int(np.max(points[:, 0]) - np.min(points[:, 0]))
        height = int(np.max(points[:, 1]) - np.min(points[:, 1]))
        
        return GameElement(
            name=text,
            center_x=center_x,
            center_y=center_y,
            width=width,
            height=height,
            confidence=confidence,
            method=method,
            text_found=text,
            bbox=(int(np.min(points[:, 0])), int(np.min(points[:, 1])), 
                  int(np.max(points[:, 0])), int(np.max(points[:, 1])))
        )