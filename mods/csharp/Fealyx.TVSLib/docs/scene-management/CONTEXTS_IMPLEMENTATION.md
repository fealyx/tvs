# Scene Contexts & Framework States - Implementation Summary

## 🎯 **What Was Implemented**

### **Core Features**
1. ✅ **ISceneContext Interface** - Contract for scene-specific contexts
2. ✅ **Framework State Support** - States not owned by plugins
3. ✅ **Automatic Context Injection** - Contexts set on states before OnEnter
4. ✅ **Context Registration System** - Register context types per scene
5. ✅ **MainSceneContext** - Example implementation with TODOs

### **Updated Components**

1. **ISceneContext.cs** (New)
   - Interface for scene contexts
   - Methods: `Initialize()`, `Cleanup()`
   - Properties: `SceneName`, `IsReady`

2. **SceneStateRegistry.cs** (Updated)
   - Added `RegisterFramework()` method
   - Updated `StateEntry` to support null plugins
   - Added `GetFrameworkStates()` method

3. **SceneState.cs** (Updated)
   - Added `Context` property (nullable ISceneContext)
   - Plugin property now nullable (for framework states)
   - Added `SetContext()` internal method

4. **SceneManager.cs** (Updated)
   - Added context registration system
   - Added `RegisterContext<T>()` method
   - Added `GetContext<T>()` method
   - Added `RegisterFrameworkState()` method
   - Context lifecycle management in scene transitions
   - Contexts initialized before states activated

5. **PluginManager.cs** (Updated)
   - Added `RegisterSceneContexts()` method
   - Added `RegisterFrameworkStates()` method
   - Calls both during initialization

6. **BaseTVSPlugin.cs** (Updated)
   - Added `MainScene` convenience property
   - Returns typed MainSceneContext when in MainScene

7. **MainSceneContext.cs** (New)
   - Example context implementation
   - Uses placeholder types (object) with TODOs
   - Ready for actual game types

### **Documentation**
8. **CONTEXTS.md** (New)
   - Complete guide to contexts and framework states
   - Usage patterns and examples
   - Decision tree for when to use what
   - Migration guide

## 🔄 **Lifecycle Flow with Contexts**

```
Scene Load Event
  ↓
1. SceneManager checks for registered context type
  ├─> Create context instance
  ├─> Call context.Initialize()
  ├─> Store in _activeContexts
  └─> Log status
  ↓
2. TransitionStates(sceneName, Entering, context)
  ↓
  For each state (priority order):
    ├─> state.SetContext(context)  ← NEW!
    ├─> state.Transition = Entering
    ├─> state.OnEnter(scene)
    └─> state.Transition = Active
  ↓

Scene Unload Event
  ↓
1. TransitionStates(sceneName, Exiting, null)
  ↓
2. Cleanup context
  ├─> Call context.Cleanup()
  └─> Remove from _activeContexts
```

## 🎨 **Usage Examples**

### **Example 1: Using Context in Plugin State**

```csharp
[SceneState("MainScene")]
public class MyFeature : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Option 1: Via Context property
        if (Context is MainSceneContext ctx && ctx.IsReady)
        {
            var player = ctx.Player;
        }

        // Option 2: Via Plugin convenience property
        if (Plugin.MainScene?.IsReady == true)
        {
            var player = Plugin.MainScene.Player;
        }
    }
}
```

### **Example 2: Framework State for Cross-Plugin System**

```csharp
// Global manager (in PluginManager)
public CostumeManager Costumes { get; } = new();

// Framework state (loads costumes in specific scene)
[SceneState("CharacterCreator", Priority = 5000)]
internal class CostumeLoaderState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        var manager = PluginManager.Instance.Costumes;
        foreach (var costume in manager.GetPendingCostumes())
        {
            // Load into game
        }
    }
}

// Plugin usage (register anytime)
public class MyPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        TVS.Costumes.RegisterCostume(new CustomCostume { ... });
    }
}
```

