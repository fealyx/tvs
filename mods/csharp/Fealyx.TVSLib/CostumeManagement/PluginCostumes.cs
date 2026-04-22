using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

using Fealyx.TVSLib.CostumeManagement.Serialization;
using Fealyx.TVSLib.Logging;

namespace Fealyx.TVSLib.CostumeManagement;

/// <summary>
/// Per-plugin costume management interface.
/// Provides convenient access to costume registration and queries.
/// </summary>
public class PluginCostumes : IDisposable
{
    private readonly CostumeManager _manager;
    private readonly BaseTVSPlugin _plugin;
    private readonly BepInEx.Logging.ManualLogSource _logger;
    private readonly List<CostumeItem> _registeredCostumes = new();
    private readonly Dictionary<string, ICostumeSerializer> _serializers = new();
    private bool _disposed = false;

    internal PluginCostumes(CostumeManager manager, BaseTVSPlugin plugin)
    {
        _manager = manager ?? throw new ArgumentNullException(nameof(manager));
        _plugin = plugin ?? throw new ArgumentNullException(nameof(plugin));
        _logger = plugin.Logger.CreateSubLogger("Costumes");

        // Register default serializers
        RegisterSerializer(new JsonCostumeSerializer());
    }

    /// <summary>
    /// Registers a costume that will be loaded into the game.
    /// Costumes are automatically loaded when the CharacterCreator scene loads.
    /// </summary>
    /// <param name="costume">The costume to register</param>
    /// <returns>True if registered successfully, false if ID already exists</returns>
    public bool Register(CostumeItem costume)
    {
        if (_disposed)
        {
            throw new InvalidOperationException("Cannot register costume - PluginCostumes already disposed");
        }

        if (costume == null)
        {
            throw new ArgumentNullException(nameof(costume));
        }

        if (_manager.RegisterCostume(costume, _plugin))
        {
            _registeredCostumes.Add(costume);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Registers multiple costumes at once.
    /// </summary>
    /// <param name="costumes">The costumes to register</param>
    /// <returns>Number of costumes successfully registered</returns>
    public int RegisterMultiple(IEnumerable<CostumeItem> costumes)
    {
        if (_disposed)
        {
            throw new InvalidOperationException("Cannot register costumes - PluginCostumes already disposed");
        }

        int registered = 0;
        foreach (var costume in costumes)
        {
            if (Register(costume))
            {
                registered++;
            }
        }

        return registered;
    }

    /// <summary>
    /// Gets a costume by its ID (from any plugin).
    /// </summary>
    public CostumeItem? GetById(string id)
    {
        return _manager.GetCostumeById(id);
    }

    /// <summary>
    /// Gets all costumes registered by this plugin.
    /// </summary>
    public IReadOnlyList<CostumeItem> RegisteredCostumes => _registeredCostumes.AsReadOnly();

    /// <summary>
    /// Gets all costumes in a specific category (from all plugins).
    /// </summary>
    public IEnumerable<CostumeItem> GetByCategory(string category)
    {
        return _manager.GetCostumesByCategory(category);
    }

    /// <summary>
    /// Gets all registered costumes (from all plugins).
    /// </summary>
    public IEnumerable<CostumeItem> GetAll()
    {
        return _manager.GetAllCostumes();
    }

    /// <summary>
    /// Registers a custom serializer for loading costume definitions.
    /// </summary>
    /// <param name="serializer">The serializer to register</param>
    public void RegisterSerializer(ICostumeSerializer serializer)
    {
        foreach (var ext in serializer.SupportedExtensions)
        {
            _serializers[ext.ToLowerInvariant()] = serializer;
        }
    }

    /// <summary>
    /// Loads a costume from a JSON file.
    /// </summary>
    /// <param name="filePath">Path to the JSON file (relative to plugin root or absolute)</param>
    /// <returns>True if loaded successfully</returns>
    public bool LoadFromJson(string filePath)
    {
        return LoadFromFile(filePath, ".json");
    }

    /// <summary>
    /// Loads a costume from a YAML file.
    /// </summary>
    /// <param name="filePath">Path to the YAML file (relative to plugin root or absolute)</param>
    /// <returns>True if loaded successfully</returns>
    public bool LoadFromYaml(string filePath)
    {
        return LoadFromFile(filePath, ".yaml");
    }

    /// <summary>
    /// Loads a costume from a file, auto-detecting the format by extension.
    /// </summary>
    /// <param name="filePath">Path to the file (relative to plugin root or absolute)</param>
    /// <returns>True if loaded successfully</returns>
    public bool LoadFromFile(string filePath)
    {
        var extension = Path.GetExtension(filePath)?.ToLowerInvariant();
        return LoadFromFile(filePath, extension);
    }

    /// <summary>
    /// Loads all costume definition files from a directory.
    /// Supports .json and .yaml files.
    /// </summary>
    /// <param name="directoryPath">Path to the directory (relative to plugin root or absolute)</param>
    /// <param name="searchPattern">File search pattern (default: "*.*")</param>
    /// <param name="recursive">Whether to search subdirectories</param>
    /// <returns>Number of costumes successfully loaded</returns>
    public int LoadFromDirectory(string directoryPath, string searchPattern = "*.*", bool recursive = false)
    {
        if (_disposed)
        {
            throw new InvalidOperationException("Cannot load costumes - PluginCostumes already disposed");
        }

        var resolvedPath = ResolvePath(directoryPath);
        if (!Directory.Exists(resolvedPath))
        {
            _logger.LogWarning($"Costume directory not found: {resolvedPath}");
            return 0;
        }

        var searchOption = recursive ? SearchOption.AllDirectories : SearchOption.TopDirectoryOnly;
        var files = Directory.GetFiles(resolvedPath, searchPattern, searchOption);

        int loaded = 0;
        foreach (var file in files)
        {
            var extension = Path.GetExtension(file)?.ToLowerInvariant();
            if (_serializers.ContainsKey(extension ?? string.Empty))
            {
                if (LoadFromFile(file))
                {
                    loaded++;
                }
            }
        }

        _logger.LogInfo($"Loaded {loaded} costume(s) from directory: {directoryPath}");
        return loaded;
    }

    private bool LoadFromFile(string filePath, string? expectedExtension = null)
    {
        if (_disposed)
        {
            throw new InvalidOperationException("Cannot load costume - PluginCostumes already disposed");
        }

        try
        {
            var resolvedPath = ResolvePath(filePath);
            var extension = expectedExtension ?? Path.GetExtension(resolvedPath)?.ToLowerInvariant();

            if (string.IsNullOrEmpty(extension))
            {
                _logger.LogError($"Cannot determine file type for: {filePath}");
                return false;
            }

            if (!_serializers.TryGetValue(extension, out var serializer))
            {
                _logger.LogError($"No serializer registered for extension: {extension}");
                return false;
            }

            var costumeItem = serializer.Deserialize(resolvedPath);
            if (costumeItem == null)
            {
                _logger.LogError($"Failed to deserialize costume from: {filePath}");
                return false;
            }

            // Set the owning plugin reference
            costumeItem.OwningPlugin = _plugin;

            if (Register(costumeItem))
            {
                _logger.LogInfo($"Loaded costume '{costumeItem.Name}' from: {Path.GetFileName(filePath)}");
                return true;
            }

            return false;
        }
        catch (Exception ex)
        {
            _logger.LogError($"Error loading costume from {filePath}: {ex.Message}");
            return false;
        }
    }

    private string ResolvePath(string path)
    {
        // If absolute path, use as-is
        if (Path.IsPathRooted(path))
        {
            return path;
        }

        // Otherwise, resolve relative to plugin root
        return Path.Combine(_plugin.FilePaths["Root"], path);
    }

    /// <summary>
    /// Disposes this costume context and unregisters all costumes.
    /// Called automatically when the owning plugin is disposed.
    /// </summary>
    public void Dispose()
    {
        if (_disposed) return;

        _logger.LogInfo($"Disposing costume context ({_registeredCostumes.Count} costumes registered)");

        // Unregister from manager
        _manager.UnregisterCostumes(_plugin);

        _registeredCostumes.Clear();
        _disposed = true;
    }
}
