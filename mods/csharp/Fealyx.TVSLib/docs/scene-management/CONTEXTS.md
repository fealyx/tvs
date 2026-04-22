# Scene Contexts & Framework States - Documentation Update

## 🎯 **What's New**

The Scene State Management system now includes:
1. **Scene Contexts** - Typed access to scene-specific objects
2. **Framework States** - Internal system states not owned by plugins
3. **Automatic Context Injection** - Contexts available via `Context` property
4. **OnReady Lifecycle** - Eliminates `ctx.IsReady` boilerplate

## 📚 **Scene Contexts**

### **What Are Scene Contexts?**

Scene contexts provide structured, typed access to scene-specific game objects and utilities. They're automatically initialized when their scene loads and cleaned up when it unloads.

### **The OnReady Pattern**

Instead of checking `if (ctx?.IsReady)` everywhere, contexts now fire an `OnReady` event when they're fully initialized. SceneStates receive this via the `OnReady()` method:

```csharp
[SceneState("MainScene")]
public class MyGameFeature : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Called immediately when scene loads
        // Context may not be ready yet - don't access Context here!
        Plugin.Logger.LogInfo("Scene entered, waiting for context...");
    }

    public override void OnReady(Scene scene)
    {
        // Called when context is ready (or immediately if no context)
        // Safe to access Context and all its objects here!
        if (Context is MainSceneContext ctx)
        {
            var player = ctx.Player;
            var manager = ctx.GameManager;
            // No IsReady check needed!
        }
    }
}
```

### **Lifecycle Flow**

```
Scene Loads
  ↓
1. SceneManager creates context
  ↓
2. SceneManager calls context.Initialize()
  ↓
3. States activated (OnEnter called)
  ↓
4. Context finishes initialization
  ↓
5. Context fires OnReady event
  ↓
6. States receive OnReady() call
  ↓
States can now safely use Context!
```

### **Using Scene Contexts**

#### **Option 1: OnReady Method (Recommended)**

```csharp
[SceneState("MainScene")]
public class MyGameFeature : SceneState
{
    public override void OnReady(Scene scene)
    {
        // Context is guaranteed to be ready!
        if (Context is MainSceneContext ctx)
        {
            ctx.Player.Health = 100;
            ctx.SpawnEnemy(Vector3.zero, EnemyType.Grunt);
        }
    }
}
```

#### **Option 2: Via Plugin Property**

```csharp
[SceneState("MainScene")]
public class MyGameFeature : SceneState
{
    public override void OnReady(Scene scene)
    {
        // Convenience property works here too
        if (Plugin.MainScene != null)
        {
            Plugin.MainScene.Player.Health = 100;
        }
    }
}
```

#### **When to Use OnEnter vs OnReady**

- **OnEnter()** - Scene setup that doesn't need game objects (UI setup, event subscriptions, etc.)
- **OnReady()** - Logic that needs access to context objects (player manipulation, game state, etc.)

```csharp
[SceneState("MainScene")]
public class CompleteExample : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Early initialization - no context needed
        Plugin.Logger.LogInfo("Initializing my feature...");
        SubscribeToEvents();
    }

    public override void OnReady(Scene scene)
    {
        // Context-dependent initialization
        if (Context is MainSceneContext ctx)
        {
            SetupPlayer(ctx.Player);
            ConfigureUI(ctx.UIManager);
        }
    }

    public override void OnExit(Scene scene)
    {
        // Cleanup
        UnsubscribeFromEvents();
    }
}
```

### **Creating Custom Contexts**

```csharp
using Fealyx.TVSLib.SceneManagement;
using UnityEngine;

public class MenuSceneContext : ISceneContext
{
    public string SceneName => "MainMenu";
    public bool IsReady => MenuManager != null;

    public MenuManager? MenuManager { get; private set; }
    public SettingsPanel? Settings { get; private set; }

    public void Initialize()
    {
        MenuManager = Object.FindObjectOfType<MenuManager>();
        Settings = Object.FindObjectOfType<SettingsPanel>();
    }

    public void Cleanup()
    {
        MenuManager = null;
        Settings = null;
    }

    // Helper methods
    public void ShowMenu(MenuType type) => MenuManager?.ShowMenu(type);
}
```

Then register it in `PluginManager`:

```csharp
private void RegisterSceneContexts()
{
    Scenes.RegisterContext<MainSceneContext>("MainScene");
    Scenes.RegisterContext<MenuSceneContext>("MainMenu"); // Add this
}
```

