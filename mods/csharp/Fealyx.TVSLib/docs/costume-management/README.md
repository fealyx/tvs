# Costume Management System

A framework system for registering and loading custom costumes into The Villain Simulator's character customization system.

## 🎯 **Overview**

The Costume Management system allows plugins to register custom clothing items that will be automatically loaded into the game when the CharacterCreator scene loads. This follows the same pattern as Asset Management and Scene Management.

## ✨ **Features**

- ✅ **Simple Registration** - Register costumes from anywhere in your plugin
- ✅ **Automatic Loading** - Costumes loaded automatically in CharacterCreator scene
- ✅ **Category Support** - Organize costumes by type (Hat, Shirt, Pants, etc.)
- ✅ **Asset Bundle Integration** - Uses your plugin's Assets system
- ✅ **Metadata Support** - Attach custom data to costumes
- ✅ **Automatic Cleanup** - Costumes unregistered when plugin disposes

## 🚀 **Quick Start**

### **Basic Usage**

```csharp
[BepInPlugin("com.example.customclothes", "Custom Clothes", "1.0.0")]
public class CustomClothesPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // Register a costume
        Costumes.Register(new CustomCostume
        {
            Id = "customclothes.superhero_cape",
            Name = "Superhero Cape",
            Description = "A majestic red cape",
            Category = "Accessory",
            AssetBundle = "capes.bundle",
            AssetName = "RedCape",
            IconAssetName = "RedCapeIcon"
        });

        Logger.LogInfo("Custom costumes registered!");
    }
}
```

That's it! Your costume will be loaded when the player enters the CharacterCreator scene.

## 📚 **API Reference**

### **CustomCostume Class**

```csharp
public class CustomCostume
{
    // Required fields
    public string Id { get; set; }              // Unique ID (namespaced)
    public string Name { get; set; }            // Display name
    public string Category { get; set; }        // Category/slot
    public string AssetBundle { get; set; }     // Bundle filename
    public string AssetName { get; set; }       // Asset name in bundle

    // Optional fields
    public string Description { get; set; }     // Description text
    public string? IconAssetName { get; set; }  // Preview icon asset
    public Dictionary<string, object> Metadata { get; set; }  // Custom data

    // Set automatically
    public BaseTVSPlugin? OwningPlugin { get; internal set; }
}
```

### **PluginCostumes Interface**

```csharp
// Available as: Costumes property on BaseTVSPlugin
public class PluginCostumes
{
    // Register individual costume
    bool Register(CustomCostume costume);

    // Register multiple at once
    int RegisterMultiple(IEnumerable<CustomCostume> costumes);

    // Query costumes
    CustomCostume? GetById(string id);
    IEnumerable<CustomCostume> GetByCategory(string category);
    IEnumerable<CustomCostume> GetAll();

    // Inspection
    IReadOnlyList<CustomCostume> RegisteredCostumes { get; }
}
```

## 🎨 **Usage Patterns**

### **Pattern 1: Register Multiple Costumes**

```csharp
public override void Initialize()
{
    base.Initialize();

    var costumes = new[]
    {
        new CustomCostume
        {
            Id = "myplugin.wizard_hat",
            Name = "Wizard Hat",
            Category = "Hat",
            AssetBundle = "hats.bundle",
            AssetName = "WizardHat"
        },
        new CustomCostume
        {
            Id = "myplugin.wizard_robe",
            Name = "Wizard Robe",
            Category = "Shirt",
            AssetBundle = "shirts.bundle",
            AssetName = "WizardRobe"
        }
    };

    int registered = Costumes.RegisterMultiple(costumes);
    Logger.LogInfo($"Registered {registered} costumes");
}
```

### **Pattern 2: Load Costume Data from File**

