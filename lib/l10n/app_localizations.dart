import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// App name shown in titles and the AppBar
  ///
  /// In en, this message translates to:
  /// **'DocuCraft'**
  String get appTitle;

  /// Opening greeting shown in the AI chat panel
  ///
  /// In en, this message translates to:
  /// **'Hi! I\'m DocuCraft AI, ready to help you craft a great deck.\n\n**What I can do:**\n✨ Create slides from plain text\n🔄 Redesign an existing slide\n📊 Build a full presentation from an outline\n🎨 Auto-generate layout + content\n🖼️ **AI from Sketches** — sketch on the canvas, AI turns it into a design\n\n*Try: \"Make a slide about marketing strategy\"*'**
  String get aiChatGreeting;

  /// No description provided for @aiSketchCanvasEmpty.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Canvas is empty. Draw a sketch on the canvas first, then try again.'**
  String get aiSketchCanvasEmpty;

  /// No description provided for @aiSketchNoCanvas.
  ///
  /// In en, this message translates to:
  /// **'⚠️ No sketch canvas available.'**
  String get aiSketchNoCanvas;

  /// No description provided for @aiSketchAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'🧠 Analyzing sketch and planning layout...'**
  String get aiSketchAnalyzing;

  /// No description provided for @aiStorageNotReady.
  ///
  /// In en, this message translates to:
  /// **'Storage not ready. Try again.'**
  String get aiStorageNotReady;

  /// No description provided for @aiErrorPlanningEmpty.
  ///
  /// In en, this message translates to:
  /// **'Planning returned no pages; using demo outline.'**
  String get aiErrorPlanningEmpty;

  /// No description provided for @aiErrorBackendOffline.
  ///
  /// In en, this message translates to:
  /// **'Backend offline: {error} — using demo outline.'**
  String aiErrorBackendOffline(String error);

  /// No description provided for @aiErrorNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages to generate.'**
  String get aiErrorNoPages;

  /// No description provided for @aiErrorGeneration.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: {error}'**
  String aiErrorGeneration(String error);

  /// No description provided for @aiBlueprintForkedNoOutline.
  ///
  /// In en, this message translates to:
  /// **'Forked {name}: no saved outline, replan from scratch.'**
  String aiBlueprintForkedNoOutline(String name);

  /// No description provided for @aiBlueprintForkedEmpty.
  ///
  /// In en, this message translates to:
  /// **'Forked {name}: saved outline was empty, replan.'**
  String aiBlueprintForkedEmpty(String name);

  /// No description provided for @aiBlueprintForkedReady.
  ///
  /// In en, this message translates to:
  /// **'Forked {name} — edit and generate.'**
  String aiBlueprintForkedReady(String name);

  /// No description provided for @aiBlueprintLoaded.
  ///
  /// In en, this message translates to:
  /// **'Loaded: {name}'**
  String aiBlueprintLoaded(String name);

  /// No description provided for @aiSketchConvertFailed.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Failed to convert sketch: {reason}'**
  String aiSketchConvertFailed(String reason);

  /// No description provided for @aiGenericError.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Error: {message}'**
  String aiGenericError(String message);

  /// No description provided for @aiGenerateFailed.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Failed to generate: no result'**
  String get aiGenerateFailed;

  /// No description provided for @aiDesignGateIntro.
  ///
  /// In en, this message translates to:
  /// **'I\'ll design with:\n• Topic: {topic}\n• Color: {color}\n• Style: {style}\n\n[✅ Generate Now] [✏️ Edit Details]'**
  String aiDesignGateIntro(String topic, String color, String style);

  /// No description provided for @aiDesignSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ **Success!** {count} visual elements added to the slide.\n\nDetails:\n• {textCount} text\n• {shapeCount} shapes\n• {imageCount} images\n\n[🔄 Try Again] [✏️ Edit]'**
  String aiDesignSuccess(
    int count,
    int textCount,
    int shapeCount,
    int imageCount,
  );

  /// No description provided for @aiSketchConvertSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ **Sketch → Design successful!**\n\n'**
  String get aiSketchConvertSuccess;

  /// No description provided for @aiSketchConvertSuccessFallback.
  ///
  /// In en, this message translates to:
  /// **'✅ **Sketch → Design successful!** (fallback)\n\n'**
  String get aiSketchConvertSuccessFallback;

  /// No description provided for @aiNoResult.
  ///
  /// In en, this message translates to:
  /// **'no result'**
  String get aiNoResult;

  /// No description provided for @uiRetry.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get uiRetry;

  /// No description provided for @uiEditDesignDetail.
  ///
  /// In en, this message translates to:
  /// **'Edit Design Detail'**
  String get uiEditDesignDetail;

  /// No description provided for @uiCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get uiCancel;

  /// No description provided for @uiGenerating.
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get uiGenerating;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
