import 'package:flutter/material.dart';
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
      case 2: return const AdminUsersView();
      case 3: return const AdminAlertsView();
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
    final routes = await ApiService.getAdminRoutes();
    if (mounted) setState(() { _routes = routes; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    return Scaffold(
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : ListView.builder(
        itemCount: _routes.length,
        itemBuilder: (ctx, i) {
          final r = _routes[i];
          Color badgeColor = const Color(0xFF0054A6);
          try { if (r['color'] != null) badgeColor = Color(int.parse('0xFF${r['color'].toString().replaceAll('#','')}')); } catch(_) {}
          final bool isActive = r['is_active'] ?? true;
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? badgeColor : Colors.grey, 
              child: Text(r['short_name'], style: const TextStyle(color: Colors.white))
            ),
            title: Text(r['long_name'], style: TextStyle(
              decoration: isActive ? null : TextDecoration.lineThrough,
              color: isActive ? null : Colors.grey,
            )),
            subtitle: Text('ID: ${r['id']}'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Ativo', style: TextStyle(fontSize: 10)),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: isActive,
                    onChanged: (val) async {
                      final success = await ApiService.updateRoute(r['id'], {'is_active': val});
                      if (success) {
                        _loadData();
                      } else {
                        messenger.showSnackBar(const SnackBar(content: Text('Erro ao atualizar estado da linha.')));
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
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
                                    activeThumbColor: Colors.purple,
                                    onChanged: (val) => _updateUser(u['id'], {'is_admin': val}),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
    );
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
