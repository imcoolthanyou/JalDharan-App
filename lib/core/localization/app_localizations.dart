import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';

class AppLocalizations {
  final String locale;

  AppLocalizations(this.locale);

  static Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Common
      'app_title': 'Jal Dharan',
      'home': 'Home',
      'profile': 'Profile',
      'settings': 'Settings',
      'logout': 'Logout',
      'language': 'Language',
      'language_selector': 'Select Language',
      'english': 'English',
      'hindi': 'Hindi',
      'back': 'Back',
      'close': 'Close',
      'save': 'Save',
      'cancel': 'Cancel',
      'loading': 'Loading...',
      'error': 'Error',
      'success': 'Success',
      'warning': 'Warning',
      'notification': 'Notification',

      // Home Screen
      'current_data': 'Current Data',
      'water_quality': 'Water Quality',
      'water_depth': 'Water Depth',
      'flow_rate': 'Flow Rate',
      'pump_status': 'Pump Status',
      'power_usage': 'Power Usage',
      'estimated_extraction': 'Estimated Extraction',
      'tds_level': 'TDS Level',
      'ph_level': 'pH Level',
      'rainwater_harvesting': 'Rainwater Harvesting',
      'knowledge_hub': 'Knowledge Hub',
      'rain_alert': 'Rain Alert',
      'temperature': 'Temperature',
      'weather_condition': 'Condition',
      'last_updated': 'Last Updated',
      'swipe_up_to_view': 'Swipe Up to View All Details',
      'excellent': 'Excellent',
      'good': 'Good',
      'poor': 'Poor',
      'very_poor': 'Very Poor',
      'safe': 'Safe',
      'normal': 'Normal',
      'off': 'Off',
      'remaining': 'Remaining',

      // Prediction Screen
      'prediction': 'Prediction',
      'future_integration': 'Future Integration',
      'weekly_forecast': 'Weekly Forecast',
      'monthly_forecast': 'Monthly Forecast',
      '30_day_forecast': '30-Day Forecast (AI Predicted)',
      'groundwater_trends': 'Groundwater Trends',
      'current_value': 'Current Value',
      'unit_meter': 'm',
      'unit_lpm': 'L/min',
      'unit_ppm': 'ppm',
      'water_stress_level': 'Water Stress Level',
      'trend': 'Trend',
      'status': 'Status',

      // Rainwater Harvesting
      'rainwater_harvesting_page': 'Rainwater Harvesting',
      'structure_recommendation': 'Structure Recommendation',
      'soil_type': 'Soil Type',
      'aquifer_type': 'Aquifer Type',
      'depth': 'Depth',
      'roof_area': 'Roof Area',
      'open_space': 'Open Space',
      'existing_structure': 'Existing Structure',
      'recommended_structure': 'Recommended Structure',
      'dimensions': 'Dimensions',
      'estimated_cost': 'Estimated Cost',
      'shape': 'Shape',
      'diameter': 'Diameter',
      'volume_capacity': 'Volume Capacity',
      'design_basis': 'Design Basis',
      'reason': 'Reason',

      // Gamification
      'gamification': 'Gamification',
      'leaderboard': 'Leaderboard',
      'your_rank': 'Your Rank',
      'points': 'Points',
      'action': 'Action',
      'actions_to_complete': 'Actions to Complete',
      'take_photo': 'Take Photo',
      'upload_proof': 'Upload Proof',
      'image_verification': 'Image Verification',
      'verification_in_progress': 'Verification in Progress...',
      'verification_result': 'Verification Result',
      'verification_passed': 'Verification Passed',
      'verification_failed': 'Verification Failed',
      'confidence_score': 'Confidence Score',
      'is_real_image': 'Real Image',
      'task_completed': 'Task Completed',
      'response_added': 'Your Response Has Been Added',
      'points_awarded': 'Points Awarded',

      // Analytics
      'analytics': 'Analytics',
      'water_depth_trends': 'Water Depth Trends',
      'water_quality_trends': 'Water Quality Trends',
      'ph_trends': 'pH Level Trends',
      'tds_trends': 'TDS Level Trends',

