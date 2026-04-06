using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

namespace Fealyx.TVSLib.AssetManagement;

/// <summary>
/// Per-plugin asset context that tracks loaded assets and provides isolated access to the global AssetsManager.
/// Automatically cleans up all tracked assets when disposed.
/// </summary>
public class PluginAssets : IDisposable
{
    private readonly AssetsManager _manager;
    private readonly BaseTVSPlugin _plugin;
    private readonly BepInEx.Logging.ManualLogSource _logger;
    private readonly HashSet<string> _loadedBundlePaths = new();
    private readonly List<UnityEngine.Object> _loadedAssets = new();
    private readonly Dictionary<string, LazyAssetHandle> _lazyHandles = new();
    private bool _disposed = false;

    internal PluginAssets(AssetsManager manager, BaseTVSPlugin plugin)
    {
        _manager = manager ?? throw new ArgumentNullException(nameof(manager));
        _plugin = plugin ?? throw new ArgumentNullException(nameof(plugin));
        _logger = plugin.CreateSubLogger("Assets");
    }

    /// <summary>
    /// Resolves a bundle path relative to the plugin's AssetBundles directory if it's not an absolute path.
    /// Supports both simple filenames ("mybundle.bundle") and relative paths ("subfolder/mybundle.bundle").
    /// Absolute paths are used as-is.
    /// </summary>
    private string ResolveBundlePath(string bundlePath)
    {
        // If it's already an absolute path, use as-is
        if (Path.IsPathRooted(bundlePath))
        {
            return bundlePath;
        }

        // Otherwise, resolve relative to plugin's AssetBundles directory
        if (_plugin.FilePaths.TryGetValue("AssetBundles", out var assetBundlesDir))
        {
            return Path.Combine(assetBundlesDir, bundlePath);
        }

        // Fallback to treating it as absolute if AssetBundles path not configured
        _logger.LogWarning($"AssetBundles path not configured in plugin, using bundle path as-is: {bundlePath}");
        return bundlePath;
    }

    /// <summary>
    /// Loads an asset from the specified bundle with default options.
    /// Bundle path can be a simple filename (resolved relative to plugin's AssetBundles directory),
    /// a relative path, or an absolute path.
    /// </summary>
    /// <param name="bundlePath">Bundle filename (e.g., "mybundle.bundle"), relative path, or absolute path</param>
    /// <param name="assetName">Name of the asset within the bundle</param>
    public T? LoadAsset<T>(string bundlePath, string assetName) where T : UnityEngine.Object
    {
        return LoadAsset<T>(bundlePath, assetName, AssetLoadOptions.Default);
    }

    /// <summary>
    /// Loads an asset from the specified bundle with custom options.
    /// Bundle path can be a simple filename (resolved relative to plugin's AssetBundles directory),
    /// a relative path, or an absolute path.
    /// </summary>
    /// <param name="bundlePath">Bundle filename (e.g., "mybundle.bundle"), relative path, or absolute path</param>
    /// <param name="assetName">Name of the asset within the bundle</param>
    /// <param name="options">Loading options (caching, async, lazy, priority)</param>
    public T? LoadAsset<T>(string bundlePath, string assetName, AssetLoadOptions options) where T : UnityEngine.Object
    {
        if (_disposed)
        {
            _logger.LogWarning($"Cannot load asset '{assetName}' - PluginAssets already disposed.");
            return null;
        }

        var resolvedPath = ResolveBundlePath(bundlePath);

        if (options.Lazy)
        {
            return GetOrCreateLazyHandle<T>(resolvedPath, assetName, options).Value;
        }

        if (options.Async)
        {
            _logger.LogWarning($"Async loading requested for '{assetName}' but called synchronously. Use LoadAssetAsync instead.");
        }

        return LoadAssetInternal<T>(resolvedPath, assetName, options);
    }

