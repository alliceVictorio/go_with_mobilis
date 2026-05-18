import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import 'package:latlong2/latlong.dart';
import 'dart:io' show Platform;

class ApiService {
  static const _storage = FlutterSecureStorage();

  // Usa o IP da rede local do computador para funcionar tanto no PC, como emuladores e telemóveis físicos
  static String get baseUrl {
    // 172.22.196.232 é o IP local atual da máquina de desenvolvimento (Dados Móveis)
    return 'http://127.0.0.1:8000';
  }

  static Future<Map<String, dynamic>> register(String firstName, String lastName, String email, String password, String? phoneNumber, String? profilePicture) async {
    final url = Uri.parse('$baseUrl/register');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'password': password,
          'phone_number': phoneNumber,
          'profile_picture': profilePicture,
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        String errorMsg = 'Erro no registo';
        if (data['detail'] != null) {
          if (data['detail'] is List) {
             errorMsg = (data['detail'] as List).map((e) => e['msg'] ?? e.toString()).join('\n');
          } else {
             errorMsg = data['detail'].toString();
          }
        }
        return {'success': false, 'message': errorMsg};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão ao servidor.'};
    }
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        await _storage.write(key: 'access_token', value: data['access_token']);
        await _storage.write(key: 'is_admin', value: data['is_admin'].toString());
        
