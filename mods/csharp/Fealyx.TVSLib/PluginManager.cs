using System;
using System.Collections.Generic;
using BepInEx;
using BepInEx.Logging;

using Fealyx.TVSLib.AssetManagement;
using Fealyx.TVSLib.CostumeManagement;
using Fealyx.TVSLib.Lifecycle;
using Fealyx.TVSLib.SceneManagement;


namespace Fealyx.TVSLib;

[BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
public sealed partial class PluginManager : BaseUnityPlugin, IDisposable
{
    public static PluginManager Instance { get; private set; } = null!;

    public new Configuration.Configuration Config;

    public AssetsManager Assets { get; } = new AssetsManager();
    public SceneManager Scenes { get; } = new SceneManager();
    public CostumeManager Costumes { get; } = new CostumeManager();

    public new ManualLogSource Logger { get; }

    private LifecycleState _lifecycleState = LifecycleState.Uninitialized;
    private List<Manager> _managers { get; }
    private List<BaseTVSPlugin> _plugins { get; } = new List<BaseTVSPlugin>();


    public PluginManager() : base()
    {
        Config = new Configuration.Configuration(base.Config)
        {
            Features.DevToolsFeatures.CreateGroup(this)
        };

        _managers = new List<Manager>
        {
            Assets,
            Scenes,
            Costumes
        };

        Logger = BepInEx.Logging.Logger.CreateLogSource(MyPluginInfo.PLUGIN_GUID);

        if (Instance != null)
        {
            Instance.Logger.LogWarning($"PluginManager instance already exists. Secondary instance self-destructing.");
            DestroyImmediate(this);
            return;
        }

        Instance = this;
        _lifecycleState = LifecycleState.Initializing;
    }

    public ManualLogSource CreateSubLogger(string name)
    {
        return BepInEx.Logging.Logger.CreateLogSource($"{MyPluginInfo.PLUGIN_GUID}.{name}");
    }

    public void RegisterPlugin(BaseTVSPlugin plugin)
    {
        if (_plugins.Contains(plugin))
        {
            Logger.LogWarning($"Plugin {plugin.GetType().Name} is already registered.");
            return;
        }
        _plugins.Add(plugin);
        Logger.LogInfo($"Registered plugin: {plugin.GetType().Name}");

        if (_lifecycleState == LifecycleState.Initialized)
        {
            plugin.Initialize();
            Logger.LogInfo($"Initialized plugin: {plugin.GetType().Name}");
        }
    }

    #region Unity Messages
    #pragma warning disable IDE0051 // Surpress "unused private members" for Unity Message methods.
    private void Awake()
    {
        Logger.LogInfo($"Initializing {MyPluginInfo.PLUGIN_NAME} v{MyPluginInfo.PLUGIN_VERSION}...");

        // Initialize managers
        foreach (var manager in _managers)
        {
            var managerLogger = BepInEx.Logging.Logger.CreateLogSource($"{Info.Metadata.Name}.{manager.GetType().Name}");
            manager.Initialize();
        }

        RegisterSceneContexts(); // Register scene contexts
        RegisterFrameworkStates(); // Register framework scene states

        Config.Initialize();

        // Initialize registered plugins
        foreach (var plugin in _plugins) {
            plugin.Initialize();
            Logger.LogInfo($"Initialized plugin: {plugin.GetType().Name}");
        }

        Logger.LogInfo($"{MyPluginInfo.PLUGIN_NAME} v{MyPluginInfo.PLUGIN_VERSION} initialized.");
        _lifecycleState = LifecycleState.Initialized;
    }

    /// <summary>
    /// Registers scene context types that will be automatically initialized when their scenes load.
    /// </summary>
    private void RegisterSceneContexts()
    {
        // Register MainScene context
        Scenes.RegisterContext<Scenes.MainScene.MainSceneContext>("MainScene");

        // TODO: Add other scene contexts as they're implemented
        // Scenes.RegisterContext<MenuSceneContext>("MainMenu");
        // Scenes.RegisterContext<CharacterCreatorContext>("CharacterCreator");
    }

    /// <summary>
    /// Registers framework scene states (internal systems not owned by plugins).
    /// </summary>
    private void RegisterFrameworkStates()
    {
        // Register costume loading for CharacterCreator scene
        Scenes.RegisterFrameworkState(new CostumeManagement.SceneStates.CharacterCreatorCostumeLoader());

        // TODO: Add other framework states as they're implemented

        Logger.LogInfo("Framework scene states registered");
    }

    private void OnDestroy()
    {
        Dispose();
    }

    private void Start()
    {
        Logger.LogInfo($"{MyPluginInfo.PLUGIN_NAME} v{MyPluginInfo.PLUGIN_VERSION} started.");
    }
    #pragma warning restore IDE0051
    #endregion

    #region Lifecycle
    private void Dispose(bool disposing)
    {
        if (_lifecycleState == LifecycleState.Destroyed || _lifecycleState == LifecycleState.Destroying)
        {
            if (_lifecycleState == LifecycleState.Destroying)
            {
                Logger.LogWarning($"PluginManager is already being destroyed. Ignoring dispose call.");
            }
            return;
        }

        if (_lifecycleState == LifecycleState.Uninitialized || _lifecycleState == LifecycleState.Initializing)
        {
            _lifecycleState = LifecycleState.Destroyed;
            Instance = null!;
            return;
        }

        _lifecycleState = LifecycleState.Destroying;

        string reason = disposing ? "Manual disposal" : "GC";
        Logger.LogInfo($"Destroying {MyPluginInfo.PLUGIN_NAME} (reason: {reason})...");

        if (disposing)
        {
            foreach (var plugin in _plugins)
            {
                plugin.Dispose();
            }

            foreach (var manager in _managers)
            {
                manager.Dispose();
            }
        }

        Instance = null!;

        Logger.LogInfo($"{MyPluginInfo.PLUGIN_NAME} destroyed.");
        _lifecycleState = LifecycleState.Destroyed;
    }

    public void Dispose()
    {
        // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }

    ~PluginManager()
    {
        // Do not change this code. Put cleanup code in 'Dispose(bool disposing)' method
        Dispose(disposing: false);
    }
    #endregion
}
