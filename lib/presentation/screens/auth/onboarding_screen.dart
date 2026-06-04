import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';
import 'device_setup_page.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _introKey = GlobalKey<IntroductionScreenState>();

  // Page 5 only appears after device setup completes successfully
  bool _deviceSetupComplete = false;
  bool _deviceLinked = false;

  // House photo state
  File? _housePhoto;
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _pickHousePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (image != null && mounted)
        setState(() => _housePhoto = File(image.path));
    } catch (_) {}
  }

  Future<void> _takeHousePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (image != null && mounted)
        setState(() => _housePhoto = File(image.path));
    } catch (_) {}
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    }
  }

  void _onDeviceSetupComplete(bool linked) {
    if (!mounted) return;
    setState(() {
      _deviceSetupComplete = true;
      _deviceLinked = linked;
    });
    // Auto-advance to page 5 after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _introKey.currentState?.animateScroll(4);
      }
    });
  }

  PageDecoration get _pageDecoration => PageDecoration(
    titleTextStyle: const TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.darkGrey,
    ),
    bodyTextStyle: const TextStyle(
      fontSize: 15,
      color: AppColors.mediumGrey,
      height: 1.5,
    ),
    imagePadding: const EdgeInsets.only(top: 40),
    pageColor: Colors.white,
    bodyPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  );

  List<PageViewModel> get _pages {
    final basePages = [
      // Page 1
      PageViewModel(
        title: 'Know Your Water',
        body:
            'Get real-time data from your borewell and groundwater with our smart sensors. Monitor depth, flow rate, TDS, pH and more.',
        image: _buildImage(Icons.water_drop_rounded, AppColors.deepAquiferBlue),
        decoration: _pageDecoration,
      ),
      // Page 2
      PageViewModel(
        title: 'Harvest Rainwater',
        body:
            'Discover how much rainwater you can collect and save. Our AI recommends the best recharge structures for your location.',
        image: _buildImage(Icons.cloud_rounded, AppColors.tealStart),
        decoration: _pageDecoration,
      ),
      // Page 3 — House photo (optional)
      PageViewModel(
        title: 'Your Home, Your Water',
        body:
            'Add a photo of your house to help us personalise your water management experience. This is optional — you can skip it.',
        image: _buildImage(Icons.home_rounded, AppColors.deepAquiferBlue),
        decoration: _pageDecoration,
        footer: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: _buildHousePhotoSection(),
        ),
      ),
      // Page 4 — Device Setup
      PageViewModel(
        title: 'Connect Your Device',
        body: 'Follow the steps below to link your JalDharan sensor.',
        image: _buildImage(Icons.wifi_rounded, AppColors.fieldGreen),
        decoration: _pageDecoration,
        footer: DeviceSetupPage(onSetupComplete: _onDeviceSetupComplete),
      ),
    ];

    // Page 5 only added after device setup completes
    if (_deviceSetupComplete) {
      basePages.add(
        PageViewModel(
          title: _deviceLinked ? 'Sensor Linked! 🎉' : 'Almost There!',
          body: _deviceLinked
              ? 'Your JalDharan sensor is now connected and sending data. You\'re all set to monitor your water!'
              : 'Your sensor wasn\'t detected yet. You can link it later from Settings once it\'s online.',
          image: _buildImage(
            _deviceLinked ? Icons.check_circle_rounded : Icons.sensors_rounded,
            _deviceLinked ? AppColors.fieldGreen : AppColors.warningOrange,
          ),
          decoration: _pageDecoration,
          footer: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                if (_deviceLinked)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.fieldGreen,
                    size: 56,
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _completeOnboarding,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _deviceLinked
                          ? AppColors.fieldGreen
                          : AppColors.deepAquiferBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _deviceLinked
                          ? 'Go to Dashboard'
                          : 'Continue to Dashboard',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return basePages;
  }

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      key: _introKey,
      pages: _pages,
      onDone: _completeOnboarding,
      onSkip: _completeOnboarding,
      showSkipButton: true,
      skip: const Text(
        'Skip',
        style: TextStyle(
          color: AppColors.mediumGrey,
          fontWeight: FontWeight.w600,
        ),
      ),
      next: const Icon(
        Icons.arrow_forward_rounded,
        color: AppColors.deepAquiferBlue,
      ),
      done: const Text(
        'Done',
        style: TextStyle(
          color: AppColors.deepAquiferBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
      dotsDecorator: DotsDecorator(
        size: const Size(8, 8),
        activeSize: const Size(20, 8),
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        activeColor: AppColors.deepAquiferBlue,
        color: AppColors.lightGrey,
      ),
    );
  }

  Widget _buildImage(IconData icon, Color color) {
    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 100, color: color),
      ),
    );
  }

  Widget _buildHousePhotoSection() {
    return Column(
      children: [
        if (_housePhoto != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _housePhoto!,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _pickHousePhoto,
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Change Photo'),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _takeHousePhoto,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Camera'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepAquiferBlue,
                    side: const BorderSide(color: AppColors.deepAquiferBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickHousePhoto,
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: const Text('Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepAquiferBlue,
                    side: const BorderSide(color: AppColors.deepAquiferBlue),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Optional — you can add this later from your profile',
            style: TextStyle(fontSize: 11, color: AppColors.mediumGrey),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
