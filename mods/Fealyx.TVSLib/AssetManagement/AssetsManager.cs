using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Fealyx.TVSLib.AssetManagement;

/// <summary>
/// Central asset management system that handles AssetBundle loading, reference counting, 
/// caching, and lifecycle management. Provides PluginAssets contexts for per-plugin isolation.
/// </summary>
public class AssetsManager : Manager
{
    private readonly Dictionary<string, BundleReference> _loadedBundles = new();
    private readonly Dictionary<string, AssetsManager> _namedContexts = new();

    /// <summary>
    /// Creates a new PluginAssets context for the specified plugin.
    /// </summary>
    public PluginAssets CreateContext(BaseTVSPlugin plugin)
    {
        return new PluginAssets(this, plugin);
    }

    /// <summary>
    /// Creates or retrieves a named shared context that multiple plugins can access.
    /// </summary>
    public AssetsManager CreateSharedContext(string contextName)
    {
        if (!_namedContexts.TryGetValue(contextName, out var context))
        {
            context = new AssetsManager();
            context.Initialize();
            _namedContexts[contextName] = context;
            _logger.LogInfo($"Created shared asset context: {contextName}");
        }
        return context;
    }

    /// <summary>
    /// Gets a named shared context if it exists.
    /// </summary>
    public AssetsManager? GetSharedContext(string contextName)
    {
        return _namedContexts.TryGetValue(contextName, out var context) ? context : null;
    }

    /// <summary>
    /// Gets the total number of bundles currently loaded.
    /// </summary>
    public int LoadedBundleCount => _loadedBundles.Count;

    /// <summary>
    /// Gets information about all loaded bundles.
    /// </summary>
    public IEnumerable<(string path, int refCount)> GetLoadedBundleInfo()
    {
        return _loadedBundles.Select(kvp => (kvp.Key, kvp.Value.ReferenceCount));
    }

    internal AssetBundle? LoadBundle(PluginAssets controller, string bundlePath)
    {
        if (!_loadedBundles.TryGetValue(bundlePath, out var bundleRef))
        {
            var bundle = AssetBundle.LoadFromFile(bundlePath);
            if (bundle == null)
            {
                _logger.LogError($"Failed to load AssetBundle: {bundlePath}");
                return null;
            }

            bundleRef = new BundleReference(bundle, bundlePath);
            _loadedBundles[bundlePath] = bundleRef;
            _logger.LogInfo($"Loaded AssetBundle: {bundlePath}");
        }

        bundleRef.AddReference(controller);
        return bundleRef.Bundle;
    }

    internal void ReleaseBundle(PluginAssets controller, string bundlePath, bool unloadAllLoadedObjects)
    {
        if (!_loadedBundles.TryGetValue(bundlePath, out var bundleRef))
        {
            return;
        }

        bundleRef.RemoveReference(controller);

        if (bundleRef.ReferenceCount == 0)
        {
            bundleRef.Unload(unloadAllLoadedObjects);
            _loadedBundles.Remove(bundlePath);
            _logger.LogInfo($"Unloaded AssetBundle: {bundlePath} (ref count reached 0)");
        }
        else
        {
            _logger.LogInfo($"Released bundle reference: {bundlePath} (ref count: {bundleRef.ReferenceCount})");
        }
    }

    internal void ReloadBundle(PluginAssets controller, string bundlePath)
    {
        if (!_loadedBundles.TryGetValue(bundlePath, out var bundleRef))
        {
            _logger.LogWarning($"Cannot reload bundle that isn't loaded: {bundlePath}");
            return;
        }

        _logger.LogInfo($"Reloading bundle: {bundlePath}");

        // Unload the old bundle
        bundleRef.Unload(true);

        // Load the new bundle
        var newBundle = AssetBundle.LoadFromFile(bundlePath);
        if (newBundle == null)
        {
            _logger.LogError($"Failed to reload AssetBundle: {bundlePath}");
            _loadedBundles.Remove(bundlePath);
            return;
        }

        var newBundleRef = new BundleReference(newBundle, bundlePath);
        newBundleRef.AddReference(controller);
        _loadedBundles[bundlePath] = newBundleRef;

        _logger.LogInfo($"Successfully reloaded bundle: {bundlePath}");
    }

    internal T? GetCachedAsset<T>(string bundlePath, string assetName) where T : UnityEngine.Object
    {
        if (_loadedBundles.TryGetValue(bundlePath, out var bundleRef))
        {
            return bundleRef.GetCachedAsset<T>(assetName);
        }
        return null;
    }

    internal void CacheAsset(string bundlePath, string assetName, UnityEngine.Object asset)
    {
        if (_loadedBundles.TryGetValue(bundlePath, out var bundleRef))
        {
            bundleRef.CacheAsset(assetName, asset);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (LifecycleState == Lifecycle.LifecycleState.Destroyed || LifecycleState == Lifecycle.LifecycleState.Destroying)
        {
            return;
        }

        LifecycleState = Lifecycle.LifecycleState.Destroying;

        if (disposing)
        {
            _logger?.LogInfo($"Unloading {_loadedBundles.Count} bundles...");

            // Dispose all shared contexts
            foreach (var context in _namedContexts.Values)
            {
                context.Dispose();
            }
            _namedContexts.Clear();
        }

        // CRITICAL: Unload Unity native resources regardless of disposing parameter
        // These are backed by native memory and must be cleaned up
        foreach (var bundleRef in _loadedBundles.Values)
        {
            bundleRef.Unload(true);
        }
        _loadedBundles.Clear();

        base.Dispose(disposing);

        LifecycleState = Lifecycle.LifecycleState.Destroyed;
    }
}
