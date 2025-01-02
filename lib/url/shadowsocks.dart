import 'dart:convert';

import 'package:flutter_v2ray/url/url.dart';

class ShadowSocksURL extends V2RayURL {
  ShadowSocksURL({required super.url}) {
    if (!url.startsWith('ss://')) {
      throw ArgumentError('url is invalid');
    }
    final temp = Uri.tryParse(url);
    if (temp == null) {
      throw ArgumentError('url is invalid');
    }
    uri = temp;
    if (uri.userInfo.isNotEmpty) {
      String raw = uri.userInfo;
      if (raw.length % 4 > 0) {
        raw += "=" * (4 - raw.length % 4);
      }
      try {
        final methodpass = utf8.decode(base64Decode(raw));
        method = methodpass.split(':')[0];
        password = methodpass.substring(method.length + 1);
      } catch (_) {}
    }

    if (uri.queryParameters.isNotEmpty) {
      var sni = super.populateTransportSettings(
        transport: uri.queryParameters['type'] ?? "tcp",
        headerType: uri.queryParameters['headerType'],
        host: uri.queryParameters["host"],
        path: uri.queryParameters["path"],
        seed: uri.queryParameters["seed"],
        quicSecurity: uri.queryParameters["quicSecurity"],
        key: uri.queryParameters["key"],
        mode: uri.queryParameters["mode"],
        serviceName: uri.queryParameters["serviceName"],
      );
      super.populateTlsSettings(
        streamSecurity: uri.queryParameters['security'] ?? '',
        allowInsecure: allowInsecure,
        sni: uri.queryParameters["sni"] ?? sni,
        fingerprint: streamSetting['tlsSettings']?['fingerprint'],
        alpns: uri.queryParameters['alpn'],
        publicKey: null,
        shortId: null,
        spiderX: null,
      );
    }

    // Update the null outboundTag in routing rules with server's remark
    for (var rule in routing['rules']) {
      if (rule['outboundTag'] == null) {
        rule['outboundTag'] = remark;
      }
    }
  }

  @override
  String get address => uri.host;

  @override
  int get port => uri.hasPort ? uri.port : super.port;

  @override
  String get remark => Uri.decodeFull(uri.fragment.replaceAll('+', '%20'));

  late final Uri uri;

  String method = "none";

  String password = "";

  @override
  Map<String, dynamic> get outbound1 => {
        "tag": remark,
        "protocol": "shadowsocks",
        "settings": {
          "servers": [
            {
              "address": address,
              "port": port,
              "method": method,
              "password": password,
              "uot": true,
              "level": 0
            }
          ]
        },
        "streamSettings": streamSetting,
        "mux": {"enabled": false, "concurrency": 8}
      };

  @override
  Map<String, dynamic> get fullConfiguration {
    // Ensure routing rules use the correct outboundTag
    for (var rule in routing['rules']) {
      if (rule['outboundTag'] == null) {
        rule['outboundTag'] = remark;
      }
    }

    // Add the catch-all rule
    routing['rules'].add({
      "type": "field",
      "port": "0-65535",
      "outboundTag": remark,
      "enabled": true
    });

    return super.fullConfiguration;
  }
}
