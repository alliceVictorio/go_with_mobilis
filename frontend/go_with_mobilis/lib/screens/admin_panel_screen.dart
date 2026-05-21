import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Gestor Mobilis (Admin)', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
            tooltip: 'Terminar sessão',
          )
        ],
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() { _selectedIndex = index; });
            },
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: Color(0xFF0054A6)),
            selectedLabelTextStyle: const TextStyle(color: Color(0xFF0054A6), fontWeight: FontWeight.bold),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard), label: Text('Visão Geral')),
              NavigationRailDestination(icon: Icon(Icons.route), label: Text('Linhas')),
              NavigationRailDestination(icon: Icon(Icons.location_on), label: Text('Paragens')),
              NavigationRailDestination(icon: Icon(Icons.schedule), label: Text('Horários')),
              NavigationRailDestination(icon: Icon(Icons.timeline), label: Text('Percursos')),
              NavigationRailDestination(icon: Icon(Icons.people), label: Text('Utilizadores')),
              NavigationRailDestination(icon: Icon(Icons.warning), label: Text('Alertas')),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return const AdminDashboardView();
      case 1: return const AdminRoutesView();
      case 2: return const AdminStopsView();
      case 3: return const AdminSchedulesView();
      case 4: return const AdminShapesView();
      case 5: return const AdminUsersView();
      case 6: return const AdminAlertsView();
      default: return const Center(child: Text('Em breve...'));
    }
  }
}

// ==========================================
// VIEW: DASHBOARD
// ==========================================
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});
  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}
class _AdminDashboardViewState extends State<AdminDashboardView> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stats = await ApiService.getAdminStats();
    if (mounted) setState(() { _stats = stats; _isLoading = false; });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 16, color: Colors.blueGrey)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return const Center(child: Text('Erro ao carregar estatísticas.'));

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Visão Geral do Sistema', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0054A6))),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard('Utilizadores', _stats!['total_users'].toString(), Icons.people, Colors.blue),
                _buildStatCard('Paragens', _stats!['total_stops'].toString(), Icons.location_on, Colors.green),
                _buildStatCard('Linhas', _stats!['total_routes'].toString(), Icons.route, const Color(0xFF0054A6)),
                _buildStatCard('Alertas Ativos', _stats!['active_alerts'].toString(), Icons.warning, Colors.orange),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// VIEW: LINHAS (Routes)
