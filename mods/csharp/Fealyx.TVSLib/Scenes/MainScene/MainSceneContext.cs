using System;
using UnityEngine;

namespace Fealyx.TVSLib.Scenes.MainScene;

/// <summary>
/// Context for the MainScene, providing typed access to scene-specific game objects and utilities.
/// This context is automatically initialized when MainScene loads and cleaned up when it unloads.
/// </summary>
public class MainSceneContext : SceneManagement.ISceneContext
{
    public event Action? OnReady;

    public string SceneName => "MainScene";

    // TODO: Replace these placeholder types with actual game types when implementing
    // For now, using object as placeholder - will be replaced with actual game types

    /// <summary>
    /// The player character in the scene.
    /// </summary>
    public object? Player { get; private set; }

    /// <summary>
    /// The main game manager for this scene.
    /// </summary>
    public object? GameManager { get; private set; }

    /// <summary>
    /// The villain controller system.
    /// </summary>
    public object? VillainController { get; private set; }

    /// <summary>
    /// The UI manager for game UI.
    /// </summary>
    public object? UIManager { get; private set; }

    /// <summary>
    /// Whether all required objects have been found and the context is ready to use.
    /// </summary>
    public bool IsReady { get; private set; }

    /// <summary>
    /// Initialize the context by discovering scene objects.
    /// Called automatically by the framework when MainScene loads.
    /// </summary>
    public void Initialize()
    {
        // TODO: Replace with actual game types when implementing
        // Example:
        // Player = Object.FindObjectOfType<PlayerController>();
        // GameManager = Object.FindObjectOfType<GameManager>();
        // VillainController = Object.FindObjectOfType<VillainController>();
        // UIManager = Object.FindObjectOfType<UIManager>();

        // Placeholder - will find actual objects when types are known
        Player = new object();
        GameManager = new object();
        VillainController = new object();
        UIManager = new object();

        // Mark as ready and fire event
        IsReady = true;
        OnReady?.Invoke();
    }

    /// <summary>
    /// Cleanup when the scene unloads.
    /// </summary>
    public void Cleanup()
    {
        Player = null;
        GameManager = null;
        VillainController = null;
        UIManager = null;
        IsReady = false;
    }

    // Helper methods can be added here as needed
    // Example:
    // public void SpawnEnemy(Vector3 position, EnemyType type) => ((GameManager)GameManager).SpawnEnemy(position, type);
    // public void ShowNotification(string message) => ((UIManager)UIManager).ShowNotification(message);
}
