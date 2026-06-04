import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/models/rainwater_harvesting_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/localization/app_localizations.dart';
import '../../widgets/rainwater_harvesting_widgets.dart';
import 'structure_recommendation_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'area_calculator_map.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../../../core/services/location_service.dart';

class RainwaterHarvestingScreen extends StatefulWidget {
  const RainwaterHarvestingScreen({super.key});

  @override
  State<RainwaterHarvestingScreen> createState() =>
      _RainwaterHarvestingScreenState();
}

class _RainwaterHarvestingScreenState extends State<RainwaterHarvestingScreen> {
  late RainwaterHarvestingData _data;
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _roofAreaController =
      TextEditingController(); // renamed for clarity
  final TextEditingController _dwellersController = TextEditingController();
  bool _isFetchingLocation = false;
  double? _lat;
  double? _lon;

  double _openSpaceSqm = 4.0; // This remains in sqm as it's a separate input

  // Conversion factor from square meters to square feet
  static const double _sqmToSqft = 10.7639;

  @override
  void initState() {
    super.initState();
    _data = RainwaterHarvestingData.mockData();
    // Reset catchment area to 0 – no pre‑filled value
    _data = RainwaterHarvestingData(
      source: _data.source,
      soilType: _data.soilType,
      catchmentArea: 0.0,
      selectedSoilImage: _data.selectedSoilImage,
    );
    _roofAreaController.text = ''; // start empty
  }

