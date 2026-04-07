using BepInEx;

namespace TVS.SampleMod;

[BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
public class Plugin : BaseUnityPlugin
{
    protected void Awake()
    {
        Logger.LogWarning("TVS.SampleMod is running in CI/no-game-refs mode. Private TVS game assemblies were not available at build time, so full runtime features are disabled until TVSManagedDir is configured.");
    }
}
