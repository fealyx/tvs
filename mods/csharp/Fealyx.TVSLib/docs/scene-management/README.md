# TVSLib Scene State Management System

A structured, declarative scene lifecycle management system for BepInEx plugins that eliminates boilerplate and provides clean separation of scene-specific logic.

## 🎯 **Why Use Scene States?**

### The Problem (Manual Approach)
```csharp
// Boilerplate nightmare
public override void Initialize()
{
    SceneManager.sceneLoaded += OnSceneLoaded;
    SceneManager.sceneUnloaded += OnSceneUnloaded;
}

private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
{
    if (scene.name == "MainMenu")
    {
        InitializeMainMenu();
    }
    else if (scene.name == "MainScene")
    {
        InitializeGame();
    }
    // ... more if/else chains
}

private void OnSceneUnloaded(Scene scene)
{
    if (scene.name == "MainMenu")
    {
        CleanupMainMenu();
    }
    // ... more cleanup
}
```

### The Solution (Scene States)
```csharp
// Clean and declarative!
public override void Initialize()
{
    base.Initialize();

    Scenes.Register(new MainMenuState());
    Scenes.Register(new GameState());
}

public class MainMenuState : SceneState
{
    public override string SceneName => "MainMenu";

    public override void OnEnter(Scene scene)
    {
        // Initialize menu - called automatically!
    }

    public override void OnExit(Scene scene)
    {
        // Cleanup - called automatically!
    }
}
```

## ✨ **Features**

- ✅ **Declarative** - Each scene gets its own class
- ✅ **Automatic cleanup** - No manual unsubscribe needed
- ✅ **Priority ordering** - Control execution order
- ✅ **State transitions** - Track state lifecycle (Entering → Active → Paused → Exiting → Exited)
- ✅ **Update loops** - Optional `OnUpdate()` and `OnFixedUpdate()` per scene
- ✅ **Attribute-based** - Auto-discover states with `[SceneState]`
- ✅ **Pause/Resume** - Temporarily suspend state updates
- ✅ **Backward compatible** - Old event-based approach still works

## 🚀 **Quick Start**

### Method 1: Simple Registration

```csharp
[BepInPlugin("com.example.myplugin", "My Plugin", "1.0.0")]
public class MyPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // Register scene states
        Scenes.Register(new MainMenuState());
        Scenes.Register(new GameState());
    }
}

// Define your states
public class MainMenuState : SceneState
{
    public override string SceneName => "MainMenu";
    public override int Priority => 100; // Higher = runs first

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Main menu loaded!");
        // Load menu UI, initialize settings, etc.
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo("Leaving main menu");
        // Cleanup menu resources
    }
}

public class GameState : SceneState
{
    public override string SceneName => "MainScene";

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Game started!");
        // Initialize game systems
    }

    public override void OnUpdate()
    {
        // Called every frame while game is active
    }
}
```

### Method 2: Attribute-Based (Recommended)

```csharp
[BepInPlugin("com.example.myplugin", "My Plugin", "1.0.0")]
public class MyPlugin : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        // Auto-discover all [SceneState] attributed classes!
        Scenes.RegisterAllStates();
    }
}

// Just add the attribute!
[SceneState("MainMenu", Priority = 100)]
public class MainMenuState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Main menu loaded!");
    }
}

[SceneState("MainScene", Priority = 50)]
public class GameState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Game started!");
    }
}
```

## 📚 **API Reference**

### SceneState Base Class

```csharp
public abstract class SceneState : IDisposable
{
    // Required: Scene this state manages
    public abstract string SceneName { get; }

    // Optional: Execution priority (default: 0, higher runs first)
    public virtual int Priority => 0;

    // Lifecycle hooks
    public virtual void OnEnter(Scene scene) { }     // Scene loaded
    public virtual void OnExit(Scene scene) { }      // Scene unloaded
    public virtual void OnUpdate() { }               // Every frame
    public virtual void OnFixedUpdate() { }          // Every physics update
    public virtual void OnPause() { }                // State paused
    public virtual void OnResume() { }               // State resumed
    public virtual void Dispose() { }                // Cleanup

    // State management
    public void Pause();                             // Pause updates
    public void Resume();                            // Resume updates
    public SceneStateTransition Transition { get; }  // Current state

    // Access plugin
    protected BaseTVSPlugin Plugin { get; }
}
```

### PluginScenes (Your Interface)

