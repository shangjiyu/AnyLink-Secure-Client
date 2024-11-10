import 'package:babstrap_settings_screen/babstrap_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screen_lock/flutter_screen_lock.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key, required this.controller});

  static const routeName = '/settings';

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.isLocked) {
        buildLockScreen(context);
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: ListView(
          children: [
            // user card
            SimpleUserCard(
              userName: "zeroq",
              userProfilePic: const AssetImage("assets/images/openconnect.png"),
            ),
            SettingsGroup(
              backgroundColor: Colors.transparent,
              items: [
                SettingsItem(
                  onTap: () {
                    controller.locked(true);
                    buildLockScreen(context);
                  },
                  icons: Icons.fingerprint,
                  iconStyle: IconStyle(
                    iconsColor: Colors.white,
                    withBackground: true,
                    backgroundColor: Colors.red,
                  ),
                  title: 'Privacy',
                  subtitle: "Lock SSLConnVPN to improve your privacy",
                ),
                SettingsItem(
                  onTap: () {
                    showDialog(context: context, builder: (context) {
                      return AlertDialog(
                        title: const Text("Follow System"),
                        content: const Text("Are you sure you want to follow system theme?"),
                        actions: [
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () => Navigator.pop(context),
                          ),
                          TextButton(
                            child: const Text("OK"),
                            onPressed: () {
                              controller.updateThemeMode(ThemeMode.system);
                              Navigator.pop(context);
                            },
                          )
                      ],
                      );
                    });
                  },
                  icons: Icons.dark_mode_rounded,
                  iconStyle: IconStyle(
                    iconsColor: Colors.white,
                    withBackground: true,
                    backgroundColor: Colors.red,
                  ),
                  title: 'Dark Mode',
                  subtitle: controller.themeMode.name,
                  trailing: Switch.adaptive(
                    value: controller.themeMode == ThemeMode.dark,
                    onChanged: (value) {
                      controller.updateThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light);
                    },
                  ),
                ),
              ],
            ),
            SettingsGroup(
              items: [
                SettingsItem(
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: "SSLConnVPN",
                      applicationVersion: "1.0.0",
                      applicationLegalese:
                          "Copyright © 2024 ZeroQ. All rights reserved.",
                    );
                  },
                  icons: Icons.info_rounded,
                  iconStyle: IconStyle(
                    backgroundColor: Colors.purple,
                  ),
                  title: 'About',
                  subtitle: "Learn more about 'SSLConnVPN'",
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<dynamic> buildLockScreen(BuildContext context) {
    return showDialog(
        context: context,
        builder: (context) {
          return controller.passcode == ""
              ? ScreenLock.create(
                  title: const Text("New Passcode"),
                  confirmTitle: const Text("Confirm New Passcode"),
                  onConfirmed: (passcode) {
                    controller.updatePasscode(passcode);
                    Navigator.pop(context);
                  })
              : ScreenLock(
                  correctString: 'x' * 4,
                  onUnlocked: () async {
                    controller.locked(false);
                    Navigator.pop(context);
                  },
                  onValidate: (passcode) async {
                    return passcode == controller.passcode;
                  },
                  customizedButtonChild: const Icon(Icons.fingerprint),
                  customizedButtonTap: () async {
                    controller.localAuth();
                  },
                  onOpened: () async => controller.localAuth(),
                  title: const Text('Unlock to Connect VPN'),
                );
        });
  }
}
