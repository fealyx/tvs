# Costume Serialization Guide

## Quick Start

### 1. Create a Costume Definition File

Create a JSON file in your plugin's directory (e.g., `costumes/my-costume.json`):

```json
{
  "$schema": "../../../schemas/costume-definition.schema.json",
  "name": "My Custom Hair",
  "description": "A cool new hairstyle",
  "category": "hair",
  "assetBundle": "mycostumes",
  "prefabPath": "assets/@myplugin/my-hair.fbx",
  "iconPath": "assets/@myplugin/my-hair-icon.png",
  "defaultColor": [0.2, 0.1, 0.05, 1],
  "additionalCostumeData": {
    "_helmetHairBlendName": "HideA",
    "_helmetHairBlendshapeAmount": 100.0
  }
}
```

### 2. Load in Your Plugin

```csharp
public class MyPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // Load all costumes from the costumes directory
        Costumes.LoadFromDirectory("costumes/");

        Scenes.RegisterAllStates();
    }
}
```

That's it! Your costumes will automatically appear in the character creator.

## Property Reference

### Required Fields

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| `name` | string | Display name | `"Toulouse Hair"` |
| `category` | string | Costume category | `"hair"`, `"hat"`, `"glasses"` |
| `assetBundle` | string | Bundle name | `"hair"` |
| `prefabPath` | string | Path to prefab | `"assets/@hairtest/hair.fbx"` |

### Optional Fields

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `description` | string | `""` | Costume description |
| `iconPath` | string | - | Path to icon sprite |
| `defaultColor` | array | `[1,1,1,1]` | RGBA color (0.0-1.0) |
| `metadata` | object | `{}` | Custom metadata |
| `additionalCostumeData` | object | `{}` | ZNE-specific data |

## Costume Categories

Valid `category` values:
- `hair`
- `hat`
- `glasses`
- `mask`
- `earrings`
- `top`
- `bottom`
- `shoes`
- `gloves`
- `accessories`

## Asset Bundle Setup

1. **Bundle Name**: Referenced in `assetBundle` property
   - Must match bundle loaded via `Assets.LoadBundle()`
   - Resolved relative to plugin's `AssetBundles/` directory

2. **Asset Paths**: Referenced in `prefabPath` and `iconPath`
   - Paths within the asset bundle
   - Example: `"assets/@myplugin/my-asset.fbx"`

## Colors

Colors are RGBA arrays with values from 0.0 to 1.0:

```json
{
  "defaultColor": [
    0.0,  // Red (0.0 = none, 1.0 = full)
    0.0,  // Green
    0.0,  // Blue
    1.0   // Alpha (transparency: 0.0 = transparent, 1.0 = opaque)
  ]
}
```

Common colors:
- Black: `[0, 0, 0, 1]`
- White: `[1, 1, 1, 1]`
- Red: `[1, 0, 0, 1]`
- Brown: `[0.4, 0.2, 0.1, 1]`

## Additional Costume Data

Used for game-specific features:

```json
{
  "additionalCostumeData": {
    "_helmetHairBlendName": "HideA",
    "_helmetHairBlendshapeAmount": 100.0
  }
}
```

### Helmet Hair Blending

For hair costumes, this controls how the hair reacts when wearing a helmet:

- `_helmetHairBlendName`: Name of the blendshape to activate
- `_helmetHairBlendshapeAmount`: Amount to blend (0-100)

## Loading Methods

### Load Single File

```csharp
// Load specific JSON file
Costumes.LoadFromJson("costumes/hair.json");

// Load specific YAML file (when YAML support is added)
Costumes.LoadFromYaml("costumes/hair.yaml");

// Auto-detect format by extension
Costumes.LoadFromFile("costumes/hair.json");
```

### Load Directory

```csharp
// Load all costume files from directory
Costumes.LoadFromDirectory("costumes/");

// Load with custom search pattern
Costumes.LoadFromDirectory("costumes/", "*.costume.json");

// Load recursively
Costumes.LoadFromDirectory("costumes/", "*.*", recursive: true);
```

## Custom Serializers

You can add support for custom formats:

```csharp
public class YamlCostumeSerializer : ICostumeSerializer
{
    public string[] SupportedExtensions => new[] { ".yaml", ".yml" };

    public CostumeItem? Deserialize(string filePath)
    {
        // Your YAML deserialization logic
    }

    public bool Serialize(CostumeItem costume, string filePath)
    {
        // Your YAML serialization logic
    }
}

// Register in your plugin
public override void Initialize()
{
    base.Initialize();

    Costumes.RegisterSerializer(new YamlCostumeSerializer());
    Costumes.LoadFromDirectory("costumes/");
}
```

## JSON Schema Support

The schema provides:
- **Auto-completion** in VS Code and other IDEs
- **Validation** of your costume files
- **Documentation** via hover tooltips

To enable, include the schema reference at the top of your JSON file:

```json
{
  "$schema": "../../../schemas/costume-definition.schema.json",
  ...
}
```

The path should point to the `schemas/costume-definition.schema.json` file in the solution root.

## Troubleshooting

### Costume doesn't appear in game
1. Check that bundle is loaded: `Assets.LoadBundle("bundlename")`
2. Verify asset paths in the JSON match bundle contents
3. Check logs for loading errors
4. Ensure category matches a valid costume category

### Icon doesn't show
1. Verify `iconPath` is correct
2. Check that icon asset is included in the bundle
3. Ensure icon is a `Sprite` asset, not just a `Texture2D`

### Colors look wrong
1. Remember RGB values are 0.0-1.0, not 0-255
2. Check alpha channel (4th value) is 1.0 for opaque

## Example: Complete Hair Costume

```json
{
  "$schema": "../../../schemas/costume-definition.schema.json",
  "name": "Viking Braids",
  "description": "Traditional Viking braided hairstyle",
  "category": "hair",
  "assetBundle": "hairstyles",
  "prefabPath": "assets/@myplugin/viking-braids.fbx",
  "iconPath": "assets/@myplugin/icons/viking-braids.png",
  "defaultColor": [0.4, 0.3, 0.2, 1],
  "metadata": {
    "author": "MyPlugin",
    "version": "1.0.0",
    "tags": ["viking", "historical", "braided"]
  },
  "additionalCostumeData": {
    "_helmetHairBlendName": "HideA",
    "_helmetHairBlendshapeAmount": 75.0
  }
}
```
