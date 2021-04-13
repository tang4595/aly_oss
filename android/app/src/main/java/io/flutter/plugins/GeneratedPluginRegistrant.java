package io.flutter.plugins;

import io.flutter.plugin.common.PluginRegistry;
import tech.jitao.aly_oss.AlyOssPlugin;

/**
 * Generated file. Do not edit.
 */
public final class GeneratedPluginRegistrant {
  public static void registerWith(PluginRegistry registry) {
    if (alreadyRegisteredWith(registry)) {
      return;
    }
    AlyOssPlugin.registerWith(registry.registrarFor("tech.jitao.aly_oss.AlyOssPlugin"));
  }

  private static boolean alreadyRegisteredWith(PluginRegistry registry) {
    final String key = GeneratedPluginRegistrant.class.getCanonicalName();
    if (registry.hasPlugin(key)) {
      return true;
    }
    registry.registrarFor(key);
    return false;
  }
}
