# Design Document: Localization Completeness & Jal Shayak Integration

## Overview

This design covers two related improvements to the Jal Dharan Flutter app:

1. **Localization fixes** — Replace all remaining hardcoded English strings across 8 screens with `AppLocalizations.get()` calls, and fix the language-switch behavior so the user stays on their current screen instead of being navigated away.

2. **Jal Shayak overlay** — Surface the existing `JalShayakOverlay` widget on the home page as a floating bottom-left button, and confirm the voice-to-text (speech_to_text) integration is working correctly.

Both areas are purely additive changes to existing code. No new packages are required — `speech_to_text` and `flutter_tts` are already declared in `pubspec.yaml` and used inside `jal_shayak_overlay.dart`.

---

## Architecture

### Locale Switching — Root Cause

The app uses `Consumer<LanguageProvider>` at the `MaterialApp` level in `main.dart`. When `LanguageProvider.changeLanguage()` is called, `notifyListeners()` triggers a rebuild of `MaterialApp` with the new `locale:`. Flutter's `Localizations` widget propagates the new locale down the tree, causing every widget that reads `AppLocalizations.of(context)` to rebuild in place.

**The current bug**: `LanguageSelectorDialog` calls `Navigator.pop(context)` *before* calling `changeLanguage`. This is correct. However, some call sites (not yet identified in the codebase but implied by the requirements) may be calling `Navigator.pushReplacementNamed(context, '/home')` after a language change, which resets the stack. The fix is to ensure no navigation side-effects exist in any language-change callback.

Because `MainNavigationScreen` uses `IndexedStack`, all five tab screens are kept alive. When the locale changes, each screen rebuilds in place — no navigation is needed. The fix is purely about removing any erroneous `Navigator` calls from language-change handlers.

### Localization Pattern

All screens already import `app_localizations.dart`. The pattern to apply uniformly is:

```dart
// Before (hardcoded)
Text('Voltage')

// After (localized)
Text(AppLocalizations.of(context)!.get('voltage'))
```

All required keys already exist in both `en` and `hi` maps inside `app_localizations.dart`. No new keys need to be added.

### Jal Shayak Overlay Placement

`HomeScreen.build()` returns a `Stack` as its root widget. The `JalShayakOverlay` widget already contains its own `Positioned` wrapper (it renders itself as `Positioned(bottom: 20, left: 16, ...)`). It must be added as a child of the `Stack` in `HomeScreen`.

Currently the home screen `Stack` has a comment placeholder `// Jal Shayak Overlay` but the widget is not actually inserted. The fix is to add `const JalShayakOverlay()` as the last child of that `Stack`.

---

## Components and Interfaces

### LanguageProvider (`lib/core/providers/language_provider.dart`)

No changes needed. `changeLanguage()` already:
- Updates `_currentLanguage`
- Persists to `SharedPreferences`
- Calls `notifyListeners()`

The `Consumer<LanguageProvider>` at `MaterialApp` level already handles locale propagation correctly.

### LanguageSelectorButton / LanguageSelectorDialog (`lib/presentation/widgets/language_selector.dart`)

Audit both widgets to confirm no `Navigator.push/replace` calls exist after `changeLanguage`. The `LanguageSelectorDialog` currently calls `Navigator.pop(context)` then `changeLanguage` — this is correct and should be preserved.

### HomeScreen (`lib/presentation/screens/home/home_screen.dart`)

Changes:
1. Replace hardcoded `'Voltage'` → `AppLocalizations.of(context)!.get('voltage')`
2. Replace hardcoded `'Current'` → `AppLocalizations.of(context)!.get('ampere')`
3. Replace hardcoded `'Session'` → `AppLocalizations.of(context)!.get('session')`
4. Replace hardcoded `'Flow Rate'` (in extraction card) → `AppLocalizations.of(context)!.get('flow_rate_info')`
5. Replace hardcoded `'Learn about structure & setup'` → `AppLocalizations.of(context)!.get('rainwater_harvesting_desc')`
6. Replace hardcoded `'Explore educational resources'` → `AppLocalizations.of(context)!.get('knowledge_hub_desc')`
7. Add `const JalShayakOverlay()` as the last child of the root `Stack`

### HomeDigitalTwin (`lib/presentation/screens/home/homedigitaltwin_clean.dart`)

Already uses `AppLocalizations` for all three overlay labels (`quality_indicator`, `depth_indicator`, `pump_indicator`). No changes needed — this screen is already compliant.

