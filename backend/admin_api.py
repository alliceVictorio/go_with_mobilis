from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordBearer
import models, schemas, database, auth
import uuid

admin_router = APIRouter(prefix="/admin", tags=["admin"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="login")

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(database.get_db)):
    payload = auth.decode_token(token)
    if not payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Não autorizado")
    user = db.query(models.User).filter(models.User.email == payload.get("sub")).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Utilizador não encontrado")
    return user

# --- ROUTES ---

@admin_router.get("/stats", response_model=schemas.AdminStatsResponse)
def get_admin_stats(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    
    total_users = db.query(models.User).count()
    total_stops = db.query(models.Stop).count()
    total_routes = db.query(models.Route).count()
    active_alerts = db.query(models.Alert).filter(models.Alert.is_active == True).count()
    
    return {
        "total_users": total_users,
        "total_stops": total_stops,
        "total_routes": total_routes,
        "active_alerts": active_alerts
    }

# --- USERS ---

@admin_router.get("/users", response_model=list[schemas.UserAdminResponse])
def get_admin_users(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    users = db.query(models.User).all()
    result = []
    for u in users:
        u_dict = {
            "id": u.id,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "email": u.email,
            "phone_number": u.phone_number,
            "profile_picture": u.profile_picture,
            "is_active": u.is_active,
            "is_admin": u.is_admin,
            "favorites_count": len(u.favorites)
        }
        result.append(u_dict)
    return result

@admin_router.put("/users/{user_id}", response_model=schemas.UserResponse)
def update_admin_user(user_id: int, user_update: schemas.UserAdminUpdate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user: raise HTTPException(status_code=404, detail="Utilizador não encontrado")
    
    if user_update.is_active is not None: db_user.is_active = user_update.is_active
    if user_update.is_admin is not None: db_user.is_admin = user_update.is_admin
    if user_update.first_name is not None: db_user.first_name = user_update.first_name
    if user_update.last_name is not None: db_user.last_name = user_update.last_name
    if user_update.email is not None: db_user.email = user_update.email
    if user_update.phone_number is not None: db_user.phone_number = user_update.phone_number
    if user_update.password is not None and len(user_update.password) > 0:
        db_user.hashed_password = auth.pwd_context.hash(user_update.password)
    
    db.commit()
    db.refresh(db_user)
    return db_user

@admin_router.delete("/users/{user_id}")
def delete_admin_user(user_id: int, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if not db_user: raise HTTPException(status_code=404, detail="Utilizador não encontrado")
    
    if db_user.id == current_user.id:
        raise HTTPException(status_code=400, detail="Não podes apagar a tua própria conta")
        
    db.query(models.Favorite).filter(models.Favorite.user_id == user_id).delete()
    db.delete(db_user)
    db.commit()
    return {"detail": "Utilizador eliminado"}


@admin_router.get("/routes", response_model=list[schemas.RouteResponse])
def get_admin_routes(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    return db.query(models.Route).all()

@admin_router.post("/routes", response_model=schemas.RouteResponse)
def create_route(route: schemas.RouteCreate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    if db.query(models.Route).filter(models.Route.id == route.id).first():
        raise HTTPException(status_code=400, detail="ID da linha já existe")
    
    new_route = models.Route(id=route.id, short_name=route.short_name, long_name=route.long_name, color=route.color)
    db.add(new_route)
    db.commit()
    db.refresh(new_route)
    return new_route

@admin_router.put("/routes/{route_id}", response_model=schemas.RouteResponse)
def update_route(route_id: str, route: schemas.RouteUpdate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route: raise HTTPException(status_code=404, detail="Linha não encontrada")
    
    if route.short_name is not None: db_route.short_name = route.short_name
    if route.long_name is not None: db_route.long_name = route.long_name
    if route.color is not None: db_route.color = route.color
    
    db.commit()
    db.refresh(db_route)
    return db_route

@admin_router.delete("/routes/{route_id}")
def delete_route(route_id: str, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_route = db.query(models.Route).filter(models.Route.id == route_id).first()
    if not db_route: raise HTTPException(status_code=404, detail="Linha não encontrada")
    
    # Check if there are trips associated
    if db.query(models.Trip).filter(models.Trip.route_id == route_id).count() > 0:
        raise HTTPException(status_code=400, detail="Não podes apagar uma linha que tem horários associados. Apaga os horários primeiro.")
        
    db.delete(db_route)
    db.commit()
    return {"detail": "Linha eliminada com sucesso"}

# --- STOPS ---

@admin_router.get("/stops", response_model=list[schemas.StopAdminResponse])
def get_admin_stops(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    stops = db.query(models.Stop).all()
    # O modelo original usa WKT, vamos usar st_x e st_y para retornar JSON
    result = []
    for stop in stops:
        point = db.query(models.Stop.geom.ST_X(), models.Stop.geom.ST_Y()).filter(models.Stop.id == stop.id).first()
        result.append({
            "id": stop.id,
            "name": stop.name,
            "lon": point[0],
            "lat": point[1],
            "is_active": stop.is_active
        })
    return result

@admin_router.post("/stops", response_model=schemas.StopAdminResponse)
def create_admin_stop(stop: schemas.StopCreate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    stop_id = "STOP_" + str(uuid.uuid4())[:8]
    point = f"POINT({stop.lon} {stop.lat})"
    new_stop = models.Stop(id=stop_id, name=stop.name, geom=point, is_active=True)
    db.add(new_stop)
    db.commit()
    return {"id": stop_id, "name": stop.name, "lon": stop.lon, "lat": stop.lat, "is_active": True}

@admin_router.put("/stops/{stop_id}", response_model=schemas.StopAdminResponse)
def update_stop(stop_id: str, stop: schemas.StopUpdate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_stop = db.query(models.Stop).filter(models.Stop.id == stop_id).first()
    if not db_stop: raise HTTPException(status_code=404, detail="Paragem não encontrada")
    
    if stop.name is not None: db_stop.name = stop.name
    if stop.is_active is not None: db_stop.is_active = stop.is_active
    if stop.lat is not None and stop.lon is not None:
        db_stop.geom = f"POINT({stop.lon} {stop.lat})"
        
    db.commit()
    
    point = db.query(models.Stop.geom.ST_X(), models.Stop.geom.ST_Y()).filter(models.Stop.id == stop_id).first()
    return {"id": db_stop.id, "name": db_stop.name, "lon": point[0], "lat": point[1], "is_active": db_stop.is_active}

@admin_router.delete("/stops/{stop_id}")
def delete_stop(stop_id: str, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_stop = db.query(models.Stop).filter(models.Stop.id == stop_id).first()
    if not db_stop: raise HTTPException(status_code=404, detail="Paragem não encontrada")
    
    if db.query(models.StopTime).filter(models.StopTime.stop_id == stop_id).count() > 0:
        raise HTTPException(status_code=400, detail="Esta paragem está a ser usada em horários. Inativa-a em vez de apagar.")
        
    db.delete(db_stop)
    db.commit()
    return {"detail": "Paragem eliminada"}

# --- SCHEDULES (Aggregated) ---

@admin_router.get("/schedules", response_model=list[schemas.ScheduleResponse])
def get_schedules(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    trips = db.query(models.Trip).all()
    result = []
    for trip in trips:
        # Get calendar
        cal = db.query(models.Calendar).filter(models.Calendar.service_id == trip.service_id).first()
        active_days = [cal.monday, cal.tuesday, cal.wednesday, cal.thursday, cal.friday, cal.saturday, cal.sunday] if cal else [1,1,1,1,1,0,0]
        
        # Get stop times limits
        first_st = db.query(models.StopTime).filter(models.StopTime.trip_id == trip.id).order_by(models.StopTime.stop_sequence.asc()).first()
        last_st = db.query(models.StopTime).filter(models.StopTime.trip_id == trip.id).order_by(models.StopTime.stop_sequence.desc()).first()
        
        result.append({
            "trip_id": trip.id,
            "route_id": trip.route_id,
            "departure_time": first_st.arrival_time if first_st else "00:00:00",
            "arrival_time": last_st.arrival_time if last_st else None,
            "active_days": active_days
        })
    return result

@admin_router.post("/schedules", response_model=schemas.ScheduleResponse)
def create_schedule(schedule: schemas.ScheduleCreate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    
    # 1. Create unique service ID (Calendar)
    service_id = "CAL_" + str(uuid.uuid4())[:8]
    days = schedule.active_days
    if len(days) != 7: days = [1,1,1,1,1,0,0] # default fallback
    new_cal = models.Calendar(
        service_id=service_id, monday=days[0], tuesday=days[1], wednesday=days[2],
        thursday=days[3], friday=days[4], saturday=days[5], sunday=days[6],
        start_date="20200101", end_date="20991231"
    )
    db.add(new_cal)
    
    # 2. Create Trip
    trip_id = "TRIP_" + str(uuid.uuid4())[:8]
    new_trip = models.Trip(id=trip_id, route_id=schedule.route_id, service_id=service_id)
    db.add(new_trip)
    db.commit()
    
    # We will let the frontend add specific StopTimes later using the existing /stoptimes endpoints,
    # but we can create dummy first/last here to satisfy the shape if needed. For now just return.
    
    return {
        "trip_id": trip_id,
        "route_id": schedule.route_id,
        "departure_time": schedule.departure_time,
        "arrival_time": schedule.arrival_time,
        "active_days": days
    }

@admin_router.delete("/schedules/{trip_id}")
def delete_schedule(trip_id: str, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    db_trip = db.query(models.Trip).filter(models.Trip.id == trip_id).first()
    if not db_trip: raise HTTPException(status_code=404, detail="Horário não encontrado")
    
    # Cascata: StopTimes -> Calendar -> Trip
    db.query(models.StopTime).filter(models.StopTime.trip_id == trip_id).delete()
    if db_trip.service_id:
        db.query(models.Calendar).filter(models.Calendar.service_id == db_trip.service_id).delete()
    db.delete(db_trip)
    db.commit()
    return {"detail": "Horário eliminado"}

# --- SHAPES ---
# Percursos shapes basic API
@admin_router.get("/shapes", response_model=list[schemas.ShapeResponse])
def get_shapes(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    # Para efeitos simples, não retornamos os pontos todos num GET all porque é muito pesado, mas para o MVP enviamos o shape_id apenas.
    shapes_db = db.query(models.Shape.shape_id).distinct().all()
    return [{"route_id": "", "shape_id": s.shape_id, "coordinates": []} for s in shapes_db]

# --- ALERTS ---

@admin_router.get("/alerts", response_model=list[schemas.AlertResponse])
def get_admin_alerts(db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    return db.query(models.Alert).order_by(models.Alert.id.desc()).all()

@admin_router.post("/alerts", response_model=schemas.AlertResponse)
def create_admin_alert(alert: schemas.AlertCreate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    
    new_alert = models.Alert(
        message=alert.message,
        is_active=alert.is_active
    )
    db.add(new_alert)
    db.commit()
    db.refresh(new_alert)
    return new_alert

@admin_router.put("/alerts/{alert_id}", response_model=schemas.AlertResponse)
def update_admin_alert(alert_id: int, alert_update: schemas.AlertUpdate, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    
    db_alert = db.query(models.Alert).filter(models.Alert.id == alert_id).first()
    if not db_alert: raise HTTPException(status_code=404, detail="Alerta não encontrado")
    
    if alert_update.message is not None:
        db_alert.message = alert_update.message
    if alert_update.is_active is not None:
        db_alert.is_active = alert_update.is_active
        
    db.commit()
    db.refresh(db_alert)
    return db_alert

@admin_router.delete("/alerts/{alert_id}")
def delete_admin_alert(alert_id: int, db: Session = Depends(database.get_db), current_user: models.User = Depends(get_current_user)):
    if not current_user.is_admin: raise HTTPException(status_code=403, detail="Não autorizado")
    
    db_alert = db.query(models.Alert).filter(models.Alert.id == alert_id).first()
    if not db_alert: raise HTTPException(status_code=404, detail="Alerta não encontrado")
    
    db.delete(db_alert)
    db.commit()
    return {"detail": "Alerta eliminado"}


