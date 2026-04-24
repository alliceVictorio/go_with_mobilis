from fastapi import FastAPI, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session, aliased
from passlib.context import CryptContext
import models, schemas, database, auth # Certifica-te que o auth.py está na pasta
from sqlalchemy import func
from geoalchemy2.elements import WKTElement
from geoalchemy2 import Geography
import uuid
from typing import List
from datetime import datetime, timedelta
import zoneinfo
from sqlalchemy import cast, Time

# 1. Inicializar a App e Base de Dados
models.Base.metadata.create_all(bind=database.engine)
app = FastAPI(title="Go with Mobilis API")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# --- ROTAS ---

@app.get("/")
def home():
    return {"status": "Online", "projeto": "Go with Mobilis"}

@app.post("/register", response_model=schemas.UserResponse)
def register_user(user: schemas.UserCreate, db: Session = Depends(database.get_db)):
    # Verificar se o email já existe [cite: 20, 58]
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email já registado")

    # Encriptar password e guardar [cite: 120]
    hashed_pwd = pwd_context.hash(user.password)
    new_user = models.User(
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone_number=user.phone_number,
        hashed_password=hashed_pwd,
        profile_picture=user.profile_picture,
        is_admin=user.is_admin
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@app.post("/login")
def login(user_credentials: schemas.UserLogin, db: Session = Depends(database.get_db)):
    # 1. Procura o utilizador
    user = db.query(models.User).filter(models.User.email == user_credentials.email).first()

    # 2. Valida credenciais [cite: 120]
    if not user or not pwd_context.verify(user_credentials.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou palavra-passe incorretos"
        )

    # 3. Gera o Token incluindo a claim de admin
    access_token = auth.create_access_token(data={
        "sub": user.email, 
        "is_admin": user.is_admin
    })

    # 4. Retorna o token E o estado de admin para o Frontend 
    return {
        "access_token": access_token, 
        "token_type": "bearer",
        "is_admin": user.is_admin 
    }

from fastapi.security import OAuth2PasswordBearer

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def get_current_admin(token: str = Depends(oauth2_scheme)):
    payload = auth.decode_token(token)
    if not payload or not payload.get("is_admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="Acesso negado: Requer privilégios de Administrador"
        )
    return payload

@app.get("/stops/nearby", response_model=List[schemas.StopNearbyResponse], summary="Obter Paragens Próximas (Raio de 500m)")
def get_nearby_stops(
    lat: float = Query(..., description="Latitude do utilizador", example=39.7436),
    lon: float = Query(..., description="Longitude do utilizador", example=-8.8071),
    db: Session = Depends(database.get_db)
):
    """
    Retorna a lista de paragens Mobilis num raio de **500 metros** das coordenadas fornecidas.
    A lista vem ordenada da paragem mais próxima para a mais distante.
    """
    # 1. Definir o ponto alvo geográfico (Atenção: A ordem é LON LAT no PostGIS)
    target_point = WKTElement(f'POINT({lon} {lat})', srid=4326)
    
    # 2. Calcular a distância em metros convertendo para a extensão genérica Geography
    distance_col = func.ST_Distance(
        func.cast(models.Stop.geom, Geography),
        func.cast(target_point, Geography)
    ).label('distance')
    
    # 3. Formar a query SQL que filtra paragens a <= 500 metros e os ordena
    stops_query = db.query(
        models.Stop.id,
        models.Stop.name,
        func.ST_Y(models.Stop.geom).label('lat'),
        func.ST_X(models.Stop.geom).label('lon'),
        distance_col
    ).filter(
        func.ST_DWithin(
            func.cast(models.Stop.geom, Geography),
            func.cast(target_point, Geography),
            500  # O valor está em metros porque convertemos para Geography
        )
    ).order_by("distance").all()
    
    # 4. Formatar e devolver JSON mapeado no modelo
    return [
        schemas.StopNearbyResponse(
            id=str(stop.id),
            name=stop.name,
            lat=stop.lat,
            lon=stop.lon,
            distance=round(stop.distance, 1)  # arredondar a distância a 1 casa decimal
        ) for stop in stops_query
    ]

@app.get("/stops", response_model=List[schemas.StopResponse])
def get_stops(db: Session = Depends(database.get_db)):
    stops_query = db.query(
        models.Stop.id,
        models.Stop.name,
        func.ST_Y(models.Stop.geom).label('lat'),
        func.ST_X(models.Stop.geom).label('lon')
    ).all()
    
    return [
        schemas.StopResponse(
            id=str(stop.id),
            name=stop.name,
            lat=stop.lat,
            lon=stop.lon
        ) for stop in stops_query
    ]

@app.get("/stops/{stop_id}/upcoming", response_model=List[schemas.UpcomingBusResponse])
def get_stop_upcoming_buses(stop_id: str, db: Session = Depends(database.get_db)):
    from datetime import datetime, timedelta
    import zoneinfo
    
    pt_tz = zoneinfo.ZoneInfo("Europe/Lisbon")
    pt_now = datetime.now(pt_tz)
    search_time = pt_now - timedelta(minutes=1)
    search_time_str = search_time.strftime("%H:%M:%S")

    day_mapping = {0: 'monday', 1: 'tuesday', 2: 'wednesday', 3: 'thursday', 4: 'friday', 5: 'saturday', 6: 'sunday'}
    current_day_col = day_mapping[pt_now.weekday()]
    
    st_alias = aliased(models.StopTime)
    trip_alias = aliased(models.Trip)
    cal_alias = aliased(models.Calendar)
    day_column = getattr(cal_alias, current_day_col)
    
    valid_stoptimes = db.query(st_alias, trip_alias.route_id)\
        .join(trip_alias, trip_alias.id == st_alias.trip_id)\
        .join(cal_alias, cal_alias.service_id == trip_alias.service_id)\
        .filter(st_alias.stop_id == stop_id)\
        .filter(day_column == 1)\
        .all()
        
    def parse_time(t_str):
        h, m, s = map(int, str(t_str).split(':'))
        return timedelta(hours=h, minutes=m, seconds=s)
        
    search_td = parse_time(search_time_str)
    route_best_arrival = {}
    
    for st, route_id in valid_stoptimes:
        base_arr_td = parse_time(st.arrival_time)
        best_diff = float('inf')
        best_time_str = None
        
        if base_arr_td >= search_td:
            diff = (base_arr_td - search_td).total_seconds()
            best_diff = diff
            best_time_str = st.arrival_time
            
        freqs = db.query(models.Frequency).filter(models.Frequency.trip_id == st.trip_id).all()
        for f in freqs:
            f_end_str = str(f.end_time)
            if f_end_str == "00:00:00":
                f_end_td = timedelta(hours=24)
            else:
                f_end_td = parse_time(f_end_str)
            headway = f.headway_secs
            curr_td = base_arr_td
            while curr_td <= f_end_td:
                curr_td += timedelta(seconds=headway)
                if curr_td >= search_td and curr_td <= f_end_td:
                    diff = (curr_td - search_td).total_seconds()
                    if diff < best_diff:
                        best_diff = diff
                        h, r = divmod(curr_td.total_seconds(), 3600)
                        m, s = divmod(r, 60)
                        best_time_str = f"{int(h):02d}:{int(m):02d}:{int(s):02d}"
                    break
        
        if best_time_str:
            if route_id not in route_best_arrival or best_diff < route_best_arrival[route_id][1]:
                route_best_arrival[route_id] = (best_time_str, best_diff)
                
    upcoming = []
    for rid, (arr_time, diff_sec) in route_best_arrival.items():
        route = db.query(models.Route).filter(models.Route.id == rid).first()
        if not route: continue
        r_name = f"Linha {route.short_name}" if route.short_name else (route.long_name or "Linha")
        r_color = route.color if route.color else "0054A6"
        if not r_color.startswith("#"): r_color = f"#{r_color}"
            
        upcoming.append(schemas.UpcomingBusResponse(
            route_id=rid,
            route_name=r_name,
            route_color=r_color,
            arrival_time=arr_time,
            wait_time_mins=int(diff_sec // 60)
        ))
        
    upcoming.sort(key=lambda x: x.wait_time_mins)
    return upcoming

@app.post("/stops", response_model=schemas.StopResponse)
def create_stop(
    stop: schemas.StopCreate, 
    db: Session = Depends(database.get_db),
    admin_payload: dict = Depends(get_current_admin)
):
    new_id = str(uuid.uuid4())
    geom_wkt = f'POINT({stop.lon} {stop.lat})'
    
    db_stop = models.Stop(
        id=new_id,
        name=stop.name,
        geom=WKTElement(geom_wkt, srid=4326)
    )
    db.add(db_stop)
    db.commit()
    
    return schemas.StopResponse(
        id=new_id,
        name=stop.name,
        lat=stop.lat,
        lon=stop.lon
    )

@app.get("/routes", response_model=List[schemas.RouteResponse])
def get_routes(db: Session = Depends(database.get_db)):
    return db.query(models.Route).all()

@app.get("/routes/{route_id}/shape", response_model=schemas.ShapeResponse)
def get_route_shape(route_id: str, db: Session = Depends(database.get_db)):
    # 1. Obter uma Trip para a Route para descobrirmos o shape_id
    trip = db.query(models.Trip).filter(models.Trip.route_id == route_id).first()
    if not trip or not trip.shape_id:
        raise HTTPException(status_code=404, detail="Traçado não disponível para esta rota.")
        
    # 2. Converter o LINESTRING armazenado no PostGIS numa string legível usando ST_AsText
    shape_raw = db.query(func.ST_AsText(models.Shape.geom)).filter(models.Shape.shape_id == trip.shape_id).scalar()
    
    if not shape_raw:
        raise HTTPException(status_code=404, detail="Geometria não encontrada na base de dados.")
        
    # Ex: "LINESTRING(-8.80705 39.74362, -8.80721 39.74378)" -> Fazer o parse
    clean_str = shape_raw.replace("LINESTRING(", "").replace(")", "")
    points = []
    
    # Processa os pares de longitude e latitude retornados do SQL
    for pt in clean_str.split(","):
        lon_str, lat_str = pt.strip().split(" ")
        points.append({"lat": float(lat_str), "lon": float(lon_str)})
        
    return {
        "route_id": route_id,
        "shape_id": trip.shape_id,
        "coordinates": points
    }

@app.get("/routes/{route_id}/stoptimes", response_model=List[schemas.StopTimeResponse])
def get_route_stoptimes(route_id: str, db: Session = Depends(database.get_db)):
    return db.query(models.StopTime).join(models.Trip).filter(models.Trip.route_id == route_id).all()

@app.put("/stoptimes/{stoptime_id}", response_model=schemas.StopTimeResponse)
def update_stoptime(
    stoptime_id: int, 
    update_data: schemas.StopTimeUpdate, 
    db: Session = Depends(database.get_db),
    admin_payload: dict = Depends(get_current_admin)
):
    db_stoptime = db.query(models.StopTime).filter(models.StopTime.id == stoptime_id).first()
    if not db_stoptime:
        raise HTTPException(status_code=404, detail="Horário não encontrado")
    
    db_stoptime.arrival_time = update_data.arrival_time
    db.commit()
    db.refresh(db_stoptime)
    return db_stoptime

@app.delete("/stoptimes/{stoptime_id}")
def delete_stoptime(
    stoptime_id: int, 
    db: Session = Depends(database.get_db),
    admin_payload: dict = Depends(get_current_admin)
):
    db_stoptime = db.query(models.StopTime).filter(models.StopTime.id == stoptime_id).first()
    if not db_stoptime:
        raise HTTPException(status_code=404, detail="Horário não encontrado")
        
    db.delete(db_stoptime)
    db.commit()
    return {"success": True}

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    payload = auth.decode_token(token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, 
            detail="Passeio não autorizado"
        )
    user = db.query(models.User).filter(models.User.email == payload.get("sub")).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilizador não encontrado")
    return user

@app.get("/users/me", response_model=schemas.UserResponse)
def get_user_me(current_user: models.User = Depends(get_current_user)):
    return current_user

@app.put("/users/me", response_model=schemas.UserResponse)
def update_user_me(
    update_data: schemas.UserUpdate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(get_current_user)
):
    if update_data.first_name is not None and update_data.first_name.strip() != "":
        current_user.first_name = update_data.first_name
    if update_data.last_name is not None and update_data.last_name.strip() != "":
        current_user.last_name = update_data.last_name
    if update_data.email is not None and update_data.email.strip() != "":
        current_user.email = update_data.email
    if update_data.password is not None and update_data.password.strip() != "":
        current_user.hashed_password = pwd_context.hash(update_data.password)
    if update_data.phone_number is not None:
        current_user.phone_number = update_data.phone_number
        
    db.commit()
    db.refresh(current_user)
    return current_user

@app.post("/favorites", response_model=schemas.FavoriteResponse)
def add_favorite(
    favorite: schemas.FavoriteCreate,
    db: Session = Depends(database.get_db),
    current_user: models.User = Depends(get_current_user)
):
    existing = db.query(models.Favorite).filter(
        models.Favorite.stop_id == favorite.stop_id,
        models.Favorite.user_id == current_user.id
    ).first()
    
    if existing:
        return existing
        
    db_fav = models.Favorite(
        stop_id=favorite.stop_id,
        route_id=favorite.route_id,
        user_id=current_user.id
    )
    db.add(db_fav)
    db.commit()
    db.refresh(db_fav)
    return db_fav

@app.get("/navigate", response_model=schemas.RoutePlanResponse, summary="Obter Rota de Navegação")
def get_navigation_route(
    from_lat: float = Query(..., description="Latitude de origem"),
    from_lon: float = Query(..., description="Longitude de origem"),
    to_lat: float = Query(..., description="Latitude de destino"),
    to_lon: float = Query(..., description="Longitude de destino"),
    departure_time: str = Query(None, description="Hora de partida no formato HH:MM:SS"),
    db: Session = Depends(database.get_db)
):
    # Definir fuso horário para Portugal
    pt_tz = zoneinfo.ZoneInfo("Europe/Lisbon")
    
    # Se o flutter não pedir hora específica ou se for passada a hora, vamos basear-nos no backend:
    pt_now = datetime.now(pt_tz)
    
    # Se o frontend mandou, poderíamos usá-la, mas garantimos que calculamos a data certa, 
    # por isso é mais seguro assumir full control no backend:
    search_time = pt_now - timedelta(minutes=1)
    search_time_str = search_time.strftime("%H:%M:%S")

    # Mapear dia da semana para o Calendar
    day_mapping = {
        0: 'monday',
        1: 'tuesday',
        2: 'wednesday',
        3: 'thursday',
        4: 'friday',
        5: 'saturday',
        6: 'sunday'
    }
    current_day_col = day_mapping[pt_now.weekday()]

    from_pt = WKTElement(f'POINT({from_lon} {from_lat})', srid=4326)
    to_pt = WKTElement(f'POINT({to_lon} {to_lat})', srid=4326)

    # 1. Obter paragens num raio (por exemplo as 5 mais próximas)
    origin_stops = db.query(models.Stop.id, func.ST_Y(models.Stop.geom).label('lat'), func.ST_X(models.Stop.geom).label('lon'), models.Stop.name).order_by(
        func.ST_Distance(func.cast(models.Stop.geom, Geography), func.cast(from_pt, Geography))
    ).limit(5).all()
    
    dest_stops = db.query(models.Stop.id, func.ST_Y(models.Stop.geom).label('lat'), func.ST_X(models.Stop.geom).label('lon'), models.Stop.name).order_by(
        func.ST_Distance(func.cast(models.Stop.geom, Geography), func.cast(to_pt, Geography))
    ).limit(5).all()

    if not origin_stops or not dest_stops:
        raise HTTPException(status_code=404, detail="Não existem paragens nas proximidades.")
        
    origin_ids = [s.id for s in origin_stops]
    dest_ids = [s.id for s in dest_stops]

    st1 = aliased(models.StopTime)
    st2 = aliased(models.StopTime)
    trip_alias = aliased(models.Trip)
    cal_alias = aliased(models.Calendar)
    
    day_column = getattr(cal_alias, current_day_col)

    # 2. Procurar viagens que passem na origem e depois no destino, join com Calendar
    valid_trips = db.query(st1.trip_id, st1.stop_id.label('o_stop'), st2.stop_id.label('d_stop'), st1.arrival_time) \
        .join(st2, st1.trip_id == st2.trip_id) \
        .join(trip_alias, trip_alias.id == st1.trip_id) \
        .join(cal_alias, cal_alias.service_id == trip_alias.service_id) \
        .filter(st1.stop_id.in_(origin_ids)) \
        .filter(st2.stop_id.in_(dest_ids)) \
        .filter(st1.stop_sequence < st2.stop_sequence) \
        .filter(day_column == 1) \
        .all()

    if not valid_trips:
        raise HTTPException(
            status_code=404, 
            detail=f"Não foram encontradas linhas de autocarro a ligar o seu local a este destino (Dia da semana: {current_day_col})."
        )
    
    def parse_time(t_str):
        h, m, s = map(int, str(t_str).split(':'))
        return timedelta(hours=h, minutes=m, seconds=s)

    search_td = parse_time(search_time_str)
    
    best_trip = None
    best_time_diff = float('inf')
    best_arrival_time_str = None
    
    for vt in valid_trips:
        base_arr_td = parse_time(vt.arrival_time)
        
        # 1. Verifica tempo base da trip
        if base_arr_td >= search_td:
            diff = (base_arr_td - search_td).total_seconds()
            if diff < best_time_diff:
                best_time_diff = diff
                best_trip = vt
                best_arrival_time_str = vt.arrival_time
                
        # 2. Verifica a tabela de Frequências (se este autocarro for repetido)
        freqs = db.query(models.Frequency).filter(models.Frequency.trip_id == vt.trip_id).all()
        for f in freqs:
            f_end_str = str(f.end_time)
            if f_end_str == "00:00:00":
                f_end_td = timedelta(hours=24) # Circula até à meia noite
            else:
                f_end_td = parse_time(f_end_str)
                
            headway = f.headway_secs
            curr_td = base_arr_td
            
            # Adicionar frequência enquanto não superar o limite final
            while curr_td <= f_end_td:
                curr_td += timedelta(seconds=headway)
                if curr_td >= search_td and curr_td <= f_end_td:
                    diff = (curr_td - search_td).total_seconds()
                    if diff < best_time_diff:
                        best_time_diff = diff
                        best_trip = vt
                        h, r = divmod(curr_td.total_seconds(), 3600)
                        m, s = divmod(r, 60)
                        best_arrival_time_str = f"{int(h):02d}:{int(m):02d}:{int(s):02d}"
                    break
                    
    if not best_trip:
         raise HTTPException(
            status_code=404, 
            detail=f"Não foram encontradas viagens. Procura a partir de: {search_time_str} (os autocarros já podem ter terminado o serviço por hoje)."
        )

    trip_id, o_stop_id, d_stop_id, _ = best_trip
    arrival_time = best_arrival_time_str
    
    trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    route = db.query(models.Route).filter(models.Route.id == trip.route_id).first()
    
    route_name = "Linha"
    route_color = "0054A6"
    if route:
        route_name = f"Linha {route.short_name}" if route.short_name else (route.long_name or "Linha")
        route_color = route.color if route.color else "0054A6"
        if not route_color.startswith("#"):
            route_color = f"#{route_color}"
    
    o_stop = next(s for s in origin_stops if s.id == o_stop_id)
    d_stop = next(s for s in dest_stops if s.id == d_stop_id)
    
    st_origin = db.query(models.StopTime.stop_sequence).filter(models.StopTime.trip_id == trip_id, models.StopTime.stop_id == o_stop_id).first()
    st_dest = db.query(models.StopTime.stop_sequence).filter(models.StopTime.trip_id == trip_id, models.StopTime.stop_id == d_stop_id, models.StopTime.stop_sequence > st_origin.stop_sequence).first()

    intermediate_db = db.query(
        models.Stop.id, 
        models.Stop.name,
        func.ST_Y(models.Stop.geom).label('lat'),
        func.ST_X(models.Stop.geom).label('lon')
    ).join(models.StopTime, models.StopTime.stop_id == models.Stop.id)\
     .filter(models.StopTime.trip_id == trip_id)\
     .filter(models.StopTime.stop_sequence > st_origin.stop_sequence)\
     .filter(models.StopTime.stop_sequence < st_dest.stop_sequence)\
     .order_by(models.StopTime.stop_sequence).all()

    intermediate_stops = [
        {"id": s.id, "name": s.name, "lat": s.lat, "lon": s.lon} for s in intermediate_db
    ]
    
    # Obter Shape Coordinates
    shape_raw = db.query(func.ST_AsText(models.Shape.geom)).filter(models.Shape.shape_id == trip.shape_id).scalar()
    
    points = []
    if shape_raw:
        clean_str = shape_raw.replace("LINESTRING(", "").replace(")", "")
        for pt in clean_str.split(","):
            l_lon, l_lat = pt.strip().split(" ")
            points.append({"lat": float(l_lat), "lon": float(l_lon)})

    return {
        "route_id": trip.route_id,
        "route_name": route_name,
        "route_color": route_color,
        "trip_id": trip_id,
        "arrival_time": arrival_time,
        "boarding_stop": {
            "id": o_stop.id,
            "name": o_stop.name,
            "lat": o_stop.lat,
            "lon": o_stop.lon
        },
        "alighting_stop": {
            "id": d_stop.id,
            "name": d_stop.name,
            "lat": d_stop.lat,
            "lon": d_stop.lon
        },
        "intermediate_stops": intermediate_stops,
        "shape_coordinates": points
    }