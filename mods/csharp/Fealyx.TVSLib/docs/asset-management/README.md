# TVSLib Asset Management System

A comprehensive, production-ready asset management system for BepInEx plugins with support for:
- **Automatic path resolution** - Just use bundle filenames, no `Path.Combine` needed!
- **Reference counting** - Shared bundles across plugins
- **Caching** - Fast repeated access to assets
- **Async loading** - Non-blocking asset loading
- **Lazy loading** - Load assets on-demand
- **Hot-reloading** - Reload assets during development
- **Per-plugin isolation** - Automatic cleanup when plugins unload

## Quick Start

The simplest possible usage:

```csharp
[BepInPlugin("com.example.myplugin", "My Plugin", "1.0.0")]
public class MyPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // That's it! Bundle path is automatically resolved to:
        // {PluginPath}/{GUID}/AssetBundles/characters.bundle
        var prefab = Assets.LoadAsset<GameObject>("characters.bundle", "Hero");

        Instantiate(prefab);
    }
}
```

No `Path.Combine`, no `FilePaths` dictionary access, no manual cleanup. Just beautiful, simple code! 🎉

## Architecture

### Components

- **`AssetsManager`** - Central manager that handles bundle loading, reference counting, and lifecycle
- **`PluginAssets`** - Per-plugin context that provides isolated access and automatic cleanup
- **`BundleReference`** - Internal class that tracks reference counts for shared bundles
- **`AssetLoadOptions`** - Configuration for loading behavior
- **`AssetLoadOperation<T>`** - Handle for async loading operations
- **`LazyAssetHandle<T>`** - Handle for lazy-loaded assets

## Basic Usage

### Loading Assets Synchronously

```csharp
[BepInPlugin("com.example.myplugin", "My Plugin", "1.0.0")]
public class MyPlugin : BaseTVSPlugin
{
    private GameObject? _myPrefab;

    public override void Initialize()
    {
        base.Initialize();

        // Simple: Just specify the bundle filename!
        // Automatically resolved to: {PluginPath}/{GUID}/AssetBundles/mybundle.bundle
        _myPrefab = Assets.LoadAsset<GameObject>("mybundle.bundle", "MyPrefab");

        // You can also use subdirectories
        _myPrefab = Assets.LoadAsset<GameObject>("characters/player.bundle", "Hero");

        // Or absolute paths if needed
        string absolutePath = Path.Combine(SomeOtherPath, "bundle.bundle");
        var asset = Assets.LoadAsset<Texture2D>(absolutePath, "Icon");

        if (_myPrefab != null)
        {
            Instantiate(_myPrefab);
        }
    }
}
```

### Loading Assets Asynchronously

```csharp
public override void Initialize()
{
    base.Initialize();

    // Simple filename - automatically resolved!
    var operation = Assets.LoadAssetAsync<Texture2D>("textures.bundle", "MyTexture");

    // Use in coroutine
    StartCoroutine(WaitForAsset(operation));
}

private IEnumerator WaitForAsset(AssetLoadOperation<Texture2D> operation)
{
    while (!operation.IsDone)
    {
        yield return null;
    }

    var texture = operation.Asset;
    if (texture != null)
    {
        // Use the texture
    }
}
```

### Lazy Loading

```csharp
public class MyPlugin : BaseTVSPlugin
{
    private LazyAssetHandle<AudioClip>? _soundEffect;

    public override void Initialize()
    {
        base.Initialize();

        // Create lazy handle (doesn't load yet) - just the bundle filename!
        _soundEffect = Assets.GetLazyAsset<AudioClip>("audio.bundle", "Explosion");
    }

    private void PlayExplosion()
    {
        // Asset loads on first access to .Value
        var clip = _soundEffect?.Value;
        if (clip != null)
        {
            AudioSource.PlayClipAtPoint(clip, transform.position);
        }
    }
}
```

## Advanced Features

### Custom Load Options

