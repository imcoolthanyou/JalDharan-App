# Requirements Document

## Introduction

This feature addresses two areas of the Jal Dharan Flutter app:

1. **Localization Completeness** — Several screens and UI sections display hardcoded English strings instead of using the `AppLocalizations` lookup. When the user switches language to Hindi, those strings remain in English. Additionally, switching language currently navigates the user back to the home page instead of staying on the current screen.

2. **Jal Shayak Integration** — The `jal_shayak` folder contains a fully-built AI chat assistant screen that is currently hidden. The user wants it surfaced as a floating overlay on the bottom-left of the home page, and wants voice-to-text (speech-to-text) input to be confirmed working inside the overlay.

---

## Glossary

- **App**: The Jal Dharan Flutter application.
- **AppLocalizations**: The in-app localization class (`lib/core/localization/app_localizations.dart`) that maps string keys to English or Hindi values.
- **LanguageProvider**: The `ChangeNotifier` (`lib/core/providers/language_provider.dart`) that stores and broadcasts the active locale.
- **HomeScreen**: The main dashboard screen (`lib/presentation/screens/home/home_screen.dart`).
- **HomeDigitalTwin**: The 3D digital-twin overlay widget (`lib/presentation/screens/home/homedigitaltwin_clean.dart`) rendered at the top of HomeScreen.
- **RainwaterHarvestingScreen**: The screen at `lib/presentation/screens/rainwater_harvesting/rainwater_harvesting_screen.dart`.
- **KnowledgeHubScreen**: The screen at `lib/presentation/screens/knowledge_hub/knowledge_hub_screen.dart`.
- **AnalyticsScreen**: The prediction/analytics screen at `lib/presentation/screens/analytics/analytics_screen.dart`.
- **MapGrindScreen**: The community map screen at `lib/presentation/screens/map_grind/map_grind_screen.dart`.
- **WaterHeroScreen**: The gamification screen at `lib/presentation/screens/gamification/water_hero_screen.dart`.
- **CommunitySettingsScreen**: The app settings screen at `lib/presentation/screens/community_settings/community_settings_screen.dart`.
- **JalShayakOverlay**: The floating chat widget at `lib/presentation/widgets/jal_shayak_overlay.dart`.
- **JalShayakScreen**: The full-page chat screen at `lib/presentation/screens/jal_shayak/jal_shayak_screen.dart`.
- **SpeechToText**: The `speech_to_text` Flutter package already integrated in `JalShayakOverlay`.
- **Locale**: An `en` (English) or `hi` (Hindi) language code.
- **Hardcoded string**: A string literal in Dart widget code that is not routed through `AppLocalizations.get()`.

---

## Requirements

### Requirement 1: Language Switch — Stay on Current Page

**User Story:** As a user, I want to stay on the same screen when I change the app language, so that I do not lose my place in the app.

#### Acceptance Criteria

1. WHEN the user selects a new Locale from `LanguageSelectorButton` or `LanguageSelectorDialog`, THE App SHALL rebuild the current screen in the new Locale without navigating away from it.
2. WHEN `LanguageProvider.changeLanguage` is called, THE App SHALL NOT push or replace any route on the navigation stack.
3. WHILE the user is on any screen other than HomeScreen, WHEN the language is changed, THE App SHALL remain on that screen and re-render all localised strings in the new Locale.
4. THE `LanguageProvider` SHALL persist the selected Locale to `SharedPreferences` so the choice survives app restarts.

---

### Requirement 2: HomeDigitalTwin — Translate Overlay Labels

**User Story:** As a user, I want the sensor labels in the 3D digital-twin overlay to appear in my chosen language, so that I can read them without switching back to English.

#### Acceptance Criteria

1. THE `HomeDigitalTwin` SHALL display the water-quality label using `AppLocalizations.get('quality_indicator')`.
2. THE `HomeDigitalTwin` SHALL display the water-depth label using `AppLocalizations.get('depth_indicator')`.
3. THE `HomeDigitalTwin` SHALL display the pump-status label using `AppLocalizations.get('pump_indicator')`.
4. WHEN the Locale changes to Hindi, THE `HomeDigitalTwin` SHALL re-render all three overlay labels in Hindi without requiring a page reload.

---

### Requirement 3: HomeScreen — Translate All Hardcoded Strings

