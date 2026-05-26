import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/translation_service.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  bool _isLoading = true;
  List<dynamic> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _isLoading = true);
    final favs = await ApiService.getFavorites();
    if (mounted) {
      setState(() {
        _favorites = favs;
        _isLoading = false;
      });
    }
  }

  Future<void> _removeFavorite(String stopId) async {
    final success = await ApiService.removeFavorite(stopId);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('stop_removed')), backgroundColor: Colors.orange),
        );
      }
      _loadFavorites();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('stop_remove_error')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('my_stops'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF156A40),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF156A40)))
          : _favorites.isEmpty
              ? _buildEmptyState()
              : _buildFavoritesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            t('no_favorites'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            t('no_favorites_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final stop = _favorites[index];
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0054A6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.directions_bus, color: Color(0xFF0054A6)),
            ),
            title: Text(
              stop['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.favorite, color: Colors.redAccent),
              onPressed: () => _removeFavorite(stop['id']),
            ),
            onTap: () {
              // Devolver a paragem para o mapa e focar nela
              Navigator.of(context).pop(stop);
            },
          ),
        );
      },
    );
  }
}
