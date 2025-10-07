"""
Модели данных для детектора игровых элементов
"""
from dataclasses import dataclass
from typing import Optional, Tuple


@dataclass
class GameElement:
    """Игровой элемент, найденный на экране"""
    name: str
    center_x: int
    center_y: int
    width: int
    height: int
    confidence: float
    method: str
    text_found: str = ""
    bbox: Optional[Tuple[int, int, int, int]] = None