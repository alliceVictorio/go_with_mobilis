import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/admin_panel_screen.dart';
import 'screens/passenger_map_screen.dart';

// Variável Global Simples para Alterar o Tema em Tempo Real
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Verifica se o utilizador já validou sessão anteriormente
  const storage = FlutterSecureStorage();
  final token = await storage.read(key: 'access_token');
  final isAdminStr = await storage.read(key: 'is_admin');
  final isAdmin = isAdminStr == 'true';

  String initialRoute = '/login';
  if (token != null) {
    if (isAdmin) {
      initialRoute = '/admin';
    } else {
      initialRoute = '/map';
    }
  }

  runApp(MyApp(initialRoute: initialRoute));
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Go with Mobilis',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode, // Define se é light ou dark
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            fontFamily: 'Roboto',
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0054A6), 
              secondary: Color(0xFF8CC63F),
              surface: Colors.white,
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0054A6),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            fontFamily: 'Roboto',
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF8CC63F),
              secondary: Color(0xFF0054A6),
              surface: Color(0xFF1E293B),
              onPrimary: Colors.white,
              onSurface: Color(0xFFF8FAFC),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              centerTitle: true,
            ),
          ),
          initialRoute: initialRoute,
          routes: {
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/admin': (context) => const AdminPanelScreen(),
            '/map': (context) => const PassengerMapScreen(),
          },
        );
      }
    );
  }
}
