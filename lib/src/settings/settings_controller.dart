import 'package:flutter/material.dart';

import '../profile_list/profile.dart';
import 'settings_service.dart';

/// A class that many Widgets can interact with to read user settings, update
/// user settings, or listen to user settings changes.
///
/// Controllers glue Data Services to Flutter Widgets. The SettingsController
/// uses the SettingsService to store and retrieve user settings.
class SettingsController with ChangeNotifier {
  SettingsController(this._settingsService) {
    _settingsService.setCallbackWithKey(
        "statusChanged",
        (p) => {
              p['connected']
                  ? effectiveProfile.value?.connect()
                  : effectiveProfile.value?.disconnect(err: p['msg']),
              effectiveProfile.value == null
                  ? null
                  : {notifyListeners(), effectiveProfile.value = null}
            });
  }

  // Make SettingsService a private variable so it is not used directly.
  final SettingsService _settingsService;
  final effectiveProfile = ValueNotifier<Profile?>(null);
  final routeObserver = RouteObserver<ModalRoute<void>>();

  // Make ThemeMode a private variable so it is not updated directly without
  // also persisting the changes with the SettingsService.
  late ThemeMode _themeMode;
  late List<Profile> _profiles;

  // Allow Widgets to read the user's preferred ThemeMode.
  ThemeMode get themeMode => _themeMode;

  List<Profile> get profiles => _profiles;

  /// Load the user's settings from the SettingsService. It may load from a
  /// local database or the internet. The controller only knows it can load the
  /// settings from the service.
  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();

    _profiles = await _settingsService.getProfiles();

    // Important! Inform listeners a change has occurred.
    notifyListeners();
  }

  /// Update and persist the ThemeMode based on the user's selection.
  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;

    // Do not perform any work if new and old ThemeMode are identical
    if (newThemeMode == _themeMode) return;

    // Otherwise, store the new ThemeMode in memory
    _themeMode = newThemeMode;

    // Important! Inform listeners a change has occurred.
    notifyListeners();

    // Persist the changes to a local database or the internet using the
    // SettingService.
    await _settingsService.updateThemeMode(newThemeMode);
  }

  Future<void> addProfile(Profile? profile) async {
    if (_profiles.contains(profile)) {
      return;
    }
    _profiles.add(profile!);
    _settingsService.saveProfiles(_profiles);
    notifyListeners();
  }

  delProfile(Profile? profile) async {
    _profiles.remove(profile!);
    notifyListeners();
  }

  updateProfile(Profile? profile) async {
    if (profile == null) {
      return;
    }
    _profiles.firstWhere((p) => p.id == profile.id).copyWith(profile);
    notifyListeners();
  }

  Future<void> saveProfile() async {
    await _settingsService.saveProfiles(_profiles);
    notifyListeners();
  }

  Future<void> profileConnect(Profile? profile) async {
    if (profile!.connected) return;

    var connected = _profiles.firstWhere(
      (p) => p.connected,
      orElse: () => profile,
    );

    await profileDisconnect(connected);

    _settingsService.profileConnect(profile);
    profile.connect();
    effectiveProfile.value = profile;
    notifyListeners();
  }

  Future<void> profileDisconnect(Profile? profile) async {
    await _settingsService.profileDisconnect(profile!).then((v) => {
          profile.disconnect(),
          _settingsService.saveProfiles(_profiles),
          notifyListeners()
        });
  }

  Future<String> profileStatus(Profile? profile) async {
    if (!profile!.connected) return "{}";

    return await _settingsService.status(profile);
  }

  Profile getProfile(String id) {
    return profiles.firstWhere((p) => p.id == id);
  }
}
