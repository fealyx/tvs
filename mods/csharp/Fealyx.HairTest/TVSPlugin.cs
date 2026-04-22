using BepInEx;
using HarmonyLib;

using Fealyx.TVSLib;


namespace Fealyx.HairTest;

[BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
[BepInDependency("Fealyx.TVSLib", BepInDependency.DependencyFlags.HardDependency)]
public class TVSPlugin : BaseTVSPlugin
{
    public static TVSPlugin? Instance { get; private set; }

    public HairItemShim HairItem { get; private set; } = null!;

    private Harmony? _harmony;

    public override void Initialize()
    {
        if (Instance != null)
        {
            Logger.LogError("No.");
            return;
        }

        Instance = this;

        Logger.LogInfo($"Initializing {Info.Metadata.Name} v{Info.Metadata.Version}...");

        base.Initialize();

        HairItem = new HairItemShim(this);

        // Apply Harmony patches
        _harmony = new Harmony(Info.Metadata.GUID);
        _harmony.PatchAll();
        Logger.LogInfo("Harmony patches applied.");

        Scenes.RegisterAllStates();

        Logger.LogInfo($"{Info.Metadata.Name} initialized.");
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            // Unpatch Harmony patches
            _harmony?.UnpatchSelf();
            Logger.LogInfo("Harmony patches removed.");
        }

        base.Dispose(disposing);
    }
}
