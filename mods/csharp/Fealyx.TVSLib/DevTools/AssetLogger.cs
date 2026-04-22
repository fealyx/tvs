using HarmonyLib;
using UnityEngine;

namespace Fealyx.TVSLib.DevTools;

[HarmonyPatch]
public class AssetLogger
{
    // 1. Monitor standard Resources.Load
    [HarmonyPrefix]
    [HarmonyPatch(typeof(Resources), nameof(Resources.Load), new[] { typeof(string), typeof(System.Type) })]
    public static void Prefix_ResourcesLoad(string path)
    {
        Debug.Log($"[AssetTracker] Resources.Load called for path: {path}");
    }

    // 2. Monitor Asset Bundle loading
    [HarmonyPrefix]
    [HarmonyPatch(typeof(AssetBundle), nameof(AssetBundle.LoadAsset), new[] { typeof(string), typeof(System.Type) })]
    public static void Prefix_BundleLoad(AssetBundle __instance, string name)
    {
        Debug.Log($"[AssetTracker] AssetBundle({__instance.name}).LoadAsset called for: {name}");
    }

    // 3. Monitor Addressables (Not used in TVS)
    //[HarmonyPrefix]
    //[HarmonyPatch(typeof(Addressables), nameof(Addressables.LoadAssetAsync), new[] { typeof(object) })]
    //public static void Prefix_AddressableLoad(object key)
    //{
    //    Debug.Log($"[AssetTracker] Addressables.LoadAssetAsync called for key: {key}");
    //}
}
