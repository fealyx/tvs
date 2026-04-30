using BepInEx;
using Fealyx.TVSLib;
using Fealyx.TVSLib.Configuration;

using HarmonyLib;


namespace Fealyx.MorePresetSlots;

[BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
[BepInDependency("Fealyx.TVSLib", BepInDependency.DependencyFlags.HardDependency)]
public class TVSPlugin : BaseTVSPlugin
{
    public static TVSPlugin Instance { get; private set; } = null!;

    public new Configuration Config { get; private set; } = null!;

    public TVSPlugin() : base()
    {
        if (Instance != null)
        {
            Logger.LogWarning($"TVSPlugin instance already exists. Secondary instance self-destructing.");
            DestroyImmediate(this);
            return;
        }
        Instance = this;

        Config = new Configuration(base.Config, $"{MyPluginInfo.PLUGIN_GUID} Configuration")
        {
            new Setting<int>(
                "AdditionalPresetPages",
                "The number of additional preset pages to add.",
                4
            ),
            new Setting<int>(
                "PageButtonsOnScreen",
                "The number of preset page buttons on-screen at once.",
                5
            ),
            new Setting<bool>(
                "CondenseConsoleSlots",
                "If true, hides empty slots when displaying presets in the in-game character console.",
                true
            )
        };
        Config.Initialize();

        Harmony.CreateAndPatchAll(typeof(TVSPlugin).Assembly, MyPluginInfo.PLUGIN_GUID);
    }
}
