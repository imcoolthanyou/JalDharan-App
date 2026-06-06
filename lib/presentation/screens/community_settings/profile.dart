import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/gamification_data.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? _currentUser;
  String _displayName = '';
  String _email = '';
  String _phone = '+91 98765 43210';
  String? _photoURL;
  String _location = 'Fetching location...';
  int _waterPoints = 0;
  int _level = 1;
  bool _isLoading = true;
  bool _isUploadingImage = false;

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ── Load user from Firestore ──
  Future<void> _loadUserData() async {
    final user = _authService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    // Always set from Firebase Auth first (instant, no network needed)
    setState(() {
      _currentUser = user;
      _displayName = user.displayName ?? 'User';
      _email = user.email ?? '';
      _photoURL = user.photoURL;
    });

    try {
      // 1. Fetch existing Firestore doc
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _displayName = data['displayName'] ?? user.displayName ?? 'User';
          _email = data['email'] ?? user.email ?? '';
          _phone = data['phone'] ?? '+91 98765 43210';
          _photoURL = data['photoURL'] ?? user.photoURL;
          _location = data['location'] ?? 'Fetching location...';
          _waterPoints = data['waterPoints'] ?? 0;
          _level = data['level'] ?? 1;
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
          _darkModeEnabled = data['darkModeEnabled'] ?? false;
        });

        // Refresh location if never saved
        if ((data['location'] ?? '').toString().isEmpty) {
          await _fetchAndSaveLocation();
        }
      } else {
        // 2. New user — fetch location then push
        await _fetchAndSaveLocation();
      }

      // 3. ALWAYS push/merge latest auth data to Firestore
      //    merge:true means existing fields won't be overwritten
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': _displayName,
        'email': _email,
        'phone': _phone,
        'photoURL': _photoURL ?? '',
        'location': _location,
        'waterPoints': _waterPoints,
        'level': _level,
        'notificationsEnabled': _notificationsEnabled,
        'darkModeEnabled': _darkModeEnabled,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Firestore push successful for uid: ${user.uid}');
    } catch (e) {
      debugPrint('❌ Firestore error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Fetch GPS location and save to Firestore ──
  Future<void> _fetchAndSaveLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _location = 'Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _location = 'Location permission permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final locationStr =
            '${place.locality}, ${place.administrativeArea}, ${place.country}';
        setState(() => _location = locationStr);

        // Save to Firestore
        if (_currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .update({'location': locationStr, 'updatedAt': FieldValue.serverTimestamp()});
        }
      }
    } catch (e) {
      setState(() => _location = 'Unable to fetch location');
    }
  }

  // ── Save a single field to Firestore ──
  Future<void> _updateField(String field, dynamic value) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('users').doc(_currentUser!.uid).update({
        field: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating $field: $e');
    }
  }

  // ── Pick image and upload to Firebase Storage ──
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null || _currentUser == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final ref = _storage
          .ref()
          .child('profile_images/${_currentUser!.uid}.jpg');
      await ref.putFile(File(image.path));
      final downloadURL = await ref.getDownloadURL();

      // Update Firestore and Firebase Auth
      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'photoURL': downloadURL, 'updatedAt': FieldValue.serverTimestamp()});
      await _currentUser!.updatePhotoURL(downloadURL);

      setState(() => _photoURL = downloadURL);
    } catch (e) {
      debugPrint('Image upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload failed. Try again.')),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // ── Edit Profile bottom sheet ──
  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _displayName);
    final phoneCtrl = TextEditingController(text: _phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(nameCtrl, 'Display Name', Icons.person_rounded),
            const SizedBox(height: 12),
            _buildTextField(phoneCtrl, 'Phone Number', Icons.phone_rounded),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final newName = nameCtrl.text.trim();
                  final newPhone = phoneCtrl.text.trim();

                  setState(() {
                    _displayName = newName.isNotEmpty ? newName : _displayName;
                    _phone = newPhone.isNotEmpty ? newPhone : _phone;
                  });

                  // Push both fields to Firestore
                  if (_currentUser != null) {
                    await _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .update({
                      'displayName': _displayName,
                      'phone': _phone,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    // Also update Firebase Auth display name
                    await _currentUser!.updateDisplayName(_displayName);
                  }
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6D5DF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: const Text(
                  'Save Changes',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF6D5DF6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF6D5DF6), width: 1.5),
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0FA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.get('profile'),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.get('profile_subtitle'),
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // ── Profile Card ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar with upload
                    GestureDetector(
                      onTap: _pickAndUploadImage,
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFEDE9FE),
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: _isUploadingImage
                                  ? Container(
                                color: const Color(0xFFEDE9FE),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF6D5DF6),
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                                  : (_photoURL != null &&
                                  _photoURL!.isNotEmpty)
                                  ? Image.network(
                                _photoURL!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildInitialsAvatar(),
                              )
                                  : _buildInitialsAvatar(),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6D5DF6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE9FE),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shield_rounded,
                                      color: Color(0xFF6D5DF6),
                                      size: 13,
                                    ),
                                    SizedBox(width: 4),
                                  Text(
                                    "Level ${UserProfile.mockCurrentUser().level}",
                                    style: const TextStyle(
                                      color: Color(0xFF6D5DF6),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Groundwater Guardian",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.water_drop,
                                  color: Color(0xFF6D5DF6), size: 16),
                              const SizedBox(width: 4),
                              Text(
                                "$_waterPoints",
                                style: const TextStyle(
                                  color: Color(0xFF6D5DF6),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(width: 4),
                              Text(
                                "Water Points",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {},
                              icon: const Icon(
                                Icons.edit_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: const Text(
                                "Edit Profile",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6D5DF6),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                padding:
                                const EdgeInsets.symmetric(vertical: 11),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Personal Details ──
              _SectionHeader(
                icon: Icons.person_outline_rounded,
                label: "Personal Details",
              ),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.email_rounded,
                    iconBg: const Color(0xFFEDE9FE),
                    iconColor: const Color(0xFF6D5DF6),
                    title: l.get('email'),
                    subtitle: _email,
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: "Mobile Number",
                    subtitle: "+91 98765 43210",
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.location_on_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: l.get('location'),
                    subtitle: _location,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Preferences ──
              _SectionHeader(
                icon: Icons.settings_outlined,
                label: "Preferences",
              ),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  // Language
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, _) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          _IconBox(
                            icon: Icons.language_rounded,
                            bg: const Color(0xFFE0F2FE),
                            color: const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Language",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: Color(0xFF0F172A))),
                                Text(
                                  languageProvider.currentLanguage == 'hi'
                                      ? 'हिंदी'
                                      : 'English',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                _showLanguagePicker(context, languageProvider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: const Color(0xFFE2E8F0), width: 1.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    languageProvider.currentLanguage == 'hi'
                                        ? 'हिंदी'
                                        : 'English',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A)),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded,
                                      size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  _divider(),

                  // Notifications
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _IconBox(
                          icon: Icons.notifications_rounded,
                          bg: const Color(0xFFDCFCE7),
                          color: const Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Notifications",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                "Stay updated with important alerts",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: (val) {
                            setState(() => _notificationsEnabled = val);
                            _updateField('notificationsEnabled', val);
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF6D5DF6),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                        ),
                      ],
                    ),
                  ),

                  _divider(),

                  // Dark Mode
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        _IconBox(
                          icon: Icons.dark_mode_rounded,
                          bg: const Color(0xFFEDE9FE),
                          color: const Color(0xFF6D5DF6),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dark Mode",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                "Reduce eye strain in low light",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _darkModeEnabled,
                          onChanged: (val) {
                            setState(() => _darkModeEnabled = val);
                            _updateField('darkModeEnabled', val);
                          },
                          activeColor: Colors.white,
                          activeTrackColor: const Color(0xFF6D5DF6),
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: const Color(0xFFE2E8F0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── Account ──
              _SectionHeader(
                icon: Icons.lock_outline_rounded,
                label: "Account",
              ),
              const SizedBox(height: 12),
              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.lock_rounded,
                    iconBg: const Color(0xFFEDE9FE),
                    iconColor: const Color(0xFF6D5DF6),
                    title: l.get('change_password'),
                    subtitle: null,
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.security_rounded,
                    iconBg: const Color(0xFFDCFCE7),
                    iconColor: const Color(0xFF16A34A),
                    title: l.get('privacy_policy'),
                    subtitle: null,
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.info_rounded,
                    iconBg: const Color(0xFFE0F2FE),
                    iconColor: const Color(0xFF0284C7),
                    title: l.get('about_app'),
                    subtitle: null,
                  ),
                  _divider(),
                  _InfoRow(
                    icon: Icons.star_rounded,
                    iconBg: const Color(0xFFFEF9C3),
                    iconColor: const Color(0xFFCA8A04),
                    title: l.get('rate_app'),
                    subtitle: null,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ── Logout ──
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(18),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.logout_rounded,
                                color: Color(0xFFEF4444), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              "Logout",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFFEF4444), size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitialsAvatar() {
    return Container(
      color: const Color(0xFFEDE9FE),
      child: Center(
        child: Text(
          _getInitials(),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6D5DF6),
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(
      BuildContext context, LanguageProvider languageProvider) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Language",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 16),
            _languageOption(
              label: 'English',
              code: 'en',
              isSelected: languageProvider.currentLanguage == 'en',
              onTap: () {
                languageProvider.changeLanguage('en');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _languageOption(
              label: 'हिंदी',
              code: 'hi',
              isSelected: languageProvider.currentLanguage == 'hi',
              onTap: () {
                languageProvider.changeLanguage('hi');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _languageOption({
    required String label,
    required String code,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEDE9FE) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
            isSelected ? const Color(0xFF6D5DF6) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF6D5DF6)
                    : const Color(0xFF0F172A),
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_rounded,
                  color: Color(0xFF6D5DF6), size: 20),
          ],
        ),
      ),
    );
  }

  String _getInitials() {
    if (_displayName.isEmpty) return 'U';
    final parts = _displayName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      indent: 70,
      endIndent: 16,
      color: Color(0xFFF1F5F9),
    );
  }
}

// ── Section Header ──
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFEDE9FE),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: const Color(0xFF6D5DF6), size: 20),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A))),
      ],
    );
  }
}

// ── Info Card ──
class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ── Info Row ──
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;

  const _InfoRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              _IconBox(icon: icon, bg: iconBg, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0F172A))),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Icon Box ──
class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color color;
  const _IconBox({required this.icon, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}