  @override
  void dispose() {
    _locationController.dispose();
    _roofAreaController.dispose();
    _dwellersController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isFetchingLocation = true;
    });

    try {
      var status = await Permission.location.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to fetch address'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location services are disabled.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _lat = position.latitude;
        _lon = position.longitude;
      });

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        // Try to find the most accurate placemark (prefer one with locality)
        Placemark place = placemarks.firstWhere(
          (p) => p.locality != null && p.locality!.isNotEmpty,
          orElse: () => placemarks.first,
        );
        String city =
            place.locality ?? place.subAdministrativeArea ?? place.name ?? '';
        String state = place.administrativeArea ?? '';
        String address = [
          city,
          state,
        ].where((element) => element.isNotEmpty).join(', ');

        if (mounted) setState(() => _locationController.text = address);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location fetched: $address'),
              backgroundColor: AppColors.fieldGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isFetchingLocation = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        setState(() {
          _lat = loc.latitude;
          _lon = loc.longitude;
        });

        // Also fetch address to standardize it
        List<Placemark> placemarks = await placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String city = place.locality ?? place.subAdministrativeArea ?? '';
          String state = place.administrativeArea ?? '';
          String address = [
            city,
            state,
          ].where((element) => element.isNotEmpty).join(', ');
          _locationController.text = address.isNotEmpty ? address : query;
        } else {
          _locationController.text = query;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Location found: ${_locationController.text}'),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Location not found')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error searching: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  void _openAreaCalculator() async {
    // Use current location (searched or GPS) or default to New Delhi
    final defaultLocation = _lat != null && _lon != null
        ? LatLng(_lat!, _lon!)
        : const LatLng(28.6139, 77.2090);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AreaCalculatorMap(
          onAreaCalculated: (areaInSqft, location) async {
            setState(() {
              _roofAreaController.text = areaInSqft.toStringAsFixed(1);
              _data = RainwaterHarvestingData(
                source: _data.source,
                soilType: _data.soilType,
                catchmentArea: areaInSqft, // store in sqft
                selectedSoilImage: _data.selectedSoilImage,
              );

              _lat = location.latitude;
              _lon = location.longitude;
            });

            // Fetch address for the new location
            try {
              List<Placemark> placemarks = await placemarkFromCoordinates(
                location.latitude,
                location.longitude,
              );

              if (placemarks.isNotEmpty) {
                Placemark place = placemarks.first;
                String city =
                    place.locality ?? place.subAdministrativeArea ?? '';
                String state = place.administrativeArea ?? '';
                String address = [
                  city,
                  state,
                ].where((e) => e.isNotEmpty).join(', ');

                setState(() {
                  _locationController.text = address;
                });
              }
            } catch (e) {
              // Ignore geocoding errors, we have coordinates
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Area: ${areaInSqft.toStringAsFixed(1)} sqft, Location updated',
                  ),
                  backgroundColor: AppColors.fieldGreen,
                ),
              );
            }
          },
          initialPosition: defaultLocation,
          title: 'Calculate Roof Area',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: RWHAppBar(
        title: AppLocalizations.of(context)!.get('rainwater_harvesting'),
        onBackPressed: () => Navigator.pop(context),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Location Section
              SectionTitle(
                title: AppLocalizations.of(context)!.get('location'),
                subtitle: AppLocalizations.of(
                  context,
                )!.get('area_based_on_location'),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TypeAheadField<LocationSuggestion>(
                  controller: _locationController,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: _searchLocation,
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!.get('enter_city_address'),
                        hintStyle: const TextStyle(color: AppColors.mediumGrey),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        suffixIcon: IconButton(
                          icon: _isFetchingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.fieldGreen,
                                  ),
                                )
                              : const Icon(
                                  Icons.search,
                                  color: AppColors.fieldGreen,
                                ),
                          onPressed: () =>
                              _searchLocation(_locationController.text),
                        ),
                      ),
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.length < 3) return [];
                    return await LocationService.getSuggestions(pattern);
                  },
                  itemBuilder: (context, suggestion) {
                    return ListTile(
                      title: Text(suggestion.displayName),
                      leading: const Icon(
                        Icons.location_on,
                        size: 20,
                        color: AppColors.mediumGrey,
                      ),
                    );
                  },
                  onSelected: (suggestion) {
                    _locationController.text = suggestion.displayName;
                    setState(() {
                      _lat = suggestion.lat;
                      _lon = suggestion.lon;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Location selected: ${suggestion.displayName}',
                        ),
                        backgroundColor: AppColors.fieldGreen,
                      ),
                    );
                  },
                  emptyBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      AppLocalizations.of(context)!.get('no_locations_found'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // GPS detect location button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isFetchingLocation ? null : _getCurrentLocation,
                  icon: _isFetchingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded, size: 18),
                  label: Text(
                    AppLocalizations.of(context)!.get('detect_location'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
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
              // Show coordinates when available
              if (_lat != null && _lon != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.fieldGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.fieldGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 14,
                        color: AppColors.fieldGreen,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${_locationController.text.isNotEmpty ? _locationController.text : "Location detected"} (${_lat!.toStringAsFixed(4)}, ${_lon!.toStringAsFixed(4)})',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.fieldGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),

              // Roof Area Section (was Catchment Area)
              SectionTitle(
                title: AppLocalizations.of(context)!.get('roof_area'),
                subtitle: AppLocalizations.of(
                  context,
                )!.get('rainwater_harvesting_desc'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Text field container
                  Container(
                    width: 200,

                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _roofAreaController,
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final area = double.tryParse(value) ?? 0.0;
                        setState(() {
                          _data = RainwaterHarvestingData(
                            source: _data.source,
                            soilType: _data.soilType,
                            catchmentArea: area, // stored in sqft
                            selectedSoilImage: _data.selectedSoilImage,
                          );
                        });
                      },
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!.get('enter_area'),
                        hintStyle: const TextStyle(color: AppColors.mediumGrey),
                        border: InputBorder.none,
                        suffixText: 'sqft', // changed from m²
                        suffixStyle: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Map icon button
                  InkWell(
                    onTap: _openAreaCalculator,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.fieldGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.map, color: AppColors.fieldGreen),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Number of Dwellers Section
              SectionTitle(
                title: AppLocalizations.of(context)!.get('dwellers'),
                subtitle: AppLocalizations.of(context)!.get('dwellers_desc'),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _dwellersController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.get('enter_number'),
                    hintStyle: const TextStyle(color: AppColors.mediumGrey),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Open Space Section (still in sqm – kept as is)
              SectionTitle(
                title: AppLocalizations.of(context)!.get('open_space'),
                subtitle: AppLocalizations.of(context)!.get('open_space_desc'),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      _openSpaceSqm = double.tryParse(value) ?? 4.0;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(
                      context,
                    )!.get('enter_area_eg'),
                    hintStyle: TextStyle(color: AppColors.mediumGrey),
                    border: InputBorder.none,
                    suffixText: 'sq.ft',
                    suffixStyle: TextStyle(
                      color: AppColors.mediumGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Recommend Button
              PrimaryButton(
                label: AppLocalizations.of(context)!.get('recommend_structure'),
                icon: Icons.water_drop,
                onPressed: () async {
                  // 1. Auto-fetch location if missing
                  if (_lat == null || _lon == null) {
                    await _getCurrentLocation();
                  }

                  // 2. Validate Inputs
                  final roofArea =
                      double.tryParse(_roofAreaController.text) ?? 0.0;
                  final dwellers = int.tryParse(_dwellersController.text) ?? 0;

                  if (_lat == null || _lon == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please fetch your location first'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (roofArea <= 0) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid roof area (> 0)'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  if (dwellers <= 0) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid number of dwellers (> 0)',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // 3. User requested check: Roof Area vs Open Space
                  // Warning if Roof Area is significantly larger than Open Space (just a heuristic check)
                  // converting _openSpaceSqm (which is in sqm) to sqft for comparison with roofArea (sqft)
                  double openSpaceSqft = _openSpaceSqm * _sqmToSqft;
                  if (roofArea > openSpaceSqft) {
                    // Check if this is a blocking condition or just a warning?
                    // User said "basic check... will be fine".
                    // Let's show a warning snackbar but allow proceeding, or block?
                    // "if roof size is less than open space" -> implies this is the DESIRED state.
                    // So if roof > open space, it might be an issue.
                    // I'll block it for now based on "check for the page".

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Roof area cannot be larger than available open space.',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  // Prepare and print the data payload
                  final payload = {
                    'lat': _lat,
                    'lon': _lon,
                    'roof_area_sqm': _data.catchmentArea / _sqmToSqft,
                    'open_space_sqm': _openSpaceSqm / _sqmToSqft,
                    'existing_structure': 'None',
                    'number_of_dwellers': dwellers,
                  };
                  log('Data sending to backend: ${jsonEncode(payload)}');

                  if (!context.mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StructureRecommendationScreen(
                        lat: _lat!,
                        lon: _lon!,
                        roofAreaSqm:
                            _data.catchmentArea /
                            _sqmToSqft, // convert sqft to sqm
                        openSpaceSqm:
                            _openSpaceSqm / _sqmToSqft, // convert sqft to sqm
                        numberOfDwellers: dwellers,
                        existingStructure: 'None',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
