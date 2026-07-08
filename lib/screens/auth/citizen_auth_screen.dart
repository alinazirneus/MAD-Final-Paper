import 'package:flutter/material.dart';
import '../../database/db_helper.dart';
import '../../models/citizen_model.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/app_colors.dart';
import '../citizen/citizen_dashboard.dart';

class CitizenAuthScreen extends StatefulWidget {
  const CitizenAuthScreen({super.key});

  @override
  State<CitizenAuthScreen> createState() => _CitizenAuthScreenState();
}

class _CitizenAuthScreenState extends State<CitizenAuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login Form Controllers
  final _loginFormKey = GlobalKey<FormState>();
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  bool _isLoginLoading = false;

  // Sign Up Form Controllers
  final _signUpFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _contactController = TextEditingController();
  final _addressController = TextEditingController();
  final _signUpUsernameController = TextEditingController();
  final _signUpPasswordController = TextEditingController();
  bool _obscureSignUpPassword = true;
  bool _isSignUpLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _nameController.dispose();
    _contactController.dispose();
    _addressController.dispose();
    _signUpUsernameController.dispose();
    _signUpPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoginLoading = true;
    });

    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text.trim();

    try {
      final dbHelper = DBHelper();
      final citizen = await dbHelper.loginCitizen(username, password);

      setState(() {
        _isLoginLoading = false;
      });

      if (citizen != null) {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Welcome Back',
            message: 'Hello, ${citizen.name}! You have successfully logged in.',
            type: CustomDialogType.success,
            onConfirm: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => CitizenDashboard(citizen: citizen),
                ),
                (route) => false,
              );
            },
          );
        }
      } else {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Login Failed',
            message: 'Invalid username or password. Please try again or sign up if you do not have an account.',
            type: CustomDialogType.error,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoginLoading = false;
      });
      if (mounted) {
        CustomDialog.show(
          context: context,
          title: 'Database Error',
          message: 'An unexpected database error occurred. Please try again.',
          type: CustomDialogType.error,
        );
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (!_signUpFormKey.currentState!.validate()) return;

    setState(() {
      _isSignUpLoading = true;
    });

    final name = _nameController.text.trim();
    final contact = _contactController.text.trim();
    final address = _addressController.text.trim();
    final username = _signUpUsernameController.text.trim();
    final password = _signUpPasswordController.text.trim();

    try {
      final dbHelper = DBHelper();
      
      // Check if username already exists
      final isTaken = await dbHelper.isUsernameTaken(username);
      if (isTaken) {
        setState(() {
          _isSignUpLoading = false;
        });
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Username Taken',
            message: 'The username "$username" is already registered. Please choose another one.',
            type: CustomDialogType.error,
          );
        }
        return;
      }

      // Create new Citizen model
      final newCitizen = Citizen(
        name: name,
        contactNumber: contact,
        address: address,
        username: username,
        password: password,
      );

      final resultId = await dbHelper.registerCitizen(newCitizen);

      setState(() {
        _isSignUpLoading = false;
      });

      if (resultId != -1) {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Success!',
            message: 'Your account has been registered successfully. You can now log in.',
            type: CustomDialogType.success,
            onConfirm: () {
              // Switch to Login tab
              _tabController.animateTo(0);
              // Clear fields
              _nameController.clear();
              _contactController.clear();
              _addressController.clear();
              _signUpUsernameController.clear();
              _signUpPasswordController.clear();
            },
          );
        }
      } else {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Registration Failed',
            message: 'Failed to create your account. Please try again.',
            type: CustomDialogType.error,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSignUpLoading = false;
      });
      if (mounted) {
        CustomDialog.show(
          context: context,
          title: 'Database Error',
          message: 'An error occurred while saving user data. Please try again.',
          type: CustomDialogType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryBlue),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primaryBlue,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Log In'),
            Tab(text: 'Sign Up'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLoginTab(),
            _buildSignUpTab(),
          ],
        ),
      ),
    );
  }

  // LOGIN PORTION
  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Form(
        key: _loginFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text(
              'Citizen Sign In',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to report civic problems or view your active complaints.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),

            // Username
            Text(
              'Username',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _loginUsernameController,
              decoration: InputDecoration(
                hintText: 'Enter your username',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your username';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Password
            Text(
              'Password',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _loginPasswordController,
              obscureText: _obscureLoginPassword,
              decoration: InputDecoration(
                hintText: 'Enter your password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureLoginPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureLoginPassword = !_obscureLoginPassword;
                    });
                  },
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            const SizedBox(height: 36),

            // Submit Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isLoginLoading ? null : _handleLogin,
                child: _isLoginLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Log In',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // SIGN UP PORTION
  Widget _buildSignUpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Form(
        key: _signUpFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Account',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Register to start filing complaints for civic resolutions.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),

            // Full Name
            Text(
              'Full Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: _buildInputDecoration(hint: 'Enter your full name', icon: Icons.badge_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Contact Number
            Text(
              'Contact Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contactController,
              keyboardType: TextInputType.phone,
              decoration: _buildInputDecoration(hint: 'Enter your contact number', icon: Icons.phone_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your contact number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Address
            Text(
              'Home Address',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _addressController,
              decoration: _buildInputDecoration(hint: 'Enter your residential address', icon: Icons.home_outlined),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Username
            Text(
              'Username',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _signUpUsernameController,
              decoration: _buildInputDecoration(hint: 'Choose a unique username', icon: Icons.person_outline_rounded),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please choose a username';
                }
                if (value.trim().length < 3) {
                  return 'Username must be at least 3 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password
            Text(
              'Password',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _signUpPasswordController,
              obscureText: _obscureSignUpPassword,
              decoration: InputDecoration(
                hintText: 'Choose a strong password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureSignUpPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureSignUpPassword = !_obscureSignUpPassword;
                    });
                  },
                ),
                filled: true,
                fillColor: AppColors.inputFill,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please choose a password';
                }
                if (value.trim().length < 6) {
                  return 'Password must be at least 6 characters long';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Sign Up Button
            SizedBox(
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: _isSignUpLoading ? null : _handleSignUp,
                child: _isSignUpLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Create Account',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }
}
