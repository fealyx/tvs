using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Central scene management system that handles Unity scene lifecycle events
/// and manages SceneState instances for structured scene-specific logic.
/// </summary>
public class SceneManager : Manager
{
    private readonly SceneStateRegistry _registry = new();
    private readonly Dictionary<string, List<SceneState>> _activeStatesByScene = new();
    private readonly List<SceneState> _updateStates = new();
    private readonly List<SceneState> _fixedUpdateStates = new();
    private string? _currentSceneName;
    private MonoBehaviour? _updateDispatcher;

    // Backward compatibility events - plugins can still use these directly if they prefer
    public event Action? OnGameLoaded;
    public event Action? OnMainMenuLoaded;
    public event Action<Scene>? OnSceneLoaded;
    public event Action<Scene, Scene>? OnSceneChanged;
    public event Action<Scene>? OnSceneUnloaded;

    /// <summary>
    /// Creates a new PluginScenes context for the specified plugin.
    /// </summary>
    public PluginScenes CreateContext(BaseTVSPlugin plugin)
    {
        return new PluginScenes(this, plugin);
    }

    /// <summary>
    /// Registers a scene state for lifecycle management.
    /// </summary>
    /// <param name="state">The scene state to register</param>
    /// <param name="plugin">The plugin that owns this state</param>
    public void RegisterState(SceneState state, BaseTVSPlugin plugin)
    {
        _registry.Register(state, plugin);
        _logger.LogInfo($"Registered scene state: {state.GetType().Name} for scene '{state.SceneName}' (priority: {state.Priority})");

        // If the state's scene is currently active, activate it immediately
        if (_currentSceneName == state.SceneName)
        {
            var activeScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            ActivateState(state, activeScene);
        }
    }

    /// <summary>
    /// Unregisters all states for a specific plugin.
    /// </summary>
    /// <param name="plugin">The plugin whose states should be unregistered</param>
    public void UnregisterStates(BaseTVSPlugin plugin)
    {
        // Get all states for this plugin before unregistering
        var statesToRemove = _registry.GetAllStates()
            .Where(e => e.Plugin == plugin)
            .Select(e => e.State)
            .ToList();

        // Deactivate any active states
        foreach (var state in statesToRemove)
        {
            if (state.Transition == SceneStateTransition.Active || 
                state.Transition == SceneStateTransition.Paused)
            {
                DeactivateState(state, UnityEngine.SceneManagement.SceneManager.GetActiveScene());
            }
        }

        _registry.UnregisterPlugin(plugin);
        _logger.LogInfo($"Unregistered all scene states for plugin: {plugin.Info.Metadata.Name}");
    }

    /// <summary>
    /// Gets the current transition state for a specific state instance.
    /// </summary>
    public SceneStateTransition GetStateTransition(SceneState state)
    {
        return state.Transition;
    }

    /// <summary>
    /// Gets the total number of registered states across all scenes.
    /// </summary>
    public int RegisteredStateCount => _registry.Count;

    public override void Initialize()
    {
        base.Initialize();

        UnityEngine.SceneManagement.SceneManager.activeSceneChanged += HandleSceneChanged;
        UnityEngine.SceneManagement.SceneManager.sceneLoaded += HandleSceneLoaded;
        UnityEngine.SceneManagement.SceneManager.sceneUnloaded += HandleSceneUnloaded;

        // Get the current scene
        _currentSceneName = UnityEngine.SceneManagement.SceneManager.GetActiveScene().name;

        // Create update dispatcher
        CreateUpdateDispatcher();

        _logger.LogInfo("Scene management system initialized");
    }

    protected override void Dispose(bool disposing)
    {
        if (LifecycleState == Lifecycle.LifecycleState.Destroyed || 
            LifecycleState == Lifecycle.LifecycleState.Destroying)
        {
            return;
        }

        if (disposing)
        {
            UnityEngine.SceneManagement.SceneManager.activeSceneChanged -= HandleSceneChanged;
            UnityEngine.SceneManagement.SceneManager.sceneLoaded -= HandleSceneLoaded;
            UnityEngine.SceneManagement.SceneManager.sceneUnloaded -= HandleSceneUnloaded;

            // Deactivate all active states
            foreach (var state in _updateStates.Concat(_fixedUpdateStates).Distinct().ToList())
            {
                DeactivateState(state, UnityEngine.SceneManagement.SceneManager.GetActiveScene());
            }

            // Destroy update dispatcher
            if (_updateDispatcher != null)
            {
                UnityEngine.Object.Destroy(_updateDispatcher.gameObject);
                _updateDispatcher = null;
            }

            // Clear event handlers to prevent memory leaks
            OnGameLoaded = null;
            OnMainMenuLoaded = null;
            OnSceneLoaded = null;
            OnSceneChanged = null;
            OnSceneUnloaded = null;
        }

        base.Dispose(disposing);
    }

    private void CreateUpdateDispatcher()
    {
        var dispatcherObj = new GameObject("TVSLib.SceneManager.UpdateDispatcher");
        UnityEngine.Object.DontDestroyOnLoad(dispatcherObj);
        _updateDispatcher = dispatcherObj.AddComponent<UpdateDispatcher>();

        var dispatcher = (UpdateDispatcher)_updateDispatcher;
        dispatcher.OnUpdateCallback = InvokeStateUpdates;
        dispatcher.OnFixedUpdateCallback = InvokeStateFixedUpdates;
    }

