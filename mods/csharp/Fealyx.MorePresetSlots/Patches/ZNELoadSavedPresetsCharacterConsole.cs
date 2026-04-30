using BepInEx.Logging;
using HarmonyLib;


namespace Fealyx.MorePresetSlots.Patches;

[HarmonyPatch(typeof(global::ZNELoadSavedPresetsCharacterConsole))]
public class ZNELoadSavedPresetsCharacterConsole
{
    public static ConsoleSlotsController Ctrl { get; private set; } = null!;
    public static ManualLogSource Logger => Plugin.Logger;
    public static TVSPlugin Plugin => TVSPlugin.Instance;

    [HarmonyPatch("OnEnable")]
    [HarmonyPrefix]
    static bool BeforeOnEnable(global::ZNELoadSavedPresetsCharacterConsole __instance)
    {
        var controller = __instance.GetComponent<ConsoleSlotsController>();

        if (controller != null)
        {
            Logger.LogWarning("ZNELoadSavedPresetsCharacterConsole already has a ConsoleSlotsController component. Skipping adding another one.");
            return true;
        }

        if (Ctrl != null)
        {
            Logger.LogWarning("A ConsoleSlotsController instance already exists. Skipping adding another one to ZNELoadSavedPresetsCharacterConsole.");
            return true;
        }

        Logger.LogInfo("Adding ConsoleSlotsController component to ZNELoadSavedPresetsCharacterConsole.");

        Ctrl = __instance.gameObject.AddComponent<ConsoleSlotsController>();

        Logger.LogInfo("ConsoleSlotsController component added successfully.");

        return true;
    }

    [HarmonyPatch("UpdateUI")]
    [HarmonyPrefix]
    static bool UpdateUI_Delegate(global::ZNELoadSavedPresetsCharacterConsole __instance)
    {
        if (Ctrl != null && Plugin.Config.GetSetting<bool>("CondenseConsoleSlots").Value)
        {
            Logger.LogDebug("Delegating UpdateUI to ConsoleSlotsController.");
            Ctrl.RebuildCompactLayout();
            return false; // Skip original method
        }

        return true; // Run original method
    }

    [HarmonyPatch("OnMoveRight")]
    [HarmonyPrefix]
    static bool OnMoveRight_Delegate(global::ZNELoadSavedPresetsCharacterConsole __instance)
    {
        if (Ctrl != null && Plugin.Config.GetSetting<bool>("CondenseConsoleSlots").Value)
        {
            if (!__instance._transitioning)
            {
                Logger.LogDebug("Delegating OnMoveRight to ConsoleSlotsController.");
                Ctrl.MoveToNextSection();
            }
            return false; // Skip original method
        }

        return true; // Run original method
    }

    [HarmonyPatch("OnMoveLeft")]
    [HarmonyPrefix]
    static bool OnMoveLeft_Delegate(global::ZNELoadSavedPresetsCharacterConsole __instance)
    {
        if (Ctrl != null && Plugin.Config.GetSetting<bool>("CondenseConsoleSlots").Value)
        {
            if (!__instance._transitioning)
            {
                Logger.LogDebug("Delegating OnMoveLeft to ConsoleSlotsController.");
                Ctrl.MoveToPreviousSection();
            }
            return false; // Skip original method
        }

        return true; // Run original method
    }
}
