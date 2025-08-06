// screens/auth_page.dart (new file)
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // To access supabase
import 'home_screen.dart';

class AuthPage extends StatefulWidget {
  final Isar isar;

  const AuthPage({super.key, required this.isar});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscureText = true;

  Future<void> _signUp() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await supabase.auth.signUp(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(isar: widget.isar)),
        );
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  Future<void> _signIn() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      await supabase.auth.signInWithPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(isar: widget.isar)),
        );
      }
    } on AuthException catch (e) {
      setState(() { _error = e.message; });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up / In'),
        centerTitle: true,
        titleSpacing: 0.0,
        toolbarHeight: 56.0,
        elevation: 4.0,
        ),
      body: Center(
        child: SingleChildScrollView(  // Adds scrollability for keyboard on small screens
          child: Padding(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Tagwerk',
                  style: TextStyle(
                    fontSize: 48.0,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[900],
                  )
                ),
                const SizedBox(height: 32.0),
                Container(
                  width: 300,
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 16.0),
                Container(
                  width: 300,
                  child: TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.grey.shade400),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.0),
                        borderSide: BorderSide(color: Colors.blue, width: 2.0),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    obscureText: _obscureText,
                  ),
                ),
                if (_error != null) Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Container(
                    width: 300,
                    alignment: Alignment.center,
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                ),
                const SizedBox(height: 24.0),
                Container(
                  width: 300,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,  // Makes buttons full width within the container
                          children: [
                            ElevatedButton(onPressed: _signUp, child: const Text('Sign Up')),
                            const SizedBox(height: 10.0),
                            ElevatedButton(onPressed: _signIn, child: const Text('Sign In')),
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

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}