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
import 'favorites_screen.dart';

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
  List<dynamic>? _routeOptions;
  bool _isRouteExpanded = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _originController = TextEditingController(text: "A minha localização");
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _originFocusNode = FocusNode();
  List<dynamic> _searchResults = [];
  List<dynamic> _originSearchResults = [];
  bool _isSearchExpanded = false;
  LatLng? _originPoint;
  List<dynamic> _allStops = [];
  bool _showNearbyStops = false;

  @override
  void initState() {
    super.initState();
    _loadState();
    _initLocationStream();
    _fetchAllStops();

    _searchController.addListener(_onSearchChanged);
    _originController.addListener(_onOriginChanged);
    _searchFocusNode.addListener(() { 
       if (!_searchFocusNode.hasFocus) {
         Future.delayed(const Duration(milliseconds: 200), () { if (mounted) setState(() => _searchResults = []); });
       } else {
         _onSearchChanged();
       }
    });
    _originFocusNode.addListener(() { 
       if (!_originFocusNode.hasFocus) {
         Future.delayed(const Duration(milliseconds: 200), () { if (mounted) setState(() => _originSearchResults = []); });
       } else {
         _onOriginChanged();
       }
    });
  }

  void _onSearchChanged() {
    if (!_searchFocusNode.hasFocus || _searchController.text.isEmpty) {
      if (_searchResults.isNotEmpty && mounted) setState(() => _searchResults = []);
    } else {
      final val = _searchController.text.toLowerCase();
      if (mounted) setState(() {
        _searchResults = _allStops.where((s) => s['name'].toString().toLowerCase().contains(val)).toList();
      });
    }
  }

  void _onOriginChanged() {
    if (!_originFocusNode.hasFocus || _originController.text.isEmpty || _originController.text.toLowerCase() == "a minha localização") {
      if (_originSearchResults.isNotEmpty && mounted) setState(() => _originSearchResults = []);
    } else {
      final val = _originController.text.toLowerCase();
      if (mounted) setState(() {
        _originSearchResults = _allStops.where((s) => s['name'].toString().toLowerCase().contains(val)).toList();
      });
    }
  }

  void _fetchAllStops() async {
    final stops = await ApiService.getStops();
    if (mounted) {
      setState(() {
        _allStops = stops;
      });
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _originController.removeListener(_onOriginChanged);
    _searchController.dispose();
    _originController.dispose();
    _searchFocusNode.dispose();
    _originFocusNode.dispose();
    super.dispose();
  }
  
  Future<void> _initLocationStream() async {
    try {
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
      }, onError: (e) {
        _fallbackToDefaultLocation();
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
      _originPoint = null;
      _boardingStop = null;
      _alightingStop = null;
      _navPolylines.clear();
      _navWaitTime = "";
      _searchController.clear();
      _originController.text = "A minha localização";
      _isSearchExpanded = false;
      _routeOptions = null;
      _isRouteExpanded = false;
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

  Future<void> _requestNavigation(LatLng dest, {LatLng? customOrigin}) async {
    final startLoc = customOrigin ?? _currentLocation;
    if (startLoc == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aguardar localização atual...')));
       return;
    }
    
    setState(() {
       _isLoading = true;
    });
    
    final now = DateTime.now();
    final depTime = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    
    final responseData = await ApiService.navigate(
      startLoc.latitude, startLoc.longitude,
      dest.latitude, dest.longitude,
      depTime
    );
    
    if (!mounted) return;

    if (responseData == null) {
       setState(() { _isLoading = false; });
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao contactar o servidor.')));
       return;
    }
    
    if (responseData is Map && responseData['error'] == 'not_found') {
       setState(() { _isLoading = false; });
       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(responseData['message'] ?? 'Já não há circulações para este destino hoje')));
       return;
    }
    
    if (responseData is List && responseData.isNotEmpty) {
      setState(() {
        _isNavigating = true;
        _isLoading = false;
        _destinationPoint = dest;
        _originPoint = customOrigin ?? _currentLocation;
      _routeOptions = responseData; // Guarda as opções
      _routePlanData = null; // Espera a escolha do utilizador
      _isRouteExpanded = false;
      _navPolylines.clear();
      });
      _mapController.move(_originPoint!, 13.0);
    }
  }

  void _selectRouteOption(Map<String, dynamic> routePlan) {
    final coords = routePlan['shape_coordinates'] as List<dynamic>;
    final points = coords.map((pt) => LatLng(pt['lat'], pt['lon'])).toList();
    
    final now = DateTime.now();
    final arrTimeStr = routePlan['arrival_time'].toString();
    final parts = arrTimeStr.split(':');
    final arrDate = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    int diffMins = arrDate.difference(now).inMinutes;
    if (diffMins < 0) diffMins = 0; 

    setState(() {
      _boardingStop = routePlan['boarding_stop'];
      _alightingStop = routePlan['alighting_stop'];
      _routePlanData = routePlan;
      _isRouteExpanded = false;
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
    
    _mapController.move(_originPoint ?? _currentLocation!, 14.0);
  }

  int _calculateWalkTime(LatLng p1, LatLng p2) {
    final distanceMeters = const Distance().as(LengthUnit.Meter, p1, p2);
    return (distanceMeters / 80).ceil(); // ~4.8 km/h
  }

  int _calculateWalkDist(LatLng p1, LatLng p2) {
    return const Distance().as(LengthUnit.Meter, p1, p2).round();
  }

  Widget _buildWalkSegment(String startName, LatLng p1, LatLng p2, {required bool isStart}) {
    final dist = _calculateWalkDist(p1, p2);
    final time = _calculateWalkTime(p1, p2);
    
    // Se a distância for muito pequena, não mostra caminhada
    if (dist < 20) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              if (isStart) const Icon(Icons.my_location, color: Colors.blueAccent, size: 16),
              if (!isStart) const Icon(Icons.location_on, color: Colors.redAccent, size: 16),
              Container(
                width: 2, height: 40,
                color: Colors.blueAccent.withValues(alpha: 0.5),
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isStart) Text(startName, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_walk, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("Ir a pé - Cerca de $time min, ${dist}m", style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBusSegment() {
    final interStops = _routePlanData!['intermediate_stops'] as List<dynamic>? ?? [];
    final routeColor = _navPolylines.isNotEmpty ? _navPolylines[0].color : const Color(0xFF0054A6);

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(Icons.circle, color: routeColor, size: 16),
              Container(
                width: 4, 
                height: _isRouteExpanded ? (interStops.length * 40.0 + 40.0) : 60.0,
                color: routeColor,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
              Icon(Icons.circle_outlined, color: routeColor, size: 16),
              if (_destinationPoint != null && _alightingStop != null && _calculateWalkDist(LatLng(_alightingStop['lat'], _alightingStop['lon']), _destinationPoint!) >= 20)
                Container(
                  width: 2, height: 20,
                  color: Colors.blueAccent.withValues(alpha: 0.5),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_boardingStop != null ? _boardingStop['name'] : 'Partida', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                
                const SizedBox(height: 8),
                
                InkWell(
                  onTap: () {
                    setState(() { _isRouteExpanded = !_isRouteExpanded; });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(_isRouteExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text("${interStops.length} paragens intermédias", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                
                if (_isRouteExpanded)
                  ...interStops.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
                    child: Text(s['name'], style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  )),
                  
                if (!_isRouteExpanded) const SizedBox(height: 12),
                  
                Text(_alightingStop != null ? _alightingStop['name'] : 'Chegada', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          )
        ],
      ),
    );
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
                  decoration: BoxDecoration(color: const Color(0xFF0054A6).withValues(alpha: 0.1), shape: BoxShape.circle),
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
                if (!_isGuest)
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.blueGrey),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      final success = await ApiService.addFavorite(stop['id'].toString());
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(success ? 'Paragem Guardada! 🤍' : 'Erro ao guardar'),
                          backgroundColor: success ? const Color(0xFF8CC63F) : Colors.redAccent,
                        ));
                      }
                    },
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.favorite_border, color: Colors.grey),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Inicie sessão para guardar favoritos!'),
                        backgroundColor: Colors.orange,
                      ));
                    },
                  )
              ],
            ),
            
            const SizedBox(height: 24),
            const Text("LINHAS NESTA PARAGEM", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            
            FutureBuilder<List<dynamic>>(
              future: ApiService.getStopRoutes(stop['id'].toString()),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF0054A6))),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Text('Nenhuma linha encontrada.', style: TextStyle(color: Colors.grey));
                }
                
                final routes = snapshot.data!;
                return Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: routes.map((r) {
                    Color rColor = const Color(0xFF0054A6);
                    if (r['color'] != null) {
                      String hexColor = r['color'].toString();
                      if (hexColor.startsWith('#')) hexColor = hexColor.substring(1);
                      try { rColor = Color(int.parse('0xFF$hexColor')); } catch (_) {}
                    }
                    return Chip(
                      backgroundColor: rColor.withValues(alpha: 0.1),
                      side: BorderSide(color: rColor, width: 1.5),
                      label: Text(
                        "Linha ${r['short_name']}", 
                        style: TextStyle(color: rColor, fontWeight: FontWeight.bold)
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.directions, color: Colors.white),
              label: const Text("DIREÇÕES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0054A6),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _isSearchExpanded = true;
                  _searchController.text = stop['name'];
                });
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
                _buildNavIcon(Icons.star, "Favoritos", onTap: () async {
                  final selectedStop = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FavoritesScreen())
                  );
                  if (selectedStop != null) {
                    _mapController.move(LatLng(selectedStop['lat'], selectedStop['lon']), 16.0);
                    if (!_stops.any((s) => s['id'] == selectedStop['id'])) {
                      setState(() { _stops.add(selectedStop); });
                    }
                    _showStopInfo(selectedStop);
                  }
                }),
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
                    if (context.mounted) {
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
                          if (!_isNavigating && _showNearbyStops)
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
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 340,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(_isSearchExpanded ? 16 : 24),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.black54 : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            if (_isSearchExpanded) ...[
                              Padding(
                                padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 12.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.my_location, color: Colors.blueAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: _originController,
                                        focusNode: _originFocusNode,
                                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                        decoration: InputDecoration(
                                          hintText: 'A minha localização',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                          border: InputBorder.none,
                                          hintStyle: TextStyle(fontSize: 15, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1),
                            ],
                            SizedBox(
                              height: 48,
                              child: Row(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Icon(Icons.search, color: _isSearchExpanded ? Colors.redAccent : Colors.blueGrey, size: 20),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                      decoration: InputDecoration(
                                        hintText: _isSearchExpanded ? 'Destino...' : 'Pesquisar por uma paragem...',
                                        border: InputBorder.none,
                                        hintStyle: TextStyle(fontSize: 16, color: Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54),
                                      ),
                                      onSubmitted: (value) async {
                                        if (value.trim().isEmpty) return;
                                        
                                        if (!_isSearchExpanded) {
                                            final lowerVal = value.trim().toLowerCase();
                                            final matchingStops = _allStops.where((s) => s['name'].toString().toLowerCase().contains(lowerVal)).toList();
                                            if (matchingStops.isNotEmpty) {
                                                final stop = matchingStops.first;
                                                _mapController.move(LatLng(stop['lat'], stop['lon']), 16.0);
                                                _showStopInfo(stop);
                                                FocusScope.of(context).unfocus();
                                                _searchController.clear();
                                            } else {
                                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Paragem não encontrada.')));
                                            }
                                            return;
                                        }

                                        setState(() { _isLoading = true; });

                                        LatLng? originPt;
                                        if (_originController.text.trim().isNotEmpty && _originController.text.trim().toLowerCase() != "a minha localização") {
                                           final lowerOrig = _originController.text.trim().toLowerCase();
                                           final matchingOrigStops = _allStops.where((s) => s['name'].toString().toLowerCase().contains(lowerOrig)).toList();
                                           if (matchingOrigStops.isNotEmpty) {
                                             originPt = LatLng(matchingOrigStops.first['lat'], matchingOrigStops.first['lon']);
                                           } else {
                                             originPt = await ApiService.geocodeAddress(_originController.text.trim());
                                           }
                                           if (originPt == null) {
                                             setState(() { _isLoading = false; });
                                             if (context.mounted) {
                                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local de origem não encontrado.')));
                                             }
                                             return;
                                           }
                                        }

                                        final lowerVal = value.trim().toLowerCase();
                                        final matchingStops = _allStops.where((s) => s['name'].toString().toLowerCase().contains(lowerVal)).toList();
                                        
                                        LatLng? pt;
                                        if (matchingStops.isNotEmpty) {
                                          pt = LatLng(matchingStops.first['lat'], matchingStops.first['lon']);
                                        } else {
                                          pt = await ApiService.geocodeAddress(value);
                                        }

                                        if (pt == null) {
                                          setState(() { _isLoading = false; });
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Local de destino não encontrado.')));
                                          }
                                          return;
                                        }
                                        await _requestNavigation(pt, customOrigin: originPt);
                                        setState(() { _isSearchExpanded = false; });
                                      },
                                    ),
                                  ),
                                  if (!_isSearchExpanded)
                                    IconButton(
                                      icon: const Icon(Icons.directions, color: Colors.blueAccent),
                                      onPressed: () {
                                        setState(() {
                                          _isSearchExpanded = true;
                                          _searchController.clear();
                                        });
                                      },
                                    ),
                                  if (_isSearchExpanded)
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 20, color: Colors.grey),
                                      onPressed: () {
                                        setState(() {
                                          _isSearchExpanded = false;
                                          _originController.text = "A minha localização";
                                          _searchController.clear();
                                          FocusScope.of(context).unfocus();
                                        });
                                      },
                                    )
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_searchResults.isNotEmpty || _originSearchResults.isNotEmpty)
                        Container(
                          width: 340,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                               BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))
                            ]
                          ),
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _searchResults.isNotEmpty ? _searchResults.length : _originSearchResults.length,
                            itemBuilder: (context, index) {
                              final isSearch = _searchResults.isNotEmpty;
                              final stop = isSearch ? _searchResults[index] : _originSearchResults[index];
                              return ListTile(
                                leading: const Icon(Icons.directions_bus, color: Colors.blueAccent),
                                title: Text(stop['name']),
                                onTap: () async {
                                  if (isSearch) {
                                    _searchController.text = stop['name'];
                                    _searchFocusNode.unfocus();
                                    if (!_isSearchExpanded) {
                                        _mapController.move(LatLng(stop['lat'], stop['lon']), 16.0);
                                        if (!_stops.any((s) => s['id'] == stop['id'])) {
                                            setState(() { _stops.add(stop); });
                                        }
                                        _searchController.clear();
                                    } else {
                                        setState(() { _isLoading = true; });
                                        LatLng? originPt;
                                        if (_originController.text.trim().isNotEmpty && _originController.text.trim().toLowerCase() != "a minha localização") {
                                           final lowerOrig = _originController.text.trim().toLowerCase();
                                           final matchingOrigStops = _allStops.where((s) => s['name'].toString().toLowerCase().contains(lowerOrig)).toList();
                                           if (matchingOrigStops.isNotEmpty) {
                                             originPt = LatLng(matchingOrigStops.first['lat'], matchingOrigStops.first['lon']);
                                           } else {
                                             originPt = await ApiService.geocodeAddress(_originController.text.trim());
                                           }
                                        }
                                        final pt = LatLng(stop['lat'], stop['lon']);
                                        await _requestNavigation(pt, customOrigin: originPt);
                                        setState(() { _isSearchExpanded = false; });
                                    }
                                  } else {
                                    _originController.text = stop['name'];
                                    _originFocusNode.unfocus();
                                  }
                                }
                              );
                            }
                          )
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
                
                // BOTÕES DE CONTROLO FLUTUANTES (Canto inferior direito)
                Positioned(
                  bottom: 24,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton(
                        heroTag: "btnToggleStops",
                        backgroundColor: _showNearbyStops ? const Color(0xFF0054A6) : Colors.white,
                        foregroundColor: _showNearbyStops ? Colors.white : Colors.grey,
                        onPressed: () {
                          setState(() {
                            _showNearbyStops = !_showNearbyStops;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(_showNearbyStops ? 'Paragens próximas visíveis.' : 'Paragens próximas ocultadas.'),
                              duration: const Duration(seconds: 2),
                            )
                          );
                        },
                        child: Icon(_showNearbyStops ? Icons.location_on : Icons.location_off),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
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
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Não foi possível obter a localização. Confirme as suas permissões.')),
                              );
                            }
                          }
                        },
                        child: const Icon(Icons.my_location),
                      ),
                    ],
                  ),
                ),

                // PAINEL DE NAVEGAÇÃO INFERIOR E DETALHADO (ESTILO GOOGLE MAPS)
                if (_isNavigating && (_routePlanData != null || _routeOptions != null))
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
                            
                            if (_routePlanData == null && _routeOptions != null)
                              ...[
                                const Text("Opções de Viagem", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 250,
                                  child: ListView.separated(
                                    itemCount: _routeOptions!.length,
                                    separatorBuilder: (ctx, idx) => const Divider(),
                                    itemBuilder: (ctx, index) {
                                      final option = _routeOptions![index];
                                      
                                      final arrTimeStr = option['arrival_time'].toString();
                                      final parts = arrTimeStr.split(':');
                                      final now = DateTime.now();
                                      final arrDate = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
                                      int diffMins = arrDate.difference(now).inMinutes;
                                      if (diffMins < 0) diffMins = 0;
                                      
                                      Color routeColor = const Color(0xFF0054A6);
                                      if (option['route_color'] != null) {
                                        String hexColor = option['route_color'].toString();
                                        if (hexColor.startsWith('#')) hexColor = hexColor.substring(1);
                                        try { routeColor = Color(int.parse('0xFF$hexColor')); } catch (_) {}
                                      }

                                      return ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: routeColor,
                                            borderRadius: BorderRadius.circular(8)
                                          ),
                                          child: const Icon(Icons.directions_bus, color: Colors.white)
                                        ),
                                        title: Text(option['route_name'] ?? 'Linha', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        subtitle: Text("⏱️ ${option['total_time_mins'] ?? diffMins} min totais de viagem\nPróximo autocarro às ${option['arrival_time']}"),
                                        isThreeLine: true,
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () => _selectRouteOption(option),
                                      );
                                    },
                                  ),
                                ),
                              ]
                            else if (_routePlanData != null)
                              ...[
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
                            
                            const Divider(height: 32),
                            
                            // Rota Detalhada (Timeline Expansível)
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.45
                              ),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 1. Caminhada inicial
                                    if (_originPoint != null && _boardingStop != null)
                                      _buildWalkSegment(
                                        _originController.text.trim().toLowerCase() == "a minha localização" || _originController.text.trim().isEmpty ? "A sua localização" : _originController.text,
                                        _originPoint!,
                                        LatLng(_boardingStop['lat'], _boardingStop['lon']),
                                        isStart: true
                                      ),
                                      
                                    // 2. Autocarro
                                    _buildBusSegment(),
                                    
                                    // 3. Caminhada final
                                    if (_destinationPoint != null && _alightingStop != null)
                                      _buildWalkSegment(
                                        _alightingStop['name'],
                                        LatLng(_alightingStop['lat'], _alightingStop['lon']),
                                        _destinationPoint!,
                                        isStart: false
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            
                              ],
                            
                            const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() { _isNavigating = false; _navPolylines.clear(); _searchController.clear(); _originController.text = "A minha localização"; _isSearchExpanded = false; _originPoint = null; _routePlanData = null; _routeOptions = null; _isRouteExpanded = false; });
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
