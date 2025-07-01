import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:sow_and_grow/Auth/Service/Auth_Service.dart';
import 'package:sow_and_grow/Auth/UI/loginPage.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _selectedItem = 'farmer'; // Default value
  bool _obscurePassword = true; // For password visibility toggle

  Future<void> _handleSignup() async {
    if (!_validateFields()) return;

    setState(() => _isLoading = true);

    try {
      print(
        'Sending signup data - Location: ${_location.text}',
      ); // Add debug log
      final result = await _authService.signup(
        username: _email.text.split('@')[0], // Generate username from email
        password: _password.text,
        email: _email.text,
        phone: _phoneNumber.text,
        name: _firstName.text, // Just use firstName instead of combining
        userType: _selectedItem ?? 'farmer',
        location: _location.text.trim(),
      );

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration successful'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Navigate to login page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LoginPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateFields() {
    bool isValid = true;

    // Email validation
    if (!emailRegExp.hasMatch(_email.text)) {
      setState(() {
        _emailError = 'Invalid Email';
      });
      isValid = false;
    } else {
      setState(() {
        _emailError = null;
      });
    }

    // Password validation
    if (_password.text.length < 6) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters';
      });
      isValid = false;
    } else {
      setState(() {
        _passwordError = null;
      });
    }

    // Required fields validation
    if (_firstName.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'First Name is required',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      isValid = false;
    }

    if (_phoneNumber.text.isEmpty) {
      Fluttertoast.showToast(
        msg: 'Phone Number is required',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      isValid = false;
    }

    if (_location.text.isEmpty) {
      print(_location.text);
      Fluttertoast.showToast(
        msg: 'Location is required',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      isValid = false;
    }

    if (_selectedItem == 'Select') {
      Fluttertoast.showToast(
        msg: 'Please select your work type',
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      isValid = false;
    }

    return isValid;
  }

  RegExp emailRegExp = RegExp(
    r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$",
  );

  TextEditingController _email = TextEditingController();
  TextEditingController _password = TextEditingController();
  TextEditingController _firstName = TextEditingController();

  TextEditingController _phoneNumber = TextEditingController();
  TextEditingController _location = TextEditingController(); // Add this line

  String? _emailError;
  String? _passwordError;
  bool _textAnimation = false;

  List<String> _doList = [
    'farmer',
    'doctor',
  ]; // Changed from 'Former' to 'farmer'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.green.shade800,
              Colors.green.shade600,
              Colors.green.shade400,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildAnimatedLogo(),
                  SizedBox(height: 20),
                  _buildRegistrationForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return Container(
      margin: EdgeInsets.only(top: 20),
      child: Column(
        children: [
          Icon(Icons.eco_rounded, size: 60, color: Colors.white),
          SizedBox(height: 10),
          _textAnimation
              ? Text(
                  "SOW&GROW",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black45,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                )
              : DefaultTextStyle(
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black45,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: AnimatedTextKit(
                    animatedTexts: [
                      TyperAnimatedText(
                        "SOW&GROW",
                        speed: Duration(milliseconds: 200),
                      ),
                    ],
                    totalRepeatCount: 1,
                    isRepeatingAnimation: false,
                    onFinished: () {
                      setState(() {
                        _textAnimation = true;
                      });
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
          children: [
            Text(
              'Create Account',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Join our farming community',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 25),

            // Name field
            _buildTextField(
              controller: _firstName,
              label: 'Name',
              icon: Icons.person_outline,
            ),
            SizedBox(height: 15),

            // Email field
            _buildTextField(
              controller: _email,
              label: 'Email',
              icon: Icons.email_outlined,
              errorText: _emailError,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 15),

            // Phone field
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: IntlPhoneField(
                  controller: _phoneNumber,
                  initialCountryCode: "IN",
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 15,
                    ),
                    floatingLabelBehavior: FloatingLabelBehavior.never,
                  ),
                  dropdownIconPosition: IconPosition.trailing,
                  flagsButtonPadding: EdgeInsets.symmetric(horizontal: 15),
                  showDropdownIcon: false,
                ),
              ),
            ),
            SizedBox(height: 15),

            // Location field
            _buildTextField(
              controller: _location,
              label: 'City/Village',
              icon: Icons.location_on_outlined,
              keyboardType: TextInputType.streetAddress,
            ),
            SizedBox(height: 15),

            // Password field
            _buildTextField(
              controller: _password,
              label: 'Password',
              icon: Icons.lock_outline,
              errorText: _passwordError,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            SizedBox(height: 20),

            // Work type selection
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Colors.grey.shade50,
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              child: Row(
                children: [
                  Icon(Icons.work_outline, color: Colors.grey),
                  SizedBox(width: 10),
                  Text(
                    'I am a:',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                  ),
                  Spacer(),
                  DropdownButton<String>(
                    value: _selectedItem,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: Colors.green.shade800,
                    ),
                    underline: SizedBox(),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _doList.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          value.substring(0, 1).toUpperCase() +
                              value.substring(1),
                          style: TextStyle(color: Colors.green.shade800),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedItem = newValue;
                      });
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 25),

            // Register button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade800,
                  foregroundColor: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : Text(
                        "REGISTER",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 15),

            // Login link
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Already have an account? ",
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text(
                    "Login",
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? errorText,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey.shade50,
        border: Border.all(
          color: errorText != null ? Colors.red : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          errorText: errorText,
          prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          floatingLabelBehavior: FloatingLabelBehavior.never,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String text,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 24, width: 24),
            SizedBox(width: 12),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
