import 'dart:async';
import 'dart:ui';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:sow_and_grow/Auth/Service/Auth_Service.dart';
import 'package:sow_and_grow/Auth/UI/signupPage.dart';
import 'package:sow_and_grow/Auth/UI/widgets/auth_text_field.dart';
import 'package:sow_and_grow/Auth/UI/widgets/auth_constants.dart';
import 'package:sow_and_grow/Auth/UI/widgets/snackbar_helper.dart';
import '../../Navigations/ContentPage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _passwordVisible = true;
  bool _isAnimationComplete = false;

  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    // Start animation immediately
    Timer(Duration(milliseconds: 500), () {
      setState(() {
        _isAnimationComplete = true;
      });
    });
  }

  Future<void> _handleLogin() async {
    if (!_validateFields()) return;

    setState(() => _isLoading = true);

    try {
      // Use the full email if provided, otherwise use as username
      final input = _emailController.text.trim();

      final result = await _authService.login(
        username: input,
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true && result['token'] != null) {
        SnackbarHelper.showSuccess(context, 'Login successful');

        // Add a small delay before navigation
        await Future.delayed(const Duration(milliseconds: 500));

        // Navigate to home page and clear navigation stack
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const UserContentPage()),
          (route) => false,
        );
      } else {
        String errorMessage = result['message'] ?? 'Login failed';
        if (errorMessage.contains('not found')) {
          errorMessage = 'User not found. Please check your email/username.';
        } else if (errorMessage.contains('password')) {
          errorMessage = 'Incorrect password. Please try again.';
        }

        SnackbarHelper.showError(context, errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      SnackbarHelper.showError(
        context,
        'Login failed: Network or server error',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _validateFields() {
    bool isValid = true;

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = 'Username/Email is required';
      });
      isValid = false;
    } else {
      setState(() {
        _emailError = null;
      });
    }

    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'Password is required';
      });
      isValid = false;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // Disable keyboard animation
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.green.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(children: [_buildHeader(), _buildLoginForm()]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.3,
      width: double.infinity,
      child: Stack(
        children: [
          // Background image with blur effect
          Positioned.fill(
            child: ClipRRect(
              child: Stack(
                children: [
                  // Farm image
                  Image.asset(
                    'images/Login/cow4.jpg',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                  // Blur overlay
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                    child: Container(color: Colors.black.withOpacity(0.2)),
                  ),
                ],
              ),
            ),
          ),
          // Logo and animated text
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.eco_rounded, size: 60, color: Colors.white),
                SizedBox(height: 10),
                _isAnimationComplete
                    ? Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.green.shade200,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                      )
                    : DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                          shadows: [
                            Shadow(
                              blurRadius: 10.0,
                              color: Colors.green.shade200,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TyperAnimatedText(
                              "Welcome Back",
                              speed: Duration(milliseconds: 150),
                            ),
                          ],
                          totalRepeatCount: 1,
                          isRepeatingAnimation: false,
                          onFinished: () {
                            setState(() {
                              _isAnimationComplete = true;
                            });
                          },
                        ),
                      ),
                SizedBox(height: 5),
                Text(
                  "Login to continue",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Login/Register tabs
            _buildLoginRegisterTabs(),
            SizedBox(height: 25),

            // Email/Username field
            AuthTextField(
              controller: _emailController,
              label: 'Email or Username',
              icon: Icons.person_outline,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 20),

            // Password field
            AuthTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline,
              errorText: _passwordError,
              obscureText: _passwordVisible,
              suffixIcon: IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _passwordVisible = !_passwordVisible;
                  });
                },
              ),
            ),
            SizedBox(height: 30),
            // Login button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: AuthConstants.primaryButtonStyle,
                child: _isLoading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRegisterTabs() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          // Login tab (active)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  "Login",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green.shade600,
                  ),
                ),
              ),
            ),
          ),
          // Register tab
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RegisterPage()),
                );
              },
              child: Center(
                child: Text(
                  "Register",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