    /// <summary>
    /// Loads an asset asynchronously from the specified bundle.
    /// Bundle path can be a simple filename (resolved relative to plugin's AssetBundles directory),
    /// a relative path, or an absolute path.
    /// </summary>
    /// <param name="bundlePath">Bundle filename (e.g., "mybundle.bundle"), relative path, or absolute path</param>
    /// <param name="assetName">Name of the asset within the bundle</param>
    public AssetLoadOperation<T> LoadAssetAsync<T>(string bundlePath, string assetName) where T : UnityEngine.Object
    {
        return LoadAssetAsync<T>(bundlePath, assetName, AssetLoadOptions.AsyncCached);
    }

    /// <summary>
    /// Loads an asset asynchronously from the specified bundle with custom options.
    /// Bundle path can be a simple filename (resolved relative to plugin's AssetBundles directory),
    /// a relative path, or an absolute path.
    /// </summary>
    /// <param name="bundlePath">Bundle filename (e.g., "mybundle.bundle"), relative path, or absolute path</param>
    /// <param name="assetName">Name of the asset within the bundle</param>
    /// <param name="options">Loading options (caching, async, lazy, priority)</param>
    public AssetLoadOperation<T> LoadAssetAsync<T>(string bundlePath, string assetName, AssetLoadOptions options) where T : UnityEngine.Object
    {
        if (_disposed)
        {
            _logger.LogWarning($"Cannot load asset '{assetName}' - PluginAssets already disposed.");
            var failedOp = new AssetLoadOperation<T>(null);
            failedOp.SetResult(null);
            return failedOp;
        }

        var resolvedPath = ResolveBundlePath(bundlePath);
        var operation = new AssetLoadOperation<T>(null);
        var coroutine = _plugin.StartCoroutine(LoadAssetAsyncCoroutine<T>(resolvedPath, assetName, options, operation));
        return operation;
    }

    /// <summary>
    /// Creates a lazy-loaded asset handle that loads on first access.
    /// Bundle path can be a simple filename (resolved relative to plugin's AssetBundles directory),
    /// a relative path, or an absolute path.
    /// </summary>
    /// <param name="bundlePath">Bundle filename (e.g., "mybundle.bundle"), relative path, or absolute path</param>
    /// <param name="assetName">Name of the asset within the bundle</param>
    public LazyAssetHandle<T> GetLazyAsset<T>(string bundlePath, string assetName) where T : UnityEngine.Object
    {
        var resolvedPath = ResolveBundlePath(bundlePath);
        return GetOrCreateLazyHandle<T>(resolvedPath, assetName, AssetLoadOptions.LazyLoaded);
    }

    /// <summary>
    /// Unloads a specific bundle, releasing the reference from this plugin.
    /// The bundle will only be truly unloaded if no other plugins reference it.
    /// Bundle path can be a simple filename (resolved relative to plugin's AssetBundles directory),
    /// a relative path, or an absolute path.
    /// </summary>
    /// <param name="bundlePath">Bundle filename (e.g., "mybundle.bundle"), relative path, or absolute path</param>
    /// <param name="unloadAllLoadedObjects">Whether to unload all loaded objects from the bundle</param>
    public void UnloadBundle(string bundlePath, bool unloadAllLoadedObjects = false)
    {
        if (_disposed) return;

        var resolvedPath = ResolveBundlePath(bundlePath);

        if (_loadedBundlePaths.Remove(resolvedPath))
        {
            _manager.ReleaseBundle(this, resolvedPath, unloadAllLoadedObjects);
            _logger.LogInfo($"Released bundle reference: {bundlePath}");
        }
    }

    /// <summary>
    /// Reloads all assets associated with this plugin. Useful for hot-reloading during development.
    /// </summary>
    public void ReloadAllAssets()
    {
        if (_disposed) return;

        _logger.LogInfo($"Reloading all assets for plugin: {_plugin.Info.Metadata.Name}");

        var bundlePaths = new List<string>(_loadedBundlePaths);

        // Unload all assets
        foreach (var asset in _loadedAssets)
        {
            if (asset != null)
            {
                Resources.UnloadAsset(asset);
            }
        }
        _loadedAssets.Clear();

        // Reload bundles
        foreach (var path in bundlePaths)
        {
            _manager.ReloadBundle(this, path);
        }

        // Clear lazy handles to force reload
        _lazyHandles.Clear();

        _logger.LogInfo($"Asset reload complete for plugin: {_plugin.Info.Metadata.Name}");
    }

