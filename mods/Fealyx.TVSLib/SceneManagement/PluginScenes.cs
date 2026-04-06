using System;
using System.Collections.Generic;
using System.Linq;

namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Per-plugin scene state management interface.
/// Provides convenient access to scene state registration and scene information.
/// </summary>
public class PluginScenes : IDisposable
{
    private readonly SceneManager _manager;
    private readonly BaseTVSPlugin _plugin;
    private readonly BepInEx.Logging.ManualLogSource _logger;
    private readonly List<SceneState> _registeredStates = new();
    private bool _disposed = false;

    internal PluginScenes(SceneManager manager, BaseTVSPlugin plugin)
    {
        _manager = manager ?? throw new ArgumentNullException(nameof(manager));
        _plugin = plugin ?? throw new ArgumentNullException(nameof(plugin));
        _logger = plugin.CreateSubLogger("Scenes");
    }

    /// <summary>
    /// Gets the current active scene name.
    /// </summary>
    public string CurrentScene => UnityEngine.SceneManagement.SceneManager.GetActiveScene().name;

    /// <summary>
    /// Registers a scene state for this plugin.
    /// The state will be automatically managed and cleaned up when the plugin is disposed.
    /// </summary>
    /// <param name="state">The scene state to register</param>
    public void Register(SceneState state)
    {
        if (_disposed)
        {
            throw new InvalidOperationException("Cannot register state - PluginScenes already disposed");
        }

        state.SetPlugin(_plugin);
        _manager.RegisterState(state, _plugin);
        _registeredStates.Add(state);
    }

    /// <summary>
    /// Registers all scene states from the plugin's assembly that have the [SceneState] attribute.
    /// This provides a declarative way to register multiple states without manual registration.
    /// </summary>
    public void RegisterAllStates()
    {
        if (_disposed)
        {
            throw new InvalidOperationException("Cannot register states - PluginScenes already disposed");
        }

        var pluginType = _plugin.GetType();
        var assembly = pluginType.Assembly;

        // Find all types with SceneStateAttribute
        var stateTypes = assembly.GetTypes()
            .Where(t => t.IsSubclassOf(typeof(SceneState)) && !t.IsAbstract)
            .Where(t => t.GetCustomAttributes(typeof(SceneStateAttribute), false).Length > 0);

        foreach (var stateType in stateTypes)
        {
            try
            {
                // Create instance (assumes parameterless constructor)
                var state = (SceneState)Activator.CreateInstance(stateType);
                Register(state);
            }
            catch (Exception ex)
            {
                _logger.LogError($"Failed to create SceneState instance for {stateType.Name}: {ex.Message}");
            }
        }
    }

    /// <summary>
    /// Checks if a specific scene is currently active.
    /// </summary>
    /// <param name="sceneName">The scene name to check</param>
    /// <returns>True if the specified scene is currently active</returns>
    public bool IsSceneActive(string sceneName)
    {
        return CurrentScene == sceneName;
    }

    /// <summary>
    /// Gets all states registered by this plugin.
    /// </summary>
    public IReadOnlyList<SceneState> RegisteredStates => _registeredStates.AsReadOnly();

    /// <summary>
    /// Disposes all registered states and cleans up resources.
    /// Called automatically when the owning plugin is disposed.
    /// </summary>
    public void Dispose()
    {
        if (_disposed) return;

        // Dispose all registered states
        foreach (var state in _registeredStates)
        {
            try
            {
                state.Dispose();
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error disposing state {state.GetType().Name}: {ex.Message}");
            }
        }
        _registeredStates.Clear();

        // Unregister from manager
        _manager.UnregisterStates(_plugin);

        _disposed = true;
    }
}
