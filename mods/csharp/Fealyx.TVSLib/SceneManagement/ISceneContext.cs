using System;

namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Interface for scene-specific context objects that provide typed access to scene objects and utilities.
/// Contexts are automatically initialized when their scene loads and cleaned up when it unloads.
/// </summary>
public interface ISceneContext
{
    /// <summary>
    /// Invoked when the context has been fully initialized and is ready to use.
    /// </summary>
    public event Action? OnReady;

    /// <summary>
    /// The name of the scene this context is for.
    /// </summary>
    string SceneName { get; }

    /// <summary>
    /// Whether the context has been fully initialized and all required objects are available.
    /// </summary>
    bool IsReady { get; }

    /// <summary>
    /// Initialize the context by discovering scene objects and setting up state.
    /// Called automatically by the framework when the scene loads.
    /// </summary>
    void Initialize();

    /// <summary>
    /// Cleanup the context when the scene unloads.
    /// Called automatically by the framework.
    /// </summary>
    void Cleanup();
}
