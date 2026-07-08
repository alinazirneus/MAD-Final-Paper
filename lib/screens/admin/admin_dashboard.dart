import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/citizen_model.dart';
import '../../models/complaint_model.dart';
import '../../models/announcement_model.dart';
import '../../database/db_helper.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/custom_dialog.dart';
import '../auth/role_selection_screen.dart';

class AdminDashboard extends StatefulWidget {
  final String adminName;
  final String adminEmail;

  const AdminDashboard({
    super.key,
    required this.adminName,
    required this.adminEmail,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Administrative metrics
  int _citizensCount = 0;
  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  int _totalCount = 0;
  bool _isLoadingMetrics = true;

  // Cached citizen details to display reporter names
  Map<int, Citizen> _registeredCitizens = {};

  @override
  void initState() {
    super.initState();
    _loadAllAdminData();
  }

  // Load metrics and registered citizens from SQLite
  Future<void> _loadAllAdminData() async {
    setState(() {
      _isLoadingMetrics = true;
    });

    try {
      final dbHelper = DBHelper();
      // Load metrics
      final metrics = await dbHelper.getAdminComplaintMetrics();
      // Load citizens
      final citizens = await dbHelper.getAllCitizens();
      
      final Map<int, Citizen> citizenMap = {};
      for (var citizen in citizens) {
        if (citizen.id != null) {
          citizenMap[citizen.id!] = citizen;
        }
      }

      setState(() {
        _citizensCount = metrics['citizens'] ?? 0;
        _pendingCount = metrics['pending'] ?? 0;
        _inProgressCount = metrics['inProgress'] ?? 0;
        _resolvedCount = metrics['resolved'] ?? 0;
        _totalCount = metrics['totalComplaints'] ?? 0;
        _registeredCitizens = citizenMap;
        _isLoadingMetrics = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMetrics = false;
      });
    }
  }

  // Update complaint status inside database
  Future<void> _changeComplaintStatus(int complaintId, String newStatus) async {
    try {
      final rowsUpdated = await DBHelper().updateComplaintStatus(complaintId, newStatus);
      if (rowsUpdated > 0) {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Status Updated',
            message: 'Complaint status has been successfully set to "$newStatus".',
            type: CustomDialogType.success,
            onConfirm: () {
              // Reload admin statistics and refresh complaints builder
              _loadAllAdminData();
            },
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CustomDialog.show(
          context: context,
          title: 'Database Error',
          message: 'Failed to update complaint status: ${e.toString()}',
          type: CustomDialogType.error,
        );
      }
    }
  }

  // Delete a complaint with confirmation check
  Future<void> _confirmDeleteComplaint(int complaintId) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: AlertDialog(
            title: const Text('Delete Complaint?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to delete this complaint? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  navigator.pop(); // Close alert
                  try {
                    final rowsDeleted = await DBHelper().deleteComplaint(complaintId);
                    if (rowsDeleted > 0) {
                      if (context.mounted) {
                        CustomDialog.show(
                          context: context,
                          title: 'Complaint Deleted',
                          message: 'The complaint record has been permanently deleted from the database.',
                          type: CustomDialogType.success,
                          onConfirm: () {
                            _loadAllAdminData();
                          },
                        );
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      CustomDialog.show(
                        context: context,
                        title: 'Database Error',
                        message: 'Failed to delete complaint record: ${e.toString()}',
                        type: CustomDialogType.error,
                      );
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _navigateToTab(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    // Refresh admin data when navigating to tabs
    _loadAllAdminData();
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens corresponding to bottom navigation tabs
    final List<Widget> pages = [
      _buildHomeContent(),
      _buildCitizensTab(),
      _buildComplaintsTab(),
      _buildAnnouncementsTab(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundLight,
      drawer: _buildAdminDrawer(),
      appBar: AppBar(
        title: Text(
          _selectedTabIndex == 0
              ? 'Admin Dashboard'
              : _selectedTabIndex == 1
                  ? 'Registered Citizens'
                  : _selectedTabIndex == 2
                      ? 'Manage Complaints'
                      : 'Announcement Board',
          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.white),
        ),
        backgroundColor: AppColors.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AppColors.white),
          onPressed: () => _scaffoldKey.currentState!.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.white),
            tooltip: 'Refresh Data',
            onPressed: _loadAllAdminData,
          ),
        ],
      ),
      body: pages[_selectedTabIndex],
      floatingActionButton: _selectedTabIndex == 3
          ? Container(
              margin: const EdgeInsets.only(bottom: 80),
              child: FloatingActionButton(
                onPressed: _showAddAnnouncementDialog,
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add_rounded),
              ),
            )
          : null,
      bottomNavigationBar: _buildFloatingBottomTabBar(),
    );
  }

  // TAB 0: Admin Overview Landing screen
  Widget _buildHomeContent() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadAllAdminData,
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryBlueLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.white.withValues(alpha: 0.2),
                          child: const Icon(Icons.security, color: AppColors.white),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'System Administrator',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Welcome, ${widget.adminName}!',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Monitor civic registrations, manage complaints, and publish updates.',
                      style: TextStyle(
                        color: AppColors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Overview Section Title
              Text(
                'System Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              // Dynamic Analytics Grid
              _isLoadingMetrics
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildStatCard(
                          title: 'Total Citizens',
                          value: _citizensCount.toString(),
                          icon: Icons.people_rounded,
                          color: Colors.blue.shade700,
                        ),
                        _buildStatCard(
                          title: 'Pending Cases',
                          value: _pendingCount.toString(),
                          icon: Icons.hourglass_empty_rounded,
                          color: Colors.orange.shade700,
                        ),
                        _buildStatCard(
                          title: 'In Progress',
                          value: _inProgressCount.toString(),
                          icon: Icons.rotate_right_rounded,
                          color: Colors.blue.shade800,
                        ),
                        _buildStatCard(
                          title: 'Resolved Cases',
                          value: _resolvedCount.toString(),
                          icon: Icons.check_circle_outline_rounded,
                          color: Colors.green.shade700,
                        ),
                      ],
                    ),
              const SizedBox(height: 32),

              // System quick notifications
              Text(
                'Recent Log Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryBlueAccent, width: 1.2),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.analytics_rounded, color: AppColors.primaryBlue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Local database contains $_totalCount cases',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'All registered citizen credentials and complaint logs are synchronized locally.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
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

  // TAB 1: Registered Citizens List Screen
  Widget _buildCitizensTab() {
    return FutureBuilder<List<Citizen>>(
      future: DBHelper().getAllCitizens(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final citizens = snapshot.data ?? [];

        if (citizens.isEmpty) {
          return _buildEmptyState('No registered citizens', Icons.people_outline_rounded);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: citizens.length,
          itemBuilder: (context, index) {
            final citizen = citizens[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlueAccent, width: 1.2),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryBlueAccent,
                    child: Text(
                      citizen.name.isNotEmpty ? citizen.name[0].toUpperCase() : 'C',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          citizen.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_rounded, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(citizen.contactNumber, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.home_rounded, size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                citizen.address,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '@${citizen.username}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: Manage Complaints Monitor Screen
  Widget _buildComplaintsTab() {
    return FutureBuilder<List<Complaint>>(
      future: DBHelper().getAllComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final complaints = snapshot.data ?? [];

        if (complaints.isEmpty) {
          return _buildEmptyState('No complaints submitted yet', Icons.assignment_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: complaints.length,
          itemBuilder: (context, index) {
            final complaint = complaints[index];
            return _buildAdminComplaintCard(complaint);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // Custom complaint card design for administrative management actions
  Widget _buildAdminComplaintCard(Complaint complaint) {
    Color badgeBg;
    Color badgeText;
    if (complaint.status == 'Resolved') {
      badgeBg = Colors.green.shade50;
      badgeText = Colors.green.shade800;
    } else if (complaint.status == 'In Progress') {
      badgeBg = Colors.blue.shade50;
      badgeText = Colors.blue.shade800;
    } else {
      badgeBg = Colors.orange.shade50;
      badgeText = Colors.orange.shade800;
    }

    // Resolve citizen reporter details
    final reporter = _registeredCitizens[complaint.citizenId];
    final reporterName = reporter?.name ?? 'Loading...';
    final reporterPhone = reporter?.contactNumber ?? 'Loading...';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryBlueAccent, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: Colors.transparent,
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.all(16),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category label
                      Expanded(
                        child: Text(
                          complaint.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryBlue.withValues(alpha: 0.6),
                            letterSpacing: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      complaint.status,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Complaint Title
              Text(
                complaint.title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 8),
              // Reporter label
              Row(
                children: [
                  const Icon(Icons.person_outline_rounded, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Filed by: $reporterName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
          subtitle: Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  complaint.location,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                complaint.createdAt.split(' ')[0],
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          leading: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: complaint.imagePath != null && File(complaint.imagePath!).existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(
                      File(complaint.imagePath!),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    _getCategoryIcon(complaint.category),
                    color: AppColors.primaryBlue,
                    size: 24,
                  ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  // Reporter Contact Info block
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reporter Details:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(height: 4),
                        Text('Name: $reporterName', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        Text('Phone: $reporterPhone', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                        if (reporter != null)
                          Text('Address: ${reporter.address}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Full Description:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    complaint.description,
                    style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.4),
                  ),
                  if (complaint.imagePath != null && File(complaint.imagePath!).existsSync()) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Evidence Image Attachment:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(complaint.imagePath!),
                        height: 200,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Status Tracking Timeline:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<List<ComplaintStatusHistory>>(
                    future: DBHelper().getComplaintStatusHistory(complaint.id!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Error loading history: ${snapshot.error}',
                            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                          ),
                        );
                      }
                      final historyList = snapshot.data ?? [];
                      if (historyList.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'No history available for this complaint.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        );
                      }

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: List.generate(historyList.length, (idx) {
                            final history = historyList[idx];
                            final isLast = idx == historyList.length - 1;

                            IconData statusIcon;
                            Color statusColor;
                            if (history.status == 'Resolved') {
                              statusIcon = Icons.check_circle_rounded;
                              statusColor = Colors.green;
                            } else if (history.status == 'In Progress') {
                              statusIcon = Icons.play_circle_rounded;
                              statusColor = Colors.blue;
                            } else {
                              statusIcon = Icons.pending_rounded;
                              statusColor = Colors.orange;
                            }

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(statusIcon, color: statusColor, size: 18),
                                    ),
                                    if (!isLast)
                                      Container(
                                        width: 2,
                                        height: 30,
                                        color: Colors.grey.shade300,
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 2.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          history.status == 'Pending' ? 'Complaint Submitted (Pending)' : 'Status updated to ${history.status}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: Colors.grey.shade800,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          history.updatedAt,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        if (!isLast) const SizedBox(height: 12),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),

                  // Actions: Change Status and Delete
                  Row(
                    children: [
                      // Status Action drop down
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: complaint.status,
                              isExpanded: true,
                              items: ['Pending', 'In Progress', 'Resolved'].map((String status) {
                                return DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(
                                    'Status: $status',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newStatus) {
                                if (newStatus != null && newStatus != complaint.status) {
                                  _changeComplaintStatus(complaint.id!, newStatus);
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Delete Action Button
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red.shade50,
                          foregroundColor: Colors.redAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 22),
                        onPressed: () => _confirmDeleteComplaint(complaint.id!),
                      ),
                    ],
                  ),
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

  // Category Icon helper
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Road Damage':
        return Icons.construction_rounded;
      case 'Streetlight Failure':
        return Icons.lightbulb_outline_rounded;
      case 'Garbage Collection':
        return Icons.delete_outline_rounded;
      case 'Water Leakage':
        return Icons.water_drop_outlined;
      case 'Drainage Problem':
        return Icons.waves_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  // TAB 3: Notice Announcements UI Screen
  Widget _buildAnnouncementsTab() {
    return FutureBuilder<List<Announcement>>(
      future: DBHelper().getAllAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.campaign_outlined, size: 64, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'No Announcements Published',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Publish emergency notices, scheduling updates, or municipal alerts. Tap the float button below to publish.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final announcement = list[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryBlueAccent, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueAccent,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.campaign_outlined,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          announcement.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    announcement.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            announcement.createdAt,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.primaryBlue),
                            onPressed: () => _showEditAnnouncementDialog(announcement),
                            tooltip: 'Edit Announcement',
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                            onPressed: () => _confirmDeleteAnnouncement(announcement.id!),
                            tooltip: 'Delete Announcement',
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAddAnnouncementDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Publish Announcement',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Announcement Title',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Title cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description / Details',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Description cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext); // Close dialog

                    final now = DateTime.now();
                    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

                    final announcement = Announcement(
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      createdAt: dateStr,
                    );

                    try {
                      final id = await DBHelper().insertAnnouncement(announcement);
                      if (id != -1) {
                        if (mounted) {
                          CustomDialog.show(
                            context: context,
                            title: 'Success',
                            message: 'Announcement has been published successfully.',
                            type: CustomDialogType.success,
                            onConfirm: () {
                              setState(() {}); // reload tab data
                            },
                          );
                        }
                      } else {
                        if (mounted) {
                          CustomDialog.show(
                            context: context,
                            title: 'Error',
                            message: 'Failed to save announcement in local database.',
                            type: CustomDialogType.error,
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        CustomDialog.show(
                          context: context,
                          title: 'Error',
                          message: 'Error: ${e.toString()}',
                          type: CustomDialogType.error,
                        );
                      }
                    }
                  }
                },
                child: const Text('Publish'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditAnnouncementDialog(Announcement announcement) async {
    final titleController = TextEditingController(text: announcement.title);
    final descController = TextEditingController(text: announcement.description);
    final formKey = GlobalKey<FormState>();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Edit Announcement',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Announcement Title',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Title cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: descController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Description / Details',
                        labelStyle: TextStyle(color: Colors.grey.shade600),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Description cannot be empty';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(dialogContext); // Close dialog

                    final updated = Announcement(
                      id: announcement.id,
                      title: titleController.text.trim(),
                      description: descController.text.trim(),
                      createdAt: announcement.createdAt, // Keep original timestamp
                    );

                    try {
                      final result = await DBHelper().updateAnnouncement(updated);
                      if (result > 0) {
                        if (mounted) {
                          CustomDialog.show(
                            context: context,
                            title: 'Success',
                            message: 'Announcement updated successfully.',
                            type: CustomDialogType.success,
                            onConfirm: () {
                              setState(() {}); // reload tab data
                            },
                          );
                        }
                      } else {
                        if (mounted) {
                          CustomDialog.show(
                            context: context,
                            title: 'Error',
                            message: 'Failed to update announcement.',
                            type: CustomDialogType.error,
                          );
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        CustomDialog.show(
                          context: context,
                          title: 'Error',
                          message: 'Error: ${e.toString()}',
                          type: CustomDialogType.error,
                        );
                      }
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteAnnouncement(int id) async {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (dialogContext, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Announcement?', style: TextStyle(fontWeight: FontWeight.bold)),
            content: const Text('Are you sure you want to delete this announcement? This action cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () async {
                  Navigator.pop(dialogContext); // Close confirmation dialog
                  try {
                    final result = await DBHelper().deleteAnnouncement(id);
                    if (result > 0) {
                      if (mounted) {
                        CustomDialog.show(
                          context: context,
                          title: 'Success',
                          message: 'Announcement deleted successfully.',
                          type: CustomDialogType.success,
                          onConfirm: () {
                            setState(() {}); // reload tab data
                          },
                        );
                      }
                    } else {
                      if (mounted) {
                        CustomDialog.show(
                          context: context,
                          title: 'Error',
                          message: 'Failed to delete announcement.',
                          type: CustomDialogType.error,
                        );
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      CustomDialog.show(
                        context: context,
                        title: 'Error',
                        message: 'Error: ${e.toString()}',
                        type: CustomDialogType.error,
                      );
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
    );
  }

  // Admin Drawer
  Widget _buildAdminDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.adminName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.adminEmail,
                  style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                _buildDrawerSectionTitle('Control Center'),
                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Control Center',
                  isSelected: _selectedTabIndex == 0,
                  onTap: () => _navigateToTab(0),
                ),
                _buildDrawerItem(
                  icon: Icons.people_outline_rounded,
                  title: 'Registered Citizens',
                  isSelected: _selectedTabIndex == 1,
                  onTap: () => _navigateToTab(1),
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_outlined,
                  title: 'Monitor Complaints',
                  isSelected: _selectedTabIndex == 2,
                  onTap: () => _navigateToTab(2),
                ),
                _buildDrawerItem(
                  icon: Icons.campaign_outlined,
                  title: 'Notice Announcements',
                  isSelected: _selectedTabIndex == 3,
                  onTap: () => _navigateToTab(3),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                _buildDrawerSectionTitle('Security & Configuration'),
                _buildDrawerItem(
                  icon: Icons.security_outlined,
                  title: 'Security Logs',
                  isSelected: false,
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.vpn_key_outlined,
                  title: 'Change Password',
                  isSelected: false,
                  onTap: () {},
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () => _handleLogout(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
                  elevation: 0,
                ),
                onPressed: () {},
                icon: const Icon(Icons.help_outline_rounded, size: 18),
                label: const Text('Admin Help Desk', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, top: 12.0, bottom: 6.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2.0),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryBlueAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? AppColors.primaryBlue : Colors.grey.shade600,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? AppColors.primaryBlue : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFloatingBottomTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: SafeArea(
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTabItem(0, Icons.dashboard_rounded, 'Portal'),
              _buildTabItem(1, Icons.people_alt_rounded, 'Citizens'),
              _buildTabItem(2, Icons.assignment_rounded, 'Complaints'),
              _buildTabItem(3, Icons.campaign_rounded, 'Alerts'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => _navigateToTab(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.white : Colors.grey.shade500,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: AppColors.primaryBlueAccent, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      (route) => false,
    );
  }
}
