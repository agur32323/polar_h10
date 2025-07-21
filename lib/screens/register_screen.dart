import 'package:flutter/material.dart';
import 'package:uyg/services/db_service.dart';
import 'package:uyg/models/user.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  String error = '';

  void _register() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      setState(() => error = 'E-posta, şifre ve isim boş olamaz');
      return;
    }

    final newUser = User(
      email: email,
      password: password,
      name: name,
      about: '',
    );

    final success = await DBService.register(newUser);
    if (success) {
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      setState(() => error = 'Bu e-posta zaten kayıtlı');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/login.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.6)),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.person_add,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Kayıt Ol",
                          style: TextStyle(color: Colors.white, fontSize: 24),
                        ),
                        const SizedBox(height: 32),
                        _buildInputField(
                          nameController,
                          "İsim",
                          Icons.person,
                        ), // 👈 İsim input
                        const SizedBox(height: 16),
                        _buildInputField(
                          emailController,
                          "E-posta",
                          Icons.email,
                        ),
                        const SizedBox(height: 16),
                        _buildInputField(
                          passwordController,
                          "Şifre",
                          Icons.lock,
                          obscure: true,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                          ),
                          child: const Text(
                            "Kayıt Ol",
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              error,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white24,
        prefixIcon: Icon(icon, color: Colors.white),
        hintText: label,
        hintStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