```csharp
var options = new AssetLoadOptions
{
    Cache = true,           // Cache the asset for fast re-access
    Async = false,          // Load synchronously
    Lazy = false,           // Load immediately
    Priority = 100          // High priority for async loads
};

// Just the bundle filename!
var asset = Assets.LoadAsset<Material>("materials.bundle", "MyMaterial", options);

// Or use predefined options
var asyncAsset = Assets.LoadAsset<Sprite>("ui.bundle", "Icon", AssetLoadOptions.AsyncCached);
var lazyAsset = Assets.LoadAsset<Mesh>("models.bundle", "Character", AssetLoadOptions.LazyLoaded);
```

### Hot-Reloading (Development)

```csharp
// Reload all assets for this plugin
Assets.ReloadAllAssets();

// This is useful during development when you update asset bundles
// All assets will be unloaded and reloaded from disk
```

### Manual Bundle Management

```csharp
// Explicitly unload a bundle (releases this plugin's reference)
// Just use the simple filename!
Assets.UnloadBundle("mybundle.bundle");

// The bundle is only truly unloaded when all plugins release their references
```

## Path Resolution

The asset system automatically resolves bundle paths for maximum convenience:

### Simple Filenames (Recommended)
```csharp
// Resolves to: {PluginPath}/{GUID}/AssetBundles/mybundle.bundle
Assets.LoadAsset<Sprite>("mybundle.bundle", "Icon");
```

### Relative Paths with Subdirectories
```csharp
// Resolves to: {PluginPath}/{GUID}/AssetBundles/characters/hero.bundle
Assets.LoadAsset<GameObject>("characters/hero.bundle", "Player");
```

### Absolute Paths
```csharp
// Used as-is (no resolution)
string absolutePath = "C:/CustomPath/bundle.bundle";
Assets.LoadAsset<Material>(absolutePath, "Special");

// Or using the FilePaths dictionary when you need it
string customPath = Path.Combine(FilePaths["Assets"], "custom.bundle");
Assets.LoadAsset<Texture2D>(customPath, "Logo");
```

### How It Works
1. **If the path is absolute** (starts with drive letter or `/`) → Used as-is
2. **Otherwise** → Resolved relative to `FilePaths["AssetBundles"]`

This means you typically **never** need to use `Path.Combine` or reference `FilePaths` manually for bundles!

### Shared Asset Contexts

```csharp
// Create a shared context that multiple plugins can access
var sharedContext = TVS.Assets.CreateSharedContext("CommonAssets");

// In another plugin
var commonAssets = TVS.Assets.GetSharedContext("CommonAssets");
```

### Monitoring

```csharp
// Check how many assets are loaded by this plugin
Logger.LogInfo($"Loaded assets: {Assets.LoadedAssetCount}");
Logger.LogInfo($"Referenced bundles: {Assets.ReferencedBundleCount}");

// Get global bundle information from the manager
foreach (var (path, refCount) in TVS.Assets.GetLoadedBundleInfo())
{
    Logger.LogInfo($"Bundle: {path}, References: {refCount}");
}
```

## Automatic Cleanup

When your plugin is disposed (or unloaded), all assets are automatically cleaned up:

```csharp
protected override void Dispose(bool disposing)
{
    if (disposing)
    {
        // Assets.Dispose() is called automatically by BaseTVSPlugin
        // You don't need to manually unload anything!
    }

    base.Dispose(disposing);
}
```

## Reference Counting Example

```csharp
// Plugin A loads a bundle
var assetA = pluginA.Assets.LoadAsset<Sprite>(bundlePath, "Icon");
// Bundle reference count: 1

// Plugin B loads from the same bundle
var assetB = pluginB.Assets.LoadAsset<Sprite>(bundlePath, "Icon");
// Bundle reference count: 2 (bundle is shared)

// Plugin A unloads
pluginA.Assets.UnloadBundle(bundlePath);
// Bundle reference count: 1 (bundle still loaded for Plugin B)

// Plugin B unloads
pluginB.Assets.UnloadBundle(bundlePath);
// Bundle reference count: 0 (bundle is now unloaded from memory)
```