### AnalyticsScreen (`lib/presentation/screens/analytics/analytics_screen.dart`)

Changes:
1. Replace hardcoded `'Insight'` → `AppLocalizations.of(context)!.get('insight')`
2. Replace hardcoded `'7 Days'`, `'14 Days'`, `'30 Days'` in `_buildPredictionBox` → `AppLocalizations` keys or formatted strings
3. Replace hardcoded insight body strings with `AppLocalizations` keys based on trend direction
4. Replace hardcoded `'CURRENT'` / `'PREDICTED'` legend labels → `AppLocalizations` keys (add `current` and `predicted` keys if missing, or use existing `current_value` / `prediction`)

### KnowledgeHubScreen (`lib/presentation/screens/knowledge_hub/knowledge_hub_screen.dart`)

Already uses `AppLocalizations` for `knowledge_hub`, `learn_grow`, and `learn_water_management`. No changes needed — this screen is already compliant.

### MapGrindScreen (`lib/presentation/screens/map_grind/map_grind_screen.dart`)

Already uses `AppLocalizations` for `community` and `community_map_desc`. No changes needed — this screen is already compliant.

### WaterHeroScreen (`lib/presentation/screens/gamification/water_hero_screen.dart`)

Changes:
1. Replace hardcoded `'Daily Assignment'` → `AppLocalizations.of(context)!.get('daily_assignment')`
2. Replace hardcoded `'Your Rank'` → `AppLocalizations.of(context)!.get('your_rank')`
3. Replace hardcoded `'PENALTY ALERT'` → `AppLocalizations.of(context)!.get('penalty')`
4. Replace hardcoded `'TOTAL WATER POINTS'` → `AppLocalizations.of(context)!.get('water_hero_desc')` (or add a dedicated key)
5. Replace hardcoded `'Accept Task?'`, `'Yes'`, `'No'` → `AppLocalizations` keys
6. Replace hardcoded `'Task Completed'` → `AppLocalizations.of(context)!.get('task_completed')`

### CommunitySettingsScreen (`lib/presentation/screens/community_settings/community_settings_screen.dart`)

Changes:
1. Replace hardcoded `'Account'` section title → `AppLocalizations` key (add `account` key or use existing)
2. Replace hardcoded `'About Jal Dharan'` subtitle → `AppLocalizations` key
3. Replace hardcoded `'Review our privacy practices'` subtitle → `AppLocalizations` key
4. Replace hardcoded `'Read our terms of service'` subtitle → `AppLocalizations` key
5. Replace hardcoded `'Sign out of your account'` subtitle → `AppLocalizations` key
6. Replace hardcoded logout dialog strings → `AppLocalizations` keys

### JalShayakOverlay (`lib/presentation/widgets/jal_shayak_overlay.dart`)

The overlay is already fully implemented with:
- Collapsed/expanded toggle
- Chat message list
- `speech_to_text` integration (`_listen()` method)
- `flutter_tts` for AI response playback
- `AppLocalizations` for `jal_shayak`, `jal_shayak_help`, `ask_question` keys
- Red mic button while listening
- Auto-send on final STT result with 500ms delay
- Snackbar on mic permission denied

The only required change is adding it to `HomeScreen`'s `Stack`.

---

## Data Models

No new data models are required. The feature touches only UI rendering and locale state.

**Existing relevant state:**
- `LanguageProvider._currentLanguage: String` — persisted to `SharedPreferences` under key `'language'`
- `_JalShayakOverlayState._isExpanded: bool` — controls collapsed/expanded view
- `_JalShayakOverlayState._isListening: bool` — controls mic button color and STT state
- `_JalShayakOverlayState._messages: List<ChatMessage>` — chat history

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Language switch does not mutate the navigation stack

*For any* screen in the app and any valid locale code (`'en'` or `'hi'`), calling `LanguageProvider.changeLanguage()` should leave the `Navigator` route stack at the same depth and with the same top route as before the call.

**Validates: Requirements 1.1, 1.2, 1.3**

---

### Property 2: Locale preference round-trip

*For any* valid locale code, after calling `LanguageProvider.changeLanguage(code)`, reading the `'language'` key from `SharedPreferences` should return the same code.

**Validates: Requirements 1.4**

---

### Property 3: Screen widgets render localized strings for all locales

*For any* screen widget (HomeScreen, AnalyticsScreen, WaterHeroScreen, CommunitySettingsScreen) and any supported locale (`'en'` or `'hi'`), every text element that has a corresponding `AppLocalizations` key should render the string returned by `AppLocalizations(locale).get(key)` — not a hardcoded English literal.

