import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _ownerNameController = TextEditingController();

  String _selectedProduct = 'cacao';
  bool _loading = false;

  final _products = [
    {'value': 'cacao', 'label': 'Cacao'},
    {'value': 'maiz', 'label': 'Maíz'},
    {'value': 'cafe', 'label': 'Café'},
    {'value': 'arroz', 'label': 'Arroz'},
    {'value': 'soya', 'label': 'Soya'},
    {'value': 'otro', 'label': 'Otro'},
  ];

  Future<void> _register() async {
    if (_businessNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        // Crear el negocio en la base de datos
        await Supabase.instance.client.from('businesses').insert({
          'user_id': response.user!.id,
          'business_name': _businessNameController.text.trim(),
          'owner_name': _ownerNameController.text.trim(),
          'product_type': _selectedProduct,
          'weight_unit': 'quintales',
          'discount_type': 'porcentaje',
          'current_price': 0.00,
          'is_active': false, // tú lo activas manualmente
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ Registro exitoso. Tu cuenta será activada en breve.',
              ),
              backgroundColor: Colors.green,
            ),
          );
          context.go('/login');
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B5E20),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              IconButton(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registra tu negocio',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Un solo registro, listo para siempre.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 32),

              _buildField(_businessNameController, 'Nombre del negocio *', Icons.store),
              const SizedBox(height: 16),
              _buildField(_ownerNameController, 'Tu nombre', Icons.person),
              const SizedBox(height: 16),
              _buildField(
                _emailController,
                'Correo electrónico *',
                Icons.email,
                type: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              _buildField(
                _passwordController,
                'Contraseña *',
                Icons.lock,
                obscure: true,
              ),
              const SizedBox(height: 16),

              // Selector de producto
              const Text(
                'Producto principal',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white38),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedProduct,
                    dropdownColor: const Color(0xFF2E7D32),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    isExpanded: true,
                    items: _products.map((p) {
                      return DropdownMenuItem(
                        value: p['value'],
                        child: Text(p['label']!),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setState(() => _selectedProduct = val!),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Crear mi cuenta',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.white70),
        labelStyle: const TextStyle(color: Colors.white70),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white38),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white),
        ),
        filled: true,
        fillColor: Colors.white12,
      ),
    );
  }
}