using HarmonyLib;


namespace Fealyx.MorePresetSlots.Patches;

[HarmonyPatch(typeof(global::ZNELoadSavedPresets))]
public class ZNELoadSavedPresets
{
    [HarmonyPatch("OnEnable")]
    [HarmonyPrefix]
    static void BeforeOnEnable(global::ZNELoadSavedPresets __instance)
    {
        TVSPlugin.Instance.Logger.LogInfo("Creating and attaching CCSlotsController...");

        CCSlotsController.CreateAndAttach(__instance);

        TVSPlugin.Instance.Logger.LogInfo("CCSlotsController created and attached.");
    }
}
