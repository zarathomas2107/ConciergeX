from dataclasses import dataclass
from typing import Optional

@dataclass
class Location:
    """Class to represent a location with coordinates and metadata."""
    latitude: float
    longitude: float
    name: str
    type: str  # 'area' or 'venue'
    similarity: float = 1.0  # Confidence score for location matching
    
    def to_dict(self) -> dict:
        """Convert location to dictionary format."""
        return {
            'type': self.type,
            'name': self.name,
            'latitude': self.latitude,
            'longitude': self.longitude,
            'similarity': self.similarity
        } 