```csharp
public override void Initialize()
{
    base.Initialize();

    // Load from JSON, CSV, or other format
    var costumeDataPath = Path.Combine(FilePaths["Assets"], "costumes.json");
    var costumesJson = File.ReadAllText(costumeDataPath);
    var costumes = JsonConvert.DeserializeObject<List<CustomCostume>>(costumesJson);

    foreach (var costume in costumes)
    {
        // Set plugin-specific namespace
        costume.Id = $"{Info.Metadata.GUID}.{costume.Id}";
        Costumes.Register(costume);
    }
}
```

### **Pattern 3: Dynamic Registration with Metadata**

```csharp
public override void Initialize()
{
    base.Initialize();

    Costumes.Register(new CustomCostume
    {
        Id = "myplugin.special_outfit",
        Name = "Special Outfit",
        Category = "FullBody",
        AssetBundle = "outfits.bundle",
        AssetName = "SpecialOutfit",
        Metadata = new Dictionary<string, object>
        {
            { "rarity", "legendary" },
            { "unlockLevel", 50 },
            { "special Effects", true },
            { "color Variants", new[] { "red", "blue", "green" } }
        }
    });
}
```

### **Pattern 4: Query Other Plugins' Costumes**

```csharp
public override void Initialize()
{
    base.Initialize();

    // See what other plugins have registered
    var allCostumes = Costumes.GetAll();
    Logger.LogInfo($"Total costumes available: {allCostumes.Count()}");

    // Check specific categories
    var hats = Costumes.GetByCategory("Hat");
    Logger.LogInfo($"Available hats: {hats.Count()}");

    // Check if a specific costume exists
    var specific = Costumes.GetById("otherplugin.cool_hat");
    if (specific != null)
    {
        Logger.LogInfo($"Found: {specific.Name}");
    }
}
```

## 🔧 **Implementation Details**

### **Costume Registration Flow**

```
1. Plugin calls Costumes.Register(costume)
   ↓
2. PluginCostumes validates and passes to CostumeManager
   ↓
3. CostumeManager stores in CostumeRegistry
   ↓
4. Costume indexed by: ID, Plugin, Category
   ↓
5. Costume available for queries
   ↓
(Later) CharacterCreator scene loads
   ↓
6. CharacterCreatorCostumeLoader state activates
   ↓
7. OnReady called when context ready
   ↓
8. Loader calls LoadCostume() for each costume
   ↓
9. Assets loaded from bundles
   ↓
10. Costumes added to ZNECharacterCustomizer
```

### **Framework State: CharacterCreatorCostumeLoader**

The system includes a framework state that automatically loads costumes:

```csharp
[SceneState("CharacterCreator", Priority = 5000)]
internal class CharacterCreatorCostumeLoader : SceneState
{
    public override void OnReady(Scene scene)
    {
        var costumeManager = PluginManager.Instance.Costumes;
        var context = Context as CharacterCreatorContext;

        // Load all registered costumes
        foreach (var costume in costumeManager.GetPendingCostumes())
        {
            LoadCostume(costume, context);
        }
    }
}
```

This is a **framework state** (not owned by any plugin), ensuring all costumes are loaded regardless of which plugins registered them.

## 📋 **Costume Categories**

While you can use any category name, these are the common categories used by the base game:

- `"Hat"` - Headwear
- `"Hair"` - Hairstyles
- `"Shirt"` - Upper body clothing
- `"Pants"` - Lower body clothing
- `"Shoes"` - Footwear
- `"Accessory"` - Accessories (glasses, jewelry, etc.)
- `"FullBody"` - Full outfits

## 🎓 **Best Practices**

### **1. Namespace Your IDs**

```csharp
// ✅ Good: Namespaced with plugin GUID
Id = "myplugin.wizard_hat"

// ❌ Avoid: Generic names can conflict
Id = "wizard_hat"
```

### **2. Validate Before Registering**

