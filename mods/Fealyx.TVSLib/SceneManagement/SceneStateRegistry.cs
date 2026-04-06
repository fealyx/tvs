using System.Collections.Generic;
using System.Linq;

namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Internal registry for managing SceneState instances across plugins.
/// Handles organization by scene, plugin ownership tracking, and priority sorting.
/// </summary>
internal class SceneStateRegistry
{
    private readonly Dictionary<string, List<StateEntry>> _statesByScene = new();
    private readonly Dictionary<BaseTVSPlugin, List<StateEntry>> _statesByPlugin = new();

    /// <summary>
    /// Represents a registered scene state with metadata.
    /// </summary>
    internal class StateEntry
    {
        public SceneState State { get; }
        public BaseTVSPlugin Plugin { get; }
        public int Priority { get; }

        public StateEntry(SceneState state, BaseTVSPlugin plugin)
        {
            State = state;
            Plugin = plugin;
            Priority = state.Priority;
        }
    }

    /// <summary>
    /// Registers a scene state for a specific plugin.
    /// </summary>
    public void Register(SceneState state, BaseTVSPlugin plugin)
    {
        var entry = new StateEntry(state, plugin);
        var sceneName = state.SceneName;

        // Add to scene-based index
        if (!_statesByScene.ContainsKey(sceneName))
        {
            _statesByScene[sceneName] = new List<StateEntry>();
        }
        _statesByScene[sceneName].Add(entry);

        // Sort by priority (descending - higher priority first)
        _statesByScene[sceneName] = _statesByScene[sceneName]
            .OrderByDescending(e => e.Priority)
            .ToList();

        // Add to plugin-based index
        if (!_statesByPlugin.ContainsKey(plugin))
        {
            _statesByPlugin[plugin] = new List<StateEntry>();
        }
        _statesByPlugin[plugin].Add(entry);
    }

    /// <summary>
    /// Unregisters all states for a specific plugin.
    /// </summary>
    public void UnregisterPlugin(BaseTVSPlugin plugin)
    {
        if (!_statesByPlugin.TryGetValue(plugin, out var entries))
        {
            return;
        }

        // Remove from scene-based index
        foreach (var entry in entries)
        {
            var sceneName = entry.State.SceneName;
            if (_statesByScene.TryGetValue(sceneName, out var sceneStates))
            {
                sceneStates.Remove(entry);
                if (sceneStates.Count == 0)
                {
                    _statesByScene.Remove(sceneName);
                }
            }
        }

        // Remove from plugin-based index
        _statesByPlugin.Remove(plugin);
    }

    /// <summary>
    /// Gets all states registered for a specific scene, sorted by priority.
    /// </summary>
    public IEnumerable<StateEntry> GetStatesForScene(string sceneName)
    {
        if (_statesByScene.TryGetValue(sceneName, out var states))
        {
            return states;
        }
        return System.Linq.Enumerable.Empty<StateEntry>();
    }

    /// <summary>
    /// Gets all registered states across all scenes.
    /// </summary>
    public IEnumerable<StateEntry> GetAllStates()
    {
        return _statesByScene.Values.SelectMany(list => list);
    }

    /// <summary>
    /// Gets the total number of registered states.
    /// </summary>
    public int Count => _statesByPlugin.Values.Sum(list => list.Count);
}
