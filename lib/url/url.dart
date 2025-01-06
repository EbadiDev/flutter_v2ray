import 'dart:convert';

class DnsSettings {
  static Map<String, dynamic> hosts = {
    "domain:googleapis.com": "googleapis.com",
    "domain:google.com": ["8.8.8.8", "8.8.4.4"],
    "domain:cloudflare.com": ["1.1.1.1", "1.0.0.1"]
  };

  static List<dynamic> servers = [
    {
      "address": "https://dns.google/dns-query",
      "domains": ["geosite:google"],
      "skipFallback": true,
      "queryStrategy": "UseIPv4"
    },
    {
      "address": "https://cloudflare-dns.com/dns-query",
      "domains": ["geosite:cloudflare"],
      "skipFallback": true,
      "queryStrategy": "UseIPv4"
    },
    "1.1.1.1",
    "1.0.0.1",
    "8.8.8.8",
    "8.8.4.4"
  ];

  static Map<String, dynamic> additionalSettings = {
    "disableCache": false,
    "disableFallback": false,
    "disableFallbackIfMatch": true
  };

  static bool useAdvancedSettings = true;
}

abstract class V2RayURL {
  V2RayURL({required this.url});
  final String url;

  bool get allowInsecure => true;
  String get security => "auto";
  int get level => 8;
  int get port => 443;
  String get network => "tcp";
  String get address => '';
  String get remark => '';

  Map<String, dynamic> inbound = {
    "tag": "socks",
    "port": 10808,
    "protocol": "socks",
    "listen": "127.0.0.1",
    "settings": {"auth": "noauth", "udp": true, "allowTransparent": false},
    "sniffing": {
      "enabled": false,
      "destOverride": ["http", "tls"],
      "routeOnly": false
    }
  };

  Map<String, dynamic> log = {
    "access": "",
    "error": "",
    "loglevel": "none",
    "dnsLog": false,
  };

  Map<String, dynamic> get dns {
    // Default simple configuration for delay testing
    Map<String, dynamic> dnsConfig = {
      "servers": ["8.8.8.8", "8.8.4.4"],
      "queryStrategy": "UseIPv4"
    };

    // Only use advanced settings when not testing delay
    if (DnsSettings.useAdvancedSettings && !isDelayTesting) {
      // Add hosts if configured
      if (DnsSettings.hosts.isNotEmpty) {
        dnsConfig["hosts"] = DnsSettings.hosts;
      }

      // Add advanced server configurations if configured
      if (DnsSettings.servers.isNotEmpty) {
        dnsConfig["servers"] = DnsSettings.servers;
      }

      // Add additional settings
      dnsConfig.addAll(DnsSettings.additionalSettings);
    }

    return dnsConfig;
  }

  bool isDelayTesting = false;

  Map<String, dynamic> get policy => {
        "system": {"statsOutboundDownlink": true, "statsOutboundUplink": true}
      };

  Map<String, dynamic> get outbound1;

  Map<String, dynamic> outbound2 = {
    "tag": "direct",
    "protocol": "freedom",
    "settings": {}
  };

  Map<String, dynamic> outbound3 = {
    "tag": "block",
    "protocol": "blackhole",
    "settings": {
      "response": {"type": "http"}
    }
  };

  Map<String, dynamic> get routing {
    if (isDelayTesting) {
      return {
        "domainStrategy": "AsIs",
        "rules": [
          {
            "type": "field",
            "outboundTag": remark,
            "port": "0-65535",
            "enabled": true
          }
        ]
      };
    }

    return {
      "domainStrategy": "AsIs",
      "domainMatcher": "hybrid",
      "rules": [
        {
          "type": "field",
          "inboundTag": ["api"],
          "outboundTag": "api",
          "enabled": true
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "ip": ["geoip:ir", "geoip:private"],
          "enabled": true
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "domain": ["geosite:ir"],
          "enabled": true
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "domain": ["keyword:discord", "keyword:discordapp"],
          "network": "udp",
          "enabled": true
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "domain": ["keyword:ttvnw.net", "keyword:tmaxfx"],
          "network": "tcp",
          "enabled": true
        },
        {
          "type": "field",
          "outboundTag": "direct",
          "domain": ["geosite:whatsapp"],
          "enabled": true
        }
      ]
    };
  }

