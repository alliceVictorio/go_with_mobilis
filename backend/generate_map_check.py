import pandas as pd

def generate_html():
    print("A ler dados...")
    st = pd.read_csv("GTFs/stop_times.txt")
    stops = pd.read_csv("GTFs/stops.txt")
    trips = pd.read_csv("GTFs/trips.txt")
    shapes = pd.read_csv("GTFs/shapes.txt")
    
    # Filtrar pela Linha 1 (trip T_UTIL_01)
    t1 = st[st['trip_id'] == 'T_UTIL_01'].sort_values('stop_sequence')
    t1 = t1.merge(stops, on='stop_id').sort_values('stop_sequence')
    
    trip_shape_id = trips[trips['trip_id'] == 'T_UTIL_01']['shape_id'].iloc[0]
    shape_pts = shapes[shapes['shape_id'] == trip_shape_id].sort_values('shape_pt_sequence')
    
    # Construir a polyline para o Leaflet
    shape_js_array = []
    for _, row in shape_pts.iterrows():
        shape_js_array.append(f"[{row['shape_pt_lat']}, {row['shape_pt_lon']}]")
    polyline_js = f"var latlngs = [\n        {', '.join(shape_js_array)}\n    ];\n    L.polyline(latlngs, {{color: 'blue', weight: 4, opacity: 0.7}}).addTo(map);"
    
    # Construir os marcadores para o Leaflet (JS array)
    markers_js = []
    for _, row in t1.iterrows():
        lat = row['stop_lat']
        lon = row['stop_lon']
        seq = row['stop_sequence']
        name = row['stop_name'].replace("'", "\\'")
        
        # Leaflet marker
        markers_js.append(f"L.marker([{lat}, {lon}]).bindPopup('<b>Paragem {seq}</b><br>{name}').addTo(map).bindTooltip('{seq}', {{permanent: true, direction: 'right'}});")
        
    markers_str = "\n    ".join(markers_js)
    
    # html base
    html_content = f"""<!DOCTYPE html>
<html>
<head>
    <title>Verificar Paragens - Linha 1</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <style>
        #map {{ height: 100vh; width: 100vw; margin: 0; padding: 0; }}
        body {{ margin: 0; }}
        .leaflet-tooltip {{ font-weight: bold; font-size: 14px; color: #d32f2f; border: 2px solid #d32f2f; }}
    </style>
</head>
<body>
<div id="map"></div>
<script>
    var map = L.map('map').setView([39.7436, -8.8071], 14);

    L.tileLayer('https://{{s}}.tile.openstreetmap.org/{{z}}/{{x}}/{{y}}.png', {{
        maxZoom: 19,
        attribution: '© OpenStreetMap'
    }}).addTo(map);

    {polyline_js}

    {markers_str}
    
</script>
</body>
</html>
"""
    
    with open("check_stops.html", "w", encoding="utf-8") as f:
        f.write(html_content)
        
    print("Ficheiro check_stops.html gerado com sucesso!")

if __name__ == "__main__":
    generate_html()