**Validates: Requirements 2.1–2.4, 3.1–3.8, 4.1–4.5, 5.1–5.4, 6.1–6.6, 7.1–7.3, 8.1–8.7, 9.1–9.4, 11.8**

---

### Property 4: Overlay expand/collapse round-trip

*For any* initial state of `JalShayakOverlay`, tapping the collapsed button to expand and then tapping the close button should return the overlay to its collapsed state (i.e., `_isExpanded == false`).

**Validates: Requirements 10.3, 10.4**

---

### Property 5: STT listen/stop round-trip

*For any* state where `JalShayakOverlay` is expanded, tapping the microphone button to start listening and then tapping it again should result in `_isListening == false` and `SpeechToText.stop()` having been called.

**Validates: Requirements 11.4, 11.7**

---

### Property 6: STT final result triggers auto-send

*For any* non-empty string returned as a final STT result, the `JalShayakOverlay` should add that string as a user `ChatMessage` within 600ms of the result being received (500ms delay + processing time).

**Validates: Requirements 11.5**

---

## Error Handling

| Scenario | Handling |
|---|---|
| Microphone permission denied | `_speechToText.initialize()` returns `false`; overlay shows a `SnackBar` with the message from `AppLocalizations.get('voice_input')` context |
| STT error during listening | `onError` callback sets `_isListening = false`; mic button returns to green |
| STT status `'done'` or `'notListening'` | `onStatus` callback sets `_isListening = false` automatically |
| RAG service network error | Existing error handler in `_fetchAIResponse` catches and displays an error `ChatMessage` |
| `AppLocalizations.of(context)` returns null | The `!` operator will throw; screens should be wrapped in a `Localizations` ancestor (guaranteed by `MaterialApp`) |
| Missing localization key | `AppLocalizations.get()` returns the key string as fallback — visible as a bug but non-crashing |

---

## Testing Strategy

### Unit Tests

- `LanguageProvider.changeLanguage('hi')` persists `'hi'` to `SharedPreferences`
- `LanguageProvider.changeLanguage('en')` after `'hi'` correctly switches back
- `AppLocalizations('hi').get('voltage')` returns `'वोल्टेज'`
- `AppLocalizations('en').get('voltage')` returns `'Voltage'`
- `AppLocalizations.get()` with an unknown key returns the key itself (fallback)

### Property-Based Tests

Using the `test` package with randomized locale selection (since there are only two locales, exhaustive testing is feasible):

**Property 1 — Navigation stack invariant**
```
// Feature: localization-and-jal-shayak, Property 1: language switch does not mutate navigation stack
// For each screen widget, pump it, call changeLanguage, verify Navigator.of(context).canPop() is unchanged
```

**Property 2 — Locale persistence round-trip**
```
// Feature: localization-and-jal-shayak, Property 2: locale preference round-trip
// For each locale in ['en', 'hi'], call changeLanguage, read SharedPreferences, assert equality
```

**Property 3 — Localized string rendering**
```
// Feature: localization-and-jal-shayak, Property 3: screen widgets render localized strings
// For each (screen, locale, key) triple, pump widget with locale, find Text widget, assert text == AppLocalizations(locale).get(key)
// Minimum 100 iterations via randomized (screen, locale) pairs
```

**Property 4 — Overlay expand/collapse round-trip**
```
// Feature: localization-and-jal-shayak, Property 4: overlay expand/collapse round-trip
// Pump JalShayakOverlay, tap collapsed button, tap close button, verify _isExpanded == false
```

**Property 5 — STT listen/stop round-trip**
```
// Feature: localization-and-jal-shayak, Property 5: STT listen/stop round-trip
// Mock SpeechToText, tap mic (start), tap mic again (stop), verify _isListening == false
```

**Property 6 — STT auto-send**
```
// Feature: localization-and-jal-shayak, Property 6: STT final result triggers auto-send
// Mock SpeechToText to emit a final result with random non-empty text, advance timer by 600ms, verify message appears in _messages
```

**Property-based testing library**: `flutter_test` (built-in) with `fake_async` for timer control. Minimum 100 iterations per property test where randomization applies (Properties 2 and 3).

### Integration / Manual Tests

- Switch language from HomeScreen → verify all labels update in place
- Switch language from RainwaterHarvestingScreen → verify user stays on that screen
- Tap Jal Shayak button → verify overlay expands
- Tap mic → speak → verify text appears in input field and is auto-sent
- Deny mic permission → verify snackbar appears
