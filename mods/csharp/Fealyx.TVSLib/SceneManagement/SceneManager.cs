using System;
using System.Collections.Generic;
using System.Linq;

using BepInEx.Logging;
using UnityEngine;
using UnityEngine.SceneManagement;

using Fealyx.TVSLib.Logging;


namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Central scene management system that handles Unity scene lifecycle events,
/// manages SceneState instances, and provides scene-specific contexts.
/// </summary>
public class SceneManager : Manager
{
    private readonly SceneStateRegistry _registry = new();
    private readonly Dictionary<string, Type> _contextTypes = new();
    private readonly Dictionary<string, ISceneContext> _activeContexts = new();
    private readonly List<SceneState> _updateStates = new();
    private readonly List<SceneState> _fixedUpdateStates = new();
    private readonly Dictionary<string, SceneLifecycleDispatcher> _sceneDispatchers = new();
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
    /// Registers a context type for a specific scene.
    /// The context will be automatically created and initialized when the scene loads.
    /// </summary>
    /// <typeparam name="TContext">The context type (must have parameterless constructor)</typeparam>
    /// <param name="sceneName">The name of the scene this context is for</param>
    public void RegisterContext<TContext>(string sceneName) where TContext : ISceneContext, new()
    {
        _contextTypes[sceneName] = typeof(TContext);
        Logger.LogInfo($"Registered context type {typeof(TContext).Name} for scene '{sceneName}'");
    }

    /// <summary>
    /// Gets the active context for a specific scene, if one exists.
    /// </summary>
    /// <typeparam name="TContext">The context type to retrieve</typeparam>
    /// <returns>The context instance, or null if not found or scene not active</returns>
    public TContext? GetContext<TContext>() where TContext : class, ISceneContext
    {
        if (_currentSceneName != null && _activeContexts.TryGetValue(_currentSceneName, out var context))
        {
            return context as TContext;
        }
        return null;
    }

    /// <summary>
    /// Registers a framework scene state (not owned by any plugin).
    /// Framework states are part of TVSLib's internal systems.
    /// </summary>
    /// <param name="state">The framework state to register</param>
    /// <param name="logger">A custom logger. Defaults to a new namespaced logger.</param>
    public void RegisterFrameworkState(SceneState state, ManualLogSource logger = null!)
    {
        _registry.RegisterFramework(state);

        if (logger == null)
        {
            logger = Logger.CreateSubLogger($"SceneState.{state.GetType().Name}");
        }

        state.SetLogger(logger);

        Logger.LogInfo($"Registered framework state: {state.GetType().Name} for scene '{state.SceneName}' (priority: {state.Priority})");

        // If the state's scene is currently active, activate it immediately
        if (_currentSceneName == state.SceneName)
        {
            var activeScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            var currentContext = _activeContexts.TryGetValue(_currentSceneName, out var ctx) ? ctx : null;
            ActivateState(state, activeScene, currentContext);
        }
    }

