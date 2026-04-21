import pandas as pd
from sqlalchemy.orm import Session
import models, database # Importa a tua configuração de BD e modelos

def import_gtfs_stops(file_path: str):
    # Criar uma sessão com a BD [cite: 105]
    db = database.SessionLocal()
    
    try:
        # Lê o ficheiro .txt (que deve estar na mesma pasta)
        df = pd.read_csv(file_path)
        
        print(f"A importar {len(df)} paragens para a BD...")

        for _, row in df.iterrows():
            # Cria o ponto geográfico para o PostGIS [cite: 161, 199]
            point = f"POINT({row['stop_lon']} {row['stop_lat']})"
            
            new_stop = models.Stop(
                id=str(row['stop_id']),
                name=row['stop_name'],
                geom=point
            )
            db.add(new_stop)
        
        db.commit()
        print("Importação concluída com sucesso!")
        
    except Exception as e:
        print(f"Erro ao importar: {e}")
        db.rollback()
    finally:
        db.close()

# Executar a função (ajusta o nome do ficheiro se necessário)
if __name__ == "__main__":
    import_gtfs_stops("stops.txt")