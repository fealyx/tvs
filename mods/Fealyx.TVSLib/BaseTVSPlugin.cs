using System;
using System.Collections.Generic;
using System.IO;

using BepInEx;
using BepInEx.Logging;

using Fealyx.TVSLib.AssetManagement;
using Fealyx.TVSLib.Lifecycle;
using Fealyx.TVSLib.SceneManagement;

namespace Fealyx.TVSLib;

#pragma warning disable BepInEx001 // Class inheriting from BaseUnityPlugin missing BepInPlugin attribute. Attribute should be added to the consuming class.
public abstract class BaseTVSPlugin : BepInEx.BaseUnityPlugin, IInitializable, IDisposable
#pragma warning restore BepInEx001
{
    public LifecycleState LifecycleState { get; private set; } = LifecycleState.Uninitialized;

    /// <summary>
    /// Asset management context for this plugin. Automatically cleans up all loaded assets when the plugin is disposed.
    /// </summary>
    public PluginAssets Assets { get; private set; } = null!;

    /// <summary>
    /// Scene state management context for this plugin. Provides structured scene lifecycle management.
    /// </summary>
    public PluginScenes Scenes { get; private set; } = null!;

    public Dictionary<string, string> FilePaths = new Dictionary<string, string>
    {
        { "AssetBundles", "" },
        { "Assets", "" },
        { "Root", "" }
    };

    protected PluginManager TVS => PluginManager.Instance;

    public BaseTVSPlugin() : base()
    {
        LifecycleState = LifecycleState.Initializing;

        string rootPath = Path.Combine(Paths.PluginPath, Info.Metadata.GUID);

        FilePaths["AssetBundles"] = Path.Combine(rootPath, "AssetBundles");
        FilePaths["Assets"] = Path.Combine(rootPath, "Assets");
        FilePaths["Root"] = rootPath;

        TVS.RegisterPlugin(this);
        Assets = TVS.Assets.CreateContext(this);
        Scenes = TVS.Scenes.CreateContext(this);
    }

    public ManualLogSource CreateSubLogger(string sourceName)
    {
        return BepInEx.Logging.Logger.CreateLogSource($"{Info.Metadata.Name}.{sourceName}");
    }

    #region Lifecycle
    public virtual void Initialize()
    {
        if (LifecycleState != LifecycleState.Initializing)
        {
            return;
        }

        LifecycleState = LifecycleState.Initialized;
    }

    protected virtual void Dispose(bool disposing)
    {
        if (LifecycleState == LifecycleState.Destroyed || LifecycleState == LifecycleState.Destroying)
        {
            return;
        }

        LifecycleState = LifecycleState.Destroying;

        if (disposing)
        {
            Logger.LogInfo($"Disposing plugin: {Info.Metadata.Name}...");

            // Dispose the asset context to clean up all loaded assets
            Assets?.Dispose();

            // Dispose the scene context to clean up all scene states
            Scenes?.Dispose();

            // Cleanup managed resources here in derived classes
        }

        // Cleanup unmanaged resources here in derived classes (if any)

        LifecycleState = LifecycleState.Destroyed;
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }
    #endregion
}
