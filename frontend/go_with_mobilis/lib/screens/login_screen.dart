import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  Future<void> _doLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Por favor, preencha todos os campos.';
      });
      return;
    }

    final result = await ApiService.login(email, password);
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      if (result['is_admin'] == true) {
        Navigator.of(context).pushReplacementNamed('/admin');
      } else {
        Navigator.of(context).pushReplacementNamed('/map');
      }
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 800;
          return Row(
            children: [
              Expanded(
                flex: 1,
                child: _buildForm(context),
              ),
              if (isDesktop)
                Expanded(
                  flex: 1,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                    child: Image.asset(
                      'img/inicio.png',
                      fit: BoxFit.cover,
                      height: double.infinity,
                      width: double.infinity,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Transform.scale(
                  scale: 0.9, // Diminui o logo
                  child: Image.asset(
                    'img/logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32), // Removido o fosso! Espaçamento curto agora.
                                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0), // Estreita todo o formulário mantendo o logótipo largo!
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent),
                          ),
                        ),
                        
                      const Text(
                        'Endereço de e-mail',
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black87, fontSize: 12),
                          decoration: InputDecoration(
                            hintText: 'Ex: utilizador@email.com',
                            hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF0054A6), width: 1.5),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Palavra-passe',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {},
                            child: const Text(
                              'Esqueceu-se da palavra-passe?',
                              style: TextStyle(
                                color: Color(0xFF3B9F3F), // Verde
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _passwordController,
                          style: const TextStyle(color: Colors.black87, fontSize: 12),
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Introduza a sua password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: const Color(0xFF94A3B8),
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            hintStyle: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: Color(0xFF0054A6), width: 1.5),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20), // Espaçamento diminuto antes do botão de Login
                      
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _doLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF156A40),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 24), // Salto apertado para os links finais
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Não tem uma conta? ',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushNamed('/register');
                            },
                            child: const Text(
                              'Registe-se',
                              style: TextStyle(
                                color: Color(0xFF3B9F3F),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 34,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacementNamed('/map');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3B9F3F),
                            side: const BorderSide(color: Color(0xFF3B9F3F), width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: const Text(
                            'Continuar como convidado',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