// ==========================================
class AdminRoutesView extends StatefulWidget {
  const AdminRoutesView({super.key});
  @override
  State<AdminRoutesView> createState() => _AdminRoutesViewState();
}
class _AdminRoutesViewState extends State<AdminRoutesView> {
  List<dynamic> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final routes = await ApiService.getRoutes(); // from public or admin
    if (mounted) setState(() { _routes = routes; _isLoading = false; });
  }

  void _showForm([Map<String, dynamic>? route]) {
    final idController = TextEditingController(text: route?['id'] ?? '');
    final shortNameController = TextEditingController(text: route?['short_name'] ?? '');
    final longNameController = TextEditingController(text: route?['long_name'] ?? '');
    final colorController = TextEditingController(text: route?['color'] ?? '');
    final isEdit = route != null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Editar Linha' : 'Nova Linha'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: idController, decoration: const InputDecoration(labelText: 'ID (ex: R1)'), enabled: !isEdit),
              TextField(controller: shortNameController, decoration: const InputDecoration(labelText: 'Nome Curto (ex: 1)')),
              TextField(controller: longNameController, decoration: const InputDecoration(labelText: 'Nome Longo (ex: Estação - Hospital)')),
              TextField(controller: colorController, decoration: const InputDecoration(labelText: 'Cor HEX (ex: 0054A6)')),
            ],
          ),
        ),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () async {
              if (idController.text.isEmpty) return;
              Navigator.of(ctx).pop();
              final data = {
                'id': idController.text, 'short_name': shortNameController.text,
                'long_name': longNameController.text, 'color': colorController.text
              };
              final success = isEdit 
                ? await ApiService.updateRoute(route['id'], data) 
                : await ApiService.createRoute(data);
                
              if (success) _loadData();
              else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao guardar linha.')));
            },
          )
        ],
      )
    );
  }

  void _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Linha?'),
        content: const Text('Atenção: Se existirem horários associados, a operação será cancelada pelo servidor.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      )
    );
    if (confirm == true) {
      final success = await ApiService.deleteRoute(id);
      if (success) _loadData();
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao eliminar. Verifica se tem horários associados.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _routes.length,
        itemBuilder: (ctx, i) {
          final r = _routes[i];
          Color badgeColor = const Color(0xFF0054A6);
          try { if (r['color'] != null) badgeColor = Color(int.parse('0xFF${r['color'].toString().replaceAll('#','')}')); } catch(_) {}
          
          return ListTile(
            leading: CircleAvatar(backgroundColor: badgeColor, child: Text(r['short_name'], style: const TextStyle(color: Colors.white))),
            title: Text(r['long_name']),
            subtitle: Text('ID: ${r['id']}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(r)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(r['id'])),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(),
      ),
    );
  }
}

// ==========================================
// VIEW: PARAGENS (Stops)
// ==========================================
class AdminStopsView extends StatefulWidget {
  const AdminStopsView({super.key});
  @override
  State<AdminStopsView> createState() => _AdminStopsViewState();
}
class _AdminStopsViewState extends State<AdminStopsView> {
  List<dynamic> _stops = [];
  List<dynamic> _filteredStops = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final stops = await ApiService.getAdminStops();
    if (mounted) {
      setState(() { 
        _stops = stops; 
        _filterStops(_searchQuery);
        _isLoading = false; 
      });
    }
  }

  void _filterStops(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredStops = List.from(_stops);
      } else {
        _filteredStops = _stops.where((stop) {
          final name = stop['name'].toString().toLowerCase();
          final id = stop['id'].toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || id.contains(q);
        }).toList();
      }
    });
  }

  void _showForm([Map<String, dynamic>? stop, LatLng? initialPoint]) {
    final nameController = TextEditingController(text: stop?['name'] ?? '');
    final latController = TextEditingController(text: stop?['lat']?.toString() ?? initialPoint?.latitude.toString() ?? '');
    final lonController = TextEditingController(text: stop?['lon']?.toString() ?? initialPoint?.longitude.toString() ?? '');
    bool isActive = stop?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) => AlertDialog(
            title: Text(stop == null ? 'Nova Paragem' : 'Editar Paragem'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome da Paragem')),
                  TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude (ex: 39.7436)'), keyboardType: TextInputType.number),
                  TextField(controller: lonController, decoration: const InputDecoration(labelText: 'Longitude (ex: -8.8071)'), keyboardType: TextInputType.number),
                  SwitchListTile(
                    title: const Text('Estado Ativo'),
                    value: isActive,
                    onChanged: (v) => setStateSB(() => isActive = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop()),
              ElevatedButton(
                child: const Text('Guardar'),
                onPressed: () async {
                  if (nameController.text.isEmpty || latController.text.isEmpty || lonController.text.isEmpty) return;
                  Navigator.of(ctx).pop();
                  final data = {
                    'name': nameController.text, 'lat': double.parse(latController.text),
                    'lon': double.parse(lonController.text), 'is_active': isActive
                  };
                  final success = stop != null 
                    ? await ApiService.updateStopAdmin(stop['id'], data) 
                    : await ApiService.createStopAdmin(data);
                  if (success) _loadData();
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao guardar paragem.')));
                },
              )
            ],
          )
        );
      }
    );
  }

  void _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Paragem?'),
        content: const Text('Tem a certeza? Se a paragem estiver num horário, falhará. Recomenda-se apenas desativar.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      )
    );
    if (confirm == true) {
      final success = await ApiService.deleteStopAdmin(id);
      if (success) _loadData();
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha. Recomendado inativar a paragem no botão editar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Row(
            children: [
              // Lista de Paragens (Esquerda)
              SizedBox(
                width: 350,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Pesquisar paragem (nome ou ID)',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        ),
                        onChanged: _filterStops,
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredStops.length,
                        itemBuilder: (ctx, i) {
                          final s = _filteredStops[i];
                          final isActive = s['is_active'] ?? true;
                          return ListTile(
                            leading: Icon(Icons.location_on, color: isActive ? Colors.green : Colors.grey),
                            title: Text(s['name'], style: TextStyle(decoration: isActive ? null : TextDecoration.lineThrough)),
                            subtitle: Text('ID: ${s['id']} | Lat: ${s['lat'].toStringAsFixed(4)}, Lon: ${s['lon'].toStringAsFixed(4)}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(s)),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(s['id'].toString())),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              // Mapa Interativo (Direita)
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: const LatLng(39.7436, -8.8071), // Leiria
                        initialZoom: 13.0,
                        onTap: (tapPosition, point) {
                          _showForm(null, point);
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.mobilis.app.admin',
                        ),
                        MarkerLayer(
                          markers: _stops.map((s) {
                            final isActive = s['is_active'] ?? true;
                            return Marker(
                              point: LatLng(s['lat'], s['lon']),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showForm(s),
                                child: Icon(
                                  Icons.location_on,
                                  color: isActive ? Colors.green : Colors.grey,
                                  size: 40,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Text('Dica: Clica no mapa para criar uma paragem!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0054A6))),
                      ),
                    )
                  ],
                ),
              ),
            ],
          ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(),
      ),
    );
  }
}

// ==========================================
// VIEW: HORÁRIOS (Schedules)
// ==========================================
class AdminSchedulesView extends StatefulWidget {
  const AdminSchedulesView({super.key});
  @override
  State<AdminSchedulesView> createState() => _AdminSchedulesViewState();
}
class _AdminSchedulesViewState extends State<AdminSchedulesView> {
  List<dynamic> _schedules = [];
  List<dynamic> _routes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    _routes = await ApiService.getRoutes();
    final scheds = await ApiService.getAdminSchedules();
    if (mounted) setState(() { _schedules = scheds; _isLoading = false; });
  }

  void _showForm() {
    String? selectedRouteId = _routes.isNotEmpty ? _routes.first['id'] : null;
    final depController = TextEditingController();
    final arrController = TextEditingController();
    List<bool> days = List.generate(7, (i) => i < 5); // Seg-Sex ativos por default

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) => AlertDialog(
            title: const Text('Novo Horário (Trip)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedRouteId,
                    items: _routes.map((r) => DropdownMenuItem<String>(value: r['id'], child: Text('${r['short_name']} - ${r['long_name']}', overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) => setStateSB(() => selectedRouteId = v),
                    decoration: const InputDecoration(labelText: 'Linha Associada'),
                    isExpanded: true,
                  ),
                  TextField(controller: depController, decoration: const InputDecoration(labelText: 'Hora Partida (HH:MM:SS)')),
                  TextField(controller: arrController, decoration: const InputDecoration(labelText: 'Hora Chegada (HH:MM:SS) (Opcional)')),
                  const SizedBox(height: 16),
                  const Text('Dias de Funcionamento', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'].asMap().entries.map((e) {
                      return FilterChip(
                        label: Text(e.value),
                        selected: days[e.key],
                        onSelected: (val) => setStateSB(() => days[e.key] = val),
                      );
                    }).toList(),
                  )
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop()),
              ElevatedButton(
                child: const Text('Criar'),
                onPressed: () async {
                  if (selectedRouteId == null || depController.text.isEmpty) return;
                  Navigator.of(ctx).pop();
                  final data = {
                    'route_id': selectedRouteId,
                    'departure_time': depController.text,
                    'arrival_time': arrController.text.isEmpty ? null : arrController.text,
                    'active_days': days.map((e) => e ? 1 : 0).toList()
                  };
                  final success = await ApiService.createSchedule(data);
                  if (success) _loadData();
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao criar.')));
                },
              )
            ],
          )
        );
      }
    );
  }

  void _delete(String tripId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Horário?'),
        content: const Text('Isto apagará a Trip, os StopTimes e o Calendar associado. Tem a certeza?'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      )
    );
    if (confirm == true) {
      final success = await ApiService.deleteSchedule(tripId);
      if (success) _loadData();
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao eliminar.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (ctx, i) {
          final s = _schedules[i];
          final days = s['active_days'] as List<dynamic>;
          int activeCount = days.where((d) => d == 1).length;
          String dayStr = activeCount == 7 ? 'Todos os dias' : (activeCount == 5 && days[5]==0 ? 'Dias úteis' : '$activeCount dias/semana');
          
          return ListTile(
            leading: const Icon(Icons.schedule, color: Color(0xFF0054A6)),
            title: Text('Linha: ${s['route_id']} | Partida: ${s['departure_time']}'),
            subtitle: Text('Trip ID: ${s['trip_id']} | Funciona: $dayStr'),
            trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(s['trip_id'])),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(),
      ),
    );
  }
}

