import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:babstrap_settings_screen/babstrap_settings_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:graphic/graphic.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zeroq/src/profile_list/profile.dart';

import '../settings/settings_controller.dart';

/// Displays detailed information about a SampleItem.
class ProfileDetailsView extends StatefulWidget {
  const ProfileDetailsView({super.key, required this.controller});

  static const routeName = '/profile_detail';

  final SettingsController controller;

  @override
  State<ProfileDetailsView> createState() => _ProfileDetailsViewState();
}

class StatusProvider extends ValueNotifier<List<Map<String, dynamic>>> {
  StatusProvider()
      : super([
          {
            'time': DateTime.now(),
            'bytesSent': 0,
            'bytesReceived': 0,
            'bytesSentTotal': 0,
            'bytesReceivedTotal': 0
          },
        ]);

  void add(Map<String, dynamic> bytesStats) {
    if (bytesStats == {}) {
      return;
    }
    value.add({
      'time': DateTime.now(),
      'bytesSent': value.last['bytesSentTotal'] == 0 || bytesStats['bytesSent'] - value.last['bytesSentTotal'] < 0
          ? 0 : bytesStats['bytesSent'] - value.last['bytesSentTotal'],
      'bytesReceived': value.last['bytesReceivedTotal'] == 0 || bytesStats['bytesReceived'] - value.last['bytesReceivedTotal'] < 0
          ? 0 : bytesStats['bytesReceived'] - value.last['bytesReceivedTotal'],
      'bytesSentTotal': bytesStats['bytesSent'],
      'bytesReceivedTotal': bytesStats['bytesReceived']
    });
    value.length > 120 ? value.removeAt(0) : null;
    notifyListeners();
  }
}

