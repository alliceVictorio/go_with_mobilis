import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  final _emailController = TextEditingController();
  
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService.getUserProfile();
    if (profile != null) {
      setState(() {
        _firstNameController.text = profile['first_name'] ?? '';
        _lastNameController.text = profile['last_name'] ?? '';
        _phoneController.text = profile['phone_number'] ?? '';
        _emailController.text = profile['email'] ?? '';
        _isLoading = false;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao carregar perfil.')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _saveChanges() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phoneText = _phoneController.text.trim();

    if (firstName.length < 2 || lastName.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, insira um nome e apelido válidos.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (email.isNotEmpty) {
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('E-mail inválido.'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    if (phoneText.isNotEmpty) {
      final regex = RegExp(r'^(9\d{8})$');
      if (!regex.hasMatch(phoneText)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Número de telemóvel inválido (ex: 912345678).'), backgroundColor: Colors.redAccent),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    
    final success = await ApiService.updateUserProfile(
      firstName,
      lastName,
      email,
      null, 
      phoneText.isNotEmpty ? phoneText : null,
    );
    
    setState(() { 
      _isSaving = false;
      if (success) {
        _isEditing = false;
      }
    });
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso! ✨'),
            backgroundColor: Color(0xFF156A40),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocorreu um erro ao atualizar o perfil.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showPasswordDialog() {
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Alterar Palavra-passe', style: TextStyle(color: Color(0xFF156A40))),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: newPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nova Palavra-passe'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPasswordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar Palavra-passe'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF156A40),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              if (newPasswordCtrl.text.isEmpty || newPasswordCtrl.text.length < 6) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('A palavra-passe deve ter pelo menos 6 caracteres.'), backgroundColor: Colors.redAccent)
                 );
                 return;
              }
              if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Palavras-passe não coincidem.'), backgroundColor: Colors.redAccent)
                 );
                 return;
              }
              Navigator.pop(ctx);
              
              setState(() => _isLoading = true);
              final success = await ApiService.updateUserProfile(null, null, null, newPasswordCtrl.text, null);
              setState(() => _isLoading = false);
              
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Palavra-passe alterada com sucesso!'), backgroundColor: Color(0xFF156A40))
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao atualizar a palavra-passe.'), backgroundColor: Colors.redAccent)
                  );
                }
              }
            },
            child: const Text('Submeter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF156A40))),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const BackButton(color: Color(0xFF156A40)),
        ),
        extendBodyBehindAppBar: true, 
        body: SingleChildScrollView(
          child: Stack(
            children: [
              // Gradiente Superior (Header) - Fica por detrás sem causar bugs no avatar
              Container(
                height: 160,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFDCEDC8),
                      Color(0xFFF1F8E9),
                    ],
                  ),
                ),
              ),
              
              // Conteúdo Inferior
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Colocamos um preenchimento na altura exata para que a foto "corte a linha" do banner em segurança
                    const SizedBox(height: 90), 
                    
                    // --- Secção do Avatar ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: const CircleAvatar(
                            radius: 35,
                            backgroundColor: Color(0xFF156A40),
                            child: Icon(Icons.person, size: 40, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_firstNameController.text} ${_lastNameController.text}',
                                style: const TextStyle(
                                  fontSize: 20, 
                                  fontWeight: FontWeight.bold, 
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _emailController.text,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 40),

                    // --- Secção do Formulário (Grid de 2 Colunas) ---
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Nome',
                            controller: _firstNameController,
                            enabled: _isEditing,
                            hint: 'O seu nome',
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildField(
                            label: 'Apelido',
                            controller: _lastNameController,
                            enabled: _isEditing,
                            hint: 'O seu apelido',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Telemóvel (Opcional)',
                            controller: _phoneController,
                            enabled: _isEditing,
                            hint: 'Ex: 912345678',
                            inputType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 24),
                        Expanded(
                          child: _buildField(
                            label: 'Email',
                            controller: _emailController,
                            enabled: _isEditing, 
                            hint: 'O seu e-mail real',
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 60),

                    // --- Botões Centrais ---
                    Center(
                      child: Column(
                        children: [
                          SizedBox(
                            width: 230,
                            height: 36,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : () {
                                if (_isEditing) {
                                  _saveChanges();
                                } else {
                                  setState(() {
                                    _isEditing = true;
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF156A40),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSaving 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : Text(
                                      _isEditing ? 'Guardar' : 'Editar',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 230,
                            height: 36,
                            child: OutlinedButton(
                              onPressed: _isEditing || _isSaving ? null : _showPasswordDialog,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF156A40),
                                side: const BorderSide(color: Color(0xFF156A40), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Alterar palavra-passe', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            ),
                          ),
                          
                          // Secção Terminar Sessão
                          const SizedBox(height: 32),
                          const Divider(thickness: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: 200,
                            height: 44,
                            child: TextButton.icon(
                              onPressed: () async {
                                await ApiService.logout();
                                if (context.mounted) {
                                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                                }
                              },
                              icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                              label: const Text(
                                'Terminar Sessão',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label, 
    required TextEditingController controller, 
    required bool enabled, 
    required String hint,
    TextInputType inputType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: inputType,
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: enabled ? const Color(0xFFCBD5E1) : Colors.transparent),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.transparent),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF156A40), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
