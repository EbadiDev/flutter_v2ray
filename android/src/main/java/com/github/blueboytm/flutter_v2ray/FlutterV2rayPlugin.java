package com.github.blueboytm.flutter_v2ray;

import android.Manifest;
import android.annotation.SuppressLint;
import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.net.VpnService;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;

import com.github.blueboytm.flutter_v2ray.v2ray.V2rayController;
import com.github.blueboytm.flutter_v2ray.v2ray.V2rayReceiver;
import com.github.blueboytm.flutter_v2ray.v2ray.utils.AppConfigs;
import com.google.gson.Gson;
import com.google.gson.JsonObject;

import java.util.List;
import java.util.Map;
import java.util.HashMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * FlutterV2rayPlugin
 */
public class FlutterV2rayPlugin implements FlutterPlugin, ActivityAware, PluginRegistry.ActivityResultListener {

    private static final int REQUEST_CODE_VPN_PERMISSION = 24;
    private static final int REQUEST_CODE_POST_NOTIFICATIONS = 1;
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private MethodChannel vpnControlMethod;
    private EventChannel vpnStatusEvent;
    private EventChannel.EventSink vpnStatusSink;
    private Activity activity;
    private BroadcastReceiver v2rayBroadCastReceiver;
    private MethodChannel.Result pendingResult;

    @SuppressLint("DiscouragedApi")
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        vpnControlMethod = new MethodChannel(binding.getBinaryMessenger(), "flutter_v2ray");
        vpnStatusEvent = new EventChannel(binding.getBinaryMessenger(), "flutter_v2ray/status");

        vpnStatusEvent.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                vpnStatusSink = events;
                V2rayReceiver.vpnStatusSink = vpnStatusSink;

