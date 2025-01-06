package com.github.blueboytm.flutter_v2ray.v2ray.utils;

import android.content.Context;
import android.util.Log;

import com.github.blueboytm.flutter_v2ray.v2ray.core.V2rayCoreManager;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.util.ArrayList;

public class Utilities {

    public static void CopyFiles(InputStream src, File dst) throws IOException {
        try (OutputStream out = new FileOutputStream(dst)) {
            byte[] buf = new byte[1024];
            int len;
            while ((len = src.read(buf)) > 0) {
                out.write(buf, 0, len);
            }
        }
    }

    public static String getUserAssetsPath(Context context) {
        File extDir = context.getExternalFilesDir("assets");
        if (extDir == null) {
            return "";
        }
        if (!extDir.exists()) {
            return context.getDir("assets", 0).getAbsolutePath();
        } else {
            return extDir.getAbsolutePath();
        }
    }

    public static void copyAssets(final Context context) {
        String extFolder = getUserAssetsPath(context);
        try {
            String geo = "geosite.dat,geoip.dat";
            for (String assets_obj : context.getAssets().list("")) {
                if (geo.contains(assets_obj)) {
                    CopyFiles(context.getAssets().open(assets_obj), new File(extFolder, assets_obj));
                }
            }
        } catch (Exception e) {
            Log.e("Utilities", "copyAssets failed=>", e);
        }
    }


    public static String convertIntToTwoDigit(int value) {
        if (value < 10) return "0" + value;
        else return value + "";
    }


