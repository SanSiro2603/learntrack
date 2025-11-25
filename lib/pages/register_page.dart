import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Password tidak cocok')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1) Buat akun di Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final uid = userCredential.user?.uid;
      if (uid == null) throw Exception('UID user is null');

      // 2) Simpan data tambahan ke Firestore (pastikan rules mengizinkan write untuk auth users)
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'username': username,
        'email': email,
        'created_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Registrasi berhasil!')));

      // 3) Navigasi ke halaman login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      // tampilkan pesan yang ramah, juga cetak kode error di console untuk debug
      print('FirebaseAuthException code: ${e.code}');
      print('FirebaseAuthException message: ${e.message}');
      String msg = 'Terjadi kesalahan';
      if (e.code == 'email-already-in-use') {
        msg = 'Email sudah terdaftar. Silakan login atau gunakan email lain.';
      } else if (e.code == 'invalid-email') {
        msg = 'Email tidak valid.';
      } else if (e.code == 'weak-password') {
        msg = 'Password terlalu lemah (minimal 6 karakter).';
      } else {
        msg = e.message ?? msg;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e, st) {
      // error non-Firebase, tampilkan di console
      print('General exception: $e');
      print(st);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.isEmpty) return 'Email tidak boleh kosong';
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(v)) return 'Format email tidak valid';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password tidak boleh kosong';
    if (v.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  String? _validateUsername(String? v) {
    if (v == null || v.isEmpty) return 'Username tidak boleh kosong';
    if (v.length < 3) return 'Username minimal 3 karakter';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Lottie: pastikan file ada di assets & didaftarkan di pubspec.yaml
              Lottie.asset('assets/lottie/register.json', height: 180),

              const SizedBox(height: 20),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Sign up to get started!',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Enter your username',
                  border: OutlineInputBorder(),
                ),
                validator: _validateUsername,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Enter your email',
                  border: OutlineInputBorder(),
                ),
                validator: _validateEmail,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter your password',
                  border: OutlineInputBorder(),
                ),
                validator: _validatePassword,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Konfirmasi password tidak boleh kosong'
                    : null,
              ),

              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register', style: TextStyle(fontSize: 16)),
                ),
              ),

              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? '),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        color: Colors.deepPurpleAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
