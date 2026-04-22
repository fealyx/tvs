using System;
using System.IO;

using Newtonsoft.Json;
using Newtonsoft.Json.Serialization;

namespace Fealyx.TVSLib.CostumeManagement.Serialization;

/// <summary>
/// JSON serializer for costume items.
/// </summary>
public class JsonCostumeSerializer : ICostumeSerializer
{
    private static readonly JsonSerializerSettings _settings = new()
    {
        ContractResolver = new CamelCasePropertyNamesContractResolver(),
        Formatting = Formatting.Indented,
        NullValueHandling = NullValueHandling.Ignore
    };

    public string[] SupportedExtensions => new[] { ".json" }; // TODO: jsonc or json5 support would be nice.

    public CostumeItem? Deserialize(string filePath)
    {
        try
        {
            if (!File.Exists(filePath))
            {
                return null;
            }

            var json = File.ReadAllText(filePath);
            return JsonConvert.DeserializeObject<CostumeItem>(json, _settings);
        }
        catch (Exception)
        {
            return null;
        }
    }

    public bool Serialize(CostumeItem costume, string filePath)
    {
        try
        {
            var directory = Path.GetDirectoryName(filePath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
            {
                Directory.CreateDirectory(directory);
            }

            var json = JsonConvert.SerializeObject(costume, _settings);
            File.WriteAllText(filePath, json);
            return true;
        }
        catch (Exception)
        {
            return false;
        }
    }
}
