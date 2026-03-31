class StructurePrediction {
  final Recommendation recommendation;
  final WaterSavings waterSavings;
  final RainfallAnalysis rainfallAnalysis;
  final LocationDetails locationDetails;
  final String status;

  StructurePrediction({
    required this.recommendation,
    required this.waterSavings,
    required this.rainfallAnalysis,
    required this.locationDetails,
    required this.status,
  });

  factory StructurePrediction.fromJson(Map<String, dynamic> json) {
    return StructurePrediction(
      recommendation: Recommendation.fromJson(json['recommendation'] ?? {}),
      waterSavings: WaterSavings.fromJson(json['water_savings'] ?? {}),
      rainfallAnalysis: RainfallAnalysis.fromJson(
        json['rainfall_analysis'] ?? {},
      ),
      locationDetails: LocationDetails.fromJson(json['location_details'] ?? {}),
      status: json['status'] ?? 'unknown',
    );
  }
}

class Recommendation {
  final String structureType;
  final String reasoning;
  final String feasibility;

  Recommendation({
    required this.structureType,
    required this.reasoning,
    required this.feasibility,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      structureType: json['structure_type'] ?? '',
      reasoning: json['reasoning'] ?? '',
      feasibility: json['feasibility'] ?? '',
    );
  }
}

class WaterSavings {
  final double dailyConsumptionL;
  final double annualConsumptionL;
  final double harvestingPotentialL;
  final PotentialBreakdown potentialBreakdown;
  final double gapL;
  final double savingsPercentage;
  final String runoffCoefficientUsed;
  final int standardLpcd;

  WaterSavings({
    required this.dailyConsumptionL,
    required this.annualConsumptionL,
    required this.harvestingPotentialL,
    required this.potentialBreakdown,
    required this.gapL,
    required this.savingsPercentage,
    required this.runoffCoefficientUsed,
    required this.standardLpcd,
  });

  factory WaterSavings.fromJson(Map<String, dynamic> json) {
    return WaterSavings(
      dailyConsumptionL: (json['daily_consumption_L'] ?? 0).toDouble(),
      annualConsumptionL: (json['annual_consumption_L'] ?? 0).toDouble(),
      harvestingPotentialL: (json['harvesting_potential_L'] ?? 0).toDouble(),
      potentialBreakdown: PotentialBreakdown.fromJson(
        json['potential_breakdown'] ?? {},
      ),
      gapL: (json['gap_L'] ?? 0).toDouble(),
      savingsPercentage: (json['savings_percentage'] ?? 0).toDouble(),
      runoffCoefficientUsed: json['runoff_coefficient_used'] ?? '',
      standardLpcd: json['standard_lpcd'] ?? 0,
    );
  }
}

class PotentialBreakdown {
  final double roof;
  final double openSpace;

  PotentialBreakdown({required this.roof, required this.openSpace});

  factory PotentialBreakdown.fromJson(Map<String, dynamic> json) {
    return PotentialBreakdown(
      roof: (json['roof'] ?? 0).toDouble(),
      openSpace: (json['open_space'] ?? 0).toDouble(),
    );
  }
}

class RainfallAnalysis {
  final double annualAvgMm;
  final double peakRainfallMm;
  final String dataSource;

  RainfallAnalysis({
    required this.annualAvgMm,
    required this.peakRainfallMm,
    required this.dataSource,
  });

  factory RainfallAnalysis.fromJson(Map<String, dynamic> json) {
    return RainfallAnalysis(
      annualAvgMm: (json['annual_avg_mm'] ?? 0).toDouble(),
      peakRainfallMm: (json['peak_rainfall_mm'] ?? 0).toDouble(),
      dataSource: json['data_source'] ?? '',
    );
  }
}

class LocationDetails {
  final String soilType;
  final String aquiferType;
  final double depthMbgl;
  final String message;
  final String usedSoilType;
  final String usedAquiferType;
  final double usedDepthM;

  LocationDetails({
    required this.soilType,
    required this.aquiferType,
    required this.depthMbgl,
    required this.message,
    required this.usedSoilType,
    required this.usedAquiferType,
    required this.usedDepthM,
  });

  factory LocationDetails.fromJson(Map<String, dynamic> json) {
    return LocationDetails(
      soilType: json['soil_type'] ?? '',
      aquiferType: json['aquifer_type'] ?? '',
      depthMbgl: (json['depth_mbgl'] ?? 0).toDouble(),
      message: json['message'] ?? '',
      usedSoilType: json['used_soil_type'] ?? '',
      usedAquiferType: json['used_aquifer_type'] ?? '',
      usedDepthM: (json['used_depth_m'] ?? 0).toDouble(),
    );
  }
}
