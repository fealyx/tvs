using HarmonyLib;

namespace Fealyx.HairTest.Patches;

/// <summary>
/// Harmony patches for ZNECharacterItemPanel.
/// Injects custom costume data before the panel initializes its UI.
/// </summary>
[HarmonyPatch(typeof(ZNECharacterItemPanel))]
internal static class CharacterItemPanelPatches
{
    /// <summary>
    /// Prefix patch for ZNECharacterItemPanel.Start().
    /// Runs before the original Start() method, allowing us to inject custom costumes
    /// into the items array before the UI is initialized.
    /// </summary>
    /// <param name="__instance">The ZNECharacterItemPanel instance being patched</param>
    [HarmonyPatch("Start")]
    [HarmonyPrefix]
    static void BeforeStart(ZNECharacterItemPanel __instance)
    {
        if (__instance.gameObject.name != "Customize-Hair")
        {
            return;
        }

        TVSPlugin.Instance?.HairItem.InjectInto(__instance);
    }
}
