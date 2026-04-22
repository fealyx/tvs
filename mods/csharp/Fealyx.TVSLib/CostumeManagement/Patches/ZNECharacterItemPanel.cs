using System.Collections.Generic;
using System.Linq;

using BepInEx.Logging;

using HarmonyLib;


namespace Fealyx.TVSLib.CostumeManagement.Patches;

/// <summary>
/// Harmony patches for ZNECharacterItemPanel.
/// Injects custom costume data before the panel initializes its UI.
/// </summary>
[HarmonyPatch(typeof(global::ZNECharacterItemPanel))]
internal class ZNECharacterItemPanel
{
    private static HashSet<string> _patchedPanels = new();
    private static CostumeManager _manager => CostumeManager.Instance!;
    private static ManualLogSource _logger => _manager.Logger;

    /// <summary>
    /// Prefix patch for ZNECharacterItemPanel.Start().
    /// Runs before the original Start() method, allowing us to inject custom costumes
    /// into the items array before the UI is initialized.
    /// </summary>
    /// <param name="__instance">The ZNECharacterItemPanel instance being patched</param>
    [HarmonyPatch("Start")]
    [HarmonyPrefix]
    static void BeforeStart(global::ZNECharacterItemPanel __instance)
    {
        var panelName = __instance.gameObject.name;

        if (!panelName.StartsWith("Customize-"))
        {
            _logger.LogWarning($"Skipping patch for panel '{panelName}' - unrecognized naming pattern.");
            return;
        }

        if (_patchedPanels.Contains(panelName))
        {
            _logger.LogWarning($"Panel '{panelName}' already patched. Skipping costume injection.");
            return;
        }

        var category = panelName.Replace("Customize-", "");
        var costumes = _manager.GetCostumesByCategory(category);

        if (costumes == null)
        {
            _logger.LogInfo($"No costumes registered for category '{category}' - skipping '{panelName}' patch.");
            return;
        }

        _logger.LogInfo($"Injecting costume(s) into panel '{panelName}' for category '{category}'...");

        var costumeDatas = costumes.Select(c => c.ToZNECostumeData()).ToArray();
        __instance._items = __instance._items.Concat(costumeDatas).ToArray();

        _patchedPanels.Add(panelName);
        _logger.LogInfo($"Injected {costumeDatas.Length} costume(s) into panel '{panelName}'. Total items now: {__instance._items.Length}");
    }
}
