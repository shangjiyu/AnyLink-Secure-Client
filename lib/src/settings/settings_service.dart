import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../profile_list/profile.dart';
import 'ffi_generated.dart';

/// A service that stores and retrieves user settings.
///
/// By default, this class does not persist user settings. If you'd like to
/// persist the user settings locally, use the shared_preferences package. If
/// you'd like to store settings on a web server, use the http package.
class SettingsService {
  static const platform = MethodChannel('com.zeroq.demo/vpn');
  static final DeviceInfoPlugin deviceInfoPlugin = DeviceInfoPlugin();
  late final LibAnyLink? _library;
  late final ReceivePort _port;
  final Map<String, dynamic> deviceId = {};
  final isWinOrLinux = Platform.isWindows || Platform.isLinux;

  SettingsService._internal() {
    platform.setMethodCallHandler(_onMethodCall);
    if (isWinOrLinux) {
      _library = LibAnyLink(DynamicLibrary.open(
          Platform.isWindows ? "libanylink.dll" : "libanylink.so"));
      _port = ReceivePort()
        ..listen((msg) {
          _callbackPool["statusChanged"]!({"connected": false, "msg": msg});
        });

      _library?.initLogger();
    }
    deviceId['computerName'] = Platform.localHostname;
    deviceId['deviceType'] = defaultTargetPlatform.name;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        deviceInfoPlugin.androidInfo.then((value) {
          deviceId['platformVersion'] = value.version;
          deviceId['uniqueId'] = value.fingerprint;
        });
        break;
      case TargetPlatform.iOS:
        deviceInfoPlugin.iosInfo.then((value) {
          deviceId['platformVersion'] = value.systemVersion;
          deviceId['uniqueId'] = value.identifierForVendor;
        });
        break;
      case TargetPlatform.macOS:
        deviceInfoPlugin.macOsInfo.then((value) {
          deviceId['platformVersion'] = value.osRelease;
          deviceId['uniqueId'] = value.systemGUID;
        });
        break;
      case TargetPlatform.windows:
        deviceInfoPlugin.windowsInfo.then((value) {
          deviceId['platformVersion'] = value.displayVersion;
          deviceId['uniqueId'] = value.deviceId;
        });
        break;
      case TargetPlatform.linux:
        deviceInfoPlugin.linuxInfo.then((value) {
          deviceId['platformVersion'] = value.version;
          deviceId['uniqueId'] = value.machineId;
        });
        break;
      default:
        break;
    }
  }

  static final SettingsService _instance = SettingsService._internal();

  factory SettingsService() => _instance;

  final FlutterSecureStorage settingsStorage = const FlutterSecureStorage();

  final Map<String, Function> _callbackPool = {};

  final effectiveProfile = ValueNotifier<Profile?>(null);

  /// Loads the User's preferred ThemeMode from local or remote storage.
  Future<ThemeMode> themeMode() async {
    return await settingsStorage.read(key: "themeMode").then((value) {
      if (value == null) return ThemeMode.system;
      return ThemeMode.values.firstWhere((e) => e.name == value);
    });
  }

  updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    await settingsStorage.write(key: "themeMode", value: newThemeMode.name);
  }

  Future<List<Profile>> getProfiles() async {
    return await settingsStorage.read(key: "profiles").then((value) {
      if (value == null) return [];
      return List<dynamic>.from(jsonDecode(value))
          .map((e) => Profile.fromJson(e))
          .toList();
    });
  }

  saveProfiles(List<Profile> profiles) async {
    await settingsStorage.write(key: "profiles", value: jsonEncode(profiles));
  }

  Future<void> profileConnect(Profile profile) async {
    if (profile.connected || profile.type != ProfileType.openconnect) return;
    final startParams = {...profile.getStartParams(), ...deviceId};
    isWinOrLinux
        ? await Isolate.spawn((sendPort) {
            var ret = LibAnyLink(DynamicLibrary.open(
                    Platform.isWindows ? "libanylink.dll" : "libanylink.so"))
                .vpnConnect(json.encode(startParams).toNativeUtf8().cast());
            sendPort.send(ret.cast<Utf8>().toDartString());
          }, _port.sendPort)
        : await platform.invokeMethod('startVpn', startParams);
  }

  Future<void> profileDisconnect(Profile profile) async {
    if (!profile.connected) return;
    isWinOrLinux ? _library!.vpnDisconnect() : platform.invokeMethod('stopVpn');
  }

  Future<String> status(Profile profile) async {
    if (!profile.connected) return '';
    return isWinOrLinux
        ? _library!.vpnStatus().cast<Utf8>().toDartString()
        : await platform.invokeMethod("status").then((value) => value ?? "{}");
  }

  Future<void> setCallbackWithKey(
      String key, Function(Map<String, dynamic> params) callback) async {
    _callbackPool[key] = callback;
  }

  Future<dynamic> _onMethodCall(MethodCall call) async {
    if (_callbackPool.containsKey(call.method)) {
      return _callbackPool[call.method]!(
          Map<String, dynamic>.from(call.arguments ?? {}));
    }
  }
}
