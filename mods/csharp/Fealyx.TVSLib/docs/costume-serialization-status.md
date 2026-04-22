# Costume Serialization System

## Status: ✅ COMPLETE (Ready for Testing)

The costume serialization system has been successfully implemented and refactored to work directly with `CostumeItem`.

## Architecture

The system uses a clean, layered architecture:

```
JSON/YAML File
    ↓ (Deserialize)
CostumeItem (framework abstraction)
    ↓ (Register with manager)
CostumeManager (tracking/lifecycle)
    ↓ (Harmony patch injects)
ZNECostumeData (game's format)
```

**Key Design Decision**: We serialize to/from `CostumeItem` instead of directly to `ZNECostumeData`. This:
- Keeps serialization layer independent of Unity/ZNE types
- Centralizes all type conversion in `CostumeItem.ToZNECostumeData()`
- Simplifies testing and maintenance
- Allows framework to evolve independently of game types

## What's Been Implemented

### Data Model ✅
- `CostumeItem` - Single class that represents a costume in the framework
- All serialization works directly with this class
- Conversion to `ZNECostumeData` happens via `ToZNECostumeData()` method

### JSON Schema ✅
- Complete JSON schema matching `CostumeItem` structure
- Published to `schemas/costume-definition.schema.json`
- Includes validation rules and examples
- Compatible with VS Code and other IDEs

### Serialization Infrastructure ✅
- `ICostumeSerializer` interface for pluggable serializers
- `JsonCostumeSerializer` implementation using Newtonsoft.Json
- Support for YAML can be added by implementing `ICostumeSerializer`

Location: `Fealyx.TVSLib/CostumeManagement/Serialization/`

### Plugin API ✅
- `PluginCostumes` with file loading methods:
  - `LoadFromJson(path)` - Load from JSON file
  - `LoadFromYaml(path)` - Load from YAML file (when serializer added)
  - `LoadFromFile(path)` - Auto-detect format by extension
  - `LoadFromDirectory(path, pattern, recursive)` - Load all costumes from directory
  - `RegisterSerializer(serializer)` - Add custom serializers

## Example Usage

### Loading Costumes in Plugin

```csharp
public class MyPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // Load individual costume files
        Costumes.LoadFromJson("costumes/toulouse-hair.json");
        Costumes.LoadFromJson("costumes/pirate-hat.json");

        // Or load all from a directory
        Costumes.LoadFromDirectory("costumes/");

        Scenes.RegisterAllStates();
    }
}
```

### Costume Definition File

```json
{
  "$schema": "../../../schemas/costume-definition.schema.json",
  "name": "Toulouse Hair",
  "description": "A stylish hair style",
  "category": "hair",
  "assetBundle": "hair",
  "prefabPath": "assets/@hairtest/toulousehair.fbx",
  "iconPath": "assets/@hairtest/icon.png",
  "defaultColor": [0, 0, 0, 1],
  "additionalCostumeData": {
    "_helmetHairBlendName": "HideA",
    "_helmetHairBlendshapeAmount": 100.0
  }
}
```

## Properties Reference

### Required Properties
- `name` - Display name for the costume
- `category` - Costume category/slot (hair, hat, glasses, mask, earrings, top, bottom, shoes, gloves, accessories)
- `assetBundle` - Name of the asset bundle (resolved relative to plugin's AssetBundles directory)
- `prefabPath` - Path to the prefab asset within the bundle

### Optional Properties
- `description` - Description of the costume
- `iconPath` - Path to icon/preview sprite within the bundle
- `defaultColor` - RGBA color array [R, G, B, A] with values 0.0-1.0 (default: [1, 1, 1, 1])
- `metadata` - Custom metadata object for plugin-specific data
- `additionalCostumeData` - ZNE-specific additional data (helmet blends, etc.)

## Asset Paths

Assets are referenced using simple paths within the specified bundle:
- Bundle name: `"hair"` (maps to plugin's AssetBundles directory)
- Asset path: `"assets/@hairtest/toulousehair.fbx"`

The system uses `PluginAssets.LoadAsset<T>(bundleName, assetPath)` internally.

## Next Steps

### Testing
1. **Convert HairTest** to use JSON definitions instead of manual creation
2. **Verify in-game** loading works end-to-end
3. **Test Harmony integration** with character creator

### Future Enhancements
1. **YAML Support** - Add `YamlCostumeSerializer` (requires YamlDotNet package)
2. **Validation** - Add JSON schema validation before deserialization
3. **Hot Reload** - Support runtime reloading of costume definitions
4. **Material System** - Expand when ZNE material system is researched
5. **Morph System** - Add morph/blendshape support to `CostumeItem`

## Files

### Core Implementation
- `Fealyx.TVSLib/CostumeManagement/CostumeItem.cs` - Main data model
- `Fealyx.TVSLib/CostumeManagement/Serialization/ICostumeSerializer.cs` - Serializer interface
- `Fealyx.TVSLib/CostumeManagement/Serialization/JsonCostumeSerializer.cs` - JSON implementation
- `Fealyx.TVSLib/CostumeManagement/PluginCostumes.cs` - Plugin API with loading methods

### Schema & Examples
- `schemas/costume-definition.schema.json` - JSON schema (published)
- `Fealyx.TVSLib/docs/examples/toulouse-hair.costume.json` - Example definition

## Changes from Original Design

**Simplified Architecture**: Removed intermediate `CostumeDefinition` data models and `CostumeFactory`. Now serialization works directly with `CostumeItem`, which already had all the necessary properties and conversion logic.

**Benefits**:
- Less code to maintain
- Single source of truth for costume data
- Easier to test and debug
- No complex type conversions during deserialization
- Framework layer stays independent of game types