// ==========================================
// VIEW: PERCURSOS (Shapes)
// ==========================================
class AdminShapesView extends StatefulWidget {
  const AdminShapesView({super.key});
  @override
  State<AdminShapesView> createState() => _AdminShapesViewState();
}
class _AdminShapesViewState extends State<AdminShapesView> {
  List<dynamic> _shapes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final shapes = await ApiService.getAdminShapes();
    if (mounted) setState(() { _shapes = shapes; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _shapes.length,
        itemBuilder: (ctx, i) {
          final s = _shapes[i];
          return ListTile(
            leading: const Icon(Icons.timeline, color: Colors.purple),
            title: Text('Shape ID: ${s['shape_id']}'),
            subtitle: const Text('Coordenadas guardadas na base de dados (WKT LineString). A edição por mapa é complexa e requer portal web avançado.'),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A adição de novos shapes é feita importando ficheiros shapes.txt no servidor.')));
        },
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}

// ==========================================
// VIEW: UTILIZADORES (Users)
// ==========================================
class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});
  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}
class _AdminUsersViewState extends State<AdminUsersView> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await ApiService.getAdminUsers();
    if (mounted) {
      setState(() { 
        _users = users; 
        _filterUsers(_searchQuery);
        _isLoading = false; 
      });
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredUsers = List.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final first = user['first_name'].toString().toLowerCase();
          final last = user['last_name'].toString().toLowerCase();
          final email = user['email'].toString().toLowerCase();
          final q = query.toLowerCase();
          return first.contains(q) || last.contains(q) || email.contains(q);
        }).toList();
      }
    });
  }

  void _updateUser(int id, Map<String, dynamic> data) async {
    final success = await ApiService.updateAdminUser(id, data);
    if (success) {
      _loadData();
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao atualizar utilizador.')));
    }
  }

  void _showForm(Map<String, dynamic> user) {
    final firstNameController = TextEditingController(text: user['first_name']);
    final lastNameController = TextEditingController(text: user['last_name']);
    final emailController = TextEditingController(text: user['email']);
    final phoneController = TextEditingController(text: user['phone_number'] ?? '');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Utilizador'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: firstNameController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: lastNameController, decoration: const InputDecoration(labelText: 'Apelido')),
              TextField(controller: emailController, decoration: const InputDecoration(labelText: 'E-mail')),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Telemóvel (opcional)')),
              TextField(
                controller: passwordController, 
                decoration: const InputDecoration(labelText: 'Nova Password (deixa em branco para manter)'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop()),
          ElevatedButton(
            child: const Text('Guardar'),
            onPressed: () {
              Navigator.of(ctx).pop();
              final data = <String, dynamic>{};
              if (firstNameController.text != user['first_name']) data['first_name'] = firstNameController.text;
              if (lastNameController.text != user['last_name']) data['last_name'] = lastNameController.text;
              if (emailController.text != user['email']) data['email'] = emailController.text;
              if (phoneController.text.isNotEmpty && phoneController.text != user['phone_number']) data['phone_number'] = phoneController.text;
              if (passwordController.text.isNotEmpty) data['password'] = passwordController.text;
              
              if (data.isNotEmpty) {
                _updateUser(user['id'], data);
              }
            },
          )
        ],
      )
    );
  }

  void _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Utilizador?'),
        content: const Text('Tem a certeza? Esta ação apagará o utilizador e os seus favoritos de forma permanente.'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      )
    );
    if (confirm == true) {
      final success = await ApiService.deleteAdminUser(id);
      if (success) {
        _loadData();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao eliminar. (Não podes apagar a tua conta atual)')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Pesquisar utilizador (nome ou e-mail)',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: _filterUsers,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (ctx, i) {
                    final u = _filteredUsers[i];
          final bool isActive = u['is_active'] ?? true;
          final bool isAdmin = u['is_admin'] ?? false;
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isAdmin ? Colors.purple : Colors.blue,
                child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person, color: Colors.white),
              ),
              title: Text('${u['first_name']} ${u['last_name']}', style: TextStyle(decoration: isActive ? null : TextDecoration.lineThrough)),
              subtitle: Text('${u['email']}${u['phone_number'] != null ? '\n${u['phone_number']}' : ''}\nFavoritos: ${u['favorites_count'] ?? 0}'),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Ativo', style: TextStyle(fontSize: 10)),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: isActive,
                          onChanged: (val) => _updateUser(u['id'], {'is_active': val}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Admin', style: TextStyle(fontSize: 10)),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: isAdmin,
                          activeColor: Colors.purple,
                          onChanged: (val) => _updateUser(u['id'], {'is_admin': val}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showForm(u),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _delete(u['id']),
                  ),
                ],
              ),
            ),
          );
        },
      )),
    ]));
  }
}

