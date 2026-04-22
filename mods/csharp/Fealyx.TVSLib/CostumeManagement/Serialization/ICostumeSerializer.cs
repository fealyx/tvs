namespace Fealyx.TVSLib.CostumeManagement.Serialization;

/// <summary>
/// Interface for costume definition serializers.
/// </summary>
public interface ICostumeSerializer
{
    /// <summary>
    /// Deserializes a costume item from a file.
    /// </summary>
    /// <param name="filePath">Path to the costume definition file</param>
    /// <returns>Deserialized costume item, or null if failed</returns>
    CostumeItem? Deserialize(string filePath);

    /// <summary>
    /// Serializes a costume item to a file.
    /// </summary>
    /// <param name="costume">Costume item to serialize</param>
    /// <param name="filePath">Path where the file should be written</param>
    /// <returns>True if successful, false otherwise</returns>
    bool Serialize(CostumeItem costume, string filePath);

    /// <summary>
    /// Gets the file extensions supported by this serializer (e.g., ".json", ".yaml").
    /// </summary>
    string[] SupportedExtensions { get; }
}