    /// <summary>
    /// Gets the number of assets currently loaded by this plugin.
    /// </summary>
    public int LoadedAssetCount => _loadedAssets.Count;

    /// <summary>
    /// Gets the number of bundles currently referenced by this plugin.
    /// </summary>
    public int ReferencedBundleCount => _loadedBundlePaths.Count;

    public void Dispose()
    {
        if (_disposed) return;

        _logger.LogInfo($"Disposing PluginAssets for: {_plugin.Info.Metadata.Name}");

        // Unload all tracked assets
        foreach (var asset in _loadedAssets)
        {
            if (asset != null)
            {
                Resources.UnloadAsset(asset);
            }
        }
        _loadedAssets.Clear();

        // Release all bundle references
        foreach (var path in _loadedBundlePaths.ToList())
        {
            _manager.ReleaseBundle(this, path, false);
        }
        _loadedBundlePaths.Clear();

        // Clear lazy handles
        _lazyHandles.Clear();

        _disposed = true;
        _logger.LogInfo($"PluginAssets disposed for: {_plugin.Info.Metadata.Name}");
    }

    private T? LoadAssetInternal<T>(string bundlePath, string assetName, AssetLoadOptions options) where T : UnityEngine.Object
    {
        var bundle = _manager.LoadBundle(this, bundlePath);
        if (bundle == null)
        {
            _logger.LogError($"Failed to load bundle: {bundlePath}");
            return null;
        }

        _loadedBundlePaths.Add(bundlePath);

        // Check cache first if enabled
        if (options.Cache)
        {
            var cached = _manager.GetCachedAsset<T>(bundlePath, assetName);
            if (cached != null)
            {
                _loadedAssets.Add(cached);
                return cached;
            }
        }

        var asset = bundle.LoadAsset<T>(assetName);
        if (asset != null)
        {
            _loadedAssets.Add(asset);
            if (options.Cache)
            {
                _manager.CacheAsset(bundlePath, assetName, asset);
            }
            _logger.LogInfo($"Loaded asset: {assetName} from {bundlePath}");
        }
        else
        {
            _logger.LogWarning($"Failed to load asset: {assetName} from {bundlePath}");
        }

        return asset;
    }

    private IEnumerator LoadAssetAsyncCoroutine<T>(string bundlePath, string assetName, AssetLoadOptions options, AssetLoadOperation<T> operation) where T : UnityEngine.Object
    {
        var bundle = _manager.LoadBundle(this, bundlePath);
        if (bundle == null)
        {
            _logger.LogError($"Failed to load bundle: {bundlePath}");
            operation.SetResult(null);
            yield break;
        }

        _loadedBundlePaths.Add(bundlePath);

        // Check cache first if enabled
        if (options.Cache)
        {
            var cached = _manager.GetCachedAsset<T>(bundlePath, assetName);
            if (cached != null)
            {
                _loadedAssets.Add(cached);
                operation.SetResult(cached);
                yield break;
            }
        }

        var request = bundle.LoadAssetAsync<T>(assetName);
        request.priority = options.Priority;

        yield return request;

        var asset = request.asset as T;
        if (asset != null)
        {
            _loadedAssets.Add(asset);
            if (options.Cache)
            {
                _manager.CacheAsset(bundlePath, assetName, asset);
            }
            _logger.LogInfo($"Async loaded asset: {assetName} from {bundlePath}");
        }
        else
        {
            _logger.LogWarning($"Failed to async load asset: {assetName} from {bundlePath}");
        }

        operation.SetResult(asset);
    }

    private LazyAssetHandle<T> GetOrCreateLazyHandle<T>(string bundlePath, string assetName, AssetLoadOptions options) where T : UnityEngine.Object
    {
        var key = $"{bundlePath}|{assetName}";

        if (!_lazyHandles.TryGetValue(key, out var handle))
        {
            handle = new LazyAssetHandle<T>(this, bundlePath, assetName, options);
            _lazyHandles[key] = handle;
        }

        return (LazyAssetHandle<T>)handle;
    }
}
