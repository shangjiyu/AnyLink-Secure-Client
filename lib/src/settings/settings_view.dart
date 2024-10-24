import 'package:babstrap_settings_screen/babstrap_settings_screen.dart';
import 'package:flutter/material.dart';

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
                  onTap: () {},
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
                  onTap: () {},
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
}
