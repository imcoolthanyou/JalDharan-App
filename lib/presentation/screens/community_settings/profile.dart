import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:io';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_colors.dart';

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
  String _location = 'Loading...';
  int _waterPoints = 0;
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _notificationsEnabled = true;

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

    setState(() {
      _currentUser = user;
      _displayName = user.displayName ?? (mounted ? AppLocalizations.of(context)?.get('user_default') ?? 'User' : 'User');
      _email = user.email ?? '';
      _photoURL = user.photoURL;
    });

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _displayName = data['displayName'] ?? user.displayName ?? (mounted ? AppLocalizations.of(context)?.get('user_default') ?? 'User' : 'User');
          _email = data['email'] ?? user.email ?? '';
          _phone = data['phone'] ?? '+91 98765 43210';
          _photoURL = data['photoURL'] ?? user.photoURL;
          _location = data['location'] ?? '';
          _waterPoints = data['waterPoints'] ?? 0;
          _notificationsEnabled = data['notificationsEnabled'] ?? true;
        });

        if ((data['location'] ?? '').toString().isEmpty) {
          await _fetchAndSaveLocation();
        }
      } else {
        await _fetchAndSaveLocation();
      }

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'displayName': _displayName,
        'email': _email,
        'phone': _phone,
        'photoURL': _photoURL ?? '',
        'location': _location,
        'waterPoints': _waterPoints,
        'notificationsEnabled': _notificationsEnabled,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Firestore error: $e');
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
          if (mounted) {
        setState(() => _location = AppLocalizations.of(context)!.get('location_denied'));
      }
      return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
        setState(() => _location = AppLocalizations.of(context)!.get('location_permanently_denied'));
      }
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

        if (_currentUser != null) {
          await _firestore
              .collection('users')
              .doc(_currentUser!.uid)
              .update({'location': locationStr, 'updatedAt': FieldValue.serverTimestamp()});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _location = AppLocalizations.of(context)!.get('unable_fetch_location'));
      }
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

      await _firestore
          .collection('users')
          .doc(_currentUser!.uid)
          .update({'photoURL': downloadURL, 'updatedAt': FieldValue.serverTimestamp()});
      await _currentUser!.updatePhotoURL(downloadURL);

      setState(() => _photoURL = downloadURL);
    } catch (e) {
      debugPrint('Image upload failed: $e');
      final l = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.get('image_upload_failed'))),
      );
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  // ── Edit Profile bottom sheet ──
  void _showEditProfile() {
    final l = AppLocalizations.of(context)!;
    final nameCtrl = TextEditingController(text: _displayName);
    final phoneCtrl = TextEditingController(text: _phone);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
            Text(
              l.get('edit_profile'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(nameCtrl, l.get('display_name')),
            const SizedBox(height: 12),
            _buildTextField(phoneCtrl, l.get('phone_number')),
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

                  if (_currentUser != null) {
                    await _firestore
                        .collection('users')
                        .doc(_currentUser!.uid)
                        .update({
                      'displayName': _displayName,
                      'phone': _phone,
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                    await _currentUser!.updateDisplayName(_displayName);
                  }
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                child: Text(
                  l.get('save_changes'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
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

  Widget _buildTextField(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        filled: true,
        fillColor: AppColors.lightGrey,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      l.get('settings'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Profile Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.lightGrey),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          GestureDetector(
                            onTap: _pickAndUploadImage,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.lightGrey,
                              ),
                              child: ClipOval(
                                child: _isUploadingImage
                                    ? const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      )
                                    : (_photoURL != null && _photoURL!.isNotEmpty)
                                        ? Image.network(
                                            _photoURL!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _buildInitialsAvatar(),
                                          )
                                        : _buildInitialsAvatar(),
                              ),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.mediumGrey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: _showEditProfile,
                                  child: Text(
                                    l.get('edit_profile'),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accentBlue,
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
                    _buildSectionTitle(l.get('personal_details')),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      _buildInfoRow(l.get('email'), _email),
                      _buildDivider(),
                      _buildInfoRow(l.get('phone'), _phone),
                      _buildDivider(),
                      _buildInfoRow(l.get('location'), _location.isEmpty ? l.get('fetching_location') : _location),
                    ]),

                    const SizedBox(height: 24),

                    // ── Preferences ──
                    _buildSectionTitle(l.get('preferences')),
                    const SizedBox(height: 12),
                    _buildSettingsCard([
                      // Language
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, _) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l.get('language'),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      languageProvider.currentLanguage == 'hi'
                                          ? l.get('hindi')
                                          : l.get('english'),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.mediumGrey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              GestureDetector(
                                onTap: () => _showLanguagePicker(context, languageProvider),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.lightGrey, width: 1.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        languageProvider.currentLanguage == 'hi'
                                            ? l.get('hindi')
                                            : l.get('english'),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: AppColors.mediumGrey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildDivider(),
                      // Notifications
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l.get('notifications'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  Text(
                                    l.get('notifications_desc'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.mediumGrey,
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
                              activeTrackColor: AppColors.accentBlue,
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: AppColors.lightGrey,
                            ),
                          ],
                        ),
                      ),
                    ]),

                    const SizedBox(height: 32),

                    // ── Logout ──
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _showLogoutDialog,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          l.get('logout'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
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

  // ── Section title ──
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
    );
  }

  // ── Settings card wrapper ──
  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightGrey),
      ),
      child: Column(children: children),
    );
  }

  // ── Simple info row (no icons) ──
  Widget _buildInfoRow(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mediumGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.lightGrey,
    );
  }

  // ── Initials avatar ──
  Widget _buildInitialsAvatar() {
    return Container(
      color: AppColors.lightGrey,
      child: Center(
        child: Text(
          _getInitials(),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  // ── Logout confirmation dialog ──
  void _showLogoutDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          l.get('logout_confirm_title'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        content: Text(
          l.get('logout_confirm_message'),
          style: const TextStyle(color: AppColors.mediumGrey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              l.get('cancel'),
              style: const TextStyle(color: AppColors.mediumGrey),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final navigator = Navigator.of(context);

              try {
                await _authService.signOut();
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove('onboarding_complete');

                if (mounted) {
                  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                }
              } catch (e) {
                debugPrint('Logout error: $e');
                if (mounted) {
                  navigator.pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
            child: Text(
              l.get('logout_confirm'),
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Language picker ──
  void _showLanguagePicker(
      BuildContext context, LanguageProvider languageProvider) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.get('language_selector'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            _languageOption(
              label: l.get('english'),
              isSelected: languageProvider.currentLanguage == 'en',
              onTap: () {
                languageProvider.changeLanguage('en');
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 12),
            _languageOption(
              label: l.get('hindi'),
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
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightGrey : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.lightGrey,
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
                color: isSelected ? AppColors.primary : AppColors.darkGrey,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_rounded, color: AppColors.primary, size: 18),
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
}
