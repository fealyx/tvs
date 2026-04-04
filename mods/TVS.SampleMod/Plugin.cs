using BepInEx;
using TVS.Core;

namespace TVS.SampleMod;

internal static class ModMetadata
{
    public const string Guid = "io.tvs.samplemod";
    public const string Name = "TVS Sample Mod";
    public const string Version = "0.1.0";
}

[BepInPlugin(ModMetadata.Guid, ModMetadata.Name, ModMetadata.Version)]
public sealed class Plugin : BaseUnityPlugin
{
    private void Awake()
    {
        Logger.LogInfo($"Loaded {ModMetadata.Guid} for {ModContext.GameName} (Unity {ModContext.UnityVersion}).");
    }
}
