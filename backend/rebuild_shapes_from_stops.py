import pandas as pd
import os

def rebuild():
    print("A ler os ficheiros GTFS...")
    trips = pd.read_csv("GTFs/trips.txt")
    stops = pd.read_csv("GTFs/stops.txt")
    st = pd.read_csv("GTFs/stop_times.txt")
    
    # Queremos reconstruir o ficheiro shapes.txt a partir das paragens
    # Cada shape_id corresponde a um trajeto. Vamos pegar numa trip de cada shape
    unique_shapes = trips.drop_duplicates(subset=['shape_id'])
    
    new_shapes = []
    
    for _, row in unique_shapes.iterrows():
        shape_id = row['shape_id']
        trip_id = row['trip_id']
        
        # Obter a sequência de paragens para esta trip
        trip_stops = st[st['trip_id'] == trip_id].sort_values('stop_sequence')
        
        # Fazer merge com as coordenadas das paragens
        trip_stops = trip_stops.merge(stops, on='stop_id')
        # Precisamos de manter a ordem! O merge altera a ordem, por isso ordenamos de novo
        trip_stops = trip_stops.sort_values('stop_sequence')
        
        # Adicionar à lista de novas shapes
        seq = 1
        for _, stop_row in trip_stops.iterrows():
            new_shapes.append({
                'shape_id': shape_id,
                'shape_pt_lat': stop_row['stop_lat'],
                'shape_pt_lon': stop_row['stop_lon'],
                'shape_pt_sequence': seq
            })
            seq += 1
            
    df_new_shapes = pd.DataFrame(new_shapes)
    
    # Guardamos como shapes_original.txt
    df_new_shapes.to_csv("GTFs/shapes_original.txt", index=False)
    print(f"shapes_original.txt reconstruído com {len(df_new_shapes)} pontos bem ordenados!")
    
    # Também guardamos por cima do shapes.txt temporariamente para o script OSRM usar
    df_new_shapes.to_csv("GTFs/shapes.txt", index=False)
    print("shapes.txt preparado para ser suavizado pelo fix_shapes.py!")

if __name__ == "__main__":
    rebuild()