        return {'success': true, 'is_admin': data['is_admin']};
      } else {
        final data = jsonDecode(response.body);
        return {'success': false, 'message': data['detail'] ?? 'Erro no login'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Erro de conexão ao servidor.'};
    }
  }

  static Future<List<dynamic>> getStops() async {
    final url = Uri.parse('$baseUrl/stops');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter paragens: $e');
      }
    }
    return [];
  }

  static Future<List<dynamic>> getNearbyStops(double lat, double lon) async {
    final url = Uri.parse('$baseUrl/stops/nearby?lat=$lat&lon=$lon');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter paragens próximas: $e');
      }
    }
    return [];
  }

  static Future<List<dynamic>> getUpcomingBuses(String stopId) async {
    final url = Uri.parse('$baseUrl/stops/$stopId/upcoming');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter próximos autocarros: $e');
      }
    }
    return [];
  }

  static Future<List<dynamic>> getStopRoutes(String stopId) async {
    final url = Uri.parse('$baseUrl/stops/$stopId/routes');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter linhas da paragem: $e');
      }
    }
    return [];
  }


  static Future<dynamic> navigate(double fromLat, double fromLon, double toLat, double toLon, String departureTime) async {
    final url = Uri.parse('$baseUrl/navigate?from_lat=$fromLat&from_lon=$fromLon&to_lat=$toLat&to_lon=$toLon&departure_time=$departureTime');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return {'error': 'not_found', 'message': jsonDecode(response.body)['detail']};
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao obter navegação: $e');
      }
    }
    return null;
  }

  static Future<LatLng?> geocodeAddress(String query) async {
    final encodedQuery = Uri.encodeComponent('$query Leiria');
    final url = Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1');
    try {
      final response = await http.get(
        url, 
        headers: {'User-Agent': 'GoWithMobilisApp/1.0'}
      );
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          return LatLng(double.parse(data[0]['lat'].toString()), double.parse(data[0]['lon'].toString()));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Erro no Geocoding: $e');
      }
    }
    return null;
  }

  static Future<bool> createStop(double lat, double lon, String name) async {
    final url = Uri.parse('$baseUrl/stops');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'lat': lat,
          'lon': lon,
          'name': name
        }),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Erro ao criar paragem: $e');
      }
      return false;
    }
  }

  static Future<Map<String, dynamic>?> getRouteShape(String routeId) async {
    final url = Uri.parse('$baseUrl/routes/$routeId/shape');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter shape da rota: $e');
    }
    return null;
  }

  static Future<List<dynamic>> getRoutes() async {
    final url = Uri.parse('$baseUrl/routes');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter linhas: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getStopTimes(String routeId) async {
    final url = Uri.parse('$baseUrl/routes/$routeId/stoptimes');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter horários: $e');
    }
    return [];
  }

  static Future<bool> updateStopTime(int stoptimeId, String arrivalTime) async {
    final url = Uri.parse('$baseUrl/stoptimes/$stoptimeId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'arrival_time': arrivalTime}),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar horário: $e');
      return false;
    }
  }

  static Future<bool> deleteStopTime(int stoptimeId) async {
    final url = Uri.parse('$baseUrl/stoptimes/$stoptimeId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao eliminar horário: $e');
      return false;
    }
  }

  static Future<bool> addFavorite(String stopId) async {
    final url = Uri.parse('$baseUrl/favorites');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'stop_id': stopId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao adicionar favorito: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getFavorites() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return [];
    
    final url = Uri.parse('$baseUrl/favorites');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter favoritos: $e');
    }
    return [];
  }

  static Future<bool> removeFavorite(String stopId) async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;
    
    final url = Uri.parse('$baseUrl/favorites/$stopId');
    try {
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao remover favorito: $e');
      return false;
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'is_admin');
  }

  static Future<Map<String, dynamic>?> getUserProfile() async {
    final url = Uri.parse('$baseUrl/users/me');
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return null;
      
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter perfil: $e');
    }
    return null;
  }

  static Future<bool> updateUserProfile(String? firstName, String? lastName, String? email, String? password, String? phoneNumber) async {
    final url = Uri.parse('$baseUrl/users/me');
    try {
      final token = await _storage.read(key: 'access_token');
      if (token == null) return false;
      
      final body = <String, dynamic>{};
      if (firstName != null && firstName.isNotEmpty) body['first_name'] = firstName;
      if (lastName != null && lastName.isNotEmpty) body['last_name'] = lastName;
      if (email != null && email.isNotEmpty) body['email'] = email;
      if (password != null && password.isNotEmpty) body['password'] = password;
      if (phoneNumber != null) body['phone_number'] = phoneNumber;
      
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar perfil: $e');
      return false;
    }
  }

  // --- ADMIN API ---
  static Future<List<dynamic>> getAdminUsers() async {
    final url = Uri.parse('$baseUrl/admin/users');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter utilizadores: $e');
    }
    return [];
  }

  static Future<bool> updateAdminUser(int userId, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/admin/users/$userId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar utilizador: $e');
      return false;
    }
  }

  static Future<bool> deleteAdminUser(int userId) async {
    final url = Uri.parse('$baseUrl/admin/users/$userId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao eliminar utilizador: $e');
      return false;
    }
  }

  static Future<bool> createRoute(Map<String, dynamic> routeData) async {
    final url = Uri.parse('$baseUrl/admin/routes');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(routeData),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao criar linha: $e');
      return false;
    }
  }

  static Future<bool> updateRoute(String routeId, Map<String, dynamic> routeData) async {
    final url = Uri.parse('$baseUrl/admin/routes/$routeId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(routeData),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar linha: $e');
      return false;
    }
  }

  static Future<bool> deleteRoute(String routeId) async {
    final url = Uri.parse('$baseUrl/admin/routes/$routeId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao apagar linha: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAdminStops() async {
    final url = Uri.parse('$baseUrl/admin/stops');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao listar paragens admin: $e');
    }
    return [];
  }

  static Future<bool> createStopAdmin(Map<String, dynamic> stopData) async {
    final url = Uri.parse('$baseUrl/admin/stops');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(stopData),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao criar paragem: $e');
      return false;
    }
  }

  static Future<bool> updateStopAdmin(String stopId, Map<String, dynamic> stopData) async {
    final url = Uri.parse('$baseUrl/admin/stops/$stopId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(stopData),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar paragem: $e');
      return false;
    }
  }

  static Future<bool> deleteStopAdmin(String stopId) async {
    final url = Uri.parse('$baseUrl/admin/stops/$stopId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao apagar paragem: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAdminSchedules() async {
    final url = Uri.parse('$baseUrl/admin/schedules');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao listar horários: $e');
    }
    return [];
  }

  static Future<bool> createSchedule(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/admin/schedules');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao criar horário: $e');
      return false;
    }
  }

  static Future<bool> deleteSchedule(String tripId) async {
    final url = Uri.parse('$baseUrl/admin/schedules/$tripId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao apagar horário: $e');
      return false;
    }
  }

  static Future<List<dynamic>> getAdminShapes() async {
    final url = Uri.parse('$baseUrl/admin/shapes');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao listar percursos: $e');
    }
    return [];
  }

  // --- ALERTS API ---
  static Future<List<dynamic>> getActiveAlerts() async {
    final url = Uri.parse('$baseUrl/alerts');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter alertas ativos: $e');
    }
    return [];
  }

  static Future<List<dynamic>> getAdminAlerts() async {
    final url = Uri.parse('$baseUrl/admin/alerts');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) print('Erro ao obter alertas admin: $e');
    }
    return [];
  }

  static Future<bool> createAdminAlert(Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/admin/alerts');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao criar alerta: $e');
      return false;
    }
  }

  static Future<bool> updateAdminAlert(int alertId, Map<String, dynamic> data) async {
    final url = Uri.parse('$baseUrl/admin/alerts/$alertId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao atualizar alerta: $e');
      return false;
    }
  }

  static Future<bool> deleteAdminAlert(int alertId) async {
    final url = Uri.parse('$baseUrl/admin/alerts/$alertId');
    try {
      final token = await _storage.read(key: 'access_token');
      final response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) print('Erro ao apagar alerta: $e');
      return false;
    }
  }
}


