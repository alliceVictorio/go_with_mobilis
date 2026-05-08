from sqlalchemy import Column, Integer, String, Boolean, ForeignKey, Float, Time
from sqlalchemy.orm import relationship
from database import Base
from geoalchemy2 import Geometry # Precisas de instalar: pip install geoalchemy2

class Stop(Base):
    __tablename__ = "stops"
    id = Column(String, primary_key=True)
    name = Column(String)
    # Define o ponto geográfico (Latitude e Longitude) 
    geom = Column(Geometry(geometry_type='POINT', srid=4326))
    is_active = Column(Boolean, default=True)

class Route(Base):
    __tablename__ = "routes"
    id = Column(String, primary_key=True) # Ex: 'L1', 'L2'
    short_name = Column(String)           # Ex: '1'
    long_name = Column(String)            # Ex: 'Estação - Hospital'
    color = Column(String)                # Cor da linha no mapa [cite: 24]

class Trip(Base):
    __tablename__ = "trips"
    id = Column(String, primary_key=True)
    route_id = Column(String, ForeignKey("routes.id"))
    service_id = Column(String(50), ForeignKey("calendar.service_id"))
    shape_id = Column(String(50), ForeignKey("shapes.shape_id"))
    headsign = Column(String)             # Destino escrito no autocarro

class StopTime(Base):
    __tablename__ = "stop_times"
    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(String, ForeignKey("trips.id"))
    stop_id = Column(String, ForeignKey("stops.id"))
    arrival_time = Column(String)         # Horário de chegada [cite: 26]
    stop_sequence = Column(Integer)       # Ordem da paragem na linha

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    first_name = Column(String, nullable=False)
    last_name = Column(String, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    phone_number = Column(String, nullable=True)
    hashed_password = Column(String, nullable=False)
    profile_picture = Column(String, nullable=True) # Guarda a imagem em base64
    is_active = Column(Boolean, default=True)
    # NOVO: Define se o utilizador é administrador 
    is_admin = Column(Boolean, default=False) 

    favorites = relationship("Favorite", back_populates="owner")

class Favorite(Base):
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, index=True)
    stop_id = Column(String, index=True)  # ID da paragem Mobilis
    route_id = Column(String, index=True) # ID da linha Mobilis
    user_id = Column(Integer, ForeignKey("users.id"))

    owner = relationship("User", back_populates="favorites")

class Calendar(Base):
    __tablename__ = "calendar"
    service_id = Column(String(50), primary_key=True)
    monday = Column(Integer, nullable=False)
    tuesday = Column(Integer, nullable=False)
    wednesday = Column(Integer, nullable=False)
    thursday = Column(Integer, nullable=False)
    friday = Column(Integer, nullable=False)
    saturday = Column(Integer, nullable=False)
    sunday = Column(Integer, nullable=False)
    start_date = Column(String(8))
    end_date = Column(String(8))

class Shape(Base):
    __tablename__ = "shapes"
    shape_id = Column(String(50), primary_key=True)
    geom = Column(Geometry(geometry_type='LINESTRING', srid=4326))

class Frequency(Base):
    __tablename__ = "frequencies"
    
    # Needs a primary key for SQLAlchemy, even though GTFS doesn't specify one
    id = Column(Integer, primary_key=True, autoincrement=True)
    trip_id = Column(String(50), ForeignKey("trips.id"))
    start_time = Column(Time, nullable=False)
    end_time = Column(Time, nullable=False)
    headway_secs = Column(Integer, nullable=False)

class Agency(Base):
    __tablename__ = "agency"
    agency_id = Column(String(50), primary_key=True)
    agency_name = Column(String(100), nullable=False)
    agency_url = Column(String(255), nullable=False)
    agency_timezone = Column(String(50), nullable=False)