## 🔧 **Framework States**

### **What Are Framework States?**

Framework states are scene states that are part of TVSLib's internal systems, not owned by any specific plugin. They're useful for cross-cutting concerns like costume management, mod integration, etc.

### **Creating Framework States**

```csharp
// In TVSLib (not user code)
[SceneState("CharacterCreator", Priority = 5000)]
internal class CostumeManagementState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Access framework systems
        var costumeManager = PluginManager.Instance.Costumes;
        var pendingCostumes = costumeManager.GetPendingCostumes();

        // Load custom costumes into the game
        var clothingSystem = Object.FindObjectOfType<ClothingSystemManager>();
        foreach (var costume in pendingCostumes)
        {
            clothingSystem.AddCustomClothing(costume);
        }
    }
}
```

Register in `PluginManager`:

```csharp
private void RegisterFrameworkStates()
{
    Scenes.RegisterFrameworkState(new CostumeManagementState());
}
```

### **Key Differences: Plugin States vs Framework States**

| Aspect | Plugin States | Framework States |
|--------|--------------|------------------|
| **Owner** | Specific plugin | TVSLib framework |
| **Registration** | `Scenes.Register()` or `Scenes.RegisterAllStates()` | `Scenes.RegisterFrameworkState()` |
| **Plugin Property** | Available (non-null) | Null |
| **Cleanup** | When plugin disposes | When PluginManager disposes |
| **Use Case** | Plugin-specific logic | Cross-plugin systems |

## 🎨 **Usage Patterns**

### **Pattern 1: Simple Context Access with OnReady**

```csharp
[SceneState("MainScene")]
public class SimpleFeature : SceneState
{
    public override void OnReady(Scene scene)
    {
        // No IsReady check needed!
        if (Plugin.MainScene != null)
        {
            var player = Plugin.MainScene.Player;
            player.Health = 100;
        }
    }
}
```

### **Pattern 2: Split Initialization (OnEnter + OnReady)**

```csharp
[SceneState("MainScene")]
public class SplitInitFeature : SceneState
{
    private EventHandler _handler;

    public override void OnEnter(Scene scene)
    {
        // Early setup - no game objects needed
        Plugin.Logger.LogInfo("Feature initializing...");
        _handler = new EventHandler();
        SubscribeEvents();
    }

    public override void OnReady(Scene scene)
    {
        // Context-dependent setup
        if (Context is MainSceneContext ctx)
        {
            _handler.SetPlayer(ctx.Player);
            ctx.UIManager.ShowWelcome();
        }
    }

    public override void OnExit(Scene scene)
    {
        UnsubscribeEvents();
        _handler = null;
    }
}
```

### **Pattern 3: Multiple Scene States with Context**

```csharp
[SceneState("MainScene", Priority = 100)]
public class CoreGameLogic : SceneState
{
    public override void OnReady(Scene scene)
    {
        if (Context is MainSceneContext ctx)
        {
            // Core initialization runs first (high priority)
            ctx.GameManager.InitializeSystems();
        }
    }
}

[SceneState("MainScene", Priority = 50)]
public class UILogic : SceneState
{
    public override void OnReady(Scene scene)
    {
        // Same context instance as CoreGameLogic
        if (Context is MainSceneContext ctx)
        {
            // UI initialization (after core - lower priority)
            ctx.UIManager.Setup();
        }
    }
}
```

### **Pattern 3: Cross-Scene System**

```csharp
// Framework manager (global)
public class CostumeManager : Manager
{
    private readonly List<CustomCostume> _costumes = new();

    public void RegisterCostume(CustomCostume costume)
    {
        _costumes.Add(costume);
    }

    internal IEnumerable<CustomCostume> GetPendingCostumes() => _costumes;
}

// Framework state (scene-specific loading)
[SceneState("CharacterCreator", Priority = 5000)]
internal class CostumeLoaderState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Load costumes registered by any plugin
        var manager = PluginManager.Instance.Costumes;
        foreach (var costume in manager.GetPendingCostumes())
        {
            // Load into game
        }
    }
}

// Plugin usage (anytime, any scene)
public class MyClothingPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // Register costume - it'll load when CharacterCreator scene loads
        TVS.Costumes.RegisterCostume(new CustomCostume
        {
            Name = "Cool Hat",
            AssetBundle = "hats.bundle",
            AssetName = "CoolHat"
        });
    }
}
```