## 📊 **Benefits**

### **Contexts**
- ✅ **No Repeated FindObjectOfType** - Done once, shared by all
- ✅ **Type-Safe** - Compile-time checking
- ✅ **Null-Safe** - IsReady property
- ✅ **Automatic** - Framework handles lifecycle
- ✅ **Extensible** - Easy to add new contexts

### **Framework States**
- ✅ **Cross-Plugin** - Shared systems
- ✅ **Centralized** - One place for logic
- ✅ **Priority Control** - Can run before/after plugin states
- ✅ **Optional** - Plugins can still use manual approach

## 🔍 **Key Design Decisions**

### **1. Why ISceneContext Interface?**
- Flexible - different contexts have different objects
- Type-safe - can cast to specific context type
- Testable - can mock contexts
- Clear contract - Initialize/Cleanup

### **2. Why Nullable Plugin in SceneState?**
- Framework states don't have a plugin owner
- States can be internal systems
- Backward compatible - existing plugin states still work

### **3. Why Context Property on SceneState?**
- All states can access context
- No need to pass context around
- Automatically set by framework
- Null if scene has no context

### **4. Why Convenience Property on BaseTVSPlugin?**
- Common case (MainScene) is very easy
- Type-safe without casting
- Discoverable via IntelliSense
- Optional - can still use Context property

## ⚠️ **Important Notes**

### **1. MainSceneContext Uses Placeholders**
The current `MainSceneContext` uses `object` types as placeholders. When implementing:
1. Replace `object?` with actual game types
2. Update `Initialize()` to find correct types
3. Add helper methods for common operations
4. Update `IsReady` if needed

### **2. Framework States are Internal**
Framework states should be marked `internal` - they're part of TVSLib, not user code.

### **3. Context Initialization Happens First**
Contexts are initialized **before** any states activate, so `Context` is always available in `OnEnter()`.

### **4. Shared Context Instance**
All states in the same scene see the **same** context instance. It's shared, not per-state.

## 🚀 **Next Steps**

### **To Complete MainScene Context:**
1. Identify actual game object types for MainScene
2. Replace `object?` types in MainSceneContext
3. Update `Initialize()` with correct FindObjectOfType calls
4. Add useful helper methods
5. Test with real game

### **To Add More Contexts:**
1. Create context class implementing `ISceneContext`
2. Register in `PluginManager.RegisterSceneContexts()`
3. (Optional) Add convenience property to BaseTVSPlugin
4. Document

### **To Add Framework Systems:**
1. Create Manager class (if needed)
2. Create Framework SceneState for scene-specific logic
3. Register in `PluginManager.RegisterFrameworkStates()`
4. Document for plugin developers

## 📁 **Files Created/Modified**

### **Created:**
- `ISceneContext.cs` - Context interface
- `Scenes\MainScene\MainSceneContext.cs` - Example context
- `docs\scene-management\CONTEXTS.md` - Documentation

### **Modified:**
- `SceneStateRegistry.cs` - Framework state support
- `SceneState.cs` - Context property, nullable Plugin
- `SceneManager.cs` - Context registration & lifecycle
- `PluginManager.cs` - Context/framework state registration
- `BaseTVSPlugin.cs` - MainScene convenience property

## ✅ **Build Status**

✅ **Success** - 0 errors, 1 pre-existing warning

## 🎊 **Summary**

You now have a complete system for:
1. **Scene-specific contexts** - Typed access to scene objects
2. **Framework states** - Internal systems not tied to plugins
3. **Automatic lifecycle** - Contexts initialized before states
4. **Cross-scene systems** - Global managers with scene-specific initialization
5. **Clean API** - Convenience properties and type-safe access

**The architecture is extensible and ready for your costume management system and other framework features!** 🚀

---

**Status**: ✅ Complete - Contexts and Framework States fully implemented!
**Next**: Implement actual game types in MainSceneContext and add CostumeManagement system!