  Map<String, dynamic> observatory = {
    "subjectSelector": [], // Will be populated with remark
    "probeUrl": "http://cp.cloudflare.com/",
    "probeInterval": "10s",
    "enableConcurrency": false,
    "pingConfig": {
      "destination": "http://cp.cloudflare.com/",
      "connectivity": "",
      "interval": "1h",
      "sampling": 3,
      "timeout": "30s"
    }
  };

  Map<String, dynamic> get fullConfiguration {
    observatory["subjectSelector"] = [remark];

    // Add the catch-all rule with ID
    routing["rules"].add({
      "id": remark.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
      "type": "field",
      "port": "0-65535",
      "outboundTag": remark,
      "enabled": true
    });

    // Add IDs to existing rules if they don't have one
    for (var rule in routing['rules']) {
      if (!rule.containsKey('id')) {
        rule['id'] = '${rule['outboundTag']}_${rule['type']}';
      }
    }

    return {
      "use_fragment": false,
      "remarks": remark,
      "log": log,
      "dns": dns,
      "policy": policy,
      "inbounds": [
        inbound,
        {
          "tag": "http",
          "port": 10809,
          "listen": "127.0.0.1",
          "protocol": "http",
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"],
            "routeOnly": false
          },
          "settings": {"auth": "noauth", "udp": true, "allowTransparent": false}
        }
      ],
      "outbounds": [outbound1, outbound2, outbound3],
      "routing": routing,
      "observatory": observatory,
    };
  }

  /// Generate Full V2Ray Configuration
  ///
  /// indent: json encoder indent
  String getFullConfiguration({int indent = 2}) {
    return JsonEncoder.withIndent(' ' * indent).convert(
      removeNulls(
        Map.from(fullConfiguration),
      ),
    );
  }

  late Map<String, dynamic> streamSetting = {
    "network": network,
    "security": "",
    "tcpSettings": null,
    "kcpSettings": null,
    "wsSettings": null,
    "httpSettings": null,
    "tlsSettings": null,
    "quicSettings": null,
    "realitySettings": null,
    "grpcSettings": null,
    "dsSettings": null,
    "sockopt": null
  };

  String populateTransportSettings({
    required String transport,
    required String? headerType,
    required String? host,
    required String? path,
    required String? seed,
    required String? quicSecurity,
    required String? key,
    required String? mode,
    required String? serviceName,
  }) {
    String sni = '';
    streamSetting['network'] = transport;
    if (transport == 'tcp') {
      streamSetting['tcpSettings'] = {
        "header": <String, dynamic>{"type": "none", "request": null},
        "acceptProxyProtocol": false
      };
      if (headerType == 'http') {
        streamSetting['tcpSettings']['header']['type'] = 'http';
        if (host != "" || path != "") {
          List<String> hostList = [];
          if (host != null && host.isNotEmpty) {
            hostList = host.split(",").map((e) => e.trim()).toList();
          }

          streamSetting['tcpSettings']['header']['request'] = {
            "version": "1.1",
            "method": "GET",
            "path": path == null
                ? ["/"]
                : path.split(",").map((e) => e.trim()).toList(),
            "headers": {
              "Host": hostList,
              "User-Agent": [
                "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2785.143 Safari/537.36",
                "Mozilla/5.0 (iPhone; CPU iPhone OS 10_0_2 like Mac OS X) AppleWebKit/601.1 (KHTML, like Gecko) CriOS/53.0.2785.109 Mobile/14A456 Safari/601.1.46"
              ],
              "Accept-Encoding": ["gzip, deflate"],
              "Connection": ["keep-alive"],
              "Pragma": "no-cache"
            }
          };

          // Set SNI from host if available
          sni = hostList.isNotEmpty ? hostList[0] : sni;
        }
      } else {
        streamSetting['tcpSettings']['header']['type'] = 'none';
        sni = host != null && host.isNotEmpty ? host : '';
      }
    } else if (transport == 'http' || transport == 'h2') {
      streamSetting['network'] = 'http';
      streamSetting['httpSettings'] = {
        "path": path == null ? "/" : path,
        "host": host?.split(",").map((e) => e.trim()).toList() ?? [],
        "method": "GET",
        "headers": {}
      };
      if (host != null && host.isNotEmpty) {
        List<String> hosts = host.split(",").map((e) => e.trim()).toList();
        sni = hosts[0];
      }
    } else if (transport == 'ws') {
      streamSetting['wsSettings'] = {
        "path": path ?? "/",
        "headers": {"Host": host ?? ""},
        "maxEarlyData": null,
        "useBrowserForwarding": null,
        "acceptProxyProtocol": false
      };
      sni = host ?? "";
    } else if (transport == 'kcp') {
      streamSetting['kcpSettings'] = {
        "mtu": 1350,
        "tti": 50,
        "uplinkCapacity": 12,
        "downlinkCapacity": 100,
        "congestion": false,
        "readBufferSize": 1,
        "writeBufferSize": 1,
        "header": {"type": headerType ?? "none"},
        "seed": (seed == null || seed == '') ? null : seed
      };
    } else if (transport == 'quic') {
      streamSetting['quicSettings'] = {
        "security": quicSecurity ?? 'none',
        "key": key ?? '',
        "header": {"type": headerType ?? "none"}
      };
    } else if (transport == 'grpc') {
      streamSetting['grpcSettings'] = {
        "serviceName": serviceName ?? "",
        "multiMode": mode == "multi"
      };
      sni = host ?? "";
    }
    return sni;
  }

  void populateTlsSettings({
    required String? streamSecurity,
    required bool allowInsecure,
    required String? sni,
    required String? fingerprint,
    required String? alpns,
    required String? publicKey,
    required String? shortId,
    required String? spiderX,
  }) {
    streamSetting['security'] = streamSecurity;
    Map<String, dynamic> tlsSetting = {
      "allowInsecure": allowInsecure,
      "serverName": sni,
      "alpn": alpns == '' ? null : alpns?.split(','),
      "minVersion": null,
      "maxVersion": null,
      "preferServerCipherSuites": null,
      "cipherSuites": null,
      "fingerprint": fingerprint,
      "certificates": null,
      "disableSystemRoot": null,
      "enableSessionResumption": null,
      "show": false,
      "publicKey": publicKey,
      "shortId": shortId,
      "spiderX": spiderX,
    };
    if (streamSecurity == 'tls') {
      streamSetting['realitySettings'] = null;
      streamSetting['tlsSettings'] = tlsSetting;
    } else if (streamSecurity == 'reality') {
      streamSetting['tlsSettings'] = null;
      streamSetting['realitySettings'] = tlsSetting;
    }
  }

  dynamic removeNulls(dynamic params) {
    if (params is Map) {
      var map = {};
      params.forEach((key, value) {
        // Special handling for DNS configuration
        if (key == "dns") {
          map[key] = value;
          return;
        }
        var value0 = removeNulls(value);
        if (value0 != null) {
          map[key] = value0;
        }
      });
      if (map.isNotEmpty) {
        return map;
      }
    } else if (params is List) {
      var list = [];
      for (var val in params) {
        var value = removeNulls(val);
        if (value != null) {
          list.add(value);
        }
      }
      if (list.isNotEmpty) return list;
    } else if (params != null) {
      return params;
    }
    return null;
  }
}
