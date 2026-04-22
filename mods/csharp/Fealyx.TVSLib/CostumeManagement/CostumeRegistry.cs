using System.Collections.Generic;
using System.Linq;

namespace Fealyx.TVSLib.CostumeManagement;

/// <summary>
/// Internal registry for managing costume registrations across plugins.
/// Handles organization by plugin and provides lookup capabilities.
/// </summary>
internal class CostumeRegistry
{
    private readonly Dictionary<string, CostumeItem> _costumesById = new();
    private readonly Dictionary<BaseTVSPlugin, List<CostumeItem>> _costumesByPlugin = new();
    private readonly Dictionary<string, List<CostumeItem>> _costumesByCategory = new();

    /// <summary>
    /// Registers a costume for a specific plugin.
    /// </summary>
    /// <param name="costume">The costume to register</param>
    /// <param name="plugin">The plugin that owns this costume</param>
    /// <returns>True if registered successfully, false if ID already exists</returns>
    public bool Register(CostumeItem costume, BaseTVSPlugin plugin)
    {
        // Check for duplicate ID
        if (_costumesById.ContainsKey(costume.Id))
        {
            return false;
        }

        costume.OwningPlugin = plugin;

        // Add to ID-based index
        _costumesById[costume.Id] = costume;

        // Add to plugin-based index
        if (!_costumesByPlugin.ContainsKey(plugin))
        {
            _costumesByPlugin[plugin] = new List<CostumeItem>();
        }
        _costumesByPlugin[plugin].Add(costume);

        // Add to category-based index
        if (!string.IsNullOrEmpty(costume.Category))
        {
            if (!_costumesByCategory.ContainsKey(costume.Category))
            {
                _costumesByCategory[costume.Category] = new List<CostumeItem>();
            }
            _costumesByCategory[costume.Category].Add(costume);
        }

        return true;
    }

    /// <summary>
    /// Unregisters all costumes for a specific plugin.
    /// </summary>
    /// <param name="plugin">The plugin whose costumes should be unregistered</param>
    public void UnregisterPlugin(BaseTVSPlugin plugin)
    {
        if (!_costumesByPlugin.TryGetValue(plugin, out var costumes))
        {
            return;
        }

        // Remove from ID index
        foreach (var costume in costumes)
        {
            _costumesById.Remove(costume.Id);

            // Remove from category index
            if (!string.IsNullOrEmpty(costume.Category) && 
                _costumesByCategory.TryGetValue(costume.Category, out var categoryList))
            {
                categoryList.Remove(costume);
                if (categoryList.Count == 0)
                {
                    _costumesByCategory.Remove(costume.Category);
                }
            }
        }

        // Remove from plugin index
        _costumesByPlugin.Remove(plugin);
    }

    /// <summary>
    /// Gets a costume by its ID.
    /// </summary>
    public CostumeItem? GetById(string id)
    {
        return _costumesById.TryGetValue(id, out var costume) ? costume : null;
    }

    /// <summary>
    /// Gets all costumes registered by a specific plugin.
    /// </summary>
    public IEnumerable<CostumeItem> GetByPlugin(BaseTVSPlugin plugin)
    {
        return _costumesByPlugin.TryGetValue(plugin, out var costumes) 
            ? costumes 
            : Enumerable.Empty<CostumeItem>();
    }

    /// <summary>
    /// Gets all costumes in a specific category.
    /// </summary>
    public IEnumerable<CostumeItem> GetByCategory(string category)
    {
        return _costumesByCategory.TryGetValue(category, out var costumes) 
            ? costumes 
            : Enumerable.Empty<CostumeItem>();
    }

    /// <summary>
    /// Gets all registered costumes.
    /// </summary>
    public IEnumerable<CostumeItem> GetAll()
    {
        return _costumesById.Values;
    }

    public string[] GetAllCategories() {
        return _costumesByCategory.Keys.ToArray();
    }

    /// <summary>
    /// Gets the total number of registered costumes.
    /// </summary>
    public int Count => _costumesById.Count;
}