```csharp
// Available as: Scenes property on BaseTVSPlugin
public class PluginScenes
{
    // Register individual states
    void Register(SceneState state);

    // Auto-discover states with [SceneState] attribute
    void RegisterAllStates();

    // Scene queries
    string CurrentScene { get; }
    bool IsSceneActive(string sceneName);

    // Inspection
    IReadOnlyList<SceneState> RegisteredStates { get; }
}
```

### SceneStateAttribute

```csharp
[SceneState("SceneName", Priority = 100)]
public class MyState : SceneState { }
```

### SceneStateTransition Enum

```csharp
public enum SceneStateTransition
{
    Entering,   // OnEnter() being called
    Active,     // Receiving updates
    Paused,     // Updates suspended
    Exiting,    // OnExit() being called
    Exited      // Fully cleaned up
}
```

## 💡 **Usage Patterns**

### Pattern 1: Asset Loading in Scenes

```csharp
[SceneState("MainScene")]
public class GameState : SceneState
{
    private GameObject? _playerPrefab;

    public override void OnEnter(Scene scene)
    {
        // Load game-specific assets
        _playerPrefab = Plugin.Assets.LoadAsset<GameObject>("player.bundle", "Hero");
        Instantiate(_playerPrefab);
    }

    public override void OnExit(Scene scene)
    {
        // Assets auto-cleaned by plugin, but you can unload early
        Plugin.Assets.UnloadBundle("player.bundle");
    }
}
```

### Pattern 2: Per-Frame Logic

```csharp
[SceneState("MainScene")]
public class GameLoopState : SceneState
{
    private float _timer;

    public override void OnEnter(Scene scene)
    {
        _timer = 0f;
    }

    public override void OnUpdate()
    {
        _timer += Time.deltaTime;

        if (Input.GetKeyDown(KeyCode.Escape))
        {
            // Handle pause, etc.
            Pause();
        }
    }

    public override void OnPause()
    {
        Plugin.Logger.LogInfo("Game paused");
        // Pause game logic
    }

    public override void OnResume()
    {
        Plugin.Logger.LogInfo("Game resumed");
    }
}
```

### Pattern 3: Priority Ordering

```csharp
// Core systems initialize first
[SceneState("MainScene", Priority = 100)]
public class CoreGameState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Initialize core systems
    }
}

// UI initializes after core systems
[SceneState("MainScene", Priority = 50)]
public class GameUIState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Initialize UI (core systems already ready)
    }
}

// Player spawns last
[SceneState("MainScene", Priority = 10)]
public class PlayerState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        // Spawn player (everything else ready)
    }
}
```

### Pattern 4: Shared State Between Scenes

```csharp
// State that exists across multiple scenes
public class PersistentDataState : SceneState
{
    private PlayerData _data;

    public override string SceneName => "MainMenu"; // Initial scene

    public override void OnEnter(Scene scene)
    {
        // Load persistent data
        _data = LoadPlayerData();
    }

    public override void OnExit(Scene scene)
    {
        // Save before leaving
        SavePlayerData(_data);
    }
}
```

## 🎨 **State Lifecycle Flow**

```
Scene Load Event
  ↓
SceneManager.HandleSceneLoaded()
  ↓
TransitionStates(Entering)
  ↓
For each state (sorted by priority, high → low):
  ├─> Set transition to Entering
  ├─> Call state.OnEnter(scene)
  ├─> Set transition to Active
  └─> Add to update loops (if OnUpdate/OnFixedUpdate implemented)
  ↓
Unity Update Loop
  ↓
For each Active state:
  └─> Call state.OnUpdate()
  ↓
Unity FixedUpdate Loop
  ↓
For each Active state:
  └─> Call state.OnFixedUpdate()
  ↓
Scene Unload Event
  ↓
TransitionStates(Exiting)
  ↓
For each state (sorted by priority, low → high):
  ├─> Set transition to Exiting
  ├─> Call state.OnExit(scene)
  ├─> Set transition to Exited
  └─> Remove from update loops
```

## 🔧 **Advanced Features**

### Manual Pause/Resume

```csharp
public class PausableGameState : SceneState
{
    public override string SceneName => "MainScene";

    public void HandlePauseInput()
    {
        if (Transition == SceneStateTransition.Active)
        {
            Pause(); // Stops OnUpdate calls, fires OnPause()
        }
        else if (Transition == SceneStateTransition.Paused)
        {
            Resume(); // Resumes OnUpdate calls, fires OnResume()
        }
    }
}
```

### Checking Current Scene

```csharp
public override void Initialize()
{
    base.Initialize();

    // Check what scene we're in
    Plugin.Logger.LogInfo($"Current scene: {Scenes.CurrentScene}");

    if (Scenes.IsSceneActive("MainMenu"))
    {
        // Do menu-specific initialization
    }
}
```

