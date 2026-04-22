# OnReady Lifecycle - Implementation Summary

## 🎯 **The Problem Solved**

Previously, developers had to check `if (ctx?.IsReady == true)` everywhere they wanted to access context objects. This was boilerplate-heavy and error-prone.

## ✨ **The Solution: OnReady Event**

Contexts now fire an `OnReady` event when fully initialized. SceneStates receive this as a method call, guaranteeing context readiness.

## 🔄 **Updated Lifecycle Flow**

```
1. Scene Loads
   ↓
2. SceneManager creates ISceneContext instance
   ↓
3. SceneManager subscribes to context.OnReady
   ↓
4. SceneManager calls context.Initialize()
   ↓
5. SceneManager activates states (OnEnter called)
   ↓
6. Context completes initialization
   ↓
7. Context fires OnReady event
   ↓
8. SceneManager receives event
   ↓
9. SceneManager calls state.OnReady() for all states
   ↓
10. States can safely use Context!
```

## 📋 **What Changed**

### **ISceneContext Interface**
Added `OnReady` event:
```csharp
public interface ISceneContext
{
    event Action? OnReady;  // NEW!
    string SceneName { get; }
    bool IsReady { get; }   // Still exists for manual checks
    void Initialize();
    void Cleanup();
}
```

### **SceneState Base Class**
Added `OnReady()` method:
```csharp
public abstract class SceneState
{
    public virtual void OnEnter(Scene scene) { }
    public virtual void OnReady(Scene scene) { }  // NEW!
    public virtual void OnExit(Scene scene) { }
    // ...
}
```

### **SceneStateTransition Enum**
Added `Ready` state:
```csharp
public enum SceneStateTransition
{
    Entering,
    Active,
    Ready,    // NEW!
    Paused,
    Exiting,
    Exited
}
```

### **SceneManager**
Updated to handle OnReady workflow:
- Subscribes to context.OnReady before calling Initialize()
- Calls OnReady() for all active states when context fires event
- If no context exists, calls OnReady() immediately after OnEnter
- If context is already ready (IsReady == true), calls OnReady() immediately

## 🎨 **Usage Examples**

### **Example 1: Simple Usage**
```csharp
[SceneState("MainScene")]
public class MyFeature : SceneState
{
    public override void OnReady(Scene scene)
    {
        // Guaranteed ready - no checks needed!
        if (Plugin.MainScene != null)
        {
            Plugin.MainScene.Player.Health = 100;
        }
    }
}
```

### **Example 2: Split Initialization**
```csharp
[SceneState("MainScene")]
public class SplitFeature : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Early setup - no context needed
        Plugin.Logger.LogInfo("Initializing...");
        SetupEventHandlers();
    }

    public override void OnReady(Scene scene)
    {
        // Context-dependent setup
        if (Context is MainSceneContext ctx)
        {
            ConfigurePlayer(ctx.Player);
        }
    }
}
```

### **Example 3: Context Implementation**
```csharp
public class MainSceneContext : ISceneContext
{
    public event Action? OnReady;
    public string SceneName => "MainScene";
    public bool IsReady { get; private set; }

    public Player? Player { get; private set; }

    public void Initialize()
    {
        // Find objects
        Player = Object.FindObjectOfType<Player>();

        // Mark ready and fire event
        IsReady = true;
        OnReady?.Invoke();
    }

    public void Cleanup()
    {
        Player = null;
        IsReady = false;
    }
}
```

### **Example 4: Async Initialization (Future)**
```csharp
public class ComplexSceneContext : ISceneContext
{
    public event Action? OnReady;
    public string SceneName => "ComplexScene";
    public bool IsReady { get; private set; }

    public async void Initialize()
    {
        // Synchronous setup
        Player = Object.FindObjectOfType<Player>();

        // NOT ready yet - need to load data

        // Async operations
        await LoadPlayerDataAsync();
        await LoadWorldStateAsync();

        // NOW ready!
        IsReady = true;
        OnReady?.Invoke();
    }

    public void Cleanup() { /* ... */ }
}
```

## 🔧 **SceneManager Implementation Details**

### **HandleSceneChanged Method**
```csharp
private void HandleSceneChanged(Scene oldScene, Scene newScene)
{
    // ... cleanup old scene ...

    ISceneContext? newContext = null;

    if (_contextTypes.TryGetValue(newScene.name, out var contextType))
    {
        newContext = (ISceneContext)Activator.CreateInstance(contextType);

        // Subscribe BEFORE initializing
        newContext.OnReady += () => OnContextReady(newScene, newContext);

        newContext.Initialize();
        _activeContexts[newScene.name] = newContext;
    }

    // Activate states
    TransitionStates(newScene.name, newScene, SceneStateTransition.Entering, newContext);
}
```