                // Register the BroadcastReceiver now that vpnStatusSink is available
                if (v2rayBroadCastReceiver == null) {
                    v2rayBroadCastReceiver = new V2rayReceiver();
                }
                IntentFilter filter = new IntentFilter("V2RAY_CONNECTION_INFO");
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    activity.registerReceiver(v2rayBroadCastReceiver, filter, Context.RECEIVER_EXPORTED);
                } else {
                    activity.registerReceiver(v2rayBroadCastReceiver, filter);
                }
            }

            @Override
            public void onCancel(Object arguments) {
                if (vpnStatusSink != null) vpnStatusSink.endOfStream();

                // Unregister the BroadcastReceiver when the stream is canceled
                if (v2rayBroadCastReceiver != null) {
                    activity.unregisterReceiver(v2rayBroadCastReceiver);
                    v2rayBroadCastReceiver = null;
                }
            }
        });

        vpnControlMethod.setMethodCallHandler((call, result) -> {
            switch (call.method) {
                case "startV2Ray":
                    AppConfigs.NOTIFICATION_DISCONNECT_BUTTON_NAME = call.argument("notificationDisconnectButtonName");
                    AppConfigs.NOTIFICATION_TITLE = call.argument("notificationTitle");
                    if (Boolean.TRUE.equals(call.argument("proxy_only"))) {
                        V2rayController.changeConnectionMode(AppConfigs.V2RAY_CONNECTION_MODES.PROXY_ONLY);
                    }
                    V2rayController.StartV2ray(binding.getApplicationContext(), call.argument("remark"), call.argument("config"), call.argument("blocked_apps"), call.argument("bypass_subnets"));
                    android.util.Log.d("Plugin", "server:" + call.argument("config"));
                    result.success(null);
                    break;
                case "stopV2Ray":
                    V2rayController.StopV2ray(binding.getApplicationContext());
                    result.success(null);
                    break;
                case "initializeV2Ray":
                    String iconResourceName = call.argument("notificationIconResourceName");
                    String iconResourceType = call.argument("notificationIconResourceType");
                    V2rayController.init(binding.getApplicationContext(), binding.getApplicationContext().getResources().getIdentifier(iconResourceName, iconResourceType, binding.getApplicationContext().getPackageName()), "Flutter V2ray");
                    result.success(null);
                    break;
                case "getServerDelay":
                    executor.submit(() -> {
                        try {
                            result.success(V2rayController.getV2rayServerDelay(call.argument("config"), call.argument("url")));
                            android.util.Log.d("Plugin", "getServerDelay: " + V2rayController.getV2rayServerDelay(call.argument("config"), call.argument("url")));
                        } catch (Exception e) {
                            result.success(-1);
                        }
                    });
                    break;
                case "getConnectedServerDelay":
                    executor.submit(() -> {
                        try {
                            AppConfigs.DELAY_URL = call.argument("url");
                            result.success(V2rayController.getConnectedV2rayServerDelay(binding.getApplicationContext()));
                        } catch (Exception e) {
                            result.success(-1);
                        }
                    });
                    break;
                
                case "getAllServerDelay":
                    String res = call.argument("configs");
                    List<String> configs = new Gson().fromJson(res, List.class);

                    ConcurrentHashMap<String, Long> realPings = new ConcurrentHashMap<>();

                    CountDownLatch latch = new CountDownLatch(configs.size());

                    for (String config : configs) {
                        new Thread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    // Simulate the ping operation
                                    Long result = V2rayController.getV2rayServerDelay(config, "");
                                    Map<String, Long> myMap = new HashMap<>();
                                    myMap.put(config, result);
                                    android.util.Log.d("Plugin", "test ping: " + myMap);

                                    if (result != null) {
                                        realPings.put(config, result);
                                    }
                                } finally {
                                    // Decrement the latch count when the thread finishes
                                    latch.countDown();
                                }
                            }
                        }).start();
                    }

                    new Thread(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                // Wait for all threads to finish
                                latch.await();

                                // Run on UI thread to return the result
                                activity.runOnUiThread(new Runnable() {
                                    @Override
                                    public void run() {
//                                        android.util.Log.d("Plugin", "Final pings: " + realPings);
                                        result.success(new Gson().toJson(realPings));
                                    }
                                });
                            } catch (InterruptedException e) {
                                e.printStackTrace();
                            }
                        }
                    }).start();
                    break;

                case "getAllServerPing":
                    String pingRes = call.argument("configs");
                    String pingUrl = call.argument("url");
                    List<String> pingConfigs = new Gson().fromJson(pingRes, List.class);
                    
                    android.util.Log.d("Plugin", "Starting ping test for " + pingConfigs.size() + " servers");

                    ConcurrentHashMap<String, Long> pingResults = new ConcurrentHashMap<>();
                    CountDownLatch pingLatch = new CountDownLatch(pingConfigs.size());

                    for (String config : pingConfigs) {
                        new Thread(new Runnable() {
                            @Override
                            public void run() {
                                try {
                                    // Parse the config to get the remark
                                    JsonObject jsonConfig = new Gson().fromJson(config, JsonObject.class);
                                    String remark = jsonConfig.has("remarks") ? 
                                        jsonConfig.get("remarks").getAsString() : "unknown";
                                    
                                    android.util.Log.d("Plugin", "Testing server: " + remark);
                                    Long pingResult = V2rayController.getV2rayServerDelay(config, pingUrl);
                                    android.util.Log.d("Plugin", "Ping result for " + remark + ": " + pingResult + "ms");
                                    
                                    if (pingResult != null && pingResult != -1) {
                                        pingResults.put(remark, pingResult);
                                        android.util.Log.d("Plugin", "Added result for " + remark + ": " + pingResult + "ms");
                                    } else {
                                        android.util.Log.d("Plugin", "Skipped invalid result for " + remark + ": " + pingResult);
                                    }
                                } catch (Exception e) {
                                    android.util.Log.e("Plugin", "Error pinging server: " + e.getMessage());
                                } finally {
                                    pingLatch.countDown();
                                    android.util.Log.d("Plugin", "Remaining servers: " + pingLatch.getCount());
                                }
                            }
                        }).start();
                    }

                    new Thread(new Runnable() {
                        @Override
                        public void run() {
                            try {
                                android.util.Log.d("Plugin", "Waiting for all pings to complete...");
                                pingLatch.await();
                                android.util.Log.d("Plugin", "All pings completed. Results: " + pingResults.size());
                                
                                activity.runOnUiThread(new Runnable() {
                                    @Override
                                    public void run() {
                                        String jsonResult = new Gson().toJson(pingResults);
                                        android.util.Log.d("Plugin", "Returning results: " + jsonResult);
                                        result.success(jsonResult);
                                    }
                                });
                            } catch (InterruptedException e) {
                                android.util.Log.e("Plugin", "Error waiting for pings: " + e.getMessage());
                                e.printStackTrace();
                                result.error("PING_ERROR", "Error while pinging servers", e.getMessage());
                            }
                        }
                    }).start();
                    break;

                case "getV2rayStatus":
                    executor.submit(() -> {
                        try {
                            result.success(V2rayController.getConnectionState().name());
                        } catch (Exception e) {
                            result.success("V2RAY_ERROR");
                        }
                    });
                    break;
                case "getCoreVersion":
                    result.success(V2rayController.getCoreVersion());
                    break;
                case "requestPermission":
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ActivityCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            ActivityCompat.requestPermissions(activity, new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST_CODE_POST_NOTIFICATIONS);
                        }
                    }
                    final Intent request = VpnService.prepare(activity);
                    if (request != null) {
                        pendingResult = result;
                        activity.startActivityForResult(request, REQUEST_CODE_VPN_PERMISSION);
                    } else {
                        result.success(true);
                    }
                    break;
                default:
                    break;
            }
        });
    }


    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (v2rayBroadCastReceiver != null) {
            activity.unregisterReceiver(v2rayBroadCastReceiver);
            v2rayBroadCastReceiver = null;
        }
        vpnControlMethod.setMethodCallHandler(null);
        vpnStatusEvent.setStreamHandler(null);
        executor.shutdown();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);
        // Register the receiver if vpnStatusSink is already set
        if (vpnStatusSink != null) {
            V2rayReceiver.vpnStatusSink = vpnStatusSink;
            if (v2rayBroadCastReceiver == null) {
                v2rayBroadCastReceiver = new V2rayReceiver();
            }
            IntentFilter filter = new IntentFilter("V2RAY_CONNECTION_INFO");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(v2rayBroadCastReceiver, filter, Context.RECEIVER_EXPORTED);
            } else {
                activity.registerReceiver(v2rayBroadCastReceiver, filter);
            }
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        // No additional cleanup required
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activity = binding.getActivity();
        binding.addActivityResultListener(this);

        // Re-register the receiver if vpnStatusSink is already set
        if (vpnStatusSink != null) {
            V2rayReceiver.vpnStatusSink = vpnStatusSink;
            if (v2rayBroadCastReceiver == null) {
                v2rayBroadCastReceiver = new V2rayReceiver();
            }
            IntentFilter filter = new IntentFilter("V2RAY_CONNECTION_INFO");
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(v2rayBroadCastReceiver, filter, Context.RECEIVER_EXPORTED);
            } else {
                activity.registerReceiver(v2rayBroadCastReceiver, filter);
            }
        }
    }

    @Override
    public void onDetachedFromActivity() {
        // No additional cleanup required
    }

    @Override
    public boolean onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        if (requestCode == REQUEST_CODE_VPN_PERMISSION) {
            if (resultCode == Activity.RESULT_OK) {
                pendingResult.success(true);
            } else {
                pendingResult.success(false);
            }
            pendingResult = null;
        }
        return true;
    }
}
