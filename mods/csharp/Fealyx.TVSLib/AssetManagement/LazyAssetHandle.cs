using UnityEngine;

namespace Fealyx.TVSLib.AssetManagement;

/// <summary>
/// Base class for lazy-loaded asset handles.
/// </summary>
public abstract class LazyAssetHandle
{
    public abstract bool IsLoaded { get; }
    public abstract UnityEngine.Object? ValueAsObject { get; }
}

/// <summary>
/// A handle to a lazily-loaded asset. The asset is only loaded when Value is accessed.
/// </summary>
public class LazyAssetHandle<T> : LazyAssetHandle where T : UnityEngine.Object
{
    private readonly PluginAssets _context;
    private readonly string _bundlePath;
    private readonly string _assetName;
    private readonly AssetLoadOptions _options;
    private T? _cachedValue;
    private bool _isLoaded;

    public override bool IsLoaded => _isLoaded;

    public T? Value
    {
        get
        {
            if (!_isLoaded)
            {
                Load();
            }
            return _cachedValue;
        }
    }

    public override UnityEngine.Object? ValueAsObject => Value;

    internal LazyAssetHandle(PluginAssets context, string bundlePath, string assetName, AssetLoadOptions options)
    {
        _context = context;
        _bundlePath = bundlePath;
        _assetName = assetName;
        _options = options;
        _isLoaded = false;
    }

    /// <summary>
    /// Explicitly loads the asset if not already loaded.
    /// </summary>
    public void Load()
    {
        if (_isLoaded) return;

        _cachedValue = _context.LoadAsset<T>(_bundlePath, _assetName, _options);
        _isLoaded = true;
    }

    /// <summary>
    /// Unloads the asset from memory (but keeps the handle valid for reloading).
    /// </summary>
    public void Unload()
    {
        if (_cachedValue != null)
        {
            Resources.UnloadAsset(_cachedValue);
            _cachedValue = null;
            _isLoaded = false;
        }
    }

    /// <summary>
    /// Reloads the asset from the bundle.
    /// </summary>
    public void Reload()
    {
        Unload();
        Load();
    }
}
