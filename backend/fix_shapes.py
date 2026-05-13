import os
import pandas as pd
import requests
import json
import time

OSRM_URL = "http://router.project-osrm.org/route/v1/driving/"

def get_osrm_route(coords_list):
    """
    coords_list: list of tuples (lon, lat)
    Returns a list of (lon, lat) from the OSRM route geometry.
    """
    # Se houver apenas 1 ponto, não podemos fazer rota
    if len(coords_list) < 2:
        return coords_list
        
    # Chunking: public OSRM limit is usually 100 coordinates per request.
    # We will chunk into 50 points to be safe, with 1 point overlap.
    chunk_size = 50
    chunks = []
    for i in range(0, len(coords_list), chunk_size - 1):
        chunk = coords_list[i:i+chunk_size]
        if len(chunk) > 1:
            chunks.append(chunk)
            
    full_route_coords = []
    
    for chunk in chunks:
        # Build coordinates string: lon,lat;lon,lat...
        coords_str = ";".join([f"{lon},{lat}" for lon, lat in chunk])
        
        url = f"{OSRM_URL}{coords_str}?overview=full&geometries=geojson"
        
        try:
            # We must be polite with the public server
            time.sleep(1)
            response = requests.get(url, timeout=20)
            if response.status_code == 200:
                data = response.json()
                if data["code"] == "Ok" and len(data["routes"]) > 0:
                    # GeoJSON geometry is a list of [lon, lat]
                    route_coords = data["routes"][0]["geometry"]["coordinates"]
                    
                    # Avoid duplicating the overlapping points exactly
                    if len(full_route_coords) > 0 and route_coords:
                        # Skip the first point if it's the exact same as the last point of previous chunk
                        # But actually GeoJSON will just give a smooth polyline, appending is fine.
                        # We'll just append.
                        pass
                    
                    full_route_coords.extend(route_coords)
                else:
                    print(f"Warning: OSRM did not return Ok for chunk. Code: {data.get('code')}")
                    # Fallback to straight lines for this chunk
                    full_route_coords.extend(chunk)
            else:
                print(f"Warning: OSRM request failed with status {response.status_code}")
                full_route_coords.extend(chunk)
        except Exception as e:
            print(f"Error requesting OSRM: {e}")
            full_route_coords.extend(chunk)
            
    # Deduplicate consecutive identical points
    deduped = []
    for c in full_route_coords:
        if not deduped or deduped[-1] != c:
            deduped.append(c)
            
    return deduped

def main():
    shapes_path = "GTFs/shapes.txt"
    if not os.path.exists(shapes_path):
        print(f"File {shapes_path} does not exist.")
        return

    print("Lendo ficheiro shapes.txt original...")
    df = pd.read_csv(shapes_path)
    
    # Backup original
    backup_path = "GTFs/shapes_original.txt"
    if not os.path.exists(backup_path):
        df.to_csv(backup_path, index=False)
        print(f"Backup guardado em {backup_path}")
        
    df = df.sort_values(by=['shape_id', 'shape_pt_sequence'])
    
    new_rows = []
    
    for shape_id, group in df.groupby('shape_id'):
        print(f"Processando shape_id: {shape_id} ({len(group)} pontos originais)...")
        
        coords = []
        for _, row in group.iterrows():
            coords.append((row['shape_pt_lon'], row['shape_pt_lat']))
            
        new_coords = get_osrm_route(coords)
        print(f"  -> Transformado em {len(new_coords)} pontos de estrada.")
        
        for i, (lon, lat) in enumerate(new_coords):
            new_rows.append({
                'shape_id': shape_id,
                'shape_pt_lat': lat,
                'shape_pt_lon': lon,
                'shape_pt_sequence': i + 1
            })
            
    new_df = pd.DataFrame(new_rows)
    new_df.to_csv(shapes_path, index=False)
    print(f"Novo ficheiro {shapes_path} guardado com sucesso! Contém {len(new_df)} pontos totais.")

if __name__ == "__main__":
    main()
