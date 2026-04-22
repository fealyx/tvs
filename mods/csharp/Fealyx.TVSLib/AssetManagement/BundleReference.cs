using System.Collections.Generic;
using UnityEngine;

namespace Fealyx.TVSLib.AssetManagement;

/// <summary>
/// Tracks reference count for an AssetBundle to enable sharing between plugins.
/// </summary>
internal class BundleReference
{
    public AssetBundle Bundle { get; }
    public string Path { get; }
    public int ReferenceCount => _references.Count;

    private readonly HashSet<PluginAssets> _references = new();
    private readonly Dictionary<string, UnityEngine.Object> _cachedAssets = new();

    public BundleReference(AssetBundle bundle, string path)
    {
        Bundle = bundle;
        Path = path;
    }

    public void AddReference(PluginAssets controller)
    {
        _references.Add(controller);
    }

    public void RemoveReference(PluginAssets controller)
    {
        _references.Remove(controller);
    }

    public T? GetCachedAsset<T>(string assetName) where T : UnityEngine.Object
    {
        if (_cachedAssets.TryGetValue(assetName, out var asset))
        {
            return asset as T;
        }
        return null;
    }

    public void CacheAsset(string assetName, UnityEngine.Object asset)
    {
        _cachedAssets[assetName] = asset;
    }

    public void ClearCache()
    {
        foreach (var asset in _cachedAssets.Values)
        {
            if (asset != null)
            {
                Resources.UnloadAsset(asset);
            }
        }
        _cachedAssets.Clear();
    }

    public void Unload(bool unloadAllLoadedObjects)
    {
        ClearCache();
        Bundle?.Unload(unloadAllLoadedObjects);
    }
}