**User Story:** As a user, I want every text element on the home page to appear in my chosen language, so that the experience is fully localised.

#### Acceptance Criteria

1. THE `HomeScreen` SHALL display the water-quality section header using `AppLocalizations.get('water_quality')`.
2. THE `HomeScreen` SHALL display the voltage parameter card label using `AppLocalizations.get('voltage')`.
3. THE `HomeScreen` SHALL display the current (ampere) parameter card label using `AppLocalizations.get('ampere')`.
4. THE `HomeScreen` SHALL display the session label in the extraction card using `AppLocalizations.get('session')`.
5. THE `HomeScreen` SHALL display the flow-rate label in the extraction card using `AppLocalizations.get('flow_rate_info')`.
6. THE `HomeScreen` SHALL display the rainwater-harvesting button description using `AppLocalizations.get('rainwater_harvesting_desc')`.
7. THE `HomeScreen` SHALL display the knowledge-hub button description using `AppLocalizations.get('knowledge_hub_desc')`.
8. WHEN the Locale changes, THE `HomeScreen` SHALL re-render all translated strings immediately without navigation.

---

### Requirement 4: RainwaterHarvestingScreen — Full Translation

**User Story:** As a user, I want the entire Rainwater Harvesting page to appear in my chosen language, so that I can understand all instructions and labels.

#### Acceptance Criteria

1. THE `RainwaterHarvestingScreen` SHALL display all section titles using the corresponding `AppLocalizations` keys (`roof_area`, `open_space`, `location`, `dwellers`).
2. THE `RainwaterHarvestingScreen` SHALL display all section subtitles and descriptions using the corresponding `AppLocalizations` keys (`rainwater_harvesting_desc`, `area_based_on_location`, `roof_area_desc`, `dwellers_desc`, `open_space_desc`).
3. THE `RainwaterHarvestingScreen` SHALL display the recommend-structure button label using `AppLocalizations.get('get_recommendation')`.
4. THE `RainwaterHarvestingScreen` SHALL display the calculate-area button label using `AppLocalizations.get('calculate_area')`.
5. WHEN the Locale changes, THE `RainwaterHarvestingScreen` SHALL re-render all translated strings in the new Locale.

---

### Requirement 5: KnowledgeHubScreen — Full Translation

**User Story:** As a user, I want the Knowledge Hub page to appear in my chosen language, so that I can navigate and read article metadata in Hindi.

#### Acceptance Criteria

1. THE `KnowledgeHubScreen` SHALL display the page header using `AppLocalizations.get('learn_grow')`.
2. THE `KnowledgeHubScreen` SHALL display the page description using `AppLocalizations.get('learn_water_management')`.
3. THE `KnowledgeHubScreen` SHALL display the app-bar title using `AppLocalizations.get('knowledge_hub')`.
4. WHEN the Locale changes, THE `KnowledgeHubScreen` SHALL re-render all translated strings in the new Locale.

---

### Requirement 6: AnalyticsScreen (Prediction Page) — Full Translation

**User Story:** As a user, I want the Prediction page descriptions and insight section to appear in my chosen language, so that I can understand groundwater forecasts in Hindi.

#### Acceptance Criteria

1. THE `AnalyticsScreen` SHALL display the groundwater-trends section title using `AppLocalizations.get('groundwater_trends')`.
2. THE `AnalyticsScreen` SHALL display the prediction description using `AppLocalizations.get('predict_info')`.
3. THE `AnalyticsScreen` SHALL display the insight section heading using `AppLocalizations.get('insight')`.
4. THE `AnalyticsScreen` SHALL display the insight body text using the appropriate `AppLocalizations` key for the trend direction.
5. THE `AnalyticsScreen` SHALL display the prediction-box day labels using `AppLocalizations` keys where applicable.
6. WHEN the Locale changes, THE `AnalyticsScreen` SHALL re-render all translated strings in the new Locale.

---

### Requirement 7: MapGrindScreen — Translate Title Section Description

**User Story:** As a user, I want the community map page header description to appear in my chosen language, so that the page is fully localised.

#### Acceptance Criteria

1. THE `MapGrindScreen` SHALL display the community title using `AppLocalizations.get('community')`.
2. THE `MapGrindScreen` SHALL display the header description using `AppLocalizations.get('community_map_desc')`.
3. WHEN the Locale changes, THE `MapGrindScreen` SHALL re-render the header section in the new Locale.

