using System.Collections.Generic;
using System.Linq;

using BepInEx.Logging;

namespace Fealyx.TVSLib.CostumeManagement;

/// <summary>
/// Central costume management system that handles costume registration and lifecycle.
/// Costumes registered here will be loaded into appropriate scenes automatically.
/// </summary>
public class CostumeManager : Manager
{
    public static CostumeManager? Instance { get; private set; }

    private readonly CostumeRegistry _registry = new();

    public CostumeManager()
    {
        if (Instance != null)
        {
            // Will be logged once Logger is initialized
            return;
        }

        Instance = this;
    }

    /// <summary>
    /// Creates a new PluginCostumes context for the specified plugin.
    /// </summary>
    public PluginCostumes CreateContext(BaseTVSPlugin plugin)
    {
        return new PluginCostumes(this, plugin);
    }

    /// <summary>
    /// Registers a costume. Called internally by PluginCostumes.
    /// </summary>
    /// <param name="costume">The costume to register</param>
    /// <param name="plugin">The plugin that owns this costume</param>
    /// <returns>True if registered successfully, false if ID already exists</returns>
    internal bool RegisterCostume(CostumeItem costume, BaseTVSPlugin plugin)
    {
        if (string.IsNullOrEmpty(costume.Id))
        {
            Logger.LogError($"Cannot register costume with empty ID from plugin {plugin.Info.Metadata.Name}");
            return false;
        }

        if (!_registry.Register(costume, plugin))
        {
            Logger.LogError($"Costume with ID '{costume.Id}' already registered");
            return false;
        }

        Logger.LogInfo($"Registered costume: {costume.Name} (ID: {costume.Id}, Category: {costume.Category})");
        return true;
    }

    /// <summary>
    /// Unregisters all costumes for a specific plugin.
    /// </summary>
    /// <param name="plugin">The plugin whose costumes should be unregistered</param>
    internal void UnregisterCostumes(BaseTVSPlugin plugin)
    {
        var count = _registry.GetByPlugin(plugin).Count();
        _registry.UnregisterPlugin(plugin);
        Logger.LogInfo($"Unregistered {count} costumes for plugin: {plugin.Info.Metadata.Name}");
    }

    /// <summary>
    /// Gets a costume by its ID.
    /// </summary>
    public CostumeItem? GetCostumeById(string id)
    {
        return _registry.GetById(id);
    }

    /// <summary>
    /// Gets all costumes in a specific category.
    /// </summary>
    public IEnumerable<CostumeItem> GetCostumesByCategory(string category)
    {
        return _registry.GetByCategory(category);
    }

    /// <summary>
    /// Gets all registered costumes.
    /// </summary>
    public IEnumerable<CostumeItem> GetAllCostumes()
    {
        return _registry.GetAll();
    }

    /// <summary>
    /// Gets all costumes that haven't been loaded yet (for internal use by scene states).
    /// </summary>
    internal IEnumerable<CostumeItem> GetPendingCostumes()
    {
        // TODO: Implement loading tracking to return only unloaded costumes
        // For now, return all costumes (scene states can filter as needed)
        return _registry.GetAll();
    }

    /// <summary>
    /// Gets the total number of registered costumes.
    /// </summary>
    public int RegisteredCostumeCount => _registry.Count;

    protected override void Dispose(bool disposing)
    {
        if (LifecycleState == Lifecycle.LifecycleState.Destroyed || 
            LifecycleState == Lifecycle.LifecycleState.Destroying)
        {
            return;
        }

        if (disposing)
        {
            Logger?.LogInfo($"Disposing costume manager ({_registry.Count} costumes registered)");
            // Costumes will be cleaned up when plugins dispose
        }

        base.Dispose(disposing);
    }
}
