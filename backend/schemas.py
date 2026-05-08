from pydantic import BaseModel, EmailStr
from typing import Optional

class UserCreate(BaseModel):
    first_name: str
    last_name: str
    email: EmailStr
    password: str
    phone_number: Optional[str] = None
    profile_picture: Optional[str] = None
    is_admin: bool = False

class UserUpdate(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    password: Optional[str] = None
    phone_number: Optional[str] = None

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class UserResponse(BaseModel):
    id: int
    first_name: str
    last_name: str
    email: EmailStr
    phone_number: Optional[str] = None
    profile_picture: Optional[str] = None
    is_active: bool
    is_admin: bool

    class Config:
        from_attributes = True

class StopCreate(BaseModel):
    name: str
    lat: float
    lon: float

class StopResponse(BaseModel):
    id: str
    name: str
    lat: float
    lon: float

    class Config:
        from_attributes = True

class StopNearbyResponse(StopResponse):
    distance: float

    class Config:
        from_attributes = True

class RouteResponse(BaseModel):
    id: str
    short_name: str
    long_name: str
    color: str

    class Config:
        from_attributes = True

class StopTimeResponse(BaseModel):
    id: int
    trip_id: str
    stop_id: str
    arrival_time: str
    stop_sequence: int

    class Config:
        from_attributes = True

class StopTimeUpdate(BaseModel):
    arrival_time: str

from typing import Optional

class FavoriteCreate(BaseModel):
    stop_id: str
    route_id: Optional[str] = None

class FavoriteResponse(BaseModel):
    id: int
    stop_id: str
    route_id: Optional[str] = None
    user_id: int

    class Config:
        from_attributes = True

from typing import List

class Coordinate(BaseModel):
    lat: float
    lon: float

class ShapeResponse(BaseModel):
    route_id: str
    shape_id: str
    coordinates: List[Coordinate]

class NavigationStop(BaseModel):
    id: str
    name: str
    lat: float
    lon: float

class RoutePlanResponse(BaseModel):
    route_id: str
    route_name: str
    route_color: str
    trip_id: str
    arrival_time: str
    boarding_stop: NavigationStop
    alighting_stop: NavigationStop
    intermediate_stops: List[NavigationStop]
    shape_coordinates: List[Coordinate]

class UpcomingBusResponse(BaseModel):
    route_id: str
    route_name: str
    route_color: str
    arrival_time: str
    wait_time_mins: int

# --- ADMIN CRUD SCHEMAS ---

class RouteCreate(BaseModel):
    id: str
    short_name: str
    long_name: str
    color: str

class RouteUpdate(BaseModel):
    short_name: Optional[str] = None
    long_name: Optional[str] = None
    color: Optional[str] = None

class StopUpdate(BaseModel):
    name: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    is_active: Optional[bool] = None

class UserAdminUpdate(BaseModel):
    is_active: Optional[bool] = None
    is_admin: Optional[bool] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    email: Optional[EmailStr] = None
    phone_number: Optional[str] = None
    password: Optional[str] = None

class StopAdminResponse(StopResponse):
    is_active: bool

    class Config:
        from_attributes = True

class ScheduleCreate(BaseModel):
    route_id: str
    departure_time: str
    arrival_time: Optional[str] = None
    active_days: List[int] # [monday, tuesday, ..., sunday] (0 or 1)

class ScheduleResponse(BaseModel):
    trip_id: str
    route_id: str
    departure_time: str
    arrival_time: Optional[str] = None
    active_days: List[int]

class ScheduleUpdate(BaseModel):
    departure_time: Optional[str] = None
    arrival_time: Optional[str] = None
    active_days: Optional[List[int]] = None

class ShapeCreate(BaseModel):
    shape_id: str
    coordinates: List[Coordinate]

class ShapeUpdate(BaseModel):
    coordinates: List[Coordinate]