// ==========================================
// VIEW: ALERTAS (Alerts)
// ==========================================
class AdminAlertsView extends StatefulWidget {
  const AdminAlertsView({super.key});
  @override
  State<AdminAlertsView> createState() => _AdminAlertsViewState();
}
class _AdminAlertsViewState extends State<AdminAlertsView> {
  List<dynamic> _alerts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final alerts = await ApiService.getAdminAlerts();
    if (mounted) setState(() { _alerts = alerts; _isLoading = false; });
  }

  void _showForm([Map<String, dynamic>? alert]) {
    final msgController = TextEditingController(text: alert?['message'] ?? '');
    bool isActive = alert?['is_active'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateSB) => AlertDialog(
            title: Text(alert == null ? 'Novo Alerta' : 'Editar Alerta'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: msgController, 
                    decoration: const InputDecoration(labelText: 'Mensagem do Alerta', hintText: 'Ex: Linha 1 com atraso'),
                    maxLines: 3,
                  ),
                  SwitchListTile(
                    title: const Text('Visível para os Passageiros'),
                    value: isActive,
                    onChanged: (v) => setStateSB(() => isActive = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop()),
              ElevatedButton(
                child: const Text('Guardar'),
                onPressed: () async {
                  if (msgController.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop();
                  final data = {
                    'message': msgController.text.trim(),
                    'is_active': isActive
                  };
                  final success = alert != null 
                    ? await ApiService.updateAdminAlert(alert['id'], data) 
                    : await ApiService.createAdminAlert(data);
                  if (success) _loadData();
                  else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao guardar alerta.')));
                },
              )
            ],
          )
        );
      }
    );
  }

  void _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Alerta?'),
        content: const Text('Tem a certeza que pretende eliminar permanentemente este alerta?'),
        actions: [
          TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(ctx).pop(false)),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Eliminar', style: TextStyle(color: Colors.white)), onPressed: () => Navigator.of(ctx).pop(true)),
        ],
      )
    );
    if (confirm == true) {
      final success = await ApiService.deleteAdminAlert(id);
      if (success) _loadData();
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao eliminar alerta.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _alerts.length,
        itemBuilder: (ctx, i) {
          final a = _alerts[i];
          final isActive = a['is_active'] ?? true;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(Icons.warning, color: isActive ? Colors.orange : Colors.grey, size: 36),
              title: Text(a['message'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isActive ? null : TextDecoration.lineThrough)),
              subtitle: Text('Criado a: ${a['created_at']}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Ativo', style: TextStyle(fontSize: 10)),
                      SizedBox(
                        height: 24,
                        child: Switch(
                          value: isActive,
                          onChanged: (val) async {
                            final success = await ApiService.updateAdminAlert(a['id'], {'is_active': val});
                            if (success) _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(a)),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _delete(a['id'])),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => _showForm(),
      ),
    );
  }
}
