import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  XFile? _profileImage;
  Uint8List? _profileImageBytes;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,  // Reduz a largura máxima
        maxHeight: 512, // Reduz a altura máxima
        imageQuality: 70, // Comprime a qualidade para 70%
      );
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _profileImage = pickedFile;
          _profileImageBytes = bytes;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao selecionar imagem: $e';
      });
    }
  }

  bool _validatePassword(String password) {
    // 7 caracteres mínimo, pelo menos uma letra e um número
    final regex = RegExp(r'^(?=.*[a-zA-Z])(?=.*\d).{7,}$');
    return regex.hasMatch(password);
  }

  bool _validatePhone(String phone) {
    if (phone.isEmpty) return true; // opcional
    // Aceita 9 dígitos obrigatórios se não for vazio (formato PT telemóvel padrão)
    final regex = RegExp(r'^(9\d{8})$');
    return regex.hasMatch(phone);
  }

  Future<void> _doRegister() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Por favor, preencha todos os campos obrigatórios.';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'As palavras-passe não coincidem.';
      });
      return;
    }

    if (!_validatePassword(password)) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'A palavra-passe deve ter pelo menos 7 caracteres, incluindo letras e números.';
      });
      return;
    }

    if (!_validatePhone(_phoneController.text.trim())) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Número de telemóvel inválido. Insira 9 dígitos (ex: 912345678).';
      });
      return;
    }

    String? profilePictureBase64;
    if (_profileImageBytes != null) {
      profilePictureBase64 = base64Encode(_profileImageBytes!);
    }

    try {

    // Agora enviamos todos os dados, incluindo nome, apelido, telefone e fotografia
    final result = await ApiService.register(
      firstName, 
      lastName, 
      email, 
      password, 
      _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(), 
      profilePictureBase64
    );
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = false;
    });

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso! Podes iniciar sessão.', style: TextStyle(color: Colors.white)), backgroundColor: Color(0xFF156A40))
      );
      Navigator.of(context).pop(); // Volta ao login
    } else {
      setState(() {
        _errorMessage = result['message'];
      });
    }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erro interno ao processar registo: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.white,
                    child: _buildForm(context),
                  ),
                ),
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
          } else {
            return _buildForm(context);
          }
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
            constraints: const BoxConstraints(maxWidth: 380), 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Transform.scale(
                  scale: 0.9, 
                  child: Image.asset(
                    'img/logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 32), 
                
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                
                // --- Avatar Upload ---
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage: _profileImageBytes != null
                              ? MemoryImage(_profileImageBytes!)
                              : null,
                          child: _profileImageBytes == null
                              ? const Icon(
                                  Icons.person_add_alt_1_rounded,
                                  size: 30,
                                  color: Color(0xFF94A3B8),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B9F3F),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // --- Nome e Apelido ---
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nome',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _firstNameController,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Ex: João',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Apelido',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          SizedBox(
                            height: 32,
                            child: TextField(
                              controller: _lastNameController,
                              style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Ex: Silva',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // --- E-mail ---
                const Text(
                  'Endereço de e-mail',
                  style: TextStyle(
                    color: Color(0xFF334155), 
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _emailController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ex: utilizador@email.com',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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

                // --- Telemóvel (Opcional) ---
                const Text(
                  'Telemóvel (Opcional)',
                  style: TextStyle(
                    color: Color(0xFF334155), 
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _phoneController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Ex: 912345678',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
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
                    keyboardType: TextInputType.phone,
                  ),
                ),
                const SizedBox(height: 12),
                
                // --- Palavra-passe ---
                const Text(
                  'Palavra-passe',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _passwordController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Introduza a sua password',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
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
                const Padding(
                  padding: EdgeInsets.only(top: 4.0, bottom: 12.0),
                  child: Text(
                    'Pelo menos 7 caracteres, combinando letras e números.',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ),

                // --- Confirmar Palavra-passe ---
                const Text(
                  'Confirmar palavra-passe',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  height: 32,
                  child: TextField(
                    controller: _confirmPasswordController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12),
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: 'Repita a password',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: const Color(0xFF94A3B8),
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
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
                const SizedBox(height: 20),
                
                SizedBox(
                  height: 34, 
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _doRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF156A40), 
                      foregroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
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
                            'Registar conta',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Já tem uma conta? ',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'Iniciar sessão',
                        style: TextStyle(
                          color: Color(0xFF3B9F3F),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