    /// <summary>
    /// Registers a scene state for lifecycle management.
    /// </summary>
    /// <param name="state">The scene state to register</param>
    /// <param name="plugin">The plugin that owns this state</param>
    public void RegisterState(SceneState state, BaseTVSPlugin plugin)
    {
        _registry.Register(state, plugin);
        Logger.LogInfo($"Registered scene state: {state.GetType().Name} for scene '{state.SceneName}' (priority: {state.Priority})");

        // If the state's scene is currently active, activate it immediately
        if (_currentSceneName == state.SceneName)
        {
            var activeScene = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
            var currentContext = _activeContexts.TryGetValue(_currentSceneName, out var ctx) ? ctx : null;
            ActivateState(state, activeScene, currentContext);
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
        Logger.LogInfo($"Unregistered all scene states for plugin: {plugin.Info.Metadata.Name}");
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

        Logger.LogInfo("Scene management system initialized");
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
        Logger.LogInfo($"Scene changed: {oldScene.name} -> {newScene.name}");

        // Cleanup old scene context and dispatcher
        if (!string.IsNullOrEmpty(oldScene.name))
        {
            if (_activeContexts.TryGetValue(oldScene.name, out var oldContext))
            {
                try
                {
                    oldContext.Cleanup();
                    _activeContexts.Remove(oldScene.name);
                    Logger.LogInfo($"Cleaned up context for scene: {oldScene.name}");
                }
                catch (Exception ex)
                {
                    Logger.LogError($"Error cleaning up context for {oldScene.name}: {ex}");
                }
            }

            // Cleanup per-scene dispatcher
            if (_sceneDispatchers.TryGetValue(oldScene.name, out var oldDispatcher))
            {
                UnityEngine.Object.Destroy(oldDispatcher.gameObject);
                _sceneDispatchers.Remove(oldScene.name);
                Logger.LogInfo($"Destroyed lifecycle dispatcher for scene: {oldScene.name}");
            }

            // Deactivate states from old scene
            TransitionStates(oldScene.name, oldScene, SceneStateTransition.Exiting);
        }

        // Initialize new scene context
        _currentSceneName = newScene.name;
        ISceneContext? newContext = null;

        if (_contextTypes.TryGetValue(newScene.name, out var contextType))
        {
            try
            {
                newContext = (ISceneContext)Activator.CreateInstance(contextType);

                // Subscribe to OnReady before initializing
                newContext.OnReady += () => OnContextReady(newScene, newContext);

                newContext.Initialize();
                _activeContexts[newScene.name] = newContext;

                if (newContext.IsReady)
                {
                    Logger.LogInfo($"Context for {newScene.name} initialized and ready immediately");
                }
                else
                {
                    Logger.LogInfo($"Context for {newScene.name} initialized, waiting for ready signal");
                }
            }
            catch (Exception ex)
            {
                Logger.LogError($"Error initializing context for {newScene.name}: {ex}");
                newContext = null;
            }
        }

        // Activate states for new scene (with context)
        TransitionStates(newScene.name, newScene, SceneStateTransition.Entering, newContext);

        // Create per-scene lifecycle dispatcher
        CreateSceneDispatcher(newScene);

        OnSceneChanged?.Invoke(oldScene, newScene);
    }

    private void OnContextReady(Scene scene, ISceneContext context)
    {
        Logger.LogInfo($"Context ready for scene: {scene.name}");

        // Get all active states for this scene and call OnReady in priority order
        var states = _registry.GetStatesForScene(scene.name).Select(e => e.State).ToList();

        foreach (var state in states)
        {
            if (state.Transition == SceneStateTransition.Active)
            {
                try
                {
                    state.Transition = SceneStateTransition.Ready;
                    state.OnReady(scene);
                    state.Transition = SceneStateTransition.Active;
                }
                catch (Exception ex)
                {
                    Logger.LogError($"Error in {state.GetType().Name}.OnReady(): {ex}");
                }
            }
        }
    }

    private void HandleSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        Logger.LogInfo($"Scene loaded: {scene.name} (mode: {mode})");

        // Invoke OnAwake for states immediately after scene is fully loaded
        // At this point, the scene hierarchy is complete but Start() hasn't been called yet
        if (scene.name == _currentSceneName)
        {
            InvokeStateAwakes();
        }

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
        Logger.LogInfo($"Scene unloaded: {scene.name}");

        // Cleanup context
        if (_activeContexts.TryGetValue(scene.name, out var context))
        {
            try
            {
                context.Cleanup();
                _activeContexts.Remove(scene.name);
            }
            catch (Exception ex)
            {
                Logger.LogError($"Error cleaning up context for {scene.name}: {ex}");
            }
        }

        // Deactivate states for unloaded scene
        TransitionStates(scene.name, scene, SceneStateTransition.Exiting, null);

        OnSceneUnloaded?.Invoke(scene);
    }

