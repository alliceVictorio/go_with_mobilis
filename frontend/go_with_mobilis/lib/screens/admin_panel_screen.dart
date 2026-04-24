import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<dynamic> _routes = [];
  List<dynamic> _stopTimes = [];
  Map<String, dynamic>? _selectedRoute;
  bool _isLoadingRoutes = true;
  bool _isLoadingStopTimes = false;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    final routes = await ApiService.getRoutes();
    if (mounted) {
      setState(() {
        _routes = routes;
        _isLoadingRoutes = false;
      });
    }
  }

  Future<void> _fetchStopTimes(Map<String, dynamic> route) async {
    setState(() {
      _selectedRoute = route;
      _isLoadingStopTimes = true;
    });

    final times = await ApiService.getStopTimes(route['id']);
    
    if (mounted) {
      setState(() {
        // Ordenar os horários minimamente, caso venham desorganizados
        _stopTimes = times..sort((a, b) => a['stop_sequence'].compareTo(b['stop_sequence']));
        _isLoadingStopTimes = false;
      });
      Navigator.of(context).pop(); // Fechar Sidebar após clique
    }
  }

  void _showEditSheet(Map<String, dynamic> stopTime) {
    final timeController = TextEditingController(text: stopTime['arrival_time']);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Horário'),
        content: TextField(
          controller: timeController,
          decoration: const InputDecoration(
            labelText: 'Horário de Chegada',
            hintText: 'HH:MM:SS',
            prefixIcon: Icon(Icons.access_time),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0054A6), foregroundColor: Colors.white),
            child: const Text('Guardar'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ApiService.updateStopTime(stopTime['id'], timeController.text.trim());
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atualizado com sucesso!')));
                if (_selectedRoute != null) _fetchStopTimes(_selectedRoute!);
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao atualizar!')));
              }
            },
          )
        ],
      ),
    );
  }

  void _triggerDelete(Map<String, dynamic> stopTime) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão', style: TextStyle(color: Colors.redAccent)),
        content: const Text('Tens a certeza que pretendes eliminar este horário? Esta operação é irreversível.'),
        actions: [
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final success = await ApiService.deleteStopTime(stopTime['id']);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removido!')));
                if (_selectedRoute != null) _fetchStopTimes(_selectedRoute!);
              } else {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Falha ao reverter!')));
              }
            },
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(_selectedRoute != null ? 'Linha ${_selectedRoute!['short_name']}' : 'Gestor Mobilis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          )
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Color(0xFF0054A6)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.directions_bus, size: 50, color: Colors.white),
                    SizedBox(height: 10),
                    Text('Frota Mobilis', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoadingRoutes 
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _routes.length,
                    itemBuilder: (context, index) {
                      final route = _routes[index];
                      // Transforma HEX (#FF0000) em Flutter Color, se presente
                      Color badgeColor = const Color(0xFF0054A6);
                      try {
                        if(route['color'] != null && route['color'].toString().isNotEmpty) {
                          String hex = route['color'].toString().replaceAll('#', '');
                          badgeColor = Color(int.parse('0xFF$hex'));
                        }
                      } catch(_) {}

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: badgeColor,
                          child: Text(route['short_name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(route['long_name'], style: const TextStyle(color: Color(0xFF334155))),
                        onTap: () => _fetchStopTimes(route),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
      body: _selectedRoute == null
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app, size: 80, color: Color(0xFFCBD5E1)),
                SizedBox(height: 20),
                Text('Abre o menu lateral e seleciona uma linha\npara visualizar os horários.', 
                  textAlign: TextAlign.center, 
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 18)
                ),
              ]
            )
          )
        : _isLoadingStopTimes
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _stopTimes.length,
              itemBuilder: (context, index) {
                final stopTime = _stopTimes[index];
                return Card(
                  elevation: 2,
                  color: Colors.white,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                      child: Text('# ${stopTime['stop_sequence']}', style: const TextStyle(color: Color(0xFF0054A6), fontWeight: FontWeight.bold)),
                    ),
                    title: Text('Chegada: ${stopTime['arrival_time']}', style: const TextStyle(color: Color(0xFF1E293B), fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Text('Trip ID: ${stopTime['trip_id']}', style: const TextStyle(color: Color(0xFF64748B))),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF0054A6)),
                          onPressed: () => _showEditSheet(stopTime),
                          tooltip: 'Editar Horário',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _triggerDelete(stopTime),
                          tooltip: 'Remover Paragem',
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