    private void HandleSceneChanged(Scene oldScene, Scene newScene)
    {
        _logger.LogInfo($"Scene changed: {oldScene.name} -> {newScene.name}");

        // Deactivate states from old scene
        if (!string.IsNullOrEmpty(oldScene.name))
        {
            TransitionStates(oldScene.name, oldScene, SceneStateTransition.Exiting);
        }

        // Activate states for new scene
        _currentSceneName = newScene.name;
        TransitionStates(newScene.name, newScene, SceneStateTransition.Entering);

        OnSceneChanged?.Invoke(oldScene, newScene);
    }

    private void HandleSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        _logger.LogInfo($"Scene loaded: {scene.name} (mode: {mode})");

        OnSceneLoaded?.Invoke(scene);

        // Fire legacy events
        if (scene.name == "MainMenu")
        {
            OnMainMenuLoaded?.Invoke();
        }
        else if (scene.name == "MainScene")
        {
            OnGameLoaded?.Invoke();
        }
    }

    private void HandleSceneUnloaded(Scene scene)
    {
        _logger.LogInfo($"Scene unloaded: {scene.name}");

        // Deactivate states for unloaded scene
        TransitionStates(scene.name, scene, SceneStateTransition.Exiting);

        OnSceneUnloaded?.Invoke(scene);
    }

    private void TransitionStates(string sceneName, Scene scene, SceneStateTransition targetTransition)
    {
        var states = _registry.GetStatesForScene(sceneName).Select(e => e.State).ToList();

        if (targetTransition == SceneStateTransition.Entering)
        {
            // Activate states in priority order (high to low)
            foreach (var state in states)
            {
                ActivateState(state, scene);
            }
        }
        else if (targetTransition == SceneStateTransition.Exiting)
        {
            // Deactivate states in reverse priority order (low to high)
            foreach (var state in states.AsEnumerable().Reverse())
            {
                DeactivateState(state, scene);
            }
        }
    }

    private void ActivateState(SceneState state, Scene scene)
    {
        if (state.Transition == SceneStateTransition.Active || 
            state.Transition == SceneStateTransition.Entering)
        {
            return; // Already active
        }

        try
        {
            state.Transition = SceneStateTransition.Entering;
            state.OnEnter(scene);
            state.Transition = SceneStateTransition.Active;

            // Add to update lists if the state implements update methods
            var stateType = state.GetType();
            var hasUpdate = stateType.GetMethod("OnUpdate").DeclaringType != typeof(SceneState);
            var hasFixedUpdate = stateType.GetMethod("OnFixedUpdate").DeclaringType != typeof(SceneState);

            if (hasUpdate && !_updateStates.Contains(state))
            {
                _updateStates.Add(state);
            }

            if (hasFixedUpdate && !_fixedUpdateStates.Contains(state))
            {
                _fixedUpdateStates.Add(state);
            }

            _logger.LogInfo($"Activated state: {state.GetType().Name} for scene '{scene.name}'");
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error activating state {state.GetType().Name}: {ex}");
            state.Transition = SceneStateTransition.Exited;
        }
    }

    private void DeactivateState(SceneState state, Scene scene)
    {
        if (state.Transition == SceneStateTransition.Exited || 
            state.Transition == SceneStateTransition.Exiting)
        {
            return; // Already exited
        }

        try
        {
            state.Transition = SceneStateTransition.Exiting;
            state.OnExit(scene);
            state.Transition = SceneStateTransition.Exited;

            // Remove from update lists
            _updateStates.Remove(state);
            _fixedUpdateStates.Remove(state);

            _logger.LogInfo($"Deactivated state: {state.GetType().Name} from scene '{scene.name}'");
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error deactivating state {state.GetType().Name}: {ex}");
            state.Transition = SceneStateTransition.Exited;
        }
    }

    private void InvokeStateUpdates()
    {
        foreach (var state in _updateStates.ToList()) // ToList to avoid modification during iteration
        {
            if (state.Transition == SceneStateTransition.Active)
            {
                try
                {
                    state.OnUpdate();
                }
                catch (Exception ex)
                {
                    _logger.LogError($"Error in {state.GetType().Name}.OnUpdate(): {ex}");
                }
            }
        }
    }

    private void InvokeStateFixedUpdates()
    {
        foreach (var state in _fixedUpdateStates.ToList()) // ToList to avoid modification during iteration
        {
            if (state.Transition == SceneStateTransition.Active)
            {
                try
                {
                    state.OnFixedUpdate();
                }
                catch (Exception ex)
                {
                    _logger.LogError($"Error in {state.GetType().Name}.OnFixedUpdate(): {ex}");
                }
            }
        }
    }

    /// <summary>
    /// Internal MonoBehaviour for dispatching Unity update callbacks.
    /// </summary>
    private class UpdateDispatcher : MonoBehaviour
    {
        public Action? OnUpdateCallback;
        public Action? OnFixedUpdateCallback;

        private void Update()
        {
            OnUpdateCallback?.Invoke();
        }

        private void FixedUpdate()
        {
            OnFixedUpdateCallback?.Invoke();
        }
    }
}