### Inspecting Registered States

```csharp
public override void Initialize()
{
    base.Initialize();

    Scenes.RegisterAllStates();

    foreach (var state in Scenes.RegisteredStates)
    {
        Plugin.Logger.LogInfo($"Registered: {state.GetType().Name} for {state.SceneName}");
    }
}
```

## ⚙️ **Best Practices**

### 1. **Use Attributes for Clean Code**
```csharp
// ✅ Good: Declarative and discoverable
[SceneState("MainScene", Priority = 100)]
public class GameState : SceneState { }

// ❌ Avoid: Manual override unless dynamic
public class GameState : SceneState
{
    public override string SceneName => "MainScene";
}
```

### 2. **Order States by Priority**
```csharp
// Higher priority = initializes first, cleans up last
[SceneState("MainScene", Priority = 100)]  // Core systems
[SceneState("MainScene", Priority = 50)]   // Gameplay
[SceneState("MainScene", Priority = 10)]   // UI/Effects
```

### 3. **Keep States Focused**
```csharp
// ✅ Good: One responsibility per state
[SceneState("MainScene")] class GameLogicState : SceneState { }
[SceneState("MainScene")] class GameUIState : SceneState { }
[SceneState("MainScene")] class GameAudioState : SceneState { }

// ❌ Avoid: God object state
[SceneState("MainScene")] class EverythingState : SceneState { }
```

### 4. **Don't Forget Cleanup**
```csharp
public override void OnEnter(Scene scene)
{
    _coroutine = Plugin.StartCoroutine(MyCoroutine());
}

public override void OnExit(Scene scene)
{
    if (_coroutine != null)
    {
        Plugin.StopCoroutine(_coroutine);
    }
}
```

## 🔄 **Migration from Manual Events**

### Before
```csharp
public override void Initialize()
{
    TVS.Scenes.OnSceneLoaded += HandleSceneLoaded;
    TVS.Scenes.OnSceneUnloaded += HandleSceneUnloaded;
}

private void HandleSceneLoaded(Scene scene)
{
    if (scene.name == "MainScene")
    {
        InitGame();
    }
}

private void OnDestroy()
{
    TVS.Scenes.OnSceneLoaded -= HandleSceneLoaded;
    TVS.Scenes.OnSceneUnloaded -= HandleSceneUnloaded;
}
```

### After
```csharp
public override void Initialize()
{
    Scenes.RegisterAllStates();
}

[SceneState("MainScene")]
public class GameState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        InitGame();
    }
}
// No manual cleanup needed!
```

## 🚨 **Troubleshooting**

### States Not Being Called

**Check:**
1. Did you call `Scenes.Register()` or `Scenes.RegisterAllStates()`?
2. Is the `SceneName` correct? (case-sensitive!)
3. Did you add the `[SceneState]` attribute?
4. Is the class `public` and not `abstract`?

### Updates Not Running

**Check:**
1. Is `OnUpdate()` overridden (not just empty base)?
2. Is the state `Active`? (check `state.Transition`)
3. Is the state paused? (call `Resume()`)

### Priority Not Working

**Remember:**
- Higher number = higher priority = runs **first**
- OnEnter: High → Low
- OnExit: Low → High (reverse order)

## 📊 **Comparison**

| Feature | Manual Events | Scene States |
|---------|--------------|--------------|
| **Boilerplate** | High (subscribe/unsubscribe) | Low (just register) |
| **Structure** | Scattered in methods | One class per scene |
| **Cleanup** | Manual (easy to forget) | Automatic |
| **Priority** | Manual ordering | Built-in |
| **Updates** | Manual Update() | Per-state OnUpdate() |
| **Testability** | Hard | Easy (mock states) |
| **Readability** | Medium | High |

## 🎓 **Future Enhancements**

The following features are planned for future versions:

### Dependency Ordering (v2)
```csharp
public override IEnumerable<string> RunAfter => new[] { "CorePlugin.GameState" };
public override IEnumerable<string> RunBefore => new[] { "UIPlugin.MenuState" };
```

### Scene State History (v3)
```csharp
var history = Scenes.GetStateHistory();
Scenes.ReplayStates(history);
```

### Hot-Reloading (v3)
```csharp
Scenes.ReloadState<GameState>();
```

### Debug Visualization (v3)
```csharp
Scenes.ShowStateGraph(); // Visual dependency graph
```

---

**Status**: ✅ Phase 1 Complete - Ready for production!
**Developer Happiness**: 📈 Significantly increased!