---

### Requirement 8: WaterHeroScreen (Gamification) — Full Translation

**User Story:** As a user, I want the entire Gamification page to appear in my chosen language, so that I can understand tasks, rankings, and points in Hindi.

#### Acceptance Criteria

1. THE `WaterHeroScreen` SHALL display the app-bar title using `AppLocalizations.get('gamification')`.
2. THE `WaterHeroScreen` SHALL display the daily-assignment section heading using `AppLocalizations.get('daily_assignment')`.
3. THE `WaterHeroScreen` SHALL display the your-rank section heading using `AppLocalizations.get('your_rank')`.
4. THE `WaterHeroScreen` SHALL display the penalty alert heading using `AppLocalizations.get('penalty')`.
5. THE `WaterHeroScreen` SHALL display the hero-card description using `AppLocalizations.get('water_hero_desc')`.
6. THE `WaterHeroScreen` SHALL display task accept/decline button labels using `AppLocalizations` keys.
7. WHEN the Locale changes, THE `WaterHeroScreen` SHALL re-render all translated strings in the new Locale.

---

### Requirement 9: CommunitySettingsScreen (App Settings) — Full Translation

**User Story:** As a user, I want every description and label on the App Settings page to appear in my chosen language, so that I can configure the app in Hindi.

#### Acceptance Criteria

1. THE `CommunitySettingsScreen` SHALL display all toggle-tile titles and descriptions using the corresponding `AppLocalizations` keys (`notifications`, `enable_notifications_desc`, `data_sharing`, `data_sharing_desc`, `community_updates`, `community_updates_desc`).
2. THE `CommunitySettingsScreen` SHALL display the About section button subtitles using `AppLocalizations` keys.
3. THE `CommunitySettingsScreen` SHALL display the Account section title using `AppLocalizations.get('logout')` and related keys.
4. WHEN the Locale changes, THE `CommunitySettingsScreen` SHALL re-render all translated strings in the new Locale without navigating away.

---

### Requirement 10: Jal Shayak Overlay — Visible on Home Page

**User Story:** As a user, I want to see the Jal Shayak AI assistant as a floating button on the bottom-left of the home page, so that I can access it without navigating away.

#### Acceptance Criteria

1. THE `HomeScreen` SHALL render `JalShayakOverlay` as a `Positioned` widget in the bottom-left corner of the screen stack.
2. WHILE the overlay is in its collapsed state, THE `JalShayakOverlay` SHALL display a circular button with the Jal Shayak icon and label.
3. WHEN the user taps the collapsed `JalShayakOverlay`, THE overlay SHALL expand to show the chat interface.
4. WHEN the user taps the close button in the expanded `JalShayakOverlay`, THE overlay SHALL collapse back to the button state.
5. THE `JalShayakOverlay` SHALL be visible on the home page at all times, including while the digital-twin section is displayed.

---

### Requirement 11: Jal Shayak Overlay — Voice-to-Text Input

**User Story:** As a user, I want to speak my question to Jal Shayak instead of typing it, so that I can interact with the assistant hands-free.

#### Acceptance Criteria

1. THE `JalShayakOverlay` SHALL display a microphone button in the chat input area.
2. WHEN the user taps the microphone button, THE `JalShayakOverlay` SHALL request microphone permission if not already granted.
3. IF microphone permission is denied, THEN THE `JalShayakOverlay` SHALL display a snackbar informing the user that microphone access is required.
4. WHEN microphone permission is granted and the user taps the microphone button, THE `SpeechToText` service SHALL begin listening and populate the text field with recognised words in real time.
5. WHEN `SpeechToText` returns a final result, THE `JalShayakOverlay` SHALL automatically send the recognised text as a message after a 500 ms delay.
6. WHILE `SpeechToText` is listening, THE microphone button SHALL display a visual indicator (red colour) to show active recording.
7. WHEN the user taps the microphone button a second time while listening, THE `SpeechToText` service SHALL stop listening.
8. THE `JalShayakOverlay` SHALL display the Jal Shayak title and subtitle using `AppLocalizations` keys (`jal_shayak`, `jal_shayak_help`) so they translate with the active Locale.
