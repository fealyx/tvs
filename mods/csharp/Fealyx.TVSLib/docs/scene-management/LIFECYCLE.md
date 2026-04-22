# SceneState Lifecycle Guide

## 🔄 **Complete Lifecycle Timeline**

```
Scene Load Timeline:
┌─────────────────────────────────────────────────────────┐
│ 1. SceneManager.activeSceneChanged event fires          │
│    ├─ OnEnter(scene) called                             │
│    │  └─ Scene loaded, but hierarchy not ready yet      │
│    │     ❌ GameObject.Find() will fail                 │
│    │                                                     │
│    ├─ OnReady(scene) called (when context ready)        │
│    │  └─ Context available, but hierarchy not ready     │
│    │     ❌ GameObject.Find() will still fail          │
│    │                                                     │
│    └─ SceneLifecycleDispatcher created                  │
│                                                          │
│ 2. Unity instantiates GameObjects in scene              │
│                                                          │
│ 3. Unity's Awake() phase                                │
│    └─ OnAwake() called                                  │
│       └─ Scene hierarchy fully available                │
│          ✅ GameObject.Find() works!                    │
│                                                          │
│ 4. Unity's Start() phase                                │
│    └─ OnStart() called                                  │
│       └─ All scripts initialized                        │
│          ✅ Everything ready                            │
│                                                          │
│ 5. Update loop begins                                   │
│    ├─ OnUpdate() - every frame                          │
│    └─ OnFixedUpdate() - every physics tick              │
│                                                          │
│ 6. Scene unload                                         │
│    └─ OnExit(scene) called                              │
└─────────────────────────────────────────────────────────┘
```

## 📋 **Lifecycle Hook Reference**

### **When to Use Each Hook**

| Hook | Purpose | GameObject.Find()? | Context Available? | Typical Use Cases |
|------|---------|-------------------|-------------------|-------------------|
| **OnEnter** | Early initialization | ❌ No | ❌ No | Load assets, initialize data structures |
| **OnReady** | Context-dependent setup | ❌ No | ✅ **Yes** | Access framework contexts, setup with scene data |
| **OnAwake** | Find GameObjects | ✅ **Yes** | ✅ Yes | GameObject.Find(), cache references |
| **OnStart** | Post-initialization | ✅ Yes | ✅ Yes | Logic depending on other scripts being ready |
| **OnUpdate** | Per-frame logic | ✅ Yes | ✅ Yes | Game logic, animations, input |
| **OnFixedUpdate** | Physics logic | ✅ Yes | ✅ Yes | Rigidbody manipulation, physics |
| **OnExit** | Cleanup | ✅ Yes | ✅ Yes | Dispose resources, cleanup state |

## 💡 **Complete Example**

```csharp
[SceneState("CharacterCreator", Priority = 100)]
public class CharacterCreatorState : SceneState
{
    private GameObject? _hairUIPanel;
    private ZNECharacterCustomizer? _customizer;
    private GameObject? _hairPrefab;
    private ZNECostumeData? _costumeData;

    public override void OnEnter(Scene scene)
    {
        // ✅ GOOD: Load assets (no GameObject access needed)
        Plugin!.Logger.LogInfo("Entered CharacterCreator scene");
        _hairPrefab = Plugin.Assets.LoadAsset<GameObject>("hair", "hair.fbx");

        // ❌ BAD: GameObject.Find() won't work here!
        // var panel = GameObject.Find("/Canvas/...");  // Will return null!
    }

    public override void OnReady(Scene scene)
    {
        // ✅ GOOD: Access framework context
        if (Context is CharacterCreatorContext ctx)
        {
            _customizer = ctx.CharacterCustomizer;
            Plugin!.Logger.LogInfo("Context ready");
        }

        // ✅ GOOD: Create data objects
        _costumeData = CreateCostumeData(_hairPrefab);

        // ❌ BAD: GameObject.Find() still won't work!
        // var panel = GameObject.Find("/Canvas/...");  // Still null!
    }

    public override void OnAwake()
    {
        // ✅ NOW GameObject.Find() works!
        _hairUIPanel = GameObject.Find("/Canvas/Customize-Section/Customize-Panels/Customize-Hair");

        if (_hairUIPanel == null)
        {
            Plugin!.Logger.LogError("Hair panel not found!");
            return;
        }

        // ✅ GOOD: Cache component references
        var controller = _hairUIPanel.GetComponent<ZNECharacterItemPanel>();
        Plugin!.Logger.LogInfo($"Found {controller._items.Length} existing items");

        // ✅ GOOD: Modify arrays, add costume data
        var newItems = new ZNECostumeData[controller._items.Length + 1];
        Array.Copy(controller._items, newItems, controller._items.Length);
        newItems[^1] = _costumeData;
        controller._items = newItems;
    }

    public override void OnStart()
    {
        // ✅ GOOD: All other scripts initialized - safe to call methods
        if (_hairUIPanel != null)
        {
            var controller = _hairUIPanel.GetComponent<ZNECharacterItemPanel>();

            // Other scripts are now initialized, safe to interact
            controller?.RefreshUI();
            controller?.RebuildButtons();

            Plugin!.Logger.LogInfo("CharacterCreator fully initialized");
        }
    }

    public override void OnUpdate()
    {
        // Per-frame logic (if needed)
        // ✅ GOOD: Input handling, animations, state updates
    }

    public override void OnFixedUpdate()
    {
        // Physics update (if needed)
        // ✅ GOOD: Rigidbody manipulation, physics calculations
    }

    public override void OnExit(Scene scene)
    {
        // ✅ GOOD: Cleanup
        _hairUIPanel = null;
        _customizer = null;
        _hairPrefab = null;
        _costumeData = null;

        Plugin!.Logger.LogInfo("Exited CharacterCreator scene");
    }
}
```

