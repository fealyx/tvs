using System;
using UnityEngine.SceneManagement;

namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Base class for scene-specific state management.
/// Inherit from this class to handle scene lifecycle events (enter, exit, update) in a structured way.
/// </summary>
public abstract class SceneState : IDisposable
{
    /// <summary>
    /// The name of the Unity scene this state manages (e.g., "MainMenu", "MainScene").
    /// Can be overridden in derived classes or set via SceneStateAttribute.
    /// </summary>
    public virtual string SceneName
    {
        get
        {
            // Check for attribute first
            var attr = GetType().GetCustomAttributes(typeof(SceneStateAttribute), false);
            if (attr.Length > 0 && attr[0] is SceneStateAttribute sceneAttr)
            {
                return sceneAttr.SceneName;
            }
            throw new InvalidOperationException(
                $"{GetType().Name} must either override SceneName property or use [SceneState] attribute.");
        }
    }

    /// <summary>
    /// Execution priority. Higher values execute first. Default: 0
    /// Can be overridden in derived classes or set via SceneStateAttribute.
    /// </summary>
    public virtual int Priority
    {
        get
        {
            var attr = GetType().GetCustomAttributes(typeof(SceneStateAttribute), false);
            if (attr.Length > 0 && attr[0] is SceneStateAttribute sceneAttr)
            {
                return sceneAttr.Priority;
            }
            return 0;
        }
    }

    /// <summary>
    /// Reference to the owning plugin. Set automatically by the framework.
    /// </summary>
    protected BaseTVSPlugin Plugin { get; private set; } = null!;

    /// <summary>
    /// The current transition state of this scene state.
    /// </summary>
    public SceneStateTransition Transition { get; internal set; } = SceneStateTransition.Exited;

    /// <summary>
    /// Called when the scene is loaded and becomes active.
    /// Use this for initialization logic specific to this scene.
    /// </summary>
    /// <param name="scene">The Unity scene that was loaded</param>
    public virtual void OnEnter(Scene scene) { }

    /// <summary>
    /// Called when leaving this scene.
    /// Use this for cleanup logic specific to this scene.
    /// </summary>
    /// <param name="scene">The Unity scene that is being unloaded</param>
    public virtual void OnExit(Scene scene) { }

    /// <summary>
    /// Called every frame while this scene is active and the state is not paused.
    /// Override this to implement per-frame game logic.
    /// </summary>
    public virtual void OnUpdate() { }

    /// <summary>
    /// Called every physics update while this scene is active and the state is not paused.
    /// Override this to implement physics-related game logic.
    /// </summary>
    public virtual void OnFixedUpdate() { }

    /// <summary>
    /// Called when the state is paused. Updates will no longer be called until resumed.
    /// Override this to implement custom pause logic.
    /// </summary>
    public virtual void OnPause() { }

    /// <summary>
    /// Called when the state is resumed from pause. Updates will resume.
    /// Override this to implement custom resume logic.
    /// </summary>
    public virtual void OnResume() { }

    /// <summary>
    /// Cleanup resources when the state is disposed.
    /// Called automatically when the owning plugin is disposed.
    /// </summary>
    public virtual void Dispose() { }

    /// <summary>
    /// Sets the owning plugin reference. Called internally by the framework.
    /// </summary>
    internal void SetPlugin(BaseTVSPlugin plugin)
    {
        Plugin = plugin ?? throw new ArgumentNullException(nameof(plugin));
    }

    /// <summary>
    /// Pauses this state, preventing OnUpdate and OnFixedUpdate from being called.
    /// </summary>
    public void Pause()
    {
        if (Transition == SceneStateTransition.Active)
        {
            Transition = SceneStateTransition.Paused;
            OnPause();
        }
    }

    /// <summary>
    /// Resumes this state from pause, allowing OnUpdate and OnFixedUpdate to be called again.
    /// </summary>
    public void Resume()
    {
        if (Transition == SceneStateTransition.Paused)
        {
            Transition = SceneStateTransition.Active;
            OnResume();
        }
    }
}
