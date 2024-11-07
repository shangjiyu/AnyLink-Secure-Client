import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zeroq/src/profile_list/profile.dart';

import '../settings/settings_controller.dart';
import '../settings/settings_view.dart';
import 'profile_detail.dart';

/// Displays a list of SampleItems.
class ProfileListView extends StatelessWidget {
  const ProfileListView({
    super.key,
    required this.controller,
  });

  static const routeName = '/';
  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const DragToMoveArea(child: Text('PROFILES')),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_outlined),
              onPressed: () {
                showDialog(context: context, builder: profileAddDialog);
              },
            ),
          ],
        ),
        drawer: Drawer(
          child: SettingsView(controller: controller),
        ),

        // To work with lists that may contain a large number of items, it’s best
        // to use the ListView.builder constructor.
        //
        // In contrast to the default ListView constructor, which requires
        // building all Widgets up front, the ListView.builder constructor lazily
        // builds Widgets as they’re scrolled into view.
        body: ListView.separated(
          // Providing a restorationId allows the ListView to restore the
          // scroll position when a user leaves and returns to the app after it
          // has been killed while running in the background.
          restorationId: 'vpn-profile-list',
          itemCount: controller.profiles.length,
          itemBuilder: (BuildContext context, int index) {
            final item = controller.profiles[index];
            if (item.lastErr != null) {
              Future.delayed(Duration.zero, () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(item.lastErr!)),
                );
                item.lastErr = null;
              });
            }
            return Slidable(
              key: Key(UniqueKey().toString()),
              startActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    // An action can be bigger than the others.
                    flex: 2,
                    onPressed: (context) => controller.profileDisconnect(item),
                    icon: Icons.pin_end_outlined,
                    label: 'PINNED',
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const StretchMotion(),
                children: [
                  SlidableAction(
                    // An action can be bigger than the others.
                    flex: 2,
                    onPressed: (context) => controller.delProfile(item),
                    icon: Icons.delete_forever,
                    label: 'DELETE',
                  ),
                ],
              ),
              child: ListTile(
                  title: Text(item.name),
                  leading: CircleAvatar(
                    // Display the profile Logo image asset.
                    foregroundImage:
                        AssetImage('assets/images/${item.type.name}.png'),
                  ),
                  trailing: Switch(
                      value: item.connected,
                      onChanged: (v) => !v ? controller.profileDisconnect(item) : {
                        if (item.remotes?[0].otp == true) {
                          showDialog(context: context, builder: (context) => AlertDialog(
                            title: const Text("Enter OTP"),
                            content: TextFormField(
                              autofocus: true,
                              onFieldSubmitted: (v) {
                                item.remotes?[0].secretKey = v;
                                controller.profileConnect(item);
                                              Navigator.pop(context);
                                            },
                                          ),
                          ))
                        } else {
                          controller.profileConnect(item),
                        }
                      },
                  ),
                  onLongPress: () {
                    controller.profileStatus(item).then((status) {
                      showModalBottomSheet(
                          isScrollControlled: true,
                          context: context,
                          builder: (context) {
                            return Container(
                              width: MediaQuery.of(context).size.width,
                              height: MediaQuery.of(context).size.height * 0.5,
                              margin: const EdgeInsets.only(top: 28),
                              child: jsonDecode(status).length > 0
                                  ? ListView.separated(
                                      itemBuilder: (context, index) {
                                        var k = jsonDecode(status)
                                            .keys
                                            .elementAt(index);
                                        var v = jsonDecode(status)[k];
                                        return ListTile(
                                          title: Text(k.toString()),
                                          subtitle: Text(v.toString()),
                                        );
                                      },
                                      separatorBuilder:
                                          (BuildContext context, int index) =>
                                              const Divider(),
                                      itemCount: jsonDecode(status).length,
                                    )
                                  : Text(status),
                            );
                          });
                    });
                  },
                  onTap: () {
                    // Navigate to the details page. If the user leaves and returns to
                    // the app after it has been killed while running in the
                    // background, the navigation stack is restored.
                    Navigator.restorablePushNamed(
                        context, ProfileDetailsView.routeName,
                        arguments: item.id);
                  }),
            );
          },
          separatorBuilder: (BuildContext context, int index) {
            return const Divider();
          },
        ));
  }

  Widget profileAddDialog(context) {
    ValueNotifier<bool?> custom = ValueNotifier(false);
    TextEditingController name = TextEditingController();
    TextEditingController url = TextEditingController();
    return AlertDialog(
      title: const Text("New Profile"),
      content: Form(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder(
              valueListenable: custom,
              builder: (context, value, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                        child: TextFormField(
                      decoration: const InputDecoration(
                          labelText: "Name", hintText: "Profile Name"),
                      readOnly: !custom.value!,
                      controller: name,
                    )),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: value,
                          onChanged: (checked) {
                            custom.value = checked;
                          },
                        ),
                        const Text(
                          "CUSTOMIZE",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 8),
                        ),
                      ],
                    )
                  ],
                );
              }),
          TextFormField(
            decoration: const InputDecoration(
                labelText: "URL", hintText: "Gateway URL"),
            onChanged: (value) {
              if (custom.value == true || value.isEmpty) {
                return;
              } else {
                var parts = value.split("//");
                if (parts.length < 2) {
                  name.text = parts[0].split(":")[0].split("/")[0];
                  return;
                }
                name.text = parts[1].split(":")[0].split("/")[0];
              }
            },
            controller: url,
          ),
        ],
      )),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("CANCEL")),
        TextButton(
            onPressed: () {
              controller.addProfile(Profile(
                id: const Uuid().v4(),
                name: name.text,
                type: ProfileType.openconnect,
                local: EndPoint(),
                remotes: [
                  EndPoint(
                    host: url.text,
                  )
                ],
              ));
              Navigator.pop(context);
            },
            child: const Text("OK")),
      ],
    );
  }
}