## 🎯 **Best Practices**

### **✅ DO:**
- **OnEnter:** Load assets, initialize non-GameObject data
- **OnReady:** Access framework contexts, prepare data
- **OnAwake:** Find and cache GameObject references
- **OnStart:** Interact with other scripts' components
- **OnExit:** Null out all references for cleanup

### **❌ DON'T:**
- Don't call `GameObject.Find()` in OnEnter or OnReady (will return null!)
- Don't assume other scripts are initialized in OnAwake (use OnStart instead)
- Don't forget to cleanup references in OnExit (memory leaks!)
- Don't do heavy processing in OnUpdate without checking performance

## 🔍 **Debugging Tips**

### **GameObject.Find() Returns Null?**
```csharp
public override void OnReady(Scene scene)
{
    // ❌ TOO EARLY
    var obj = GameObject.Find("/Canvas/...");  // null!
}

public override void OnAwake()
{
    // ✅ NOW IT WORKS
    var obj = GameObject.Find("/Canvas/...");  // Found!

    if (obj == null)
    {
        // Actually not found - check the path
        Debug.LogError("GameObject not found - check the hierarchy path!");
    }
}
```

### **Component Not Initialized?**
```csharp
public override void OnAwake()
{
    var obj = GameObject.Find("/Canvas/...");
    var controller = obj.GetComponent<SomeController>();

    // ❌ Component might not be initialized yet
    controller.DoSomething();  // Might fail!
}

public override void OnStart()
{
    var obj = GameObject.Find("/Canvas/...");
    var controller = obj.GetComponent<SomeController>();

    // ✅ Component is now initialized
    controller.DoSomething();  // Works!
}
```

## 📊 **State Transition Diagram**

```
┌──────────────┐
│    Exited    │  Initial state
└──────┬───────┘
       │ Scene loads
       ▼
┌──────────────┐
│   Entering   │  OnEnter() called
└──────┬───────┘
       │ Context ready (or no context)
       ▼
┌──────────────┐
│    Active    │  OnReady() → OnAwake() → OnStart()
│              │  OnUpdate() / OnFixedUpdate() loop
└──────┬───────┘
       │ Scene unloads
       ▼
┌──────────────┐
│   Exiting    │  OnExit() called
└──────┬───────┘
       │
       ▼
┌──────────────┐
│    Exited    │  Back to initial state
└──────────────┘
```

## 🚀 **Performance Considerations**

### **OnUpdate / OnFixedUpdate**
- Only override if you actually need per-frame logic
- These are called every frame/physics tick - can impact performance
- Consider using coroutines for periodic tasks instead

### **GameObject.Find()**
- Expensive operation - only call once in OnAwake()
- Cache the result, don't call every frame
- Use direct references when possible

```csharp
private GameObject? _cachedPanel;

public override void OnAwake()
{
    // ✅ GOOD: Cache once
    _cachedPanel = GameObject.Find("/Canvas/...");
}

public override void OnUpdate()
{
    // ✅ GOOD: Use cached reference
    if (_cachedPanel != null)
    {
        // Do something
    }

    // ❌ BAD: Finding every frame!
    // var panel = GameObject.Find("/Canvas/...");
}
```

---

**Remember:** The lifecycle is designed to match Unity's natural flow. Use the right hook for the right timing! 🎯
