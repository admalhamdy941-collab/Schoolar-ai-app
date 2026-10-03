# Scholar AI — Flutter reference implementation

Mobile counterpart of the web app in this repository. Same system prompts,
same JSON contract, same gamification rules.

## Setup
```bash
flutter create . --org com.scholar --project-name scholar_ai   # generates platform folders
flutter pub get
echo "GEMINI_API_KEY=your_key" > .env
flutter pub run build_runner build --delete-conflicting-outputs   # Hive adapters
flutter run
```

### Android (camera + share-to-app)
`android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<intent-filter>
  <action android:name="android.intent.action.SEND"/>
  <category android:name="android.intent.category.DEFAULT"/>
  <data android:mimeType="application/pdf"/>
  <data android:mimeType="image/*"/>
  <data android:mimeType="text/plain"/>
</intent-filter>
```
### iOS
`ios/Runner/Info.plist`: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`.
Share Extension: follow `receive_sharing_intent` setup so WhatsApp / Telegram "Open in Scholar AI" works.

### Viral features
1. Share-to-unlock camera solver (`ShareUnlockDialog`)
2. Story card export (`screenshot` + `Share.shareXFiles`)
3. Peer quiz challenge links
4. PDF import via `receive_sharing_intent` + `syncfusion_flutter_pdf`

## Architecture
```
lib/
  main.dart                  App bootstrap, Material 3 theme, BottomNavigationBar shell
  core/prompts.dart          Bilingual (AR/EN) system prompts — mirror of src/lib/prompts.ts
  models/models.dart         Typed result models + JSON parsing (Hive-cached)
  services/gemini_service.dart   Async Gemini handler (text + inline image, retries, JSON repair)
  services/cache_service.dart    Hive offline-first store
  bloc/study_cubit.dart      Generation state machine (idle / loading / success / failure)
  bloc/gamification_cubit.dart   XP, levels, streaks, badges (persisted in Hive)
  widgets/active_recall_widget.dart  Micro-quiz + flip flashcards
  widgets/step_by_step_view.dart     Collapsible pedagogy steps with "Why this formula?" tooltips
  screens/home_dashboard.dart        Streak / XP dashboard
  screens/module_screen.dart         Generic module tab (A–D) with camera OCR hook
```
