import 'dart:convert';
import 'package:flutter_v2ray/url/url.dart';

class CustomConfigURL extends V2RayURL {
  CustomConfigURL({required super.url}) {
    try {
      final Map<String, dynamic> config = jsonDecode(url);
      _parseConfig(config);
    } catch (e) {
      throw ArgumentError('Invalid configuration JSON');
    }
  }

  late final Map<String, dynamic> _config;
  late final String _remarks;

  void _parseConfig(Map<String, dynamic> config) {
    _config = config;
    _remarks = config['remarks'] ?? '';

    // Override log settings
    if (config['log'] != null) {
      log = Map<String, dynamic>.from(config['log']);
    }

    // Override DNS settings
    if (config['dns'] != null) {
      dns = Map<String, dynamic>.from(config['dns']);
    }

    // Override routing settings
    if (config['routing'] != null) {
      routing = Map<String, dynamic>.from(config['routing']);
    }

    // Override inbound settings
    if (config['inbounds'] != null && config['inbounds'].isNotEmpty) {
      inbound = Map<String, dynamic>.from(config['inbounds'][0]);
    }

    // Parse stream settings if available
    if (config['outbounds'] != null &&
        config['outbounds'].isNotEmpty &&
        config['outbounds'][0]['streamSettings'] != null) {
      streamSetting =
          Map<String, dynamic>.from(config['outbounds'][0]['streamSettings']);
    }
  }

  @override
  String get remark => _remarks;

  @override
  String get address =>
      _config['outbounds']?[0]?['settings']?['servers']?[0]?['address'] ??
      _config['outbounds']?[0]?['settings']?['vnext']?[0]?['address'] ??
      '';

  @override
  int get port =>
      _config['outbounds']?[0]?['settings']?['servers']?[0]?['port'] ??
      _config['outbounds']?[0]?['settings']?['vnext']?[0]?['port'] ??
      super.port;

  @override
  Map<String, dynamic> get outbound1 {
    if (_config['outbounds'] != null && _config['outbounds'].isNotEmpty) {
      return Map<String, dynamic>.from(_config['outbounds'][0]);
    }
    return {
      "tag": "proxy",
      "protocol": "freedom",
      "settings": {},
      "streamSettings": streamSetting,
    };
  }

  @override
  Map<String, dynamic> get fullConfiguration => {
        "log": log,
        "dns": dns,
        "stats": _config['stats'] ?? {},
        "api": _config['api'] ?? {},
        "policy": _config['policy'] ?? {},
        "inbounds": [inbound],
        "outbounds": [outbound1, outbound2, outbound3],
        "routing": routing,
        "observatory": _config['observatory'] ?? {},
        "burstObservatory": _config['burstObservatory'] ?? {},
      };
}
