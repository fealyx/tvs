using BepInEx.Logging;

namespace Fealyx.TVSLib.Logging;

/// <summary>
/// Extension methods for BepInEx logging.
/// </summary>
public static class LoggingExtensions
{
    /// <summary>
    /// Creates a sub-logger with a namespaced name based on the parent logger.
    /// </summary>
    /// <param name="parent">The parent logger</param>
    /// <param name="name">The sub-logger name (will be appended to parent's source name)</param>
    /// <returns>A new ManualLogSource with the combined name</returns>
    /// <example>
    /// var mainLogger = Logger.CreateLogSource("MyPlugin");
    /// var subLogger = mainLogger.CreateSubLogger("Assets"); // Creates "MyPlugin.Assets"
    /// </example>
    public static ManualLogSource CreateSubLogger(this ManualLogSource parent, string name)
    {
        var fullName = $"{parent.SourceName}.{name}";
        return Logger.CreateLogSource(fullName);
    }
}