## Best Practices

### 1. Use the Right Loading Method

- **Synchronous** (`LoadAsset`) - Small assets, initialization code
- **Asynchronous** (`LoadAssetAsync`) - Large assets, avoid frame drops
- **Lazy** (`GetLazyAsset`) - Assets that may not be used every session

### 2. Enable Caching for Repeated Access

```csharp
// Good: Cache assets you'll access multiple times
var options = new AssetLoadOptions { Cache = true };
var material = Assets.LoadAsset<Material>(bundlePath, "Shared", options);
```

### 3. Organize Bundles by Plugin

```csharp
// Structure your asset bundles in plugin-specific folders
FilePaths["AssetBundles"] = Path.Combine(Paths.PluginPath, Info.Metadata.GUID, "AssetBundles");
```

### 4. Don't Mix Manual and Automatic Cleanup

```csharp
// ❌ Bad: Manual cleanup when using PluginAssets
Resources.UnloadAsset(myAsset);  // Don't do this

// ✅ Good: Let PluginAssets handle it
// Just dispose the plugin or unload the bundle
Assets.UnloadBundle(bundlePath);
```

### 5. Use Lazy Loading for Optional Content

```csharp
// Assets that players might not use
private LazyAssetHandle<AudioClip>? _rareSound;
private LazyAssetHandle<GameObject>? _debugVisualization;

// Only loaded if/when accessed
```

## Memory Management

### Unity Assets are Unmanaged Resources

Unity assets (textures, meshes, audio clips from bundles) are backed by native memory and must be explicitly unloaded:

```csharp
// The system handles this automatically in Dispose:
// 1. Unload all tracked assets via Resources.UnloadAsset()
// 2. Release bundle references
// 3. When ref count hits 0, unload the bundle with bundle.Unload(true)
```

### When Assets Are Unloaded

1. **Plugin disposal** - All assets tracked by that plugin's `PluginAssets` instance
2. **Manual bundle unload** - When you call `Assets.UnloadBundle()`
3. **Manager disposal** - When `AssetsManager` is disposed (on plugin shutdown)
4. **Hot-reload** - When you call `Assets.ReloadAllAssets()`

## Troubleshooting

### Asset Not Loading

```csharp
// Check if the bundle loaded
var bundle = AssetBundle.LoadFromFile(bundlePath);
Logger.LogInfo($"Bundle loaded: {bundle != null}");

// Check if the asset exists in the bundle
if (bundle != null)
{
    var allAssets = bundle.LoadAllAssets();
    Logger.LogInfo($"Bundle contains {allAssets.Length} assets");
}
```

### Memory Leaks

```csharp
// Check for leaked references
Logger.LogInfo($"Total bundles loaded: {TVS.Assets.LoadedBundleCount}");
foreach (var (path, refCount) in TVS.Assets.GetLoadedBundleInfo())
{
    Logger.LogInfo($"{path}: {refCount} refs");
}
```

### Performance Issues

```csharp
// Use async loading for large assets
var operation = Assets.LoadAssetAsync<Texture2D>(path, name, new AssetLoadOptions
{
    Async = true,
    Priority = 50,  // Lower priority to avoid frame drops
    Cache = true
});
```

## Migration Guide

If you're updating from the old direct `AssetsManager` usage:

### Before (Old)
```csharp
var asset = TVS.Assets.LoadAsset<Sprite>(bundlePath, "Icon");
```

### After (New)
```csharp
// Now scoped to the plugin, with automatic cleanup AND automatic path resolution!
var asset = Assets.LoadAsset<Sprite>("mybundle.bundle", "Icon");

// That's it! No Path.Combine, no FilePaths dictionary access needed!
```

The key improvements:
1. `Assets` is now a `PluginAssets` instance specific to your plugin
2. Better isolation and automatic cleanup
3. **Automatic path resolution** - just use simple filenames!
