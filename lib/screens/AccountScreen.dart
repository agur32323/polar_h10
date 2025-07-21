import 'package:flutter/material.dart';
import 'package:uyg/services/db_service.dart';
import 'package:uyg/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _aboutController = TextEditingController();

  User? currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? -1;

    if (userId == -1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final user = await DBService.getUserById(userId);
    if (user != null) {
      setState(() {
        currentUser = user;
        _nameController.text = user.name;
        _emailController.text = user.email;
        _passwordController.text = user.password;
        _aboutController.text = user.about;
      });
    }
  }

  Future<void> _updateUserData() async {
    if (currentUser == null) return;

    final updatedUser = User(
      id: currentUser!.id,
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
      about: _aboutController.text,
    );

    await DBService.updateUser(updatedUser);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Bilgiler güncellendi.")));
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userId');
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        title: const Text('Hesabım'),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text(
              "Oturumu kapat",
              style: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            currentUser == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                  children: [
                    const Text(
                      'Hesap e-posta adresiniz:',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _emailController.text,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    _buildEditableField('İsim', _nameController),
                    _buildEditableField('E-posta', _emailController),
                    _buildEditableField(
                      'Şifre',
                      _passwordController,
                      obscureText: true,
                    ),
                    _buildEditableField(
                      'Hakkımda',
                      _aboutController,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _updateUserData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                      ),
                      child: const Text("Güncelle"),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white54),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.blueAccent),
          ),
        ),
      ),
    );
  }
}
