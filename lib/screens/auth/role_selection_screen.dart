import 'package:flutter/material.dart';
import '../../widgets/app_colors.dart';
import 'admin_login_screen.dart';
import 'citizen_auth_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              // App Logo / Icon Header
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlueAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.campaign_rounded,
                    size: 56,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Welcome Text
              Text(
                'Welcome to CMS',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                  fontFamily: 'Roboto',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Select your portal below to report issues or manage complaints.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontFamily: 'Roboto',
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 2),

              // Portal Option 1: Citizen Portal
              _buildRoleCard(
                context: context,
                title: 'Citizen Portal',
                subtitle: 'Submit, track, and manage your civic complaints',
                icon: Icons.person_rounded,
                primaryColor: AppColors.primaryBlueLight,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CitizenAuthScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // Portal Option 2: Admin Portal
              _buildRoleCard(
                context: context,
                title: 'Admin Control Center',
                subtitle: 'Monitor system, update status, and manage records',
                icon: Icons.admin_panel_settings_rounded,
                primaryColor: AppColors.primaryBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AdminLoginScreen(),
                    ),
                  );
                },
              ),
              const Spacer(flex: 3),

              // Footer Text
              Center(
                child: Text(
                  'Powered by Municipal Administration',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.primaryBlueAccent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon block
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: 20),
              // Text descriptions
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow forward indicator
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.primaryBlue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
