import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/models/structure_prediction.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/rainwater_prediction_service.dart';
import 'structure_ar_viewer.dart';

class StructureRecommendationScreen extends StatefulWidget {
  final double lat;
  final double lon;
  final double roofAreaSqm;
  final double openSpaceSqm;
  final int numberOfDwellers;
  final String existingStructure;

  const StructureRecommendationScreen({
    super.key,
    required this.lat,
    required this.lon,
    required this.roofAreaSqm,
    required this.openSpaceSqm,
    required this.numberOfDwellers,
    required this.existingStructure,
  });

  @override
  State<StructureRecommendationScreen> createState() =>
      _StructureRecommendationScreenState();
}

class _StructureRecommendationScreenState
    extends State<StructureRecommendationScreen> {
  StructurePrediction? _prediction;
  bool _isLoading = true;
  String? _errorMessage;
  late FlutterTts _flutterTts;
  bool _isSpeaking = false;

  // Placeholder images as requested
  final String _placeholderStructureImage =
      'https://images.unsplash.com/photo-1594488518974-9c049ee48459?auto=format&fit=crop&q=80&w=1000'; // Check dam / water body
  final String _placeholderArImage =
      'https://images.unsplash.com/photo-1633419461186-7d40a2307e29?auto=format&fit=crop&q=80&w=800'; // AR/Tech abstract

  final Map<String, String> _structureImages = {
    'recharge pit with borewell':
        'https://5.imimg.com/data5/SELLER/Default/2021/11/AC/XG/GV/2793594/img-20160710-113917.jpg',
    'check dam / percolation tank':
        'https://5.imimg.com/data5/SELLER/Default/2023/10/354350364/SL/UP/OO/2402236/rain-water-percolation-tank.jpeg',
    'recharge pit':
        'https://5.imimg.com/data5/SELLER/Default/2021/11/AC/XG/GV/2793594/img-20160710-113917.jpg',
    'injection well / recharge shaft':
        'https://live.staticflickr.com/8508/8423016623_ff645c3908_b.jpg',
    'recharge trench':
        'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSPieiBHwD0MOTYjImx5K66biJuhp2FiRtWpw&s',
    'farm pond / storage tank':
        'https://40800710.delivery.rocketcdn.me/wp-content/uploads/2018/11/above-ground-vs-underground-water-storage-tanks-the-pros-and-cons-image-01.jpg',
    'surface storage / gabion structure':
        'https://www.tirupatifence.com/uploaded-files/category/images/thumbs/Gabion-Box-thumbs-500X500.jpg',
  };

  @override
  void initState() {
    super.initState();
    _initTts();
    _fetchPrediction();
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-IN");
    _flutterTts.setPitch(1.0);
    _flutterTts.setSpeechRate(0.5);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speakRecommendation() async {
    if (_prediction == null) return;
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    final text =
        "Based on your inputs, we recommend a ${_prediction!.recommendation.structureType}. ${_prediction!.recommendation.reasoning}";
    await _flutterTts.speak(text);
  }

  Future<void> _fetchPrediction() async {
    try {
      final prediction = await RainwaterPredictionService.predictStructure(
        lat: widget.lat,
        lon: widget.lon,
        roofAreaSqm: widget.roofAreaSqm,
        openSpaceSqm: widget.openSpaceSqm,
        numberOfDwellers: widget.numberOfDwellers,
        existingStructure: widget.existingStructure,
      );

      if (mounted) {
        setState(() {
          _prediction = prediction;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        title: const Text('Recommendation'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGrey),
          onPressed: () {
            _flutterTts.stop();
            Navigator.pop(context);
          },
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.darkGrey,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppColors.deepAquiferBlue),
          SizedBox(height: 16),
          Text(
            'Analyzing geospatial data...',
            style: TextStyle(color: AppColors.mediumGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.warningOrange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Analysis Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mediumGrey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _fetchPrediction();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final recommendation = _prediction!.recommendation;
    final waterSavings = _prediction!.waterSavings;
    final rainfall = _prediction!.rainfallAnalysis;
    final location = _prediction!.locationDetails;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Structure Card
          _buildStructureCard(recommendation),
          const SizedBox(height: 24),

          // 2. Audio Explanation Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _speakRecommendation,
              icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
              label: Text(
                _isSpeaking ? 'Stop Explanation' : 'Listen to Explanation',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSpeaking
                    ? AppColors.warningOrange
                    : AppColors.fieldGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // 3. Water Savings Stats
          _buildSectionTitle('Water Savings Analysis'),
          _buildSavingsCard(waterSavings),
          const SizedBox(height: 24),

          // 4. Rainfall & Location Analysis
          _buildSectionTitle('Site Analysis'),
          _buildEnvironmentCard(rainfall, location),
          const SizedBox(height: 24),

          // 5. AR Structure Viewer
          _buildSectionTitle('Visualize'),
          _buildARCard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStructureCard(Recommendation rec) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(
            _getStructureImage(rec.structureType),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: Colors.grey[200],
              child: const Center(child: Icon(Icons.image_not_supported)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        rec.structureType,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.deepAquiferBlue,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealStart.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.tealStart),
                      ),
                      child: Text(
                        'Feasibility: ${rec.feasibility}',
                        style: const TextStyle(
                          color: AppColors.tealStart,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  rec.reasoning,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.darkGrey,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsCard(WaterSavings savings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Daily Demand',
                  '${savings.dailyConsumptionL.toStringAsFixed(2)} L',
                  Icons.water_drop_outlined,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ), // Divider
              Expanded(
                child: _buildStatItem(
                  'Annual Demand',
                  '${(savings.annualConsumptionL / 1000).toStringAsFixed(2)} kL',
                  Icons.calendar_today,
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Harvesting Potential',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.mediumGrey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(savings.harvestingPotentialL / 1000).toStringAsFixed(2)} kL/yr',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.fieldGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '(${savings.savingsPercentage}% of demand)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.fieldGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: savings.savingsPercentage / 100,
                backgroundColor: Colors.grey[200],
                color: AppColors.fieldGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(
    RainfallAnalysis rain,
    LocationDetails location,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          _buildRow(
            'Rainfall (Avg)',
            '${rain.annualAvgMm.toStringAsFixed(2)} mm/yr',
          ),
          const SizedBox(height: 12),
          _buildRow(
            'Peak Rainfall',
            '${rain.peakRainfallMm.toStringAsFixed(2)} mm',
          ),
          const SizedBox(height: 12),
          _buildRow('Soil Type', location.soilType),
          const SizedBox(height: 12),
          _buildRow('Aquifer', location.aquiferType),
          const SizedBox(height: 12),
          _buildRow('Groundwater Depth', '${location.depthMbgl} m bgl'),
        ],
      ),
    );
  }

  Widget _buildARCard() {
    return GestureDetector(
      onTap: _openARViewer,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(_placeholderArImage),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.4),
              BlendMode.darken,
            ),
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.view_in_ar,
                color: Colors.black,
                size: 48,
              ), // Changed to black
              SizedBox(height: 12),
              Text(
                'View Structure in AR',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openARViewer() {
    if (_prediction == null) return;

    final structureType = _prediction!.recommendation.structureType
        .toLowerCase();
    String modelPath;

    // Determine models based on structure type
    if (structureType.contains('trench')) {
      modelPath = 'assets/recharge_Trench.glb';
    } else {
      // Default fallback for shafts, pits, etc.
      modelPath = 'assets/recharge_shaft_with_pit.glb';
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StructureARViewer(
          modelPath: modelPath,
          title: _prediction!.recommendation.structureType,
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.deepAquiferBlue, size: 20),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.darkGrey,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.mediumGrey),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mediumGrey)),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.darkGrey,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.darkGrey,
        ),
      ),
    );
  }

  String _getStructureImage(String structureType) {
    final normalizedType = structureType.toLowerCase().trim();
    // Check for partial matches or exact keys
    for (final key in _structureImages.keys) {
      if (normalizedType.contains(key)) {
        return _structureImages[key]!;
      }
    }
    return _placeholderStructureImage;
  }
}
