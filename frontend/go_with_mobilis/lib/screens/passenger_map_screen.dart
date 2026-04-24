import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../main.dart';
import 'profile_screen.dart';
import 'linha1_schedule_screen.dart';
import 'linha2_schedule_screen.dart';
import 'linha9_schedule_screen.dart';

class PassengerMapScreen extends StatefulWidget {
  const PassengerMapScreen({super.key});

  @override
  State<PassengerMapScreen> createState() => _PassengerMapScreenState();
}

class _PassengerMapScreenState extends State<PassengerMapScreen> {
  final MapController _mapController = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<dynamic> _stops = [];
  List<Polyline> _polylines = [];
  String? _activeRouteId;
  bool _isAdmin = false;
  bool _isGuest = false;
  bool _isLoading = true;
  String _userName = "Mobilis Perfil";
  LatLng? _currentLocation;
  
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? _lastFetchLocation;
  
  bool _isNavigating = false;
  LatLng? _destinationPoint;
  dynamic _boardingStop;
  dynamic _alightingStop;
  List<Polyline> _navPolylines = [];
  String _navWaitTime = "";
  Map<String, dynamic>? _routePlanData;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadState();
    _initLocationStream();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _initLocationStream() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _fallbackToDefaultLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _fallbackToDefaultLocation();
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      _fallbackToDefaultLocation();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      final firstLoc = LatLng(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentLocation = firstLoc;
        });
      }
      _fetchNearbyStops(firstLoc);

      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      ).listen((Position pos) {
        final newLoc = LatLng(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _currentLocation = newLoc;
          });
        }

        if (_isNavigating && _alightingStop != null) {
           _mapController.move(newLoc, 16.0);
           
           final destLoc = LatLng(_alightingStop['lat'], _alightingStop['lon']);
           final dist = const Distance().as(LengthUnit.Meter, newLoc, destLoc);
           if (dist < 50) {
              _finishNavigation();
           }
        } else {
           if (_lastFetchLocation != null) {
             final distance = const Distance().as(LengthUnit.Meter, _lastFetchLocation!, newLoc);
             if (distance > 30) {
               _fetchNearbyStops(newLoc);
             }
           } else {
             _fetchNearbyStops(newLoc);
           }
        }
      });
    } catch (e) {
      _fallbackToDefaultLocation();
    }
  }

  void _fallbackToDefaultLocation() {
    final defaultLoc = const LatLng(39.7436, -8.8071); // Leiria centro
    if (mounted) {
      setState(() {
        _currentLocation = defaultLoc;
      });
    }
    _fetchNearbyStops(defaultLoc);
  }

  Future<void> _fetchNearbyStops(LatLng location) async {
    _lastFetchLocation = location;
    final stops = await ApiService.getNearbyStops(location.latitude, location.longitude);
    if (mounted) {
      setState(() {
        _stops = stops;
      });
    }
  }

  void _finishNavigation() {
    if (!mounted) return;
    setState(() {
      _isNavigating = false;
      _destinationPoint = null;
      _boardingStop = null;
      _alightingStop = null;
      _navPolylines.clear();
      _navWaitTime = "";
      _searchController.clear();
    });
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chegou ao seu destino! 🎉'),
        content: const Text('Com a Mobilis, a sua viagem chegou ao fim com sucesso.'),
        actions: [
          TextButton(
            child: const Text('MUITO BEM'),
            onPressed: () => Navigator.of(ctx).pop(),
          )
        ],
      )
    );
    
    if (_currentLocation != null) {
      _fetchNearbyStops(_currentLocation!);
    }
  }

  Future<void> _requestNavigation(LatLng dest) async {
    if (_currentLocation == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aguardar localização atual...')));
       return;
    }
    
    setState(() {
       _isLoading = true;
    });
    
    final now = DateTime.now();
    final depTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    final routePlan = await ApiService.navigate(
      _currentLocation!.latitude, _currentLocation!.longitude,
      dest.latitude, dest.longitude,
      depTime
    );
    
    if (!mounted) return;

    if (routePlan == null) {
       setState(() { _isLoading = false; });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao contactar o servidor.')));
       return;
    }
    
    if (routePlan['error'] == 'not_found') {
       setState(() { _isLoading = false; });
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(routePlan['message'] ?? 'Já não há circulações para este destino hoje')));
       return;
    }
    
    final coords = routePlan['shape_coordinates'] as List<dynamic>;
    final points = coords.map((pt) => LatLng(pt['lat'], pt['lon'])).toList();
    
    final arrTimeStr = routePlan['arrival_time'].toString();
    final parts = arrTimeStr.split(':');
    final arrDate = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    int diffMins = arrDate.difference(now).inMinutes;
    if (diffMins < 0) diffMins = 0; 

    setState(() {
      _isNavigating = true;
      _isLoading = false;
      _destinationPoint = dest;
      _boardingStop = routePlan['boarding_stop'];
      _alightingStop = routePlan['alighting_stop'];
      _routePlanData = routePlan;
      _navWaitTime = "Próximo autocarro em $diffMins min";
      
      Color routeColor = const Color(0xFF0054A6);
      if (routePlan['route_color'] != null) {
        String hexColor = routePlan['route_color'].toString();
        if (hexColor.startsWith('#')) hexColor = hexColor.substring(1);
        try {
          routeColor = Color(int.parse('0xFF$hexColor'));
        } catch (_) {}
      }

      _navPolylines = [
        Polyline(points: points, color: routeColor, strokeWidth: 6.0)
      ];
    });
    
    _mapController.move(_currentLocation!, 15.0);
  }

  Future<void> _loadState() async {
    const storage = FlutterSecureStorage();
    final adminState = await storage.read(key: 'is_admin');
    
    final profile = await ApiService.getUserProfile();
    String userName = "Mobilis Perfil";
    bool isGuestLocal = false;
    if (profile != null) {
      userName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
      if (userName.isEmpty) userName = "Utilizador Mobilis";
    } else {
      userName = "Convidado";
      isGuestLocal = true;
    }

    // Não carregamos formas geométricas aqui, deixamos isso para ser selecionado nos botões

    if (mounted) {
      setState(() {
        _isAdmin = adminState == 'true';
        _isGuest = isGuestLocal;
        _userName = userName;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRouteShape(String routeId, Color routeColor) async {
    if (_activeRouteId == routeId) {
      // O utilizador clicou na linha que já está ativa, por isso vamos removê-la (toggle off)
      setState(() {
        _polylines = [];
        _activeRouteId = null;
      });
      return;
    }

    // O utilizador clicou numa nova linha, por isso vamos carregá-la
    final shapeData = await ApiService.getRouteShape(routeId);
    List<Polyline> polylines = [];
    
    if (shapeData != null && shapeData['coordinates'] != null) {
      List<dynamic> coords = shapeData['coordinates'];
      List<LatLng> points = coords.map((pt) => LatLng(pt['lat'], pt['lon'])).toList();
      
      polylines.add(
        Polyline(
          points: points,
          color: routeColor,
          strokeWidth: 4.5,
        )
      );
    }
    
    if (mounted) {
      setState(() {
        _polylines = polylines;
        _activeRouteId = routeId;
      });
    }
  }

  Widget _buildRouteChip(String label, String routeId, Color routeColor) {
    return ActionChip(
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: routeColor,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onPressed: () {
        _loadRouteShape(routeId, routeColor);
      },
      elevation: 2,
    );
  }

  void _showAddStopDialog(LatLng point) {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Paragem Mobilis'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Nome da Paragem'),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Criar'),
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              
              bool success = await ApiService.createStop(
                point.latitude,
                point.longitude,
                nameController.text.trim()
              );
              
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Paragem criada com sucesso!'))
                );
                _loadState(); // reload stops
              }
            },
          )
        ],
      )
    );
  }

  void _showStopInfo(dynamic stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Puxador draggabull
            Center(
              child: Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            
            // Título
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0054A6).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.flag_circle, size: 36, color: Color(0xFF0054A6)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop['name'],
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (stop['distance'] != null)
                        Text(
                          '🚶 ${(stop['distance'] as num).toStringAsFixed(0)}m até à paragem',
                          style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.blueGrey),
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final success = await ApiService.addFavorite(stop['id']);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? 'Paragem Guardada! 🤍' : 'Erro ao guardar'),
                        backgroundColor: success ? const Color(0xFF8CC63F) : Colors.redAccent,
                      ));
                    }
                  },
                )
              ],
            ),
            
            const SizedBox(height: 24),
            const Text("PRÓXIMOS AUTOCARROS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            
            // Área dinâmica dos autocarros
            FutureBuilder<List<dynamic>>(
              future: ApiService.getUpcomingBuses(stop['id'].toString()),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0054A6))),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: const Center(
                      child: Text('Não existem viagens agendadas para esta paragem nas próximas horas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
                    ),
                  );
                }
                
                final buses = snapshot.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: buses.length,
                  separatorBuilder: (ctx, i) => const Divider(height: 1, color: Colors.black12),
                  itemBuilder: (ctx, i) {
                    final bus = buses[i];
                    Color rColor = const Color(0xFF0054A6);
                    if (bus['route_color'] != null) {
                      String hexColor = bus['route_color'].toString();
                      if (hexColor.startsWith('#')) hexColor = hexColor.substring(1);
                      try { rColor = Color(int.parse('0xFF$hexColor')); } catch (_) {}
                    }
                    
                    int waitMins = bus['wait_time_mins'];
                    String timeLabel = waitMins == 0 ? "Agora" : "$waitMins min";
                    Color timeColor = waitMins <= 5 ? Colors.redAccent : Colors.black87;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48, height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: rColor, borderRadius: BorderRadius.circular(8)),
                                child: const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    bus['route_name'] ?? 'Mobilis',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    bus['arrival_time'].toString().substring(0, 5), // hh:mm
                                    style: const TextStyle(color: Colors.blueGrey, fontSize: 13),
                                  )
                                ],
                              )
                            ],
                          ),
                          Text(
                            timeLabel,
                            style: TextStyle(fontSize: waitMins == 0 ? 18 : 22, fontWeight: FontWeight.w900, color: timeColor),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      )
    );
  }

  void _showLinesScheduleModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Escolha a Linha',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildLineOption('Linha 1', const Color(0xFF156A40)), // Verde Mobilis
            _buildLineOption('Linha 2', const Color(0xFFE31C39)), // Vermelho
            _buildLineOption('Linha 9', Colors.black87),          // Preto
          ],
        ),
      ),
    );
  }

  Widget _buildLineOption(String lineName, Color lineColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 24.0),
      height: 44, // Altura reduzida para botoes menores
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: lineColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12), // Bordas mais suaves proporcionais
          ),
        ),
        onPressed: () {
          Navigator.of(context).pop();
          _showSchedulePlaceholder(lineName);
        },
        child: Text(
          lineName.toUpperCase(),
          style: const TextStyle(
            fontSize: 15, // Mais clean
            fontWeight: FontWeight.w400, // Sem negrito
            letterSpacing: 1.0 // Espaçamento mais leve
          ),
        ),
      ),
    );
  }

  void _showSchedulePlaceholder(String lineName) {
    if (lineName == 'Linha 1') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const Linha1ScheduleScreen())
      );
      return;
    }
    if (lineName == 'Linha 2') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const Linha2ScheduleScreen())
      );
      return;
    }
    if (lineName == 'Linha 9') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const Linha9ScheduleScreen())
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Horário da $lineName'),
        content: const Text('Por favor cole o horário desta linha na documentação para que eu possa exibi-lo aqui!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fechar'),
          ),
        ],
      )
    );
  }

  Widget _buildNavIcon(IconData icon, String label, {VoidCallback? onTap, Color? colorOverride}) {
    final defaultColor = Theme.of(context).colorScheme.onSurface;
    final finalColor = colorOverride ?? defaultColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: finalColor, size: 28),
            const SizedBox(height: 4),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: finalColor)
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color(0xFF156A40),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 40, color: Color(0xFF156A40)),
                        ),
                        const SizedBox(height: 12),
                        Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
            if (!_isGuest)
              ListTile(
                leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
                title: Text('Definições da Conta', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                onTap: () {
                  Navigator.of(context).pop(); // fecha o drawer primeiro
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfileScreen())
                  );
                },
              ),
            ListTile(
              leading: Icon(Icons.language, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Alterar Idioma', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A alteração de idioma estará disponível em breve!')));
              },
            ),
            ListTile(
              leading: Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Cor (Noturno/Diurno)', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onSurface),
              title: Text('Notificações', style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Definições de notificações estarão disponíveis em breve!')));
              },
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 24.0, top: 16.0),
        child: Image.asset(
          'img/logo.jpg', // logo da Mobilis no final
          height: 48,
          fit: BoxFit.contain,
        ),
      ),
    ],
  ),
),
      body: Row(
        children: [
          // 1. BARRA LATERAL FIXA (Navigation Rail Style Screenshot)
          Container(
            width: 75,
            color: Theme.of(context).colorScheme.surface,
            child: Column(
              children: [
                const SizedBox(height: 40),
                IconButton(
                  icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface, size: 28),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
                const SizedBox(height: 20),
                _buildNavIcon(Icons.star, "Favoritos"),
                _buildNavIcon(Icons.notifications_active, "Alertas"),
                _buildNavIcon(Icons.schedule, "Horários", onTap: _showLinesScheduleModal),
                const Spacer(),
                _buildNavIcon(
                  Icons.logout, 
                  "Sair", 
                  colorOverride: Colors.redAccent,
                  onTap: () async {
                    const storage = FlutterSecureStorage();
                    await storage.deleteAll(); // Limpa as credenciais/tokens
                    if (mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  }
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          // 2. ÁREA DO MAPA com BARRA FLUTUANTE
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: const LatLng(39.7436, -8.8071), // Leiria
                    initialZoom: 13.0,
                    onTap: (tapPosition, point) {
                      if (_isAdmin) {
                        _showAddStopDialog(point);
                      }
                    },
                    onLongPress: (tapPosition, point) {
                      _requestNavigation(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mobilis.app',
                    ),
                    PolylineLayer(
                      polylines: _isNavigating ? _navPolylines : _polylines,
                    ),
                    if (_currentLocation != null || _stops.isNotEmpty || _isNavigating)
                      MarkerLayer(
                        markers: [
                          if (_currentLocation != null)
                            Marker(
                              point: _currentLocation!,
                              width: 24,
                              height: 24,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          if (!_isNavigating)
                            ..._stops.map((stop) {
                              return Marker(
                                point: LatLng(stop['lat'], stop['lon']),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showStopInfo(stop),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF0054A6), // Azul Mobilis
                                    size: 40,
                                  ),
                                ),
                              );
                            }),
                          if (_isNavigating && _destinationPoint != null)
                            Marker(
                              point: _destinationPoint!,
                              width: 40, height: 40,
                              child: const Icon(Icons.stars, color: Colors.purple, size: 40)
                            ),
                          if (_isNavigating && _boardingStop != null)
                            Marker(
                              point: LatLng(_boardingStop['lat'], _boardingStop['lon']),
                              width: 40, height: 40,
                              child: const Icon(Icons.location_on, color: Colors.green, size: 40)
                            ),
                          if (_isNavigating && _alightingStop != null)
                            Marker(
                              point: LatLng(_alightingStop['lat'], _alightingStop['lon']),
                              width: 40, height: 40,
                              child: const Icon(Icons.location_on, color: Colors.red, size: 40)
                            ),
                        ],
                      ),
                  ],
                ),
      
                // BARRA DE PESQUISA FLUTUANTE À GOOGLE MAPS + BOTÕES DE ROTAS
                Positioned(
                  top: 40,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 48,
                        width: 340, // Largura comprimida para menos de metade do monitor
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Row(
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: Icon(Icons.search, color: Colors.blueGrey, size: 20),
                            ),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                decoration: InputDecoration(
                                  hintText: 'Pesquise por um destino...',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                                ),
                                onSubmitted: (value) async {
                                  if (value.trim().isEmpty) return;
                                  
                                  setState(() { _isLoading = true; });
                                  final pt = await ApiService.geocodeAddress(value);
                                  if (pt == null) {
                                    setState(() { _isLoading = false; });
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local não encontrado.')));
                                    }
                                    return;
                                  }
                                  await _requestNavigation(pt);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildRouteChip('LINHA 1', 'R1', const Color(0xFF156A40)), // Verde
                          const SizedBox(width: 8),
                          _buildRouteChip('LINHA 2', 'R2', const Color(0xFFE31C39)), // Vermelho
                          const SizedBox(width: 8),
                          _buildRouteChip('LINHA 9', 'R9', Colors.black87), // Preto
                        ],
                      )
                    ],
                  ),
                ),
                
                // AVATAR DE PERFIL FLUTUANTE (Canto superior direito)
                if (!_isGuest)
                  Positioned(
                  top: 40,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const ProfileScreen())
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2), // Afasta o contorno da fotografia
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green, width: 2.5), // A bela linha verde a circundar
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          )
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 24, color: Color(0xFF0054A6)),
                      ),
                    ),
                  ),
                ),
                
                // BOTÃO: CENTRAR LOCALIZAÇÃO (Canto inferior direito)
                Positioned(
                  bottom: 24,
                  right: 20,
                  child: FloatingActionButton(
                    heroTag: "btnLocation",
                    backgroundColor: const Color(0xFF156A40),
                    foregroundColor: Colors.white,
                    onPressed: () async {
                      final latLng = await LocationService.getCurrentLocation();
                      if (latLng != null) {
                        if (mounted) {
                          setState(() {
                            _currentLocation = latLng;
                          });
                        }
                        _mapController.move(latLng, 15.0);
                      } else {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Não foi possível obter a localização. Confirme as suas permissões.')),
                          );
                        }
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),

                // PAINEL DE NAVEGAÇÃO INFERIOR E DETALHADO (ESTILO GOOGLE MAPS)
                if (_isNavigating && _routePlanData != null)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32.0)),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4))]
                      ),
                      child: SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // "Puxador" visual
                            Center(
                              child: Container(
                                width: 40, height: 5,
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(4)
                                ),
                              ),
                            ),
                            
                            // Tempo e Informação da Linha
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _navWaitTime.replaceAll("Próximo autocarro em ", ""),
                                        style: TextStyle(fontSize: 32, color: _navPolylines.isNotEmpty ? _navPolylines[0].color : const Color(0xFF156A40), fontWeight: FontWeight.w900, letterSpacing: -0.5)
                                      ),
                                      const Text("Tempo de espera", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _navPolylines.isNotEmpty ? _navPolylines[0].color : const Color(0xFF0054A6),
                                    borderRadius: BorderRadius.circular(12)
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.directions_bus, color: Colors.white, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        _routePlanData!['route_name'] ?? 'Mobilis', 
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            
                            const Divider(height: 32),
                            
                            // Rota Detalhada: Ponto A -> N Paragens -> Ponto B
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Coluna dos Pontos Visuais
                                Column(
                                  children: [
                                    const Icon(Icons.my_location, color: Colors.blueAccent, size: 20),
                                    Container(
                                      width: 2, height: 30,
                                      color: Colors.grey.shade300,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                    ),
                                    const Icon(Icons.circle, color: Colors.grey, size: 12),
                                    Container(
                                      width: 2, height: 30,
                                      color: Colors.grey.shade300,
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                    ),
                                    Icon(Icons.location_on, color: Theme.of(context).colorScheme.error, size: 24),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                // Textos da Rota
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Partida
                                      const SizedBox(height: 2),
                                      Text(
                                        _boardingStop != null ? _boardingStop['name'] : 'Ponto de Partida',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                      
                                      const SizedBox(height: 22),
                                      // Paragens intermédias
                                      Text(
                                        _routePlanData!['intermediate_stops'] != null 
                                        ? '${(_routePlanData!['intermediate_stops'] as List).length} paragens intermédias'
                                        : 'Viagem direta',
                                        style: const TextStyle(color: Colors.grey, fontSize: 14)
                                      ),
                                      
                                      const SizedBox(height: 26),
                                      // Destino
                                      Text(
                                        _alightingStop != null ? _alightingStop['name'] : 'Destino',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1, overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() { _isNavigating = false; _navPolylines.clear(); _searchController.clear(); _routePlanData = null; });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200, 
                                  foregroundColor: Colors.redAccent, 
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 16)
                                ),
                                child: const Text('CANCELAR VIAGEM', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0))
                              ),
                            )
                          ]
                        )
                      )
                    )
                  )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
