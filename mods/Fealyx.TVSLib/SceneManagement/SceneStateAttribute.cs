using System;

namespace Fealyx.TVSLib.SceneManagement;

/// <summary>
/// Attribute for declaratively marking SceneState classes and specifying their properties.
/// When applied, the SceneState can be auto-discovered via RegisterAllStates().
/// </summary>
[AttributeUsage(AttributeTargets.Class, AllowMultiple = false, Inherited = false)]
public class SceneStateAttribute : Attribute
{
    /// <summary>
    /// The name of the scene this state manages (e.g., "MainMenu", "MainScene")
    /// </summary>
    public string SceneName { get; }

    /// <summary>
    /// Execution priority. Higher values execute first. Default: 0
    /// </summary>
    public int Priority { get; set; } = 0;

    /// <summary>
    /// Creates a new SceneState attribute for the specified scene.
    /// </summary>
    /// <param name="sceneName">The Unity scene name this state handles</param>
    public SceneStateAttribute(string sceneName)
    {
        SceneName = sceneName ?? throw new ArgumentNullException(nameof(sceneName));
    }
}
