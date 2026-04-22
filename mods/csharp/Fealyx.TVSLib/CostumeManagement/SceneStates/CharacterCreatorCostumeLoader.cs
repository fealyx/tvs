using System;
using System.Linq;
using UnityEngine.SceneManagement;

namespace Fealyx.TVSLib.CostumeManagement.SceneStates;

/// <summary>
/// Framework scene state that loads custom costumes into the CharacterCreator scene.
/// This is an internal system state - not a plugin state.
/// Automatically activated when the CharacterCreator scene loads.
/// </summary>
[SceneManagement.SceneState("CharacterCreator", Priority = 5000)]
internal class CharacterCreatorCostumeLoader : SceneManagement.SceneState
{
    private BepInEx.Logging.ManualLogSource _logger => PluginManager.Instance.Logger;

    public override void OnReady(Scene scene)
    {
        var costumeManager = PluginManager.Instance.Costumes;
        var context = Context as Scenes.CharacterCreator.CharacterCreatorContext;

        if (context?.CharacterCustomizer == null)
        {
            _logger.LogWarning("CharacterCreator context not ready, cannot load costumes");
            return;
        }

        var pendingCostumes = costumeManager.GetPendingCostumes().ToList();
        var costumeCount = pendingCostumes.Count;

        if (costumeCount == 0)
        {
            _logger.LogInfo("No custom costumes to load");
            return;
        }

        _logger.LogInfo($"Loading {costumeCount} custom costumes into CharacterCreator...");

        foreach (var costume in pendingCostumes)
        {
            try
            {
                LoadCostume(costume, context);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to load costume '{costume.Name}' (ID: {costume.Id}): {ex.Message}");
            }
        }

        _logger.LogInfo($"Finished loading custom costumes");
    }

    private void LoadCostume(CostumeItem costume, Scenes.CharacterCreator.CharacterCreatorContext context)
    {
        // TODO: Implement actual costume loading logic
        // This is where you'll:
        // 1. Load the asset bundle (using costume.OwningPlugin.Assets if needed)
        // 2. Extract the costume asset
        // 3. Add it to the ZNECharacterCustomizer
        // 4. Register it in the UI

        _logger.LogInfo($"[STUB] Loading costume: {costume.Name} from {costume.AssetBundle}/{costume.PrefabPath}");

        // Example implementation structure:
        /*
        var assetBundle = costume.OwningPlugin?.Assets.LoadAsset<GameObject>(
            costume.AssetBundle, 
            costume.AssetName
        );

        if (assetBundle != null)
        {
            // Add to character customizer
            context.CharacterCustomizer.AddCustomCostume(
                costume.Id,
                costume.Category,
                assetBundle,
                costume.Name,
                costume.Description
            );
        }
        */
    }
}
