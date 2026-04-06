using System;

using Fealyx.TVSLib.Lifecycle;

namespace Fealyx.TVSLib;


public abstract class Manager : IDisposable, IInitializable
{
    public event Action? OnDispose = null!;
    public event Action? OnInitialize = null!;

    public LifecycleState LifecycleState { get; protected set; } = LifecycleState.Uninitialized;
    public PluginManager LibraryPlugin { get; private set; } = null!;

    protected BepInEx.Logging.ManualLogSource _logger { get; private set; } = null!;

    #region Lifecycle
    public virtual void Initialize()
    {
        if (LifecycleState != LifecycleState.Uninitialized)
        {
            return;
        }

        LifecycleState = LifecycleState.Initializing;

        _logger = BepInEx.Logging.Logger.CreateLogSource($"{PluginManager.Instance.Info.Metadata.Name}.{GetType().Name}");
        _logger.LogInfo($"Initializing...");

        LibraryPlugin = PluginManager.Instance;

        OnInitialize?.Invoke();

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
            _logger?.LogInfo($"Disposing...");

            OnDispose?.Invoke();

            // Clear event handlers to prevent memory leaks
            OnDispose = null;
            OnInitialize = null;
        }

        LifecycleState = LifecycleState.Destroyed;
    }

    public void Dispose()
    {
        Dispose(disposing: true);
        GC.SuppressFinalize(this);
    }
    #endregion
}