class _ProfileDetailsViewState extends State<ProfileDetailsView>
    with RouteAware, WidgetsBindingObserver {
  final PageStorageKey<String> _key = const PageStorageKey('profile_detail');
  final StatusProvider statusData = StatusProvider();
  final ValueNotifier<Profile> _profile = ValueNotifier(Profile());
  Timer? _timer;

  @override
  Widget build(BuildContext context) {
    _profile.value = widget.controller
        .getProfile(ModalRoute.of(context)?.settings.arguments as String);
    //轮训status
    _profile.value.connected == false
        ? _timer?.cancel()
        : {
            _timer = _timer ??
                Timer.periodic(const Duration(seconds: 1), (timer) {
                  widget.controller.profileStatus(_profile.value).then((s) {
                    statusData.add(jsonDecode(s)['Stat']);
                  });
                }),
          };
    return ListenableBuilder(
        listenable: _profile,
        builder: (BuildContext context, Widget? child) {
          return Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(child: Text(_profile.value.name)),
            ),
            body: Padding(
              key: _key,
              padding: const EdgeInsets.all(10),
              child: ListView(
                children: [
                  _profile.value.connected == true
                      ? ValueListenableBuilder(
                          valueListenable: statusData,
                          builder: (context, value, child) {
                            return Column(
                              children: [
                                buildTrafficChart(context, value),
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                          "Sent: ${formatBytes(value.last['bytesSentTotal'], 2)}"),
                                      const SizedBox(
                                        width: 20,
                                      ),
                                      Text(
                                          "Received: ${formatBytes(value.last['bytesReceivedTotal'], 2)}"),
                                    ]),
                              ],
                            );
                          })
                      :
                      // user card
                      SimpleUserCard(
                          userName: _profile.value.type.name,
                          userProfilePic: AssetImage(
                              "assets/images/${_profile.value.type.name}.png"),
                        ),
                  SettingsGroup(settingsGroupTitle: 'Server', items: [
                    SettingsItem(
                      title: 'Name',
                      subtitle: _profile.value.name,
                      onTap: () async {
                        var property =
                            await alertProperty(context, _profile.value.name);
                        if (property != null) {
                          _profile.value.name = property;
                        }
                        widget.controller.updateProfile(_profile.value);
                      },
                      icons: Icons.account_box_rounded,
                    ),
                    SettingsItem(
                      title: 'Gateway',
                      subtitle: _profile.value.remotes?[0].host,
                      onTap: () async {
                        var property = await alertProperty(
                            context, _profile.value.remotes?[0].host, 'IP/Domain w/ :PORT');
                        if (property != null) {
                          _profile.value.remotes?[0].host = property;
                        }
                        widget.controller.updateProfile(_profile.value);
                      },
                      icons: Icons.computer_rounded,
                    ),
                    SettingsItem(
                      title: 'Server Cert',
                      subtitle: _profile.value.remotes?[0].cert,
                      onTap: () async {
                        var property = await alertProperty(
                            context, _profile.value.remotes?[0].cert, 'Server Cert Fingerprint SHA1');
                        if (property != null) {
                          _profile.value.remotes?[0].cert = property;
                        }
                        widget.controller.updateProfile(_profile.value);
                      },
                      icons: Icons.security_rounded,
                    ),
                    SettingsItem(
                      title: 'CA Cert',
                      subtitle: _profile.value.local?.caCert,
                      onTap: () async {
                        var property = await alertProperty(
                            context, _profile.value.local?.caCert, 'CA Cert in PEM format');
                        if (property != null) {
                          _profile.value.local?.caCert = property;
                        }
                        widget.controller.updateProfile(_profile.value);
                      },
                      icons: Icons.account_balance_outlined,
                    ),
                  ]),
                  // You can add a settings title
                  SettingsGroup(
                    settingsGroupTitle: "Account",
                    items: [
                      SettingsItem(
                        onTap: () async {
                          var property = await alertProperty(
                              context, _profile.value.local?.username);
                          if (property != null) {
                            _profile.value.local?.username = property;
                          }
                          widget.controller.updateProfile(_profile.value);
                        },
                        icons: Icons.account_circle_rounded,
                        title: "Username",
                        subtitle: _profile.value.local?.username,
                      ),
                      SettingsItem(
                        onTap: () async {
                          var property = await alertProperty(
                              context, _profile.value.local?.password);
                          if (property != null) {
                            _profile.value.local?.password = property;
                          }
                          widget.controller.updateProfile(_profile.value);
                        },
                        icons: Icons.password_rounded,
                        title: "Password",
                        subtitle: _profile.value.local?.password,
                      ),
                      SettingsItem(
                        onTap: () async {
                          var pickerResult = await FilePicker.platform.pickFiles(allowedExtensions: ['p12', 'pfx'], type: FileType.custom);
                          if (pickerResult != null) {
                            _profile.value.local?.secretKey = pickerResult.files.single.name;
                            var bytes = await File(pickerResult.files.single.path!).readAsBytes();
                            _profile.value.local?.cert = base64Encode(bytes);
                          } else {
                            _profile.value.local?.cert = null;
                            _profile.value.local?.secretKey = null;
                          }
                          widget.controller.updateProfile(_profile.value);
                        },
                        icons: Icons.security_rounded,
                        title: "User Cert",
                        subtitle: _profile.value.local?.secretKey,
                        subtitleMaxLine: 1,
                      ),
                      SettingsItem(
                        onTap: () async {
                          var property = await alertProperty(
                              context, _profile.value.local?.group);
                          if (property != null) {
                            _profile.value.local?.group = property;
                          }
                          widget.controller.updateProfile(_profile.value);
                        },
                        icons: Icons.group_outlined,
                        title: "Group",
                        subtitle: _profile.value.local?.group,
                      ),
                      SettingsItem(
                        onTap: () {},
                        icons: Icons.pin_outlined,
                        title: "OTP",
                        trailing: Switch(
                          value: _profile.value.remotes?[0].otp ?? false,
                          onChanged: (b) {
                            _profile.value.remotes?[0].otp = b;
                            widget.controller.updateProfile(_profile.value);
                        }),
                      ),
                    ],
                  ),
                  SettingsGroup(settingsGroupTitle: 'MISC', items: [
                    SettingsItem(
                        icons: Icons.network_ping_outlined,
                        title: 'DTLS',
                        trailing: Switch(
                            value: _profile.value.local?.dtls ?? true,
                            onChanged: (b) {
                              _profile.value.local?.dtls = b;
                              widget.controller.updateProfile(_profile.value);
                            })),
                    SettingsItem(
                        icons: Icons.security_rounded,
                        title: 'Insecure Skip Verify',
                        trailing: Switch(
                            value: _profile.value.local?.insecureSkipVerify ??
                                true,
                            onChanged: (b) {
                              _profile.value.local?.insecureSkipVerify = b;
                              widget.controller.updateProfile(_profile.value);
                            })),
                    SettingsItem(
                        icons: Icons.apple_rounded,
                        title: 'Cisco Compat',
                        trailing: Switch(
                            value: _profile.value.local?.ciscoCompat ?? true,
                            onChanged: (b) {
                              _profile.value.local?.ciscoCompat = b;
                              widget.controller.updateProfile(_profile.value);
                            })),
                  ]),
                ],
              ),
            ),
          );
        });
  }

  String formatBytes(int bytes, int decimals) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  SizedBox buildTrafficChart(
      BuildContext context, List<Map<String, dynamic>> value) {
    return SizedBox(
      height: MediaQuery.of(context).size.height / 3,
      width: MediaQuery.of(context).size.width,
      child: Chart(
        changeData: true,
        data: value,
        variables: {
          'time': Variable(
            accessor: (Map map) => map['time'] as DateTime,
          ),
          'bytesSent': Variable(
            accessor: (Map map) => map['bytesSent'] as num,
            scale: LinearScale(
                min: 0,
                max: value.map((e) => e['bytesReceived'] as num).reduce(max)),
          ),
          'bytesReceived': Variable(
            accessor: (Map map) => map['bytesReceived'] as num,
            scale: LinearScale(
                min: 0,
                max: value.map((e) => e['bytesReceived'] as num).reduce(max)),
          ),
        },
        selections: {
          'hover': PointSelection(
            on: {GestureType.tap},
            clear: {
              GestureType.mouseExit,
              GestureType.scroll,
              GestureType.doubleTap
            },
          ),
        },
        tooltip: TooltipGuide(
          followPointer: [true, true],
          // renderer: (s, o, m) {
          //   return <MarkElement>[
          //     LabelElement(text: 'good', anchor: o, style: LabelStyle())
          //   ];
          // },
        ),
        crosshair: CrosshairGuide(followPointer: [true, true]),
        marks: [
          LineMark(
            position: Varset('time') * Varset('bytesReceived'),
            shape: ShapeEncode(value: BasicLineShape(smooth: true)),
          ),
          LineMark(
            position: Varset('time') * Varset('bytesSent'),
            shape: ShapeEncode(value: BasicLineShape(smooth: true)),
          ),
          AreaMark(
            position: Varset('time') * Varset('bytesReceived'),
            shape: ShapeEncode(value: BasicAreaShape(smooth: true)),
            color: ColorEncode(
              value: Colors.green.withAlpha(80),
            ),
          ),
          AreaMark(
            position: Varset('time') * Varset('bytesSent'),
            shape: ShapeEncode(value: BasicAreaShape(smooth: true)),
            color: ColorEncode(
              value: Colors.red.withAlpha(80),
            ),
          )
        ],
        axes: [
          Defaults.horizontalAxis
            ..label = null
            ..variable = 'time',
          AxisGuide(
            labelMapper: (String? text, int index, int total) {
              return LabelStyle(
                textStyle: Defaults.textStyle,
                offset: const Offset(-7.5, 0),
              );
            },
            grid: Defaults.strokeStyle,
          ),
        ],
      ),
    );
  }

  Future<String?> alertProperty(BuildContext context, item, [String? hint]) async {
    return await showDialog(
        context: context,
        builder: (context) {
          var editor = TextEditingController(text: item);
          return AlertDialog(
            content: TextFormField(
              autofocus: true,
              controller: editor,
              decoration: InputDecoration(
                hintText: hint,
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CANCEL")),
              TextButton(
                  onPressed: () => Navigator.pop(context, editor.text.trim()),
                  child: const Text("OK")),
            ],
          );
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.inactive:
        _timer?.cancel();
        break;
      case AppLifecycleState.paused:
        _timer?.cancel();
        break;
      case AppLifecycleState.detached:
        _timer?.cancel();
        break;
      case AppLifecycleState.hidden:
        _timer?.cancel();
        break;
      default:
        break;
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.controller.routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPop() {
    super.didPop();
    widget.controller.saveProfile();
  }

  @override
  void dispose() {
    super.dispose();
    _timer?.cancel();
    widget.controller.routeObserver.unsubscribe(this);
  }
}