    public static V2rayConfig parseV2rayJsonFile(final String remark, String config, final ArrayList<String> blockedApplication, final ArrayList<String> bypass_subnets) {
        Log.d("ArchNet", "Parsing V2Ray config with remark: " + remark);
        final V2rayConfig v2rayConfig = new V2rayConfig();
        v2rayConfig.REMARK = remark;
        v2rayConfig.BLOCKED_APPS = blockedApplication;
        v2rayConfig.BYPASS_SUBNETS = bypass_subnets;
        v2rayConfig.APPLICATION_ICON = AppConfigs.APPLICATION_ICON;
        v2rayConfig.APPLICATION_NAME = AppConfigs.APPLICATION_NAME;
        v2rayConfig.NOTIFICATION_DISCONNECT_BUTTON_NAME = AppConfigs.NOTIFICATION_DISCONNECT_BUTTON_NAME;
        v2rayConfig.NOTIFICATION_TITLE = AppConfigs.NOTIFICATION_TITLE;
        try {
            Log.d("ArchNet", "Parsing JSON config...");
            JSONObject config_json = new JSONObject(config);
            try {
                JSONArray inbounds = config_json.getJSONArray("inbounds");
                Log.d("ArchNet", "Found " + inbounds.length() + " inbound configurations");
                for (int i = 0; i < inbounds.length(); i++) {
                    try {
                        if (inbounds.getJSONObject(i).getString("protocol").equals("socks")) {
                            v2rayConfig.LOCAL_SOCKS5_PORT = inbounds.getJSONObject(i).getInt("port");
                            Log.d("ArchNet", "Found SOCKS5 port: " + v2rayConfig.LOCAL_SOCKS5_PORT);
                        }
                    } catch (Exception e) {
                        Log.w("ArchNet", "Error parsing SOCKS5 config: " + e.getMessage());
                    }
                    try {
                        if (inbounds.getJSONObject(i).getString("protocol").equals("http")) {
                            v2rayConfig.LOCAL_HTTP_PORT = inbounds.getJSONObject(i).getInt("port");
                            Log.d("ArchNet", "Found HTTP port: " + v2rayConfig.LOCAL_HTTP_PORT);
                        }
                    } catch (Exception e) {
                        Log.w("ArchNet", "Error parsing HTTP config: " + e.getMessage());
                    }
                }
            } catch (Exception e) {
                Log.e("ArchNet", "Failed to parse inbound ports: " + e.getMessage());
                return null;
            }
            try {
                Log.d("ArchNet", "Parsing outbound configuration...");
                JSONArray outbounds = config_json.getJSONArray("outbounds");
                JSONObject firstOutbound = outbounds.getJSONObject(0);
                String protocol = firstOutbound.getString("protocol");
                JSONObject settings = firstOutbound.getJSONObject("settings");
                
                // Fix HTTP headers in all outbounds
                for (int i = 0; i < outbounds.length(); i++) {
                    JSONObject outbound = outbounds.getJSONObject(i);
                    if (outbound.has("streamSettings")) {
                        JSONObject streamSettings = outbound.getJSONObject("streamSettings");
                        if (streamSettings.has("tcpSettings")) {
                            JSONObject tcpSettings = streamSettings.getJSONObject("tcpSettings");
                            if (tcpSettings.has("header")) {
                                JSONObject header = tcpSettings.getJSONObject("header");
                                if (header.getString("type").equals("http") && header.has("request")) {
                                    JSONObject request = header.getJSONObject("request");
                                    if (request.has("headers")) {
                                        JSONObject headers = request.getJSONObject("headers");
                                        // Fix Host header format
                                        if (headers.has("Host")) {
                                            headers.remove("Host");  // Remove Host from headers as it's handled separately
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Handle HTTPUpgrade settings
                        if (streamSettings.has("httpupgradeSettings")) {
                            JSONObject httpupgradeSettings = streamSettings.getJSONObject("httpupgradeSettings");
                            if (httpupgradeSettings.has("headers")) {
                                JSONObject headers = httpupgradeSettings.getJSONObject("headers");
                                if (headers.has("Host")) {
                                    headers.remove("Host");  // Remove Host from headers as it's handled separately
                                }
                            }
                        }
                    }
                    Log.d("ArchNet", "Processed outbound: " + outbound.getString("tag"));
                }

                // Parse server address and port based on protocol
                if (protocol.equals("vless") || protocol.equals("vmess")) {
                    if (settings.has("vnext") && settings.getJSONArray("vnext").length() > 0) {
                        JSONObject vnext = settings.getJSONArray("vnext").getJSONObject(0);
                        v2rayConfig.CONNECTED_V2RAY_SERVER_ADDRESS = vnext.getString("address");
                        v2rayConfig.CONNECTED_V2RAY_SERVER_PORT = vnext.getString("port");
                        Log.d("ArchNet", "Server address (vnext): " + v2rayConfig.CONNECTED_V2RAY_SERVER_ADDRESS + ":" + v2rayConfig.CONNECTED_V2RAY_SERVER_PORT);
                    } else {
                        throw new Exception("Invalid vnext configuration");
                    }
                } else if (protocol.equals("shadowsocks")) {
                    if (settings.has("servers") && settings.getJSONArray("servers").length() > 0) {
                        JSONObject server = settings.getJSONArray("servers").getJSONObject(0);
                        v2rayConfig.CONNECTED_V2RAY_SERVER_ADDRESS = server.getString("address");
                        v2rayConfig.CONNECTED_V2RAY_SERVER_PORT = server.getString("port");
                        
                        // Add specific DNS configuration for Shadowsocks
                        JSONObject dnsConfig = config_json.getJSONObject("dns");
                        dnsConfig.put("queryStrategy", "UseIPv4");
                        JSONArray servers = new JSONArray()
                            .put(new JSONObject().put("address", "8.8.8.8"))
                            .put(new JSONObject().put("address", "8.8.4.4"))
                            .put(new JSONObject().put("address", "1.1.1.1"))
                            .put(new JSONObject().put("address", "1.0.0.1"));
                        dnsConfig.put("servers", servers);
                        
                        // Add DNS routing rule
                        JSONObject routing = config_json.getJSONObject("routing");
                        JSONArray rules = routing.getJSONArray("rules");
                        JSONObject dnsRule = new JSONObject();
                        dnsRule.put("type", "field");
                        dnsRule.put("port", "53");
                        dnsRule.put("network", "udp");
                        dnsRule.put("outboundTag", "direct");
                        rules.put(0, dnsRule);
                        
                        Log.d("ArchNet", "Server address (servers): " + v2rayConfig.CONNECTED_V2RAY_SERVER_ADDRESS + ":" + v2rayConfig.CONNECTED_V2RAY_SERVER_PORT);
                    } else {
                        throw new Exception("Invalid servers configuration");
                    }
                } else if (protocol.equals("trojan") || protocol.equals("socks")) {
                    if (settings.has("servers") && settings.getJSONArray("servers").length() > 0) {
                        JSONObject server = settings.getJSONArray("servers").getJSONObject(0);
                        v2rayConfig.CONNECTED_V2RAY_SERVER_ADDRESS = server.getString("address");
                        v2rayConfig.CONNECTED_V2RAY_SERVER_PORT = server.getString("port");
                        Log.d("ArchNet", "Server address (servers): " + v2rayConfig.CONNECTED_V2RAY_SERVER_ADDRESS + ":" + v2rayConfig.CONNECTED_V2RAY_SERVER_PORT);
                    } else {
                        throw new Exception("Invalid servers configuration");
                    }
                } else {
                    throw new Exception("Unsupported protocol: " + protocol);
                }
            } catch (Exception e) {
                Log.e("ArchNet", "Failed to parse outbound configuration: " + e.getMessage());
                return null;
            }

            // Handle routing and balancer configuration
            try {
                JSONObject routing = config_json.getJSONObject("routing");
                if (routing.has("rules")) {
                    JSONArray rules = routing.getJSONArray("rules");
                    for (int i = 0; i < rules.length(); i++) {
                        JSONObject rule = rules.getJSONObject(i);
                        if (rule.has("balancerTag")) {
                            String balancerTag = rule.getString("balancerTag");
                            // Ensure the referenced balancer exists
                            if (routing.has("balancers")) {
                                JSONArray balancers = routing.getJSONArray("balancers");
                                boolean balancerFound = false;
                                for (int j = 0; j < balancers.length(); j++) {
                                    if (balancers.getJSONObject(j).getString("tag").equals(balancerTag)) {
                                        balancerFound = true;
                                        break;
                                    }
                                }
                                if (!balancerFound) {
                                    // Update the balancer tag to match an existing one
                                    rule.put("balancerTag", balancers.getJSONObject(0).getString("tag"));
                                    Log.d("ArchNet", "Updated balancer tag to: " + balancers.getJSONObject(0).getString("tag"));
                                }
                            }
                        }
                    }
                }
            } catch (Exception e) {
                Log.w("ArchNet", "Error handling routing configuration: " + e.getMessage());
            }

            try {
                if (config_json.has("policy")) {
                    config_json.remove("policy");
                    Log.d("ArchNet", "Removed policy configuration");
                }
                if (config_json.has("stats")) {
                    config_json.remove("stats");
                    Log.d("ArchNet", "Removed stats configuration");
                }
            } catch (Exception ignore_error) {
                Log.w("ArchNet", "Error handling policy/stats: " + ignore_error.getMessage());
            }
            if (AppConfigs.ENABLE_TRAFFIC_AND_SPEED_STATICS) {
                try {
                    Log.d("ArchNet", "Adding traffic statistics configuration...");
                    JSONObject policy = new JSONObject();
                    JSONObject levels = new JSONObject();
                    levels.put("8", new JSONObject()
                            .put("connIdle", 300)
                            .put("downlinkOnly", 1)
                            .put("handshake", 4)
                            .put("uplinkOnly", 1));
                    JSONObject system = new JSONObject()
                            .put("statsOutboundUplink", true)
                            .put("statsOutboundDownlink", true);
                    policy.put("levels", levels);
                    policy.put("system", system);
                    config_json.put("policy", policy);
                    config_json.put("stats", new JSONObject());
                    config = config_json.toString();
                    v2rayConfig.ENABLE_TRAFFIC_STATICS = true;
                    Log.d("ArchNet", "Traffic statistics configuration added");
                } catch (Exception e) {
                    Log.e("ArchNet", "Failed to add traffic statistics: " + e.getMessage());
                }
            }
            v2rayConfig.V2RAY_FULL_JSON_CONFIG = config_json.toString();
        } catch (Exception e) {
            Log.e("ArchNet", "Failed to parse V2Ray config: " + e.getMessage());
            e.printStackTrace();
            return null;
        }
        Log.d("ArchNet", "V2Ray configuration parsing completed successfully");
        return v2rayConfig;
    }


}
