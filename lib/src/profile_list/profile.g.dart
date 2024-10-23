// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
      id: json['id'] as String? ?? '',
      type: $enumDecodeNullable(_$ProfileTypeEnumMap, json['type']) ??
          ProfileType.openconnect,
      name: json['name'] as String? ?? '',
      connected: json['connected'] as bool? ?? false,
      local: json['local'] == null
          ? null
          : EndPoint.fromJson(json['local'] as Map<String, dynamic>),
      remotes: (json['remotes'] as List<dynamic>?)
          ?.map((e) => EndPoint.fromJson(e as Map<String, dynamic>))
          .toList(),
    )
      ..logLevel = json['logLevel'] as String?
      ..logPath = json['logPath'] as String?
      ..lastErr = json['lastErr'] as String?;

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
      'id': instance.id,
      'type': _$ProfileTypeEnumMap[instance.type]!,
      'name': instance.name,
      'connected': instance.connected,
      'logLevel': instance.logLevel,
      'logPath': instance.logPath,
      'local': instance.local?.toJson(),
      'remotes': instance.remotes?.map((e) => e.toJson()).toList(),
      'lastErr': instance.lastErr,
    };

const _$ProfileTypeEnumMap = {
  ProfileType.ipsec: 'ipsec',
  ProfileType.ikev2: 'ikev2',
  ProfileType.wireguard: 'wireguard',
  ProfileType.openconnect: 'openconnect',
  ProfileType.anyconnect: 'anyconnect',
  ProfileType.openvpn: 'openvpn',
};

EndPoint _$EndPointFromJson(Map<String, dynamic> json) => EndPoint(
      host: json['host'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      cert: json['cert'] as String?,
      secretKey: json['secretKey'] as String?,
      insecureSkipVerify: json['insecureSkipVerify'] as bool? ?? true,
      ciscoCompat: json['ciscoCompat'] as bool? ?? true,
      dtls: json['dtls'] as bool? ?? true,
      routes: json['routes'] as String?,
    )
      ..group = json['group'] as String?
      ..caCert = json['caCert'] as String?
      ..otp = json['otp'] as bool?;

Map<String, dynamic> _$EndPointToJson(EndPoint instance) => <String, dynamic>{
      'host': instance.host,
      'username': instance.username,
      'password': instance.password,
      'group': instance.group,
      'caCert': instance.caCert,
      'cert': instance.cert,
      'secretKey': instance.secretKey,
      'insecureSkipVerify': instance.insecureSkipVerify,
      'ciscoCompat': instance.ciscoCompat,
      'dtls': instance.dtls,
      'otp': instance.otp,
      'routes': instance.routes,
    };
