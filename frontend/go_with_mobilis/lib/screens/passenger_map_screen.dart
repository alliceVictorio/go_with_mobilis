import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../main.dart';
import 'profile_screen.dart';
import 'linha1_schedule_screen.dart';
import 'linha2_schedule_screen.dart';
import 'linha9_schedule_screen.dart';
import 'favorites_screen.dart';
import '../services/translation_service.dart';
import 'dart:ui' show ImageFilter;


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
  Uint8List? _profileImageBytes;
  
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? _lastFetchLocation;
  
  bool _isNavigating = false;
  bool _isTripStarted = false;
  final Set<String> _passedStopIds = {};
  LatLng? _destinationPoint;
  dynamic _boardingStop;
  dynamic _alightingStop;
  List<Polyline> _navPolylines = [];
  String _navWaitTime = "";
  Map<String, dynamic>? _routePlanData;
  List<dynamic>? _routeOptions;
  bool _isRouteExpanded = false;
  bool _isRoutePanelMinimized = false;
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
  dynamic _selectedSearchStop;

  LatLng? _searchedPlaceLocation;
  String? _searchedPlaceName;
  List<dynamic> _closestStopsToSearchedPlace = [];
  int _alertBadgeCount = 0;
  Timer? _busAnimationTimer;
  int _busPathIndex = 0;
  LatLng? _animatedBusLocation;

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

  Future<void> _searchPlace(String value) async {
    if (value.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final lowerVal = value.trim().toLowerCase();
    
    // 1. Tentar encontrar correspondência exata de paragem (por precaução)
    final matchingStops = _allStops.where((s) => s['name'].toString().toLowerCase() == lowerVal).toList();
    if (matchingStops.isNotEmpty) {
      final stop = matchingStops.first;
      setState(() {
        _isLoading = false;
        _searchedPlaceLocation = null;
        _searchedPlaceName = null;
        _closestStopsToSearchedPlace = [];
        _selectedSearchStop = stop;
      });
      _mapController.move(LatLng((stop['lat'] as num).toDouble(), (stop['lon'] as num).toDouble()), 16.0);
      _showStopInfo(stop);
      _searchController.clear();
      FocusScope.of(context).unfocus();
      return;
    }

    // 2. Geocodificar o local pesquisado
    final LatLng? placePt = await ApiService.geocodeAddress(value);
    if (!mounted) return;
    
    if (placePt == null) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Local ou paragem não encontrado.')),
        );
      }
      return;
    }

    // 3. Encontrar as paragens mais próximas
    if (_allStops.isNotEmpty) {
      List<Map<String, dynamic>> sortedStops = _allStops.map((s) {
        final stopPt = LatLng((s['lat'] as num).toDouble(), (s['lon'] as num).toDouble());
        final dist = const Distance().as(LengthUnit.Meter, placePt, stopPt);
        return {
          'stop': s as Map<String, dynamic>,
          'distance': dist,
        };
      }).toList();

      sortedStops.sort((a, b) => (a['distance'] as num).compareTo(b['distance'] as num));

      final List<dynamic> closestStops = sortedStops.take(3).map((e) => e['stop']).toList();
      final closestStop = closestStops.first;

      setState(() {
        _isLoading = false;
        _searchedPlaceLocation = placePt;
        _searchedPlaceName = value;
        _closestStopsToSearchedPlace = closestStops;
        _selectedSearchStop = closestStop;
      });

      _mapController.move(placePt, 16.0);
      _showStopInfo(closestStop);
    } else {
      setState(() {
        _isLoading = false;
        _searchedPlaceLocation = placePt;
        _searchedPlaceName = value;
        _closestStopsToSearchedPlace = [];
        _selectedSearchStop = null;
      });
      _mapController.move(placePt, 16.0);
    }

    _searchController.clear();
    FocusScope.of(context).unfocus();
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
    try {
      final stops = await ApiService.getStops();
      if (mounted) {
        setState(() {
          _allStops = stops;
        });
        if (stops.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sem ligação ao servidor. Nenhuma paragem em cache local.'),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modo offline: utilizando dados em cache.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _busAnimationTimer?.cancel();
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
           
           if (_isTripStarted) {
             _checkStopProximity(newLoc);
             
             final destLoc = LatLng(_alightingStop['lat'], _alightingStop['lon']);
             final dist = const Distance().as(LengthUnit.Meter, newLoc, destLoc);
             if (dist < 50) {
                _finishNavigation();
             }
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

  void _startBusAnimation(List<LatLng> pathPoints) {
    _stopBusAnimation();
    if (pathPoints.isEmpty) return;

    _busPathIndex = 0;
    setState(() {
      _animatedBusLocation = pathPoints[0];
    });

    _busAnimationTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (!mounted) return;
      if (_busPathIndex < pathPoints.length - 1) {
        _busPathIndex++;
        setState(() {
          _animatedBusLocation = pathPoints[_busPathIndex];
        });
        _checkStopProximity(_animatedBusLocation!);
        _mapController.move(_animatedBusLocation!, _mapController.camera.zoom);
      } else {
        _stopBusAnimation();
        _finishNavigation();
      }
    });
  }

  void _stopBusAnimation() {
    _busAnimationTimer?.cancel();
    _busAnimationTimer = null;
    setState(() {
      _animatedBusLocation = null;
      _busPathIndex = 0;
    });
  }

  void _checkStopProximity(LatLng currentLoc) {
    if (!_isNavigating || !_isTripStarted || _routePlanData == null) return;

    final boarding = _routePlanData!['boarding_stop'];
    final alighting = _routePlanData!['alighting_stop'];
    final interStops = _routePlanData!['intermediate_stops'] as List<dynamic>? ?? [];

    void checkAndMark(dynamic stop) {
      if (stop == null) return;
      final stopId = stop['id'].toString();
      if (_passedStopIds.contains(stopId)) return;

      final double lat = (stop['lat'] as num).toDouble();
      final double lon = (stop['lon'] as num).toDouble();
      final stopLoc = LatLng(lat, lon);
      final dist = const Distance().as(LengthUnit.Meter, currentLoc, stopLoc);

      if (dist < 50) {
        setState(() {
          _passedStopIds.add(stopId);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.greenAccent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${t('passed_stop_msg')}: ${stop['name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF156A40),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }

    checkAndMark(boarding);
    for (final stop in interStops) {
      checkAndMark(stop);
    }
    checkAndMark(alighting);
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
    _busAnimationTimer?.cancel();
    _busAnimationTimer = null;
    setState(() {
      _isNavigating = false;
      _isTripStarted = false;
      _passedStopIds.clear();
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
      _isRoutePanelMinimized = false;
      _selectedSearchStop = null;
      _searchedPlaceLocation = null;
      _searchedPlaceName = null;
      _closestStopsToSearchedPlace = [];
      _animatedBusLocation = null;
      _busPathIndex = 0;
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
        _selectedSearchStop = null;
        _searchedPlaceLocation = null;
        _searchedPlaceName = null;
        _closestStopsToSearchedPlace = [];
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
      _isTripStarted = false;
      _passedStopIds.clear();
      _boardingStop = routePlan['boarding_stop'];
      _alightingStop = routePlan['alighting_stop'];
      _routePlanData = routePlan;
      _isRouteExpanded = false;
      _isRoutePanelMinimized = false;
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

    final boardingPassed = _boardingStop != null && _passedStopIds.contains(_boardingStop['id'].toString());
    final alightingPassed = _alightingStop != null && _passedStopIds.contains(_alightingStop['id'].toString());

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                boardingPassed ? Icons.check_circle : Icons.circle, 
                color: boardingPassed ? Colors.green : routeColor, 
                size: 16
              ),
              Container(
                width: 4, 
                height: _isRouteExpanded ? (interStops.length * 40.0 + 40.0) : 60.0,
                color: routeColor,
                margin: const EdgeInsets.symmetric(vertical: 2),
              ),
              Icon(
                alightingPassed ? Icons.check_circle : Icons.circle_outlined, 
                color: alightingPassed ? Colors.green : routeColor, 
                size: 16
              ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _boardingStop != null ? _boardingStop['name'] : t('boarding_label'), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: boardingPassed ? Colors.green.shade700 : null,
                          decoration: boardingPassed ? TextDecoration.lineThrough : null,
                        )
                      ),
                    ),
                    if (boardingPassed)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
                
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
                        Text("${interStops.length} ${t('intermediate_stops')}", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                
                if (_isRouteExpanded)
                  ...interStops.map((s) {
                    final passed = _passedStopIds.contains(s['id'].toString());
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0, top: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              s['name'], 
                              style: TextStyle(
                                color: passed ? Colors.green.shade700 : Colors.black87, 
                                fontSize: 14,
                                decoration: passed ? TextDecoration.lineThrough : null,
                              )
                            ),
                          ),
                          if (passed)
                            const Icon(Icons.check_circle, color: Colors.green, size: 18),
                        ],
                      ),
                    );
                  }),
                  
                if (!_isRouteExpanded) const SizedBox(height: 12),
                  
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _alightingStop != null ? _alightingStop['name'] : t('arrival_label'), 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: alightingPassed ? Colors.green.shade700 : null,
                          decoration: alightingPassed ? TextDecoration.lineThrough : null,
                        )
                      ),
                    ),
                    if (alightingPassed)
                      const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  ],
                ),
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
    Uint8List? imgBytes;
    if (profile != null) {
      userName = '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim();
      if (userName.isEmpty) userName = "Utilizador Mobilis";
      if (profile['profile_picture'] != null && profile['profile_picture'].toString().isNotEmpty) {
        try {
          imgBytes = base64Decode(profile['profile_picture']);
        } catch (e) {
          // Ignorar
        }
      }
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
        _profileImageBytes = imgBytes;
        _isLoading = false;
      });
      _checkAlertsPopup();
    }
  }

  Future<void> _checkAlertsPopup() async {
    try {
      final alerts = await ApiService.getActiveAlerts();
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final dismissedStr = prefs.getString('dismissed_alert_ids') ?? '';
      final dismissedIds = dismissedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

      // Filtramos os alertas que o utilizador ainda não viu para definir o badgeCount
      final unreadAlerts = alerts.where((alert) {
        final alertId = alert['id'].toString();
        return !dismissedIds.contains(alertId);
      }).toList();

      setState(() {
        _alertBadgeCount = unreadAlerts.length;
      });
    } catch (_) {}
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

  void _showAlertsModal() async {
    setState(() {
      _alertBadgeCount = 0;
    });

    try {
      final alerts = await ApiService.getActiveAlerts();
      final prefs = await SharedPreferences.getInstance();
      final currentDismissedStr = prefs.getString('dismissed_alert_ids') ?? '';
      final currentDismissedList = currentDismissedStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      bool changed = false;
      for (var alert in alerts) {
        final idStr = alert['id'].toString();
        if (!currentDismissedList.contains(idStr)) {
          currentDismissedList.add(idStr);
          changed = true;
        }
      }
      if (changed) {
        await prefs.setString('dismissed_alert_ids', currentDismissedList.join(','));
      }
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
            Center(
              child: Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Row(
              children: [
                Icon(Icons.notifications_active, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text('Avisos e Alertas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<dynamic>>(
              future: ApiService.getActiveAlerts(),
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: const Center(
                      child: Text('Não existem avisos ou alertas ativos no momento.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))
                    ),
                  );
                }
                
                final alerts = snapshot.data!;
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: alerts.length,
                  separatorBuilder: (ctx, i) => const Divider(),
                  itemBuilder: (ctx, i) {
                    final alert = alerts[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 32),
                      title: Text(alert['message'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Text(alert['created_at'].toString().substring(0, 16), style: const TextStyle(fontSize: 12)),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
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



  Widget _buildBottomNavIcon(IconData icon, String label, {VoidCallback? onTap, Color? colorOverride, int badgeCount = 0}) {
    final defaultColor = Theme.of(context).colorScheme.onSurface;
    final finalColor = colorOverride ?? defaultColor;
    
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: finalColor, size: 24),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: PulsingBadge(count: badgeCount),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label, 
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, color: finalColor, fontWeight: FontWeight.w500)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavIcon(IconData icon, String label, {VoidCallback? onTap, Color? colorOverride, int badgeCount = 0}) {
    final defaultColor = Theme.of(context).colorScheme.onSurface;
    final finalColor = colorOverride ?? defaultColor;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: finalColor, size: 28),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: PulsingBadge(count: badgeCount),
                  ),
              ],
            ),
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

    final bool isWide = MediaQuery.of(context).size.width > 768;

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
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white,
                          backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                          child: _profileImageBytes == null ? const Icon(Icons.person, size: 40, color: Color(0xFF156A40)) : null,
                        ),
                        const SizedBox(height: 12),
                        Text(_userName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
            if (!_isGuest)
              ListTile(
                leading: Icon(Icons.settings, color: Theme.of(context).colorScheme.onSurface),
                title: Text(t('profile_title'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
                onTap: () {
                  Navigator.of(context).pop(); // fecha o drawer primeiro
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const ProfileScreen())
                  ).then((_) {
                    _loadState();
                  });
                },
              ),
            ListTile(
              leading: Icon(Icons.language, color: Theme.of(context).colorScheme.onSurface),
              title: Text(t('language_btn'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                final current = TranslationService.currentLanguage;
                final next = current == 'pt' ? 'en' : 'pt';
                TranslationService.setLanguage(next);
              },
            ),
            ListTile(
              leading: Icon(Icons.dark_mode, color: Theme.of(context).colorScheme.onSurface),
              title: Text(t('theme_btn'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                themeNotifier.value = themeNotifier.value == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
              },
            ),
            ListTile(
              leading: Icon(Icons.notifications, color: Theme.of(context).colorScheme.onSurface),
              title: Text(t('notifications_btn'), style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('notif_soon'))));
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
                      } else {
                        setState(() {
                          _selectedSearchStop = null;
                          _searchedPlaceLocation = null;
                          _searchedPlaceName = null;
                          _closestStopsToSearchedPlace = [];
                        });
                      }
                    },
                    onLongPress: (tapPosition, point) {
                      _requestNavigation(point);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: Theme.of(context).brightness == Brightness.dark
                          ? 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                          : 'https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.mobilis.app',
                    ),
                    PolylineLayer(
                      polylines: _isNavigating ? _navPolylines : _polylines,
                    ),
                    if (_currentLocation != null || _stops.isNotEmpty || _isNavigating || _selectedSearchStop != null || _searchedPlaceLocation != null)
                      MarkerLayer(
                        markers: [
                          if (_isTripStarted && _animatedBusLocation != null)
                            Marker(
                              point: _animatedBusLocation!,
                              width: 45,
                              height: 45,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0054A6), // Azul Mobilis
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: const Icon(
                                  Icons.directions_bus,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
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
                          if (_selectedSearchStop != null)
                            Marker(
                              point: LatLng((_selectedSearchStop['lat'] as num).toDouble(), (_selectedSearchStop['lon'] as num).toDouble()),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showStopInfo(_selectedSearchStop),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFF0054A6), // Mobilis blue
                                  size: 40,
                                ),
                              ),
                            ),
                          if (_searchedPlaceLocation != null)
                            Marker(
                              point: _searchedPlaceLocation!,
                              width: 45,
                              height: 45,
                              child: Tooltip(
                                message: _searchedPlaceName ?? "Local Pesquisado",
                                child: const Icon(
                                  Icons.location_pin,
                                  color: Colors.redAccent,
                                  size: 45,
                                ),
                              ),
                            ),
                          if (_searchedPlaceLocation != null)
                            ..._closestStopsToSearchedPlace.map((stop) {
                              final isSelected = _selectedSearchStop != null && _selectedSearchStop['id'].toString() == stop['id'].toString();
                              return Marker(
                                point: LatLng((stop['lat'] as num).toDouble(), (stop['lon'] as num).toDouble()),
                                width: 40,
                                height: 40,
                                child: GestureDetector(
                                  onTap: () => _showStopInfo(stop),
                                  child: Icon(
                                    Icons.location_on,
                                    color: isSelected ? Colors.green : const Color(0xFF0054A6),
                                    size: 40,
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                  ],
                ),
                if (isWide)
                  Positioned(
                    top: 20,
                    bottom: 20,
                    left: 20,
                    width: 75,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.black.withOpacity(0.45)
                                : Colors.white.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white12
                                  : Colors.white24,
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              IconButton(
                                icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.onSurface, size: 28),
                                onPressed: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                              ),
                              const SizedBox(height: 20),
                              _buildNavIcon(Icons.star, t('favoritos_label'), onTap: () async {
                                final selectedStop = await Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const FavoritesScreen())
                                );
                                if (selectedStop != null) {
                                  setState(() {
                                    _selectedSearchStop = selectedStop;
                                  });
                                  _mapController.move(LatLng(selectedStop['lat'], selectedStop['lon']), 16.0);
                                  _showStopInfo(selectedStop);
                                }
                              }),
                              _buildNavIcon(Icons.notifications_active, t('alertas_label'), onTap: _showAlertsModal, badgeCount: _alertBadgeCount),
                              _buildNavIcon(Icons.schedule, t('horarios_label'), onTap: _showLinesScheduleModal),
                              _buildNavIcon(
                                _showNearbyStops ? Icons.location_on : Icons.location_off, 
                                t('nearby_stops_label'), 
                                colorOverride: _showNearbyStops ? const Color(0xFF0054A6) : null,
                                onTap: () {
                                  setState(() {
                                    _showNearbyStops = !_showNearbyStops;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(_showNearbyStops ? t('nearby_stops_visible') : t('nearby_stops_hidden')),
                                      duration: const Duration(seconds: 2),
                                    )
                                  );
                                }
                              ),
                              const Spacer(),
                              _buildNavIcon(
                                Icons.logout, 
                                t('logout_label'), 
                                colorOverride: Colors.redAccent,
                                onTap: () async {
                                  const storage = FlutterSecureStorage();
                                  await storage.delete(key: 'access_token');
                                  await storage.delete(key: 'is_admin');
                                  if (context.mounted) {
                                    Navigator.of(context).pushReplacementNamed('/login');
                                  }
                                }
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
      
                // BARRA DE PESQUISA FLUTUANTE À GOOGLE MAPS + BOTÕES DE ROTAS
                if (!_isNavigating)
                  Positioned(
                    top: 40,
                    left: isWide ? 110 : 20,
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(_isSearchExpanded ? 16 : 24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 340,
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.black.withOpacity(0.45)
                                  : Colors.white.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(_isSearchExpanded ? 16 : 24),
                              border: Border.all(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white12
                                    : Colors.white24,
                                width: 1.5,
                              ),
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
                                                setState(() {
                                                  _selectedSearchStop = stop;
                                                  _searchedPlaceLocation = null;
                                                  _searchedPlaceName = null;
                                                  _closestStopsToSearchedPlace = [];
                                                });
                                                _mapController.move(LatLng((stop['lat'] as num).toDouble(), (stop['lon'] as num).toDouble()), 16.0);
                                                _showStopInfo(stop);
                                                FocusScope.of(context).unfocus();
                                                _searchController.clear();
                                            } else {
                                                await _searchPlace(value);
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
                     ),
                    ),
                      if (_searchResults.isNotEmpty || _originSearchResults.isNotEmpty || (!_isSearchExpanded && _searchController.text.isNotEmpty && _searchFocusNode.hasFocus))
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 340,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.black.withOpacity(0.45)
                                    : Colors.white.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.white12
                                      : Colors.white24,
                                  width: 1.5,
                                ),
                                boxShadow: const [
                                   BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0,4))
                                ]
                              ),
                          constraints: const BoxConstraints(maxHeight: 250),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            itemCount: _isSearchExpanded
                                ? (_searchResults.isNotEmpty ? _searchResults.length : _originSearchResults.length)
                                : (_searchController.text.isNotEmpty && _searchFocusNode.hasFocus ? _searchResults.length + 1 : 0),
                            itemBuilder: (context, index) {
                              if (!_isSearchExpanded && _searchController.text.isNotEmpty && _searchFocusNode.hasFocus) {
                                if (index == 0) {
                                  return ListTile(
                                    leading: const Icon(Icons.search, color: Colors.blueAccent),
                                    title: Text('Pesquisar "${_searchController.text}" no mapa'),
                                    onTap: () {
                                      _searchPlace(_searchController.text);
                                    },
                                  );
                                }
                                final stop = _searchResults[index - 1];
                                return ListTile(
                                  leading: const Icon(Icons.directions_bus, color: Colors.blueAccent),
                                  title: Text(stop['name']),
                                  onTap: () async {
                                    _searchController.text = stop['name'];
                                    _searchFocusNode.unfocus();
                                    setState(() {
                                      _selectedSearchStop = stop;
                                      _searchedPlaceLocation = null;
                                      _searchedPlaceName = null;
                                      _closestStopsToSearchedPlace = [];
                                    });
                                    _mapController.move(LatLng((stop['lat'] as num).toDouble(), (stop['lon'] as num).toDouble()), 16.0);
                                    _showStopInfo(stop);
                                    _searchController.clear();
                                  },
                                );
                              }

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
                                        setState(() {
                                          _selectedSearchStop = stop;
                                          _searchedPlaceLocation = null;
                                          _searchedPlaceName = null;
                                          _closestStopsToSearchedPlace = [];
                                        });
                                        _mapController.move(LatLng((stop['lat'] as num).toDouble(), (stop['lon'] as num).toDouble()), 16.0);
                                        _showStopInfo(stop);
                                        _searchController.clear();
                                    } else {
                                        setState(() { _isLoading = true; });
                                        LatLng? originPt;
                                        if (_originController.text.trim().isNotEmpty && _originController.text.trim().toLowerCase() != "a minha localização") {
                                           final lowerOrig = _originController.text.trim().toLowerCase();
                                           final matchingOrigStops = _allStops.where((s) => s['name'].toString().toLowerCase().contains(lowerOrig)).toList();
                                           if (matchingOrigStops.isNotEmpty) {
                                             originPt = LatLng((matchingOrigStops.first['lat'] as num).toDouble(), (matchingOrigStops.first['lon'] as num).toDouble());
                                           } else {
                                             originPt = await ApiService.geocodeAddress(_originController.text.trim());
                                           }
                                        }
                                        final pt = LatLng((stop['lat'] as num).toDouble(), (stop['lon'] as num).toDouble());
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
                      ).then((_) {
                        _loadState();
                      });
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
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        backgroundImage: _profileImageBytes != null ? MemoryImage(_profileImageBytes!) : null,
                        child: _profileImageBytes == null ? const Icon(Icons.person, size: 24, color: Color(0xFF0054A6)) : null,
                      ),
                     ),
                    ),
                  ),
                Positioned(
                  bottom: 96,
                  right: 20,
                  child: FloatingActionButton(
                    heroTag: "btnThemeToggle",
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1E293B),
                    onPressed: () {
                      themeNotifier.value =
                          themeNotifier.value == ThemeMode.light
                              ? ThemeMode.dark
                              : ThemeMode.light;
                    },
                    child: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                  ),
                ),
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
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Não foi possível obter a localização. Confirme as suas permissões.')),
                          );
                        }
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
                
                // PAINEL DE NAVEGAÇÃO INFERIOR E DETALHADO (ESTILO GOOGLE MAPS / SIDEBAR RESPONSIVO)
                if (_isNavigating && (_routePlanData != null || _routeOptions != null))
                  Builder(
                    builder: (context) {
                      final bool isWide = MediaQuery.of(context).size.width > 768;
                      
                      return Positioned(
                        top: isWide ? 20 : null,
                        bottom: isWide ? 20 : 0,
                        left: isWide ? 110 : 0,
                        right: isWide ? null : 0,
                        width: isWide ? 380 : null,
                        child: ClipRRect(
                          borderRadius: isWide 
                              ? BorderRadius.circular(24.0) 
                              : const BorderRadius.vertical(top: Radius.circular(32.0)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: isWide ? 12 : 0, sigmaY: isWide ? 12 : 0),
                            child: Container(
                              padding: isWide ? const EdgeInsets.all(24) : const EdgeInsets.fromLTRB(24, 16, 24, 24),
                              decoration: BoxDecoration(
                                color: isWide
                                    ? (Theme.of(context).brightness == Brightness.dark
                                        ? Colors.black.withOpacity(0.45)
                                        : Colors.white.withOpacity(0.55))
                                    : Theme.of(context).colorScheme.surface,
                                borderRadius: isWide 
                                    ? BorderRadius.circular(24.0) 
                                    : const BorderRadius.vertical(top: Radius.circular(32.0)),
                                border: isWide
                                    ? Border.all(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.white12
                                            : Colors.white24,
                                        width: 1.5,
                                      )
                                    : null,
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26, 
                                    blurRadius: 16, 
                                    offset: Offset(0, -4)
                                  )
                                ]
                              ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: isWide ? MainAxisSize.max : MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Se ainda não escolheu a rota (Opções de Viagem)
                                if (_routePlanData == null && _routeOptions != null) ...[
                                  // "Puxador" visual apenas para telemóveis
                                  if (!isWide)
                                    Center(
                                      child: Container(
                                        width: 40, 
                                        height: 5,
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(4)
                                        ),
                                      ),
                                    ),
                                  const Text("Opções de Viagem", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 16),
                                  (() {
                                    final listView = ListView.separated(
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
                                    );
                                    
                                    return isWide 
                                        ? Expanded(child: listView)
                                        : SizedBox(height: 250, child: listView);
                                  })(),
                                ]
                                // Se a rota já está selecionada (Navegação Ativa)
                                else if (_routePlanData != null) ...[
                                  // Cabeçalho Interativo (Puxador + Info da Rota)
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      if (!isWide) {
                                        setState(() {
                                          _isRoutePanelMinimized = !_isRoutePanelMinimized;
                                        });
                                      }
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // "Puxador" visual apenas para telemóveis
                                        if (!isWide)
                                          Center(
                                            child: Container(
                                              width: 40, 
                                              height: 5,
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
                                                    style: TextStyle(
                                                      fontSize: 32, 
                                                      color: _navPolylines.isNotEmpty ? _navPolylines[0].color : const Color(0xFF156A40), 
                                                      fontWeight: FontWeight.w900, 
                                                      letterSpacing: -0.5
                                                    )
                                                  ),
                                                  Row(
                                                    children: [
                                                      const Text("Tempo de espera", style: TextStyle(color: Colors.grey, fontSize: 13)),
                                                      if (!isWide) ...[
                                                        const SizedBox(width: 8),
                                                        Icon(
                                                          _isRoutePanelMinimized ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                                          color: Colors.grey.shade500,
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ],
                                                  ),
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
                                      ],
                                    ),
                                  ),
                                  
                                  // Elementos que serão ocultados quando minimizado
                                  if (!_isRoutePanelMinimized) ...[
                                    const Divider(height: 32),
                                    
                                    // Rota Detalhada (Timeline Expansível)
                                    (() {
                                      final timelineWidget = SingleChildScrollView(
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
                                      );
                                      
                                      return isWide 
                                          ? Expanded(child: timelineWidget)
                                          : ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight: MediaQuery.of(context).size.height * 0.45
                                              ),
                                              child: timelineWidget,
                                            );
                                    })(),
                                    
                                    const SizedBox(height: 24),
                                    if (!_isTripStarted)
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            setState(() {
                                              _isTripStarted = true;
                                            });
                                            if (_navPolylines.isNotEmpty && _navPolylines[0].points.isNotEmpty) {
                                              _startBusAnimation(_navPolylines[0].points);
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(t('trip_started_msg')),
                                                backgroundColor: const Color(0xFF156A40),
                                              ),
                                            );
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF156A40), 
                                            foregroundColor: Colors.white, 
                                            elevation: 2,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            padding: const EdgeInsets.symmetric(vertical: 16)
                                          ),
                                          child: Text(t('start_trip_btn'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13))
                                        ),
                                      )
                                    else
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _busAnimationTimer?.cancel();
                                            _busAnimationTimer = null;
                                            setState(() {
                                              _isNavigating = false;
                                              _isTripStarted = false;
                                              _passedStopIds.clear();
                                              _navPolylines.clear();
                                              _searchController.clear();
                                              _originController.text = "A minha localização";
                                              _isSearchExpanded = false;
                                              _originPoint = null;
                                              _routePlanData = null;
                                              _routeOptions = null;
                                              _isRouteExpanded = false;
                                              _isRoutePanelMinimized = false;
                                              _selectedSearchStop = null;
                                              _searchedPlaceLocation = null;
                                              _searchedPlaceName = null;
                                              _closestStopsToSearchedPlace = [];
                                              _animatedBusLocation = null;
                                              _busPathIndex = 0;
                                            });
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade200, 
                                            foregroundColor: Colors.redAccent, 
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            padding: const EdgeInsets.symmetric(vertical: 16)
                                          ),
                                          child: Text(t('cancel_trip_btn'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5, fontSize: 13))
                                        ),
                                      ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                     ),
                    );
                    }
                  ),

              ],
            ),
          ),
        ],
      ),
        bottomNavigationBar: isWide ? null : Container(
          height: 70,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomNavIcon(Icons.menu, t('menu_label'), onTap: () {
                  _scaffoldKey.currentState?.openDrawer();
                }),
                _buildBottomNavIcon(Icons.star, t('favoritos_label'), onTap: () async {
                  final selectedStop = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FavoritesScreen())
                  );
                  if (selectedStop != null) {
                    setState(() {
                      _selectedSearchStop = selectedStop;
                    });
                    _mapController.move(LatLng(selectedStop['lat'], selectedStop['lon']), 16.0);
                    _showStopInfo(selectedStop);
                  }
                }),
                _buildBottomNavIcon(Icons.notifications_active, t('alertas_label'), onTap: _showAlertsModal, badgeCount: _alertBadgeCount),
                _buildBottomNavIcon(Icons.schedule, t('horarios_label'), onTap: _showLinesScheduleModal),
                _buildBottomNavIcon(
                  _showNearbyStops ? Icons.location_on : Icons.location_off, 
                  t('nearby_stops_label'), 
                  colorOverride: _showNearbyStops ? const Color(0xFF0054A6) : null,
                  onTap: () {
                    setState(() {
                      _showNearbyStops = !_showNearbyStops;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_showNearbyStops ? t('nearby_stops_visible') : t('nearby_stops_hidden')),
                        duration: const Duration(seconds: 2),
                      )
                    );
                  }
                ),
                _buildBottomNavIcon(
                  Icons.logout, 
                  t('logout_label'), 
                  colorOverride: Colors.redAccent,
                  onTap: () async {
                    const storage = FlutterSecureStorage();
                    await storage.delete(key: 'access_token');
                    await storage.delete(key: 'is_admin');
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  }
                ),
              ],
            ),
          ),
        ),
      );
  }
}

class PulsingBadge extends StatefulWidget {
  final int count;
  const PulsingBadge({super.key, required this.count});

  @override
  State<PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<PulsingBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.count <= 0) return const SizedBox.shrink();
    
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              width: 16 + (16 * _controller.value),
              height: 16 + (16 * _controller.value),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 1.0 - _controller.value),
                shape: BoxShape.circle,
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          constraints: const BoxConstraints(
            minWidth: 16,
            minHeight: 16,
          ),
          child: Center(
            child: Text(
              '${widget.count}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