      // Community
      'community': 'Community',
      'knowledge_base': 'Knowledge Base',
      'map_grid': 'Map Grid',
      'water_score': 'Water Score',
      'community_members': 'Community Members',

      // Settings
      'app_settings': 'App Settings',
      'notifications': 'Notifications',
      'enable_notifications': 'Enable Notifications',
      'about': 'About',
      'version': 'Version',
      'privacy_policy': 'Privacy Policy',
      'terms_conditions': 'Terms & Conditions',

      // Digital Twin
      'quality_indicator': 'Quality',
      'depth_indicator': 'Depth',
      'pump_indicator': 'Pump',

      // Status Messages
      'pump_on': 'Pump On',
      'pump_off': 'Pump Off',
      'online': 'Online',
      'offline': 'Offline',
      'critical': 'Critical',
      'warning_level': 'Warning',
      'optimal': 'Optimal',

      // Units & Measurements
      'meter': 'm',
      'cubic_meter': 'm³',
      'liter_per_minute': 'L/min',
      'ppm': 'ppm',
      'voltage': 'Voltage',
      'voltage_unit': 'V',
      'ampere': 'Current',
      'ampere_unit': 'A',
      'kilowatt': 'Power',
      'kilowatt_unit': 'kW',
      'celsius': '°C',
      'inr': '₹',

      // Digital Twin Indicators
      'quality_meter': 'Quality Meter',
      'depth_meter': 'Depth Meter',
      'pump_meter': 'Pump Status',

      // Session & Flow
      'session': 'Session',
      'session_duration': 'Session Duration',
      'session_info': 'Extracted Session',
      'flow_rate_info': 'Flow Rate',

      // Rainwater Harvesting Descriptions
      'rainwater_harvesting_desc':
          'Collect and store rainwater for sustainable water management',
      'calculate_area': 'Calculate Catchment Area',
      'get_recommendation': 'Get Structure Recommendation',
      'area_based_on_location': 'Calculate area based on your location',

      // Knowledge Hub Descriptions
      'learn_grow': 'Learn & Grow',
      'learn_water_management':
          'Explore expert guides on water management, farming, and conservation.',
      'knowledge_hub_desc':
          'Find expert articles about water conservation and sustainable farming',

      // Prediction Descriptions
      'groundwater_depth_desc': 'Predicted water depth for upcoming period',
      'groundwater_depth_title': 'Groundwater Depth',
      'water_extraction_rate':
          'Expected extraction rate based on current trends',
      'insight': 'Insight',
      'predict_info': 'AI-based prediction of groundwater levels',
      'current': 'CURRENT',
      'predicted': 'PREDICTED',
      'days_7': '7 Days',
      'days_14': '14 Days',
      'days_30': '30 Days',
      'insight_declining':
          'Groundwater levels are predicted to decline over the next 30 days. Consider reducing extraction or implementing water conservation measures.',
      'insight_improving':
          'Groundwater levels are predicted to improve over the next 30 days. Conditions appear favorable for continued extraction.',
      'insight_stable':
          'Groundwater levels are predicted to remain stable over the next 30 days.',

      // Community Map
      'community_map_desc': 'Explore water quality across your community',
      'map_grid_desc': 'View water quality data from neighboring areas',

      // Gamification
      'daily_assignment': 'Daily Assignment',
      'water_hero_desc':
          'Complete tasks and earn points to become a Water Hero',
      'complete_to_earn': 'Complete tasks to earn points',
      'penalty': 'Penalty',
      'penalty_alert': 'PENALTY ALERT',
      'penalty_desc': '-50 pts if daily extraction exceeds 500L.',
      'total_water_points': 'TOTAL WATER POINTS',
      'accept_task': 'Accept Task?',
      'yes': 'Yes',
      'no': 'No',
      'view_all': 'View All',
      'false_image_warning':
          '⚠️ Uploading false or AI-generated images will be instantly detected and will lead to a permanent ban without refund of the security deposit.',
      'leaderboard_title': 'Leaderboard',
      'leaderboard_rank': 'Rank',
      'leaderboard_name': 'Name',
      'leaderboard_points': 'Points',
      'detect_location': 'Detect My Location',
      'task_completed_points': 'Task completed! +{points} points earned',
      'rank_label': 'RANK',
      'level_label': 'Level',
      'level_progress': '{progress}% to Level {next}',