### **TransitionStates Method**
```csharp
private void TransitionStates(string sceneName, Scene scene, 
    SceneStateTransition targetTransition, ISceneContext? context = null)
{
    var states = _registry.GetStatesForScene(sceneName).Select(e => e.State).ToList();

    if (targetTransition == SceneStateTransition.Entering)
    {
        // Activate all states
        foreach (var state in states)
        {
            ActivateState(state, scene, context);
        }

        // Handle immediate OnReady scenarios
        if (context == null)
        {
            // No context - call OnReady immediately
            CallOnReadyForStates(states, scene);
        }
        else if (context.IsReady)
        {
            // Context already ready - call OnReady immediately
            CallOnReadyForStates(states, scene);
        }
        // Otherwise, OnReady will be called when context fires event
    }
}
```

### **OnContextReady Callback**
```csharp
private void OnContextReady(Scene scene, ISceneContext context)
{
    _logger.LogInfo($"Context ready for scene: {scene.name}");

    var states = _registry.GetStatesForScene(scene.name).Select(e => e.State).ToList();

    foreach (var state in states)
    {
        if (state.Transition == SceneStateTransition.Active)
        {
            try
            {
                state.Transition = SceneStateTransition.Ready;
                state.OnReady(scene);
                state.Transition = SceneStateTransition.Active;
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error in {state.GetType().Name}.OnReady(): {ex}");
            }
        }
    }
}
```

## ✅ **Benefits**

### **For Developers**
- ✅ **No Boilerplate** - No `IsReady` checks in every method
- ✅ **Clearer Intent** - OnReady means "context is ready"
- ✅ **Safer** - Guaranteed ready when OnReady is called
- ✅ **Flexible** - Can still use OnEnter for early setup

### **For Complex Contexts**
- ✅ **Async Support** - Contexts can initialize asynchronously
- ✅ **Progressive Loading** - Fire OnReady when truly ready
- ✅ **Error Handling** - Can delay OnReady if initialization fails

### **For Framework**
- ✅ **Consistent** - Same pattern everywhere
- ✅ **Trackable** - Ready transition is logged
- ✅ **Debuggable** - Clear state transitions

## 📊 **State Transition Timeline**

```
State Created
  ↓
Transition: Exited
  ↓
Scene Loads
  ↓
Transition: Entering
  ↓
OnEnter() called
  ↓
Transition: Active
  ↓
Context fires OnReady (or immediate if no context)
  ↓
Transition: Ready (temporarily)
  ↓
OnReady() called
  ↓
Transition: Active
  ↓
OnUpdate() / OnFixedUpdate() loop
  ↓
Scene Unloads
  ↓
Transition: Exiting
  ↓
OnExit() called
  ↓
Transition: Exited
```

## 🎓 **Best Practices**

### **1. Use OnReady for Context-Dependent Logic**
```csharp
// ✅ Good
public override void OnReady(Scene scene)
{
    if (Plugin.MainScene != null)
    {
        Plugin.MainScene.Player.Heal();
    }
}

// ❌ Avoid
public override void OnEnter(Scene scene)
{
    if (Plugin.MainScene?.IsReady == true)
    {
        Plugin.MainScene.Player.Heal();
    }
}
```

### **2. Use OnEnter for Early Setup**
```csharp
// ✅ Good
public override void OnEnter(Scene scene)
{
    // Subscribe to events, create handlers, etc.
    SubscribeEvents();
}

public override void OnReady(Scene scene)
{
    // Use context objects
    if (Plugin.MainScene != null)
    {
        SetupWithPlayer(Plugin.MainScene.Player);
    }
}
```

### **3. Fire OnReady Immediately When Appropriate**
```csharp
// ✅ Good - immediate ready
public void Initialize()
{
    Player = Object.FindObjectOfType<Player>();
    IsReady = true;
    OnReady?.Invoke();  // Immediate!
}

// ✅ Also good - delayed ready
public async void Initialize()
{
    Player = Object.FindObjectOfType<Player>();
    await LoadDataAsync();
    IsReady = true;
    OnReady?.Invoke();  // After async work!
}
```

## 🚨 **Important Notes**

1. **OnReady is called ONCE per scene load** - Not every frame
2. **Context.IsReady still exists** - For manual checks if needed
3. **No context = immediate OnReady** - States without contexts still work
4. **Priority order maintained** - OnReady called in priority order
5. **Exception safe** - Errors in one state don't prevent others from receiving OnReady

---

**Status**: ✅ Implemented and documented!
**Developer Happiness**: 📈 Even higher - no more boilerplate!
