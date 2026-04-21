import os
import pandas as pd
from sqlalchemy.orm import Session
from database import engine, SessionLocal, Base
import models

def recreate_database():
    print("Recriando a base de dados (Limpando tabelas anteriores)...")
    # Limpa todas as tabelas e recria-as do zero para garantir chaves limpas
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    print("Base de dados recriada e fresca configurada!")

def import_all():
    db = SessionLocal()
    try:
        # 1. Agency
        if os.path.exists("GTFs/agency.txt"):
            print("Importando Agency...")
            df = pd.read_csv("GTFs/agency.txt")
            for _, row in df.iterrows():
                db.add(models.Agency(
                    agency_id=str(row['agency_id']),
                    agency_name=row['agency_name'],
                    agency_url=row['agency_url'],
                    agency_timezone=row['agency_timezone']
                ))
            db.commit()

        # 2. Calendar
        if os.path.exists("GTFs/calendar.txt"):
            print("Importando Calendar...")
            df = pd.read_csv("GTFs/calendar.txt")
            for _, row in df.iterrows():
                db.add(models.Calendar(
                    service_id=str(row['service_id']),
                    monday=int(row['monday']),
                    tuesday=int(row['tuesday']),
                    wednesday=int(row['wednesday']),
                    thursday=int(row['thursday']),
                    friday=int(row['friday']),
                    saturday=int(row['saturday']),
                    sunday=int(row['sunday']),
                    start_date=str(row['start_date']),
                    end_date=str(row['end_date'])
                ))
            db.commit()

        # 3. Stops
        if os.path.exists("GTFs/stops.txt"):
            print("Importando Stops...")
            df = pd.read_csv("GTFs/stops.txt")
            for _, row in df.iterrows():
                # Formato WKT para POINT
                point = f"POINT({row['stop_lon']} {row['stop_lat']})"
                db.add(models.Stop(
                    id=str(row['stop_id']),
                    name=row['stop_name'],
                    geom=point
                ))
            db.commit()

        # 4. Routes
        if os.path.exists("GTFs/routes.txt"):
            print("Importando Routes...")
            df = pd.read_csv("GTFs/routes.txt")
            for _, row in df.iterrows():
                db.add(models.Route(
                    id=str(row['route_id']),
                    short_name=str(row.get('route_short_name', '')) if pd.notna(row.get('route_short_name')) else None,
                    long_name=str(row.get('route_long_name', '')) if pd.notna(row.get('route_long_name')) else None,
                    color=str(row.get('route_color', '')) if pd.notna(row.get('route_color')) else None
                ))
            db.commit()

        # 5. Shapes
        if os.path.exists("GTFs/shapes.txt"):
            print("Importando Shapes (Fundindo pontos numa LINESTRING geométrica)...")
            df = pd.read_csv("GTFs/shapes.txt")
            # Ordenar perfeitamente para evitar zigue-zagues espaciais
            df = df.sort_values(by=['shape_id', 'shape_pt_sequence'])
            
            # Agrupar coordenadas pelo shape_id
            for shape_id, group in df.groupby('shape_id'):
                # Construir a string WKT: "lon1 lat1, lon2 lat2"
                coords = ", ".join([f"{row['shape_pt_lon']} {row['shape_pt_lat']}" for _, row in group.iterrows()])
                
                if coords:
                    line_string = f"LINESTRING({coords})"
                    db.add(models.Shape(
                        shape_id=str(shape_id),
                        geom=line_string
                    ))
            db.commit()

        # 6. Trips
        if os.path.exists("GTFs/trips.txt"):
            print("Importando Trips...")
            df = pd.read_csv("GTFs/trips.txt")
            for _, row in df.iterrows():
                db.add(models.Trip(
                    id=str(row['trip_id']),
                    route_id=str(row['route_id']),
                    service_id=str(row.get('service_id', '')) if pd.notna(row.get('service_id')) else None,
                    shape_id=str(row.get('shape_id', '')) if pd.notna(row.get('shape_id')) else None,
                    headsign=str(row.get('trip_headsign', '')) if pd.notna(row.get('trip_headsign')) else None
                ))
            db.commit()

        # 7. Stop Times
        if os.path.exists("GTFs/stop_times.txt"):
            print("Importando Stop Times...")
            df = pd.read_csv("GTFs/stop_times.txt")
            objects = []
            for _, row in df.iterrows():
                objects.append(models.StopTime(
                    trip_id=str(row['trip_id']),
                    stop_id=str(row['stop_id']),
                    arrival_time=str(row['arrival_time']),
                    stop_sequence=int(row['stop_sequence'])
                ))
            # Batch Mode para ser extremamente rápido devido a serem centenas/milhares
            db.bulk_save_objects(objects)
            db.commit()

        # 8. Frequencies
        if os.path.exists("GTFs/frequencies.txt"):
            print("Importando Frequencies...")
            df = pd.read_csv("GTFs/frequencies.txt")
            for _, row in df.iterrows():
                db.add(models.Frequency(
                    trip_id=str(row['trip_id']),
                    start_time=str(row['start_time']),
                    end_time=str(row['end_time']),
                    headway_secs=int(row['headway_secs'])
                ))
            db.commit()
            
        print("=========")
        print("Término Magistral: Total sincronização com ficheiros GTFS efetuada!")
        print("=========")
        
    except Exception as e:
        print(f"Erro durante a importação GTFS: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    recreate_database()
    import_all()