## 🔍 **Context vs Framework States Decision Tree**

```
Do you need scene-specific objects?
  ├─> YES: Use a Scene Context
  │    └─> Will multiple plugins need these objects?
  │         ├─> YES: Create a context in TVSLib
  │         └─> NO: Access objects directly in your state
  │
  └─> NO: Do you need scene-specific LOGIC?
       ├─> YES: Is it plugin-specific?
       │    ├─> YES: Use a regular SceneState
       │    └─> NO: Use a Framework State
       │
       └─> NO: Use a global Manager (no scene state needed)
```

## 📋 **Implementation Checklist**

### **Adding a New Scene Context**

1. ✅ Create context class implementing `ISceneContext`
2. ✅ Discover scene objects in `Initialize()`
3. ✅ Register in `PluginManager.RegisterSceneContexts()`
4. ✅ (Optional) Add convenience property to `BaseTVSPlugin`
5. ✅ Document usage

### **Adding a Framework State**

1. ✅ Create state class inheriting `SceneState`
2. ✅ Mark as `internal` (it's part of TVSLib)
3. ✅ Register in `PluginManager.RegisterFrameworkStates()`
4. ✅ Document the system it supports

## 🎓 **Best Practices**

### **1. Use Contexts for Object Discovery**
```csharp
// ✅ Good: Context handles discovery
public class MainSceneContext : ISceneContext
{
    public void Initialize()
    {
        Player = Object.FindObjectOfType<Player>();
    }
}

// ❌ Avoid: Manual discovery in every state
public class MyState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        var player = Object.FindObjectOfType<Player>(); // Don't do this
    }
}
```

### **2. Check IsReady Before Using Context**
```csharp
// ✅ Good: Check if ready
if (Plugin.MainScene?.IsReady == true)
{
    Plugin.MainScene.Player.DoSomething();
}

// ❌ Avoid: Assume it's ready
Plugin.MainScene.Player.DoSomething(); // NullReferenceException!
```

### **3. Framework States for Cross-Plugin Systems**
```csharp
// ✅ Good: Framework state for shared functionality
[SceneState("CharacterCreator")]
internal class CostumeLoaderState : SceneState { }

// ❌ Avoid: Each plugin duplicating the same logic
public class PluginACostumeLoader : SceneState { }
public class PluginBCostumeLoader : SceneState { }
```

## 🚀 **Migration Guide**

### **Before (Manual FindObjectOfType)**
```csharp
[SceneState("MainScene")]
public class MyFeature : SceneState
{
    public override void OnEnter(Scene scene)
    {
        var player = Object.FindObjectOfType<Player>();
        var manager = Object.FindObjectOfType<GameManager>();

        if (player != null && manager != null)
        {
            player.Health = 100;
            manager.StartGame();
        }
    }
}
```

### **After (With Contexts and OnReady)**
```csharp
[SceneState("MainScene")]
public class MyFeature : SceneState
{
    public override void OnReady(Scene scene)
    {
        // No FindObjectOfType needed!
        // No IsReady check needed!
        if (Plugin.MainScene != null)
        {
            Plugin.MainScene.Player.Health = 100;
            Plugin.MainScene.GameManager.StartGame();
        }
    }
}
```

**Benefits:**
- ✅ No FindObjectOfType calls (done once by context)
- ✅ No IsReady boilerplate (guaranteed ready in OnReady)
- ✅ Type-safe access
- ✅ Cleaner, more readable code
- ✅ Shared across all states
- ✅ Automatic cleanup

### **Migration Steps**

1. **Move logic from OnEnter to OnReady:**
   ```csharp
   // Old
   public override void OnEnter(Scene scene) { /* access objects */ }

   // New
   public override void OnEnter(Scene scene) { /* early setup */ }
   public override void OnReady(Scene scene) { /* access objects */ }
   ```

2. **Remove IsReady checks:**
   ```csharp
   // Old
   if (ctx?.IsReady == true) { ... }

   // New (in OnReady)
   if (ctx != null) { ... }  // or just use it directly
   ```

3. **Replace FindObjectOfType:**
   ```csharp
   // Old
   var player = Object.FindObjectOfType<Player>();

   // New
   var player = Plugin.MainScene?.Player;
   ```

---

**Status**: ✅ Contexts and Framework States implemented and documented!
