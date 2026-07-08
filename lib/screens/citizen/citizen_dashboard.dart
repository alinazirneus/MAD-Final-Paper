import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/citizen_model.dart';
import '../../models/complaint_model.dart';
import '../../database/db_helper.dart';
import '../../widgets/app_colors.dart';
import '../../widgets/custom_dialog.dart';
import '../auth/role_selection_screen.dart';

class CitizenDashboard extends StatefulWidget {
  final Citizen citizen;

  const CitizenDashboard({super.key, required this.citizen});

  @override
  State<CitizenDashboard> createState() => _CitizenDashboardState();
}

class _CitizenDashboardState extends State<CitizenDashboard> {
  int _selectedTabIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Home Dashboard counts
  int _pendingCount = 0;
  int _inProgressCount = 0;
  int _resolvedCount = 0;
  bool _isLoadingMetrics = true;

  // New Complaint Form keys & controllers
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedCategory;
  File? _evidenceImage;
  bool _isSubmitting = false;

  // Dropdown list categories
  final List<String> _categories = [
    'Road Damage',
    'Streetlight Failure',
    'Garbage Collection',
    'Water Leakage',
    'Drainage Problem',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // Load metrics from SQLite database
  Future<void> _loadMetrics() async {
    if (widget.citizen.id == null) return;
    setState(() {
      _isLoadingMetrics = true;
    });

    try {
      final metrics = await DBHelper().getCitizenComplaintMetrics(widget.citizen.id!);
      setState(() {
        _pendingCount = metrics['Pending'] ?? 0;
        _inProgressCount = metrics['In Progress'] ?? 0;
        _resolvedCount = metrics['Resolved'] ?? 0;
        _isLoadingMetrics = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMetrics = false;
      });
    }
  }

  // Pick evidence image using Camera or Gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _evidenceImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        CustomDialog.show(
          context: context,
          title: 'Image Picker Error',
          message: 'Unable to capture or select image. Please check camera/gallery permissions.',
          type: CustomDialogType.error,
        );
      }
    }
  }

  // Form submission handler
  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final title = _titleController.text.trim();
    final description = _descController.text.trim();
    final category = _selectedCategory!;
    final location = _locationController.text.trim();
    final imagePath = _evidenceImage?.path;

    // Formatting date string
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final complaint = Complaint(
      citizenId: widget.citizen.id!,
      title: title,
      description: description,
      category: category,
      location: location,
      imagePath: imagePath,
      createdAt: dateStr,
    );

    try {
      final id = await DBHelper().insertComplaint(complaint);
      setState(() {
        _isSubmitting = false;
      });

      if (id != -1) {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Complaint Registered',
            message: 'Your complaint has been submitted successfully with ID #$id.',
            type: CustomDialogType.success,
            onConfirm: () {
              // Refresh metrics counts
              _loadMetrics();
              // Reset complaint form
              _titleController.clear();
              _descController.clear();
              _locationController.clear();
              setState(() {
                _selectedCategory = null;
                _evidenceImage = null;
              });
              // Navigate to history tab
              _navigateToTab(2);
            },
          );
        }
      } else {
        if (mounted) {
          CustomDialog.show(
            context: context,
            title: 'Submission Failed',
            message: 'Failed to record your complaint in local database. Please try again.',
            type: CustomDialogType.error,
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (mounted) {
        CustomDialog.show(
          context: context,
          title: 'Database Error',
          message: 'Error: ${e.toString()}',
          type: CustomDialogType.error,
        );
      }
    }
  }

  void _navigateToTab(int index) {
    setState(() {
      _selectedTabIndex = index;
    });
    // Trigger refresh when entering Home or History tabs
    if (index == 0) {
      _loadMetrics();
    }
    if (_scaffoldKey.currentState!.isDrawerOpen) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // List of screens corresponding to bottom navigation tabs
    final List<Widget> pages = [
      _buildHomeContent(),
      _buildFormContent(),
      _buildHistoryContent(),
      _buildProfileContent(),
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.backgroundLight,
      drawer: _buildCitizenDrawer(),
      appBar: AppBar(
        title: Text(
          _selectedTabIndex == 0
              ? 'Citizen Portal'
              : _selectedTabIndex == 1
                  ? 'Submit Complaint'
                  : _selectedTabIndex == 2
                      ? 'My Complaints'
                      : 'My Profile',
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
            onPressed: () {
              _loadMetrics();
              // Trigger setState to reload history future
              setState(() {});
            },
          ),
        ],
      ),
      body: pages[_selectedTabIndex],
      bottomNavigationBar: _buildFloatingBottomTabBar(),
    );
  }

  // TAB 0: Home dashboard landing content
  Widget _buildHomeContent() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadMetrics,
        color: AppColors.primaryBlue,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 100.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome Greeting Box
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
                          child: Text(
                            widget.citizen.name.isNotEmpty ? widget.citizen.name[0].toUpperCase() : 'C',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Verified Citizen',
                          style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.95),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hello, ${widget.citizen.name}!',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Report road damage, streetlight failure, garbage collection, and more.',
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

              // Status Tracking Section
              Text(
                'Track Complaints',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              // Track Status Cards (Dynamic Counts)
              _isLoadingMetrics
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildTrackingCard(
                            label: 'Pending',
                            count: _pendingCount.toString(),
                            color: Colors.amber.shade700,
                            icon: Icons.hourglass_empty_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTrackingCard(
                            label: 'In Progress',
                            count: _inProgressCount.toString(),
                            color: Colors.blue.shade700,
                            icon: Icons.rotate_right_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTrackingCard(
                            label: 'Resolved',
                            count: _resolvedCount.toString(),
                            color: Colors.green.shade700,
                            icon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 32),

              // Notice Board Banner
              Text(
                'Notice Board & Activities',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 16),

              // Notice List Box
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primaryBlueAccent, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.note_add_outlined,
                      size: 48,
                      color: AppColors.primaryBlue,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Notice Board Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Check the Sidebar or announcements feed to view municipal notice letters.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
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

  // TAB 1: Complaint Form UI Screen
  Widget _buildFormContent() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 110.0), // Padding to avoid overlap with tab bar
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'File a Complaint',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Enter detailed specifications and evidence regarding the issue.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),

              // Form field: Title
              _buildFieldLabel('Complaint Title'),
              TextFormField(
                controller: _titleController,
                decoration: _buildInputDecoration('e.g. Garbage Piles in Main Street', Icons.title_rounded),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title for the complaint';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Form field: Category Dropdown
              _buildFieldLabel('Category'),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: _categories.map((String category) {
                  return DropdownMenuItem<String>(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category_outlined),
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
                hint: const Text('Select issue category'),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Form field: Location
              _buildFieldLabel('Incident Location'),
              TextFormField(
                controller: _locationController,
                decoration: _buildInputDecoration('e.g. Block C, Sector 4 near park', Icons.location_on_outlined),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the specific location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 18),

              // Form field: Description
              _buildFieldLabel('Detailed Description'),
              TextFormField(
                controller: _descController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Describe the issue (e.g. garbage has been piling up for 3 days and is causing bad smell)...',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: const EdgeInsets.all(16),
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
                    return 'Please enter a description of the issue';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Form field: Image picker UI
              _buildFieldLabel('Supporting Evidence Image'),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryBlueAccent, width: 1.2),
                ),
                child: Column(
                  children: [
                    _evidenceImage == null
                        ? Container(
                            height: 120,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_not_supported_outlined, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text(
                                  'No evidence image attached',
                                  style: TextStyle(color: Colors.grey, fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Image.file(
                                  _evidenceImage!,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _evidenceImage = null;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryBlue,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 18),
                            label: const Text('Camera', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryBlue,
                              side: const BorderSide(color: AppColors.primaryBlue, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 18),
                            label: const Text('Gallery', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isSubmitting ? null : _submitComplaint,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          'Submit Case',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // TAB 2: Complaints List History UI Screen
  Widget _buildHistoryContent() {
    if (widget.citizen.id == null) return const Center(child: Text('Invalid user profile'));

    return SafeArea(
      child: FutureBuilder<List<Complaint>>(
        future: DBHelper().getComplaintsByCitizen(widget.citizen.id!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading complaints: ${snapshot.error}'));
          }

          final complaints = snapshot.data ?? [];

          if (complaints.isEmpty) {
            return _buildEmptyHistoryState();
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            itemCount: complaints.length,
            itemBuilder: (context, index) {
              final complaint = complaints[index];
              return _buildComplaintCard(complaint);
            },
          );
        },
      ),
    );
  }

  // TAB 3: Citizen Profile Settings view placeholder
  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.primaryBlueAccent,
                  child: Text(
                    widget.citizen.name.isNotEmpty ? widget.citizen.name[0].toUpperCase() : 'C',
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Color(0xFF00B074), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            widget.citizen.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            textAlign: TextAlign.center,
          ),
          Text(
            '@${widget.citizen.username}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Detail blocks
          _buildProfileDetailRow(Icons.phone_outlined, 'Contact Number', widget.citizen.contactNumber),
          const Divider(height: 24),
          _buildProfileDetailRow(Icons.home_outlined, 'Home Address', widget.citizen.address),
          const Divider(height: 24),
          _buildProfileDetailRow(Icons.assignment_ind_outlined, 'User ID Reference', '#${widget.citizen.id ?? "N/A"}'),
          const Divider(height: 48),

          // Sign Out button
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _handleLogout(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log Out from Portal', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailRow(IconData icon, String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.primaryBlueAccent, shape: BoxShape.circle),
              child: const Icon(Icons.history_toggle_off_rounded, size: 56, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Cases Registered',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 8),
            Text(
              'All civic complaints submitted by you will be listed here. Tap the "New Case" tab to register one.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Modern complaint list card
  Widget _buildComplaintCard(Complaint complaint) {
    // Set status colors matching requirements
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
                  Text(
                    complaint.category.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryBlue.withValues(alpha: 0.6),
                      letterSpacing: 1.2,
                    ),
                  ),
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
                complaint.createdAt.split(' ')[0], // Date portion only
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Category to Icon mapping
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

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
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

  // Drawer matching design reference
  Widget _buildCitizenDrawer() {
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
                    child: Text(
                      widget.citizen.name.isNotEmpty ? widget.citizen.name[0].toUpperCase() : 'C',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.citizen.name.toUpperCase(),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.citizen.contactNumber,
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
                _buildDrawerSectionTitle('General'),
                _buildDrawerItem(
                  icon: Icons.home_outlined,
                  title: 'Home',
                  isSelected: _selectedTabIndex == 0,
                  onTap: () => _navigateToTab(0),
                ),
                _buildDrawerItem(
                  icon: Icons.campaign_outlined,
                  title: 'File Complaint',
                  isSelected: _selectedTabIndex == 1,
                  onTap: () => _navigateToTab(1),
                ),
                _buildDrawerItem(
                  icon: Icons.history_rounded,
                  title: 'My History',
                  isSelected: _selectedTabIndex == 2,
                  onTap: () => _navigateToTab(2),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider(height: 1)),
                _buildDrawerSectionTitle('Profile'),
                _buildDrawerItem(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  isSelected: _selectedTabIndex == 3,
                  onTap: () => _navigateToTab(3),
                ),
                _buildDrawerItem(
                  icon: Icons.vpn_key_outlined,
                  title: 'Change Password',
                  isSelected: false,
                  onTap: () {},
                ),
                _buildDrawerItem(
                  icon: Icons.info_outline_rounded,
                  title: 'About App',
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
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B074),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                        elevation: 0,
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.phone_rounded, size: 16),
                      label: const Text('Call Helpline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryBlue,
                        side: BorderSide(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: () {},
                      icon: const Icon(Icons.language_rounded, size: 16),
                      label: const Text('Language', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

  // Floating tab bar
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
              _buildTabItem(0, Icons.home_rounded, 'Home'),
              _buildTabItem(1, Icons.campaign_rounded, 'New Case'),
              _buildTabItem(2, Icons.history_rounded, 'History'),
              _buildTabItem(3, Icons.person_outline_rounded, 'Profile'),
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

  Widget _buildTrackingCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          )
        ],
        border: Border.all(color: AppColors.primaryBlueAccent, width: 1),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            count,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
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