```csharp
public bool RegisterCostume(CustomCostume costume)
{
    if (string.IsNullOrEmpty(costume.Id))
    {
        Logger.LogError("Costume ID cannot be empty");
        return false;
    }

    if (!Costumes.Register(costume))
    {
        Logger.LogWarning($"Failed to register costume: {costume.Id}");
        return false;
    }

    return true;
}
```

### **3. Register Early**

```csharp
// ✅ Good: Register in Initialize()
public override void Initialize()
{
    base.Initialize();
    Costumes.Register(...);
}

// ❌ Avoid: Registering in scene states might be too late
```

### **4. Use Asset Management Integration**

```csharp
// Costumes use your plugin's Assets system
// Make sure bundles are in AssetBundles directory
public override void Initialize()
{
    base.Initialize();

    Costumes.Register(new CustomCostume
    {
        Id = "myplugin.costume",
        AssetBundle = "mycostumes.bundle",  // In YourPlugin/AssetBundles/
        AssetName = "CostumePrefab"
    });
}
```

## 🔍 **Debugging**

### **Check Registration**

```csharp
public override void Initialize()
{
    base.Initialize();

    bool success = Costumes.Register(myCostume);
    if (success)
    {
        Logger.LogInfo($"Successfully registered: {myCostume.Name}");
    }
    else
    {
        Logger.LogError($"Failed to register: {myCostume.Id} (duplicate ID?)");
    }
}
```

### **List All Costumes**

```csharp
public void LogAllCostumes()
{
    Logger.LogInfo("=== All Registered Costumes ===");
    foreach (var costume in Costumes.GetAll())
    {
        Logger.LogInfo($"  {costume.Id}: {costume.Name} ({costume.Category})");
    }
}
```

### **Check What Your Plugin Registered**

```csharp
public void LogMyCostumes()
{
    Logger.LogInfo("=== My Plugin's Costumes ===");
    foreach (var costume in Costumes.RegisteredCostumes)
    {
        Logger.LogInfo($"  {costume.Name} - {costume.AssetBundle}");
    }
}
```

## 🚨 **Common Issues**

### **Costume Not Loading**

1. **Check the ID** - Is it unique?
2. **Check AssetBundle path** - Is the bundle in AssetBundles directory?
3. **Check AssetName** - Does the asset exist in the bundle?
4. **Check logs** - Look for error messages during loading

### **Duplicate ID Error**

```csharp
// Make sure IDs are unique across ALL plugins
Id = $"{Info.Metadata.GUID}.my_costume"  // Guaranteed unique
```

### **Assets Not Found**

```csharp
// Make sure asset bundle is in correct location:
// YourPlugin/
//   AssetBundles/
//     mycostumes.bundle  ← Here!
```

## 🔮 **Future Enhancements**

The following features are planned for future versions:

- **Loading State Tracking** - Track which costumes have been loaded
- **Unload Support** - Ability to unload specific costumes
- **Hot Reload** - Reload costumes without scene reload
- **Validation Hooks** - Custom validation before loading
- **Load Events** - Callbacks when costumes load/unload
- **Batch Loading** - Optimize loading multiple costumes
- **Preview Generation** - Auto-generate preview icons

## 📊 **System Architecture**

```
PluginManager
  └─> CostumeManager (global)
       ├─> CostumeRegistry (internal storage)
       └─> Framework States
            └─> CharacterCreatorCostumeLoader

BaseTVSPlugin
  └─> PluginCostumes (per-plugin interface)
       └─> Calls CostumeManager.RegisterCostume()

CharacterCreator Scene Loads
  └─> CharacterCreatorCostumeLoader.OnReady()
       └─> For each costume:
            ├─> Load from AssetBundle (via owning plugin's Assets)
            ├─> Add to ZNECharacterCustomizer
            └─> Register in UI
```

---

**Status**: ✅ Core system implemented - Ready for costume loading implementation!

**Next Steps**: Implement the actual loading logic in `CharacterCreatorCostumeLoader.LoadCostume()` to integrate with ZNECharacterCustomizer.