      // Settings Descriptions
      'enable_notifications_desc':
          'Receive updates about water levels and tasks',
      'data_sharing': 'Data Sharing',
      'data_sharing_desc': 'Share your data to help improve predictions',
      'community_updates': 'Community Updates',
      'community_updates_desc':
          'Receive newsletters about community activities related to Jal Dharan',

      // Account Section
      'account': 'Account',
      'about_jal_dharan': 'About Jal Dharan',
      'about_jal_dharan_desc': 'Learn about our mission and vision',
      'privacy_policy_desc': 'Review our privacy practices',
      'terms_desc': 'Read our terms of service',
      'logout_desc': 'Sign out of your account',
      'logout_confirm_title': 'Logout',
      'logout_confirm_message': 'Are you sure you want to logout?',
      'logout_confirm': 'Logout',

      // Jal Shayak
      'jal_shayak': 'Jal Shayak',
      'jal_shayak_help': 'Your Water Conservation Assistant',
      'ask_question': 'Ask your water conservation questions',
      'voice_input': 'Voice Input',
      'listening': 'Listening...',
      'water_health_ai': 'Water Health AI',
      'health_risks': 'Health Risks',
      'sensor_insights': 'Sensor Insights',
      'jal_shayak_greeting':
          'Hello! I\'m Jal Shayak, your water conservation assistant. How can I help you today?',

      // Daily Tasks
      'task_1_title': 'Check pump valves for leaks',
      'task_1_desc':
          'Inspect the main distribution valves in Field #4 to ensure zero wastage.',
      'task_2_title': 'Monitor water level readings',
      'task_2_desc':
          'Check the groundwater depth at monitoring well #2 and record the measurement.',
      'task_3_title': 'Test water quality',
      'task_3_desc':
          'Collect water samples and test pH, TDS, and turbidity levels.',
      'task_4_title': 'Inspect irrigation pipes',
      'task_4_desc':
          'Walk through Field #1-3 to check for any visible leaks or damage in irrigation lines.',
      'task_5_title': 'Record maintenance log',
      'task_5_desc':
          'Update the daily maintenance log with current system status and any issues found.',

      // Proof Upload Dialog
      'upload_proof_desc': 'Provide photo/video evidence for',
      'no_image_selected': 'No image selected',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'submit_proof': 'Submit Proof',
      'ai_analysis': 'AI Analysis',
      'real_image': 'Real Image',
      'confidence': 'Confidence',
      'details': 'Details',
      'try_again': 'Try Again',
      'points_added': '+{points} Water Hero Points Added!',
      'try_again_msg': 'Please try again with a valid photo.',

      // Knowledge Hub
      'no_articles_found': 'No articles found',
      'min_read': 'min read',
      'cat_all': 'All',
      'cat_water_management': 'Water Management',
      'cat_harvesting': 'Harvesting',
      'cat_quality': 'Quality',
      'cat_irrigation': 'Irrigation',
      'cat_soil': 'Soil',
      'cat_planning': 'Planning',
      'article_1_title': 'Groundwater Recharge Techniques',
      'article_1_desc':
          'Learn effective methods to recharge groundwater and improve water availability in your region.',
      'article_2_title': 'Rainwater Harvesting Systems',
      'article_2_desc':
          'Complete guide to designing and implementing rainwater harvesting systems for agricultural use.',
      'article_3_title': 'Water Quality Testing at Home',
      'article_3_desc':
          'Simple methods to test water quality and understand what different measurements mean.',
      'article_4_title': 'Sustainable Irrigation Practices',
      'article_4_desc':
          'Optimize irrigation to reduce water wastage while maintaining crop productivity.',
      'article_5_title': 'Soil Moisture Management',
      'article_5_desc':
          'Understand soil moisture levels and their impact on crop growth and water conservation.',
      'article_6_title': 'Seasonal Water Planning Guide',
      'article_6_desc':
          'Plan water usage for different seasons and prepare for water scarcity periods.',

