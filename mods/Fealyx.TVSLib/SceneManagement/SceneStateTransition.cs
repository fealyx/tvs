namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Represents the current transition state of a SceneState instance.
/// </summary>
public enum SceneStateTransition
{
    /// <summary>
    /// State is being initialized (OnEnter will be called)
    /// </summary>
    Entering,

    /// <summary>
    /// State is fully active and receiving updates
    /// </summary>
    Active,

    /// <summary>
    /// State is paused (updates suspended, but not exited)
    /// </summary>
    Paused,

    /// <summary>
    /// State is being cleaned up (OnExit will be called)
    /// </summary>
    Exiting,

    /// <summary>
    /// State has been fully cleaned up
    /// </summary>
    Exited
}
