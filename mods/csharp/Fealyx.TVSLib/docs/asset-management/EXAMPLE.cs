using System.Collections;
using System.IO;
using BepInEx;
using UnityEngine;
using Fealyx.TVSLib;
using Fealyx.TVSLib.AssetManagement;

namespace Examples;

/// <summary>
/// Example plugin demonstrating the TVSLib asset management system.
/// </summary>
[BepInPlugin("com.example.assetdemo", "Asset Management Demo", "1.0.0")]
public class AssetManagementExample : BaseTVSPlugin
{
    // Synchronously loaded assets
    private GameObject? _playerPrefab;
    private Material? _glowMaterial;

    // Lazy-loaded assets (loaded on first access)
    private LazyAssetHandle<AudioClip>? _explosionSound;
    private LazyAssetHandle<Sprite>? _rareBadge;

    public override void Initialize()
    {
        base.Initialize();

        Logger.LogInfo("=== Asset Management Demo ===");

        // Example 1: Basic synchronous loading
        LoadBasicAssets();

        // Example 2: Async loading
        StartCoroutine(LoadAssetsAsync());

        // Example 3: Lazy loading setup
        SetupLazyAssets();

        // Example 4: Custom load options
        LoadWithCustomOptions();

        // Example 5: Monitoring
        MonitorAssetStatus();
    }

    private void LoadBasicAssets()
    {
        Logger.LogInfo("--- Basic Synchronous Loading ---");

        // Simple! Just specify the bundle filename
        // Automatically resolved to: {PluginPath}/{GUID}/AssetBundles/characters.bundle
        _playerPrefab = Assets.LoadAsset<GameObject>("characters.bundle", "PlayerCharacter");

        if (_playerPrefab != null)
        {
            Logger.LogInfo($"Loaded player prefab: {_playerPrefab.name}");

            // You can now instantiate it
            // var instance = Instantiate(_playerPrefab);
        }
    }

    private IEnumerator LoadAssetsAsync()
    {
        Logger.LogInfo("--- Asynchronous Loading ---");

        // No need for Path.Combine anymore!
        var operation = Assets.LoadAssetAsync<Material>("materials.bundle", "GlowMaterial");

        Logger.LogInfo("Async load started...");

        // Wait for completion
        while (!operation.IsDone)
        {
            yield return null;
        }

        _glowMaterial = operation.Asset;

        if (_glowMaterial != null)
        {
            Logger.LogInfo($"Async loaded material: {_glowMaterial.name}");
        }
    }

    private void SetupLazyAssets()
    {
        Logger.LogInfo("--- Lazy Loading Setup ---");

        // These assets are NOT loaded yet, just creating handles
        // Super clean - just bundle filenames!
        _explosionSound = Assets.GetLazyAsset<AudioClip>("sounds.bundle", "Explosion");
        _rareBadge = Assets.GetLazyAsset<Sprite>("ui.bundle", "LegendaryBadge");

        Logger.LogInfo("Lazy handles created (assets not loaded yet)");
        Logger.LogInfo($"Explosion sound loaded: {_explosionSound.IsLoaded}");
        Logger.LogInfo($"Badge loaded: {_rareBadge.IsLoaded}");
    }

    private void LoadWithCustomOptions()
    {
        Logger.LogInfo("--- Custom Load Options ---");

        // High-priority async loading with caching
        var options = new AssetLoadOptions
        {
            Async = true,
            Cache = true,
            Priority = 100  // High priority
        };

        var operation = Assets.LoadAssetAsync<Texture2D>("textures.bundle", "Logo", options);

        Logger.LogInfo("Started high-priority async load");

        // Or use predefined options
        var sprite = Assets.LoadAsset<Sprite>("textures.bundle", "Icon", AssetLoadOptions.Cached);
        Logger.LogInfo($"Loaded with cached option: {sprite?.name}");
    }

    private void MonitorAssetStatus()
    {
        Logger.LogInfo("--- Asset Monitoring ---");
        Logger.LogInfo($"Assets loaded by this plugin: {Assets.LoadedAssetCount}");
        Logger.LogInfo($"Bundles referenced by this plugin: {Assets.ReferencedBundleCount}");

        Logger.LogInfo("--- Global Bundle Status ---");
        foreach (var (path, refCount) in TVS.Assets.GetLoadedBundleInfo())
        {
            Logger.LogInfo($"  {Path.GetFileName(path)}: {refCount} reference(s)");
        }
    }

    // Example: Using lazy-loaded asset when needed
    private void PlayExplosionSound()
    {
        // Asset loads on first access to .Value
        var clip = _explosionSound?.Value;

        if (clip != null)
        {
            Logger.LogInfo($"Playing explosion sound: {clip.name}");
            // AudioSource.PlayClipAtPoint(clip, transform.position);
        }

        // Check if it's loaded now
        Logger.LogInfo($"Explosion sound is now loaded: {_explosionSound?.IsLoaded}");
    }

    // Example: Hot-reloading during development
    private void ReloadAssets()
    {
        Logger.LogInfo("--- Hot Reloading Assets ---");
        Assets.ReloadAllAssets();
        Logger.LogInfo("All assets reloaded!");
    }

    // Example: Manual bundle management
    private void UnloadSpecificBundle()
    {
        // Simple!
        Assets.UnloadBundle("characters.bundle");
        Logger.LogInfo("Released reference to characters.bundle");

        // The bundle is only truly unloaded when all plugins release their references
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            Logger.LogInfo("=== Disposing Asset Demo ===");
            Logger.LogInfo("Assets will be automatically cleaned up by BaseTVSPlugin");

            // You don't need to manually unload anything!
            // Assets.Dispose() is called automatically
        }

        base.Dispose(disposing);
    }
}
