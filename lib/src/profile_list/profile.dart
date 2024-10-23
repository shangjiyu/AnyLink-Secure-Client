import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

/// A placeholder class that represents an entity or model.
@JsonSerializable(explicitToJson: true)
class Profile {
  Profile({this.id = '',
      this.type = ProfileType.openconnect,
      this.name = '',
      this.connected = false,
      this.local,
      this.remotes});

  String id;
  ProfileType type;
  String name;
  bool connected;
  String? logLevel;
  String? logPath;
  EndPoint? local;
  List<EndPoint>? remotes;
  String? lastErr;

  void connect() => {connected = true};

  void disconnect({String? err}) => {connected = false, lastErr = err};

  Map<String, dynamic> getStartParams() => {
        "logLevel": kDebugMode ? 'Debug' : logLevel ?? 'Info',
        "logPath": logPath ?? '',
        "username": local?.username,
        "password": local?.password,
        "group": local?.group,
        "certificate": local?.cert,
        "caCert": local?.caCert,
        "insecureSkipVerify": local?.insecureSkipVerify,
        "ciscoCompat": local?.ciscoCompat,
        "noDtls": local?.dtls == true ? false : true,
        "routes": local?.routes,
        "host": remotes?[0].host,
        "serverCert": remotes?[0].cert,
        "secretKey": remotes?[0].secretKey,
      };

  @override
  bool operator ==(Object other) {
    if (other is Profile &&
        other.id == id &&
        other.remotes?[0].host == remotes?[0].host) {
      return true;
    } else {
      return false;
    }
  }

  copyWith(Profile profile) {
    id = profile.id;
    type = profile.type;
    name = profile.name;
    local = profile.local;
    remotes = profile.remotes;
  }

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
}

@JsonSerializable(explicitToJson: true)
class EndPoint {
  EndPoint({this.host,
      this.username,
      this.password,
      this.cert,
      this.secretKey,
      this.insecureSkipVerify = true,
      this.ciscoCompat = true,
      this.dtls = true,
      this.routes});

  String? host;
  String? username;
  String? password;
  String? group;
  String? caCert;
  String? cert;
  String? secretKey;
  bool? insecureSkipVerify;
  bool? ciscoCompat;
  bool? dtls;
  bool? otp;
  String? routes;

  factory EndPoint.fromJson(Map<String, dynamic> json) =>
      _$EndPointFromJson(json);

  Map<String, dynamic> toJson() => _$EndPointToJson(this);
}

enum ProfileType {
  @JsonValue('ipsec')
  ipsec(
    protocol: 'ipsec',
    description:
        'Internet Protocol Security (IPsec) is a secure network protocol suite that authenticates and encrypts packets of data to provide secure encrypted communication between two computers over an Internet Protocol network',
    url: 'https://www.strongswan.org',
    authType: AuthType.password,
    configType: ConfigType.text,
  ),
  @JsonValue('ikev2')
  ikev2(
    protocol: 'ikev2',
    description:
        'In computing, Internet Key Exchange (IKE, versioned as IKEv1 and IKEv2) is the protocol used to set up a security association (SA) in the IPsec protocol suite. IKE builds upon the Oakley protocol and ISAKMP.[1] IKE uses X.509 certificates for authentication ‒ either pre-shared or distributed using DNS (preferably with DNSSEC) ‒ and a Diffie–Hellman key exchange to set up a shared session secret from which cryptographic keys are derived.[2][3] In addition, a security policy for every peer which will connect must be manually maintained',
    url: 'https://www.strongswan.org',
    authType: AuthType.cert,
    configType: ConfigType.form,
  ),
  @JsonValue('wireguard')
  wireguard(
    protocol: 'wireguard',
    description:
        'WireGuard® is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography',
    url: 'https://www.wireguard.com',
    authType: AuthType.password,
    configType: ConfigType.form,
  ),
  @JsonValue('openconnect')
  openconnect(
    protocol: 'openconnect',
    description:
        'OpenConnect is a cross-platform multi-protocol SSL VPN client which supports a number of VPN protocols',
    url: 'https://www.infradead.org/openconnect/index.html',
    authType: AuthType.password,
    configType: ConfigType.form,
  ),
  @JsonValue('anyconnect')
  anyconnect(
    protocol: 'anyconnect',
    description: 'AnyConnect',
    url: 'http://www.cisco.com/go/anyconnect',
    authType: AuthType.password,
    configType: ConfigType.form,
  ),
  @JsonValue('openvpn')
  openvpn(
    protocol: 'openvpn',
    description: 'OpenVPN',
    url: 'https://openvpn.net/',
    authType: AuthType.cert,
    configType: ConfigType.text,
  );

  const ProfileType({
    required this.protocol,
    required this.description,
    required this.url,
    required this.authType,
    required this.configType,
  });

  final String protocol;
  final String description;
  final String url;
  final AuthType authType;
  final ConfigType configType;
}

enum AuthType {
  @JsonValue('password')
  password,
  @JsonValue('cert')
  cert
}

enum ConfigType {
  @JsonValue('form')
  form,
  @JsonValue('text')
  text
}