      // Rainwater Harvesting Page
      'enter_city_address': 'Enter city or address',
      'enter_area': 'Enter area',
      'enter_number': 'Enter number',
      'enter_area_eg': 'Enter area (e.g., 4.0)',
      'recommend_structure': 'Recommend Structure',
      'location_not_found': 'Location not found',
      'no_locations_found': 'No locations found',

      // Structure Recommendation Page
      'recommendation': 'Recommendation',
      'analyzing_data': 'Analyzing geospatial data...',
      'analysis_failed': 'Analysis Failed',
      'try_again': 'Try Again',
      'listen_explanation': 'Listen to Explanation',
      'stop_explanation': 'Stop Explanation',
      'water_savings_analysis': 'Water Savings Analysis',
      'site_analysis': 'Site Analysis',
      'visualize': 'Visualize',
      'view_in_ar': 'View Structure in AR',
      'daily_demand': 'Daily Demand',
      'annual_demand': 'Annual Demand',
      'harvesting_potential': 'Harvesting Potential',
      'of_demand': 'of demand',
      'rainfall_avg': 'Rainfall (Avg)',
      'peak_rainfall': 'Peak Rainfall',
      'soil_type_label': 'Soil Type',
      'aquifer_label': 'Aquifer',
      'groundwater_depth_label': 'Groundwater Depth',
      'feasibility_label': 'Feasibility',
      'auto_detect_location': 'Auto-detect your city and state',
      'roof_area_desc': 'Enter the roof area available for harvesting',
      'dwellers': 'Number of Dwellers',
      'dwellers_desc': 'How many people live in the household?',
      'open_space_desc': 'How much space is available for structure?',
    },
    'hi': {
      // Common
      'app_title': 'जल धरण',
      'home': 'होम',
      'profile': 'प्रोफाइल',
      'settings': 'सेटिंग्स',
      'logout': 'लॉगआउट',
      'language': 'भाषा',
      'language_selector': 'भाषा चुनें',
      'english': 'अंग्रेजी',
      'hindi': 'हिंदी',
      'back': 'पीछे',
      'close': 'बंद करें',
      'save': 'सहेजें',
      'cancel': 'रद्द करें',
      'loading': 'लोड हो रहा है...',
      'error': 'त्रुटि',
      'success': 'सफल',
      'warning': 'चेतावनी',
      'notification': 'सूचना',

      // Home Screen
      'current_data': 'वर्तमान डेटा',
      'water_quality': 'जल गुणवत्ता',
      'water_depth': 'जल गहराई',
      'flow_rate': 'प्रवाह दर',
      'pump_status': 'पंप की स्थिति',
      'power_usage': 'बिजली का उपयोग',
      'estimated_extraction': 'अनुमानित निष्कर्षण',
      'tds_level': 'TDS स्तर',
      'ph_level': 'pH स्तर',
      'rainwater_harvesting': 'वर्षा जल संचयन',
      'knowledge_hub': 'ज्ञान केंद्र',
      'rain_alert': 'बारिश की चेतावनी',
      'temperature': 'तापमान',
      'weather_condition': 'स्थिति',
      'last_updated': 'अंतिम अपडेट',
      'swipe_up_to_view': 'सभी विवरण देखने के लिए ऊपर स्वाइप करें',
      'excellent': 'उत्कृष्ट',
      'good': 'अच्छा',
      'poor': 'खराब',
      'very_poor': 'बहुत खराब',
      'safe': 'सुरक्षित',
      'normal': 'सामान्य',
      'off': 'बंद',
      'remaining': 'शेष',

      // Prediction Screen
      'prediction': 'भविष्यवाणी',
      'future_integration': 'भविष्य एकीकरण',
      'weekly_forecast': 'साप्ताहिक पूर्वानुमान',
      'monthly_forecast': 'मासिक पूर्वानुमान',
      '30_day_forecast': '30-दिन का पूर्वानुमान (AI भविष्यवाणी)',
      'groundwater_trends': 'भूजल प्रवृत्तियां',
      'current_value': 'वर्तमान मूल्य',
      'unit_meter': 'm',
      'unit_lpm': 'L/min',
      'unit_ppm': 'ppm',
      'water_stress_level': 'जल तनाव स्तर',
      'trend': 'प्रवृत्ति',
      'status': 'स्थिति',

      // Rainwater Harvesting
      'rainwater_harvesting_page': 'वर्षा जल संचयन',
      'structure_recommendation': 'संरचना सिफारिश',
      'soil_type': 'मिट्टी का प्रकार',
      'aquifer_type': 'जलवाही स्तर का प्रकार',
      'depth': 'गहराई',
      'roof_area': 'छत का क्षेत्र',
      'open_space': 'खुली जगह',
      'existing_structure': 'मौजूदा संरचना',
      'recommended_structure': 'अनुशंसित संरचना',
      'dimensions': 'आयाम',
      'estimated_cost': 'अनुमानित लागत',
      'shape': 'आकार',
      'diameter': 'व्यास',
      'volume_capacity': 'वॉल्यूम क्षमता',
      'design_basis': 'डिजाइन आधार',
      'reason': 'कारण',

      // Gamification
      'gamification': 'गेमिफिकेशन',
      'leaderboard': 'लीडरबोर्ड',
      'your_rank': 'आपकी रैंक',
      'points': 'अंक',
      'action': 'क्रिया',
      'actions_to_complete': 'पूरी करने के लिए कार्य',
      'take_photo': 'फोटो लें',
      'upload_proof': 'प्रमाण अपलोड करें',
      'image_verification': 'छवि सत्यापन',
      'verification_in_progress': 'सत्यापन प्रगति में है...',
      'verification_result': 'सत्यापन परिणाम',
      'verification_passed': 'सत्यापन पास',
      'verification_failed': 'सत्यापन विफल',
      'confidence_score': 'आत्मविश्वास स्कोर',
      'is_real_image': 'वास्तविक छवि',
      'task_completed': 'कार्य पूर्ण',
      'response_added': 'आपकी प्रतिक्रिया जोड़ी गई है',
      'points_awarded': 'पुरस्कृत अंक',

      // Analytics
      'analytics': 'विश्लेषण',
      'water_depth_trends': 'जल गहराई की प्रवृत्तियां',
      'water_quality_trends': 'जल गुणवत्ता की प्रवृत्तियां',
      'ph_trends': 'pH स्तर की प्रवृत्तियां',
      'tds_trends': 'TDS स्तर की प्रवृत्तियां',

      // Community
      'community': 'समुदाय',
      'knowledge_base': 'ज्ञान आधार',
      'map_grid': 'मानचित्र ग्रिड',
      'water_score': 'जल स्कोर',
      'community_members': 'समुदाय सदस्य',

      // Settings
      'app_settings': 'ऐप सेटिंग्स',
      'notifications': 'सूचनाएं',
      'enable_notifications': 'सूचनाएं सक्षम करें',
      'about': 'परिचय',
      'version': 'संस्करण',
      'privacy_policy': 'गोपनीयता नीति',
      'terms_conditions': 'शर्तें और शर्तें',

      // Digital Twin
      'quality_indicator': 'गुणवत्ता',
      'depth_indicator': 'गहराई',
      'pump_indicator': 'पंप',

      // Status Messages
      'pump_on': 'पंप चालू',
      'pump_off': 'पंप बंद',
      'online': 'ऑनलाइन',
      'offline': 'ऑफलाइन',
      'critical': 'गंभीर',
      'warning_level': 'चेतावनी',
      'optimal': 'इष्टतम',

      // Units & Measurements
      'meter': 'm',
      'cubic_meter': 'm³',
      'liter_per_minute': 'L/min',
      'ppm': 'ppm',
      'voltage': 'वोल्टेज',
      'voltage_unit': 'V',
      'ampere': 'करंट',
      'ampere_unit': 'A',
      'kilowatt': 'पावर',
      'kilowatt_unit': 'kW',
      'celsius': '°C',
      'inr': '₹',

      // Digital Twin Indicators (Hindi)
      'quality_meter': 'गुणवत्ता मीटर',
      'depth_meter': 'गहराई मीटर',
      'pump_meter': 'पंप स्थिति',

      // Session & Flow (Hindi)
      'session': 'सत्र',
      'session_duration': 'सत्र की अवधि',
      'session_info': 'निकाले गए सत्र',
      'flow_rate_info': 'प्रवाह दर',

      // Rainwater Harvesting Descriptions (Hindi)
      'rainwater_harvesting_desc':
          'टिकाऊ जल प्रबंधन के लिए बारिश के पानी को एकत्रित और संग्रहित करें',
      'calculate_area': 'बहाव क्षेत्र की गणना करें',
      'get_recommendation': 'संरचना सिफारिश प्राप्त करें',
      'area_based_on_location': 'अपने स्थान के आधार पर क्षेत्र की गणना करें',

      // Knowledge Hub Descriptions (Hindi)
      'learn_grow': 'सीखें और बढ़ें',
      'learn_water_management':
          'जल प्रबंधन, खेती और संरक्षण पर विशेषज्ञ गाइड देखें।',
      'knowledge_hub_desc':
          'जल संरक्षण और सतत खेती के बारे में विशेषज्ञ लेख खोजें',

      // Prediction Descriptions (Hindi)
      'groundwater_depth_desc': 'आने वाली अवधि के लिए प्रत्याशित जल गहराई',
      'groundwater_depth_title': 'भूजल गहराई',
      'water_extraction_rate':
          'वर्तमान प्रवृत्तियों के आधार पर अपेक्षित निकालने की दर',
      'insight': 'अंतर्दृष्टि',
      'predict_info': 'भूजल स्तर की AI-आधारित भविष्यवाणी',
      'current': 'वर्तमान',
      'predicted': 'पूर्वानुमानित',
      'days_7': '7 दिन',
      'days_14': '14 दिन',
      'days_30': '30 दिन',
      'insight_declining':
          'अगले 30 दिनों में भूजल स्तर घटने का अनुमान है। निष्कर्षण कम करने या जल संरक्षण उपाय अपनाने पर विचार करें।',
      'insight_improving':
          'अगले 30 दिनों में भूजल स्तर में सुधार का अनुमान है। निरंतर निष्कर्षण के लिए परिस्थितियाँ अनुकूल प्रतीत होती हैं।',
      'insight_stable': 'अगले 30 दिनों में भूजल स्तर स्थिर रहने का अनुमान है।',

      // Community Map (Hindi)
      'community_map_desc': 'अपने समुदाय में जल गुणवत्ता देखें',
      'map_grid_desc': 'पड़ोसी क्षेत्रों से जल गुणवत्ता डेटा देखें',

      // Gamification (Hindi)
      'daily_assignment': 'दैनिक कार्य',
      'water_hero_desc':
          'कार्य पूर्ण करें और एक जल नायक बनने के लिए अंक अर्जित करें',
      'complete_to_earn': 'अंक अर्जित करने के लिए कार्य पूर्ण करें',
      'penalty': 'दंड',
      'penalty_alert': 'दंड चेतावनी',
      'penalty_desc': 'यदि दैनिक निष्कर्षण 500L से अधिक हो तो -50 अंक।',
      'total_water_points': 'कुल जल अंक',
      'accept_task': 'कार्य स्वीकार करें?',
      'yes': 'हाँ',
      'no': 'नहीं',
      'view_all': 'सभी देखें',
      'false_image_warning':
          '⚠️ झूठी या AI-जनित छवियाँ अपलोड करने पर तुरंत पता चल जाएगा और सुरक्षा जमा वापस किए बिना स्थायी प्रतिबंध लगाया जाएगा।',
      'leaderboard_title': 'लीडरबोर्ड',
      'leaderboard_rank': 'रैंक',
      'leaderboard_name': 'नाम',
      'leaderboard_points': 'अंक',
      'detect_location': 'मेरी लोकेशन पहचानें',
      'task_completed_points': 'कार्य पूर्ण! +{points} अंक अर्जित',
      'rank_label': 'रैंक',
      'level_label': 'स्तर',
      'level_progress': '{progress}% स्तर {next} तक',

      // Settings Descriptions (Hindi)
      'enable_notifications_desc':
          'जल स्तर और कार्यों के बारे में अपडेट प्राप्त करें',
      'data_sharing': 'डेटा साझाकरण',
      'data_sharing_desc': 'भविष्यवाणियों में सुधार के लिए अपना डेटा साझा करें',
      'community_updates': 'सामुदायिक अपडेट',
      'community_updates_desc':
          'जल धरण से संबंधित सामुदायिक गतिविधियों के बारे में समाचार पत्र प्राप्त करें',

      // Account Section (Hindi)
      'account': 'खाता',
      'about_jal_dharan': 'जल धरण के बारे में',
      'about_jal_dharan_desc': 'हमारे मिशन और दृष्टि के बारे में जानें',
      'privacy_policy_desc': 'हमारी गोपनीयता प्रथाओं की समीक्षा करें',
      'terms_desc': 'हमारी सेवा की शर्तें पढ़ें',
      'logout_desc': 'अपने खाते से साइन आउट करें',
      'logout_confirm_title': 'लॉगआउट',
      'logout_confirm_message': 'क्या आप वाकई लॉगआउट करना चाहते हैं?',
      'logout_confirm': 'लॉगआउट',

      // Jal Shayak (Hindi)
      'jal_shayak': 'जल शायक',
      'jal_shayak_help': 'आपका जल संरक्षण सहायक',
      'ask_question': 'अपने जल संरक्षण प्रश्न पूछें',
      'voice_input': 'वॉयस इनपुट',
      'listening': 'सुन रहे हैं...',
      'water_health_ai': 'जल स्वास्थ्य AI',
      'health_risks': 'स्वास्थ्य जोखिम',
      'sensor_insights': 'सेंसर अंतर्दृष्टि',
      'jal_shayak_greeting':
          'नमस्ते! मैं जल शायक हूँ, आपका जल संरक्षण सहायक। आज मैं आपकी कैसे मदद कर सकता हूँ?',
      // Daily Tasks (Hindi)
      'task_1_title': 'पंप वाल्व में रिसाव की जांच करें',
      'task_1_desc':
          'शून्य बर्बादी सुनिश्चित करने के लिए फील्ड #4 में मुख्य वितरण वाल्व का निरीक्षण करें।',
      'task_2_title': 'जल स्तर रीडिंग की निगरानी करें',
      'task_2_desc':
          'निगरानी कुएं #2 पर भूजल गहराई की जांच करें और माप दर्ज करें।',
      'task_3_title': 'जल गुणवत्ता परीक्षण करें',
      'task_3_desc':
          'पानी के नमूने एकत्र करें और pH, TDS और टर्बिडिटी स्तर का परीक्षण करें।',
      'task_4_title': 'सिंचाई पाइपों का निरीक्षण करें',
      'task_4_desc':
          'सिंचाई लाइनों में किसी भी दृश्यमान रिसाव या क्षति की जांच के लिए फील्ड #1-3 से गुजरें।',
      'task_5_title': 'रखरखाव लॉग दर्ज करें',
      'task_5_desc':
          'वर्तमान सिस्टम स्थिति और किसी भी समस्या के साथ दैनिक रखरखाव लॉग अपडेट करें।',

      // Proof Upload Dialog (Hindi)
      'upload_proof_desc': 'के लिए फोटो/वीडियो प्रमाण प्रदान करें',
      'no_image_selected': 'कोई छवि नहीं चुनी गई',
      'camera': 'कैमरा',
      'gallery': 'गैलरी',
      'submit_proof': 'प्रमाण जमा करें',
      'ai_analysis': 'AI विश्लेषण',
      'real_image': 'वास्तविक छवि',
      'confidence': 'विश्वास',
      'details': 'विवरण',
      'try_again': 'पुनः प्रयास करें',
      'points_added': '+{points} जल नायक अंक जोड़े गए!',
      'try_again_msg': 'कृपया एक वैध फोटो के साथ पुनः प्रयास करें।',

      // Knowledge Hub (Hindi)
      'no_articles_found': 'कोई लेख नहीं मिला',
      'min_read': 'मिनट पढ़ें',
      'cat_all': 'सभी',
      'cat_water_management': 'जल प्रबंधन',
      'cat_harvesting': 'संचयन',
      'cat_quality': 'गुणवत्ता',
      'cat_irrigation': 'सिंचाई',
      'cat_soil': 'मिट्टी',
      'cat_planning': 'योजना',
      'article_1_title': 'भूजल पुनर्भरण तकनीकें',
      'article_1_desc':
          'अपने क्षेत्र में भूजल पुनर्भरण और जल उपलब्धता सुधारने के प्रभावी तरीके जानें।',
      'article_2_title': 'वर्षा जल संचयन प्रणालियाँ',
      'article_2_desc':
          'कृषि उपयोग के लिए वर्षा जल संचयन प्रणालियों को डिजाइन और लागू करने की पूरी गाइड।',
      'article_3_title': 'घर पर जल गुणवत्ता परीक्षण',
      'article_3_desc':
          'जल गुणवत्ता परीक्षण के सरल तरीके और विभिन्न मापों का अर्थ समझें।',
      'article_4_title': 'टिकाऊ सिंचाई प्रथाएं',
      'article_4_desc':
          'फसल उत्पादकता बनाए रखते हुए जल बर्बादी कम करने के लिए सिंचाई को अनुकूलित करें।',
      'article_5_title': 'मिट्टी नमी प्रबंधन',
      'article_5_desc':
          'मिट्टी की नमी के स्तर और फसल वृद्धि व जल संरक्षण पर उनके प्रभाव को समझें।',
      'article_6_title': 'मौसमी जल योजना गाइड',
      'article_6_desc':
          'विभिन्न मौसमों के लिए जल उपयोग की योजना बनाएं और जल की कमी के लिए तैयार रहें।',

      // Rainwater Harvesting Page (Hindi)
      'enter_city_address': 'शहर या पता दर्ज करें',
      'enter_area': 'क्षेत्र दर्ज करें',
      'enter_number': 'संख्या दर्ज करें',
      'enter_area_eg': 'क्षेत्र दर्ज करें (जैसे, 4.0)',
      'recommend_structure': 'संरचना की सिफारिश करें',
      'location_not_found': 'स्थान नहीं मिला',
      'no_locations_found': 'कोई स्थान नहीं मिला',

      // Structure Recommendation Page (Hindi)
      'recommendation': 'सिफारिश',
      'analyzing_data': 'भू-स्थानिक डेटा का विश्लेषण हो रहा है...',
      'analysis_failed': 'विश्लेषण विफल',
      'listen_explanation': 'स्पष्टीकरण सुनें',
      'stop_explanation': 'रोकें',
      'water_savings_analysis': 'जल बचत विश्लेषण',
      'site_analysis': 'साइट विश्लेषण',
      'visualize': 'विज़ुअलाइज़ करें',
      'view_in_ar': 'AR में संरचना देखें',
      'daily_demand': 'दैनिक मांग',
      'annual_demand': 'वार्षिक मांग',
      'harvesting_potential': 'संचयन क्षमता',
      'of_demand': 'मांग का',
      'rainfall_avg': 'वर्षा (औसत)',
      'peak_rainfall': 'अधिकतम वर्षा',
      'soil_type_label': 'मिट्टी का प्रकार',
      'aquifer_label': 'जलभृत',
      'groundwater_depth_label': 'भूजल गहराई',
      'feasibility_label': 'व्यवहार्यता',

      // Additional (Hindi)
      'location': 'स्थान',
      'auto_detect_location': 'अपने शहर और राज्य को ऑटो-डिटेक्ट करें',
      'roof_area_desc': 'फसल के लिए उपलब्ध छत क्षेत्र दर्ज करें',
      'dwellers': 'निवासियों की संख्या',
      'dwellers_desc': 'घर में कितने लोग रहते हैं?',
      'open_space_desc': 'संरचना के लिए कितनी जगह उपलब्ध है?',
    },
  };

  static List<String> languages() => ['en', 'hi'];
  static Map<String, String> languageNames() => {
    'en': 'English',
    'hi': 'हिंदी',
  };

  String get(String key) {
    return _localizedValues[locale]?[key] ?? key;
  }

  static Future<AppLocalizations> load(String locale) async {
    final appLocalizations = AppLocalizations(locale);
    return appLocalizations;
  }

  static AppLocalizations? of(context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'hi'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return AppLocalizations.load(locale.languageCode);
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}