    private void TransitionStates(string sceneName, Scene scene, SceneStateTransition targetTransition, ISceneContext? context = null)
    {
        var states = _registry.GetStatesForScene(sceneName).Select(e => e.State).ToList();

        if (targetTransition == SceneStateTransition.Entering)
        {
            // Activate states in priority order (high to low)
            foreach (var state in states)
            {
                ActivateState(state, scene, context);
            }

            // If there's no context, call OnReady immediately for all states
            if (context == null)
            {
                Logger.LogInfo($"No context for scene {sceneName}, calling OnReady immediately");
                foreach (var state in states)
                {
                    if (state.Transition == SceneStateTransition.Active)
                    {
                        try
                        {
                            state.Transition = SceneStateTransition.Ready;
                            state.OnReady(scene);
                            state.Transition = SceneStateTransition.Active;
                        }
                        catch (Exception ex)
                        {
                            Logger.LogError($"Error in {state.GetType().Name}.OnReady(): {ex}");
                        }
                    }
                }
            }
            // If context exists and is already ready, call OnReady immediately
            else if (context.IsReady)
            {
                Logger.LogInfo($"Context for scene {sceneName} already ready, calling OnReady immediately");
                foreach (var state in states)
                {
                    if (state.Transition == SceneStateTransition.Active)
                    {
                        try
                        {
                            state.Transition = SceneStateTransition.Ready;
                            state.OnReady(scene);
                            state.Transition = SceneStateTransition.Active;
                        }
                        catch (Exception ex)
                        {
                            Logger.LogError($"Error in {state.GetType().Name}.OnReady(): {ex}");
                        }
                    }
                }
            }
            // Otherwise, OnReady will be called when context fires its OnReady event
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

    private void ActivateState(SceneState state, Scene scene, ISceneContext? context = null)
    {
        if (state.Transition == SceneStateTransition.Active || 
            state.Transition == SceneStateTransition.Entering)
        {
            return; // Already active
        }

        try
        {
            // Set context before activating
            state.SetContext(context);

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

            Logger.LogInfo($"Activated state: {state.GetType().Name} for scene '{scene.name}'");
        }
        catch (Exception ex)
        {
            Logger.LogError($"Error activating state {state.GetType().Name}: {ex}");
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

            Logger.LogInfo($"Deactivated state: {state.GetType().Name} from scene '{scene.name}'");
        }
        catch (Exception ex)
        {
            Logger.LogError($"Error deactivating state {state.GetType().Name}: {ex}");
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
                    Logger.LogError($"Error in {state.GetType().Name}.OnUpdate(): {ex}");
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
                    Logger.LogError($"Error in {state.GetType().Name}.OnFixedUpdate(): {ex}");
                }
            }
        }
    }

    private void CreateSceneDispatcher(Scene scene)
    {
        var dispatcherObj = new GameObject($"TVSLib.SceneManager.SceneDispatcher[{scene.name}]");
        dispatcherObj.SetActive(false);

        var dispatcher = dispatcherObj.AddComponent<SceneLifecycleDispatcher>();

        dispatcher.OnStartCallback = InvokeStateStarts;

        // Move the dispatcher to the scene's hierarchy so Unity calls Start
        UnityEngine.SceneManagement.SceneManager.MoveGameObjectToScene(dispatcherObj, scene);

        _sceneDispatchers[scene.name] = dispatcher;

        dispatcherObj.SetActive(true);

        Logger.LogInfo($"Created lifecycle dispatcher for scene: {scene.name}");
    }

    private void InvokeStateAwakes()
    {
        if (_currentSceneName == null) return;

        // Invoke on all active states for the current scene
        var states = _registry.GetStatesForScene(_currentSceneName).Select(e => e.State).ToList();
        foreach (var state in states)
        {
            try
            {
                state.OnAwake();
            }
            catch (Exception ex)
            {
                Logger.LogError($"Error in {state.GetType().Name}.OnAwake(): {ex}");
            }
        }
    }

    private void InvokeStateStarts()
    {
        if (_currentSceneName == null) return;

        // Invoke on all active states for the current scene
        var states = _registry.GetStatesForScene(_currentSceneName).Select(e => e.State).ToList();
        foreach (var state in states)
        {
            try
            {
                state.OnStart();
            }
            catch (Exception ex)
            {
                Logger.LogError($"Error in {state.GetType().Name}.OnStart(): {ex}");
            }
        }
    }

    /// <summary>
    /// Per-scene MonoBehaviour for dispatching Unity lifecycle events (Start).
    /// Created for each scene and destroyed when the scene unloads.
    /// OnAwake is called directly from HandleSceneLoaded to ensure scene hierarchy is complete.
    /// </summary>
    private class SceneLifecycleDispatcher : MonoBehaviour
    {
        public Action? OnStartCallback;

        private void Start()
        {
            OnStartCallback?.Invoke();
        }
    }

    /// <summary>
    /// Internal MonoBehaviour for dispatching Unity update callbacks.
    /// Persists across scene loads (DontDestroyOnLoad).
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
