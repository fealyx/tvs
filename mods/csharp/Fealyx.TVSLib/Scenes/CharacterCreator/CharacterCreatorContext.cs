using System;
using UnityEngine;

namespace Fealyx.TVSLib.Scenes.CharacterCreator;

public class CharacterCreatorContext : SceneManagement.ISceneContext
{
    public event Action? OnReady;

    public string SceneName => "CharacterCreator";

    public ZNECharacterCustomizer? CharacterCustomizer { get; private set; }

    public bool IsReady { get; private set; }

    /// <summary>
    /// Initialize the context by discovering scene objects.
    /// Called automatically by the framework when CharacterCreator loads.
    /// </summary>
    public void Initialize()
    {
        CharacterCustomizer = ZNECharacterCustomizer.sharedInstance;

        // Mark as ready and fire event
        IsReady = true;
        OnReady?.Invoke();
    }

    /// <summary>
    /// Cleanup when the scene unloads.
    /// </summary>
    public void Cleanup()
    {
        CharacterCustomizer = null;
        IsReady = false;
    }

    // Helper methods can be added here as needed
    // Example:
    // public void SpawnEnemy(Vector3 position, EnemyType type) => ((GameManager)GameManager).SpawnEnemy(position, type);
    // public void ShowNotification(string message) => ((UIManager)UIManager).ShowNotification(message);
}
