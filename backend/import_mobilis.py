import pandas as pd
from sqlalchemy.orm import Session
import models, database

def seed_data():
    db = database.SessionLocal()
    try:
        # 1. Importar Paragens (Stops)
        stops_df = pd.read_csv("stops.txt")
        for _, row in stops_df.iterrows():
            point = f"POINT({row['stop_lon']} {row['stop_lat']})"
            db.add(models.Stop(id=str(row['stop_id']), name=row['stop_name'], geom=point))
        
        # 2. Importar Linhas (Routes)
        routes_df = pd.read_csv("routes.txt")
        for _, row in routes_df.iterrows():
            db.add(models.Route(id=str(row['route_id']), short_name=row['route_short_name'], long_name=row['route_long_name']))

        db.commit()
        print("Dados da Mobilis importados com sucesso!")
    except Exception as e:
        print(f"Erro: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_data()