namespace Fealyx.TVSLib.AssetManagement;

/// <summary>
/// Configuration options for asset loading behavior.
/// </summary>
public class AssetLoadOptions
{
    /// <summary>
    /// Whether to cache the loaded asset for faster subsequent access.
    /// Default: true
    /// </summary>
    public bool Cache { get; set; } = true;

    /// <summary>
    /// Whether to load the asset asynchronously.
    /// Default: false
    /// </summary>
    public bool Async { get; set; } = false;

    /// <summary>
    /// Whether to defer loading until first access (lazy loading).
    /// Default: false
    /// </summary>
    public bool Lazy { get; set; } = false;

    /// <summary>
    /// Priority for async loading operations (0-100, higher = more priority).
    /// Default: 50
    /// </summary>
    public int Priority { get; set; } = 50;

    public static AssetLoadOptions Default => new();
    public static AssetLoadOptions Cached => new() { Cache = true };
    public static AssetLoadOptions AsyncCached => new() { Cache = true, Async = true };
    public static AssetLoadOptions LazyLoaded => new() { Lazy = true, Cache = true };
}
