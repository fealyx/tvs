# Configuration System - Declarative Syntax Guide

## 🎯 **Overview**

The TVSLib configuration system supports hierarchical, declarative configuration with three syntaxes:
1. **Collection Initializer** - Clean, nested structure
2. **Fluent API** - Method chaining
3. **Mixed** - Combine both styles

## ✨ **Collection Initializer Pattern (Recommended)**

### **Simple Configuration**

```csharp
var config = new Configuration("MyPlugin.cfg")
{
    new Setting<bool>("Enabled", "Enable the plugin", true),
    new Setting<string>("ApiUrl", "API endpoint", "https://api.example.com"),
    new Setting<int>("MaxRetries", "Maximum retry attempts", 3)
};

config.Initialize(config);
```

### **Features with Callbacks**

```csharp
var config = new Configuration("MyPlugin.cfg")
{
    // Simple feature flag
    new Feature(
        "DebugMode",
        "Enable debug logging",
        defaultEnabled: false,
        onEnable: f => EnableDebugging(),
        onDisable: f => DisableDebugging()
    ),

    // Feature with additional settings
    new Feature("PerformanceMonitor", "Monitor performance", defaultEnabled: true)
    {
        new Setting<int>("SampleRate", "Samples per second", 60),
        new Setting<bool>("LogToFile", "Log to file", false)
    }
};

config.Initialize(config);
```

### **Complete TVSLib Example (PluginManagerConfiguration)**

```csharp
public class PluginManagerConfiguration : Configuration
{
    public PluginManagerConfiguration(ConfigFile configFile)
        : base(configFile, "TVSLib Framework Configuration")
    {
        // Declarative feature definitions
        var features = new SettingGroup("Features", "Framework feature flags")
        {
            new Feature(
                "AssetLogger",
                "Log asset and resource load events for debugging",
                defaultEnabled: false,
                onEnable: f => Harmony.CreateAndPatchAll(typeof(DevTools.AssetLogger)),
                onDisable: f =>
                {
                    var harmony = new Harmony("fealyx.tvslib.devtools.assetlogger");
                    harmony.UnpatchSelf();
                }
            )
        };

        AddGroup(features);
        Initialize(this);
    }
}
```

---

**Status**: ✅ Declarative configuration system fully implemented!
