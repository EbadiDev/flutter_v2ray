import 'dart:convert';
import 'dart:io';

import 'package:flutter_v2ray/url/shadowsocks.dart';
import 'package:flutter_v2ray/url/socks.dart';
import 'package:flutter_v2ray/url/trojan.dart';
import 'package:flutter_v2ray/url/url.dart';
import 'package:flutter_v2ray/url/vless.dart';
import 'package:flutter_v2ray/url/vmess.dart';

import 'flutter_v2ray_platform_interface.dart';
import 'model/v2ray_status.dart';

export 'model/v2ray_status.dart';
export 'url/url.dart';

class FlutterV2ray {
  FlutterV2ray({required this.onStatusChanged});

  /// This method is called when V2Ray status has changed.
  final void Function(V2RayStatus status) onStatusChanged;

  /// Request VPN service permission specifically for Android.
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      return await FlutterV2rayPlatform.instance.requestPermission();
    }
    return true;
  }

  /// You must initialize V2Ray before using it.
  Future<void> initializeV2Ray({
    String notificationIconResourceType = "mipmap",
    String notificationIconResourceName = "ic_launcher",
  }) async {
    await FlutterV2rayPlatform.instance.initializeV2Ray(
      onStatusChanged: onStatusChanged,
      notificationIconResourceType: notificationIconResourceType,
      notificationIconResourceName: notificationIconResourceName,
    );
  }

  /// Start V2Ray service.
  ///
  /// config:
  ///
  ///   V2Ray Config (json)
  ///
  /// blockedApps:
  ///
  ///   Apps that won't go through the VPN tunnel.
  ///
  ///   Contains a list of package names.
  ///
  ///   specifically for Android.
  ///
  /// bypassSubnets:
  ///
  ///     [Default = 0.0.0.0/0]
  ///
  ///     Add at least one route if you want the system to send traffic through the VPN interface.
  ///
  ///     Routes filter by destination addresses.
  ///
  ///     To accept all traffic, set an open route such as 0.0.0.0/0 or ::/0.
  ///
  /// proxyOnly:
  ///
  ///   If it is true, only the v2ray proxy will be executed,
  ///
  ///   and the VPN tunnel will not be executed.
  Future<void> startV2Ray({
    required String remark,
    required String config,
    List<String>? blockedApps,
    List<String>? bypassSubnets,
    bool proxyOnly = false,
    String notificationDisconnectButtonName = "DISCONNECT",
    String? notificationTitle,
  }) async {
    try {
      print('📦 Starting V2Ray with raw config: $config');

      if (jsonDecode(config) == null) {
        throw ArgumentError('The provided string is not valid JSON');
      }

      // Log the configuration details
      Map<String, dynamic> configMap = jsonDecode(config);
      print('🔍 Outbound protocol: ${configMap['outbounds']?[0]?['protocol']}');
      print(
          '🔍 Network type: ${configMap['outbounds']?[0]?['streamSettings']?['network']}');
      print(
          '🔍 Routing rules count: ${configMap['routing']?['rules']?.length ?? 0}');
      print('🔍 DNS servers: ${configMap['dns']?['servers']}');

      await FlutterV2rayPlatform.instance.startV2Ray(
        remark: remark,
        config: config,
        blockedApps: blockedApps,
        proxyOnly: proxyOnly,
        bypassSubnets: bypassSubnets,
        notificationDisconnectButtonName: notificationDisconnectButtonName,
        notificationTitle: notificationTitle ?? remark,
      );
      print('✅ V2Ray service start command sent');
    } catch (e) {
      print('❌ Error starting V2Ray: $e');
      throw ArgumentError('Failed to start V2Ray: $e');
    }
  }

  Future<dynamic> getAllServerDelay({required List<String> configs}) async {
    try {
      List<String> modifiedConfigs = [];

      for (String config in configs) {
        Map<String, dynamic> configMap = jsonDecode(config);
        final parsedConfig =
            parseCompleteConfig(configMap, isDelayTesting: true);
        modifiedConfigs.add(jsonEncode(parsedConfig));
      }

      return await FlutterV2rayPlatform.instance
          .getAllServerDelay(configs: modifiedConfigs);
    } catch (e) {
      print('Error in getAllServerDelay: $e');
      throw ArgumentError('Error processing configurations: $e');
    }
  }

  /// Get ping times for multiple servers in parallel
  /// Returns a map of config string to ping time in milliseconds
  /// Returns -1 for failed pings
  Future<Map<String, int>> getAllServerPing({
    required List<String> configs,
    String url = 'http://cp.cloudflare.com',
  }) async {
    try {
      List<String> modifiedConfigs = [];

      for (String config in configs) {
        Map<String, dynamic> configMap = jsonDecode(config);
        final parsedConfig =
            parseCompleteConfig(configMap, isDelayTesting: true);
        modifiedConfigs.add(jsonEncode(parsedConfig));
      }

      return await FlutterV2rayPlatform.instance.getAllServerPing(
        configs: modifiedConfigs,
        url: url,
      );
    } catch (e) {
      print('Error in getAllServerPing: $e');
      throw ArgumentError('Error processing configurations: $e');
    }
  }

  /// Stop V2Ray service.
  Future<void> stopV2Ray() async {
    await FlutterV2rayPlatform.instance.stopV2Ray();
  }

  /// This method returns the real server delay of the configuration.
  Future<int> getServerDelay(
      {required String config,
      String url = 'https://google.com/generate_204'}) async {
    try {
      Map<String, dynamic> configMap = jsonDecode(config);
      final parsedConfig = parseCompleteConfig(configMap, isDelayTesting: true);
      String modifiedConfig = jsonEncode(parsedConfig);

      return await FlutterV2rayPlatform.instance
          .getServerDelay(config: modifiedConfig, url: url);
    } catch (e) {
      print('Error in getServerDelay: $e');
      throw ArgumentError('Error processing configuration: $e');
    }
  }

  /// This method returns the current connection state
  /// in the form of the String, which can be either
  ///  - ["CONNECTING"]
  ///  - ["CONNECTED"]
  ///  - ["DISCONNECTED"]
  ///  - ["ERROR"]
  Future<String> getV2rayStatus() async {
    return await FlutterV2rayPlatform.instance.getV2rayStatus();
  }

  /// This method returns the connected server delay.
  Future<int> getConnectedServerDelay(
      {String url = 'https://google.com/generate_204'}) async {
    return await FlutterV2rayPlatform.instance.getConnectedServerDelay(url);
  }

  // This method returns the V2Ray Core version.
  Future<String> getCoreVersion() async {
    return await FlutterV2rayPlatform.instance.getCoreVersion();
  }

  /// parse V2RayURL object from V2Ray share link
  ///
  /// like vmess://, vless://, trojan://, ss://, socks://
  static V2RayURL parseFromURL(String url) {
    switch (url.split("://")[0].toLowerCase()) {
      case 'vmess':
        return VmessURL(url: url);
      case 'vless':
        return VlessURL(url: url);
      case 'trojan':
        return TrojanURL(url: url);
      case 'ss':
        return ShadowSocksURL(url: url);
      case 'socks':
        return SocksURL(url: url);
      default:
        throw ArgumentError('url is invalid');
    }
  }

  /// Parse a complete V2Ray configuration
  ///
  /// This method accepts a complete V2Ray configuration as a Map
  /// and returns a validated and normalized configuration that can be used directly.
  /// The input should be a complete V2Ray configuration containing:
  /// remarks, log, stats, api, dns, policy, inbounds, outbounds, routing, observatory
  static Map<String, dynamic> parseCompleteConfig(Map<String, dynamic> config,
      {bool isDelayTesting = false}) {
    print(
        '🔄 Parsing ${isDelayTesting ? "delay testing" : "full"} configuration');

    // Validate required fields
    if (!config.containsKey('outbounds') || config['outbounds'].isEmpty) {
      print('❌ No outbounds found in configuration');
      throw ArgumentError('Configuration must contain at least one outbound');
    }

    // Don't modify the original config
    Map<String, dynamic> finalConfig = Map.from(config);
    print('📝 Original config remarks: ${finalConfig['remarks']}');

    // Ensure remarks is present
    if (!finalConfig.containsKey('remarks')) {
      finalConfig['remarks'] = finalConfig['outbounds'][0]['tag'] ?? 'proxy';
      print('ℹ️ Using default remarks: ${finalConfig['remarks']}');
    }

    // Ensure log configuration
    if (!finalConfig.containsKey('log')) {
      finalConfig['log'] = {
        "access": "",
        "error": "",
        "loglevel": "debug",
        "dnsLog": false
      };
    }

    // For delay testing, use simplified DNS config
    if (isDelayTesting) {
      finalConfig['dns'] = {
        "servers": ["8.8.8.8", "8.8.4.4"],
        "queryStrategy": "UseIPv4"
      };
      print('🔄 Using simplified DNS for delay testing');
    } else if (!finalConfig.containsKey('dns')) {
      finalConfig['dns'] = {
        "servers": ["1.1.1.1", "1.0.0.1", "8.8.8.8", "8.8.4.4"],
        "queryStrategy": "UseIPv4"
      };
      print('ℹ️ Added default DNS configuration');
    }

    // For delay testing, we don't need stats and api
    if (!isDelayTesting) {
      // Ensure stats and api configuration for traffic monitoring
      if (!finalConfig.containsKey('stats')) {
        finalConfig['stats'] = {};
      }
      if (!finalConfig.containsKey('api')) {
        finalConfig['api'] = {
          "tag": "api",
          "services": ["StatsService"]
        };
      }

      // Ensure policy configuration
      if (!finalConfig.containsKey('policy')) {
        finalConfig['policy'] = {
          "system": {"statsOutboundDownlink": true, "statsOutboundUplink": true}
        };
      }
    } else {
      // Remove stats and policy for delay testing
      finalConfig.remove('stats');
      finalConfig.remove('policy');
    }

    // Ensure inbounds configuration
    if (!finalConfig.containsKey('inbounds')) {
      finalConfig['inbounds'] = [
        {
          "tag": "socks",
          "port": 10808,
          "listen": "127.0.0.1",
          "protocol": "socks",
          "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls"],
            "routeOnly": false
          },
          "settings": {"auth": "noauth", "udp": true, "allowTransparent": false}
        },
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
      ];
    }

    // Handle routing configuration
    if (isDelayTesting) {
      print('🔄 Configuring for delay testing');
      finalConfig['routing'] = {
        "domainStrategy": "AsIs",
        "domainMatcher": "hybrid"
      };
    } else {
      print('🔄 Processing routing configuration');
      String mainOutboundTag = finalConfig['outbounds'][0]['tag'];

      // Create routing configuration with balancers
      finalConfig['routing'] = {
        "domainMatcher": "hybrid",
        "domainStrategy": "IPIfNonMatch",
        "rules": [
          {
            "type": "field",
            "network": "tcp,udp",
            "balancerTag": "balancer_leastPing",
            "enabled": true
          },
          {
            "type": "field",
            "inboundTag": ["api"],
            "outboundTag": "api",
            "enabled": true
          },
          {
            "type": "field",
            "domain": ["geosite:ir"],
            "outboundTag": "direct",
            "enabled": true
          },
          {
            "type": "field",
            "ip": ["geoip:ir"],
            "outboundTag": "direct",
            "enabled": true
          }
        ],
        "balancers": [
          {
            "tag": "balancer_leastPing",
            "selector": [mainOutboundTag],
            "strategy": {"type": "leastPing"}
          },
          {
            "tag": "balancer_leastLoad",
            "fallbackTag": "balancer_leastPing",
            "selector": [mainOutboundTag],
            "strategy": {"type": "leastLoad"}
          }
        ]
      };
      print('✅ Routing configuration updated with balancers');
    }

    // Add observatory if not present
    if (!finalConfig.containsKey('observatory')) {
      String mainOutboundTag = finalConfig['outbounds'][0]['tag'];
      finalConfig['observatory'] = {
        "subjectSelector": [mainOutboundTag],
        "probeUrl": "http://cp.cloudflare.com/",
        "probeInterval": "10s",
        "enableConcurrency": true
      };
    }

    print('✅ Configuration parsing completed');
    return finalConfig;
  }
}
