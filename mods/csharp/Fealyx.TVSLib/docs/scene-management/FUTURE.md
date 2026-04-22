# Scene State Management - Future Enhancements

This document outlines planned features and enhancements for future versions of the Scene State Management system.

## 📋 **Phase 2: Enhanced Features**

### 1. ✅ ~~Attribute-Based Registration~~ (COMPLETED)
Already implemented in Phase 1!

### 2. 🔮 Scene-Specific Helpers
**Status**: To be discussed

Provide specialized base classes or helpers for specific scene types that offer convenience methods and utilities relevant only to that scene context.

**Potential Approaches:**

#### Option A: Scene-Specific Base Classes
```csharp
// Base class with game-specific helpers
public abstract class GameSceneState : SceneState
{
    public override string SceneName => "MainScene";

    // Convenience properties
    protected Player Player => FindPlayer();
    protected GameManager GameManager => FindGameManager();

    // Helper methods
    protected void SpawnEnemy(Vector3 position) { }
    protected void ShowGameUI() { }
}

// Usage
public class MyGameFeature : GameSceneState
{
    public override void OnEnter(Scene scene)
    {
        Player.Health = 100; // Easy access!
    }
}
```

#### Option B: Context Objects
```csharp
public class GameSceneContext
{
    public Player Player { get; set; }
    public GameManager Manager { get; set; }
    // ... other game-specific objects
}

public class GameState : SceneState
{
    private GameSceneContext _context;

    public override void OnEnter(Scene scene)
    {
        _context = FindGameContext();
    }
}
```

#### Option C: Service Locator Pattern
```csharp
public class SceneServices
{
    public T Get<T>() where T : class;
    public void Register<T>(T service) where T : class;
}

// States can request services
public class GameState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        var player = Services.Get<Player>();
        var manager = Services.Get<GameManager>();
    }
}
```

**Questions to Discuss:**
- How to organize scene-specific utilities?
- Should they be in the framework or user-defined?
- How to handle dependencies between scene-specific services?
- Should there be dependency injection?

---

## 🚀 **Phase 3: Advanced Features**

### 1. Dependency Ordering (RunBefore/RunAfter)

**Goal**: Allow states to declare dependencies on other states for initialization ordering beyond simple priority.

**Proposed API:**
```csharp
public class UIState : SceneState
{
    public override string SceneName => "MainScene";

    // This state must run after CoreGameState
    public override IEnumerable<string> RunAfter => new[] 
    { 
        "CorePlugin.CoreGameState",
        "DataPlugin.GameDataState"
    };

    // This state must run before EffectsState
    public override IEnumerable<string> RunBefore => new[]
    {
        "EffectsPlugin.EffectsState"
    };
}
```

**Implementation Considerations:**
- Use topological sort to resolve dependency graph
- Detect circular dependencies
- Handle missing dependencies gracefully
- Combine with priority for final ordering

**Challenges:**
- State naming/identification (full type name? custom IDs?)
- Cross-plugin dependencies
- Versioning (what if dependency changes?)

---

### 2. Scene State History & Replay

**Goal**: Record state transitions and events for debugging, testing, or replay functionality.

**Proposed API:**
```csharp
// Recording
var recorder = Scenes.StartRecording();
// ... play game ...
var history = recorder.StopRecording();

// Replay
Scenes.ReplayHistory(history);

// Inspection
foreach (var entry in history.Entries)
{
    Logger.LogInfo($"{entry.Timestamp}: {entry.State.GetType().Name} -> {entry.Transition}");
}

// Serialization for bug reports
var json = history.ToJson();
File.WriteAllText("scene_history.json", json);
```

**Use Cases:**
- Debugging state transition bugs
- Automated testing
- Cinematic replays
- Bug report attachments

**Implementation:**
- Capture all state transitions
- Record OnEnter/OnExit calls
- Optional: Record input events
- Optional: Record game state snapshots

---

### 3. Hot-Reloading Support

**Goal**: Reload scene states at runtime without restarting the game (for development).

**Proposed API:**
```csharp
// Reload a specific state type
Scenes.ReloadState<GameUIState>();

// Reload all states for current scene
Scenes.ReloadCurrentSceneStates();

// Reload all states across all scenes
Scenes.ReloadAllStates();
```

**Implementation:**
- Save current state data
- Dispose old state instance
- Create new state instance (reloaded assembly)
- Restore state data
- Re-call OnEnter if scene is active

**Challenges:**
- Preserving state across reload
- Assembly reloading in Unity
- Handling state data serialization
- Managing references to reloaded types

---

### 4. Debug Visualization

**Goal**: Visual tools for understanding state lifecycle and dependencies.

**Proposed Features:**

#### A. State Dependency Graph
```csharp
// Show visual graph in Unity Editor or overlay
Scenes.ShowDependencyGraph();
```

Output:
```
[Priority: 100] CoreGameState
    ↓ (RunAfter)
[Priority: 50] GameplayState
    ↓ (RunAfter)
[Priority: 10] UIState
```

#### B. Runtime State Inspector
```csharp
// Show current states in ImGui overlay or Unity window
Scenes.ShowStateInspector();
```

Display:
- All active states
- Current transition
- Priority
- Dependencies
- Last update time
- Performance metrics

#### C. Performance Profiling
```csharp
var profile = Scenes.ProfileStates();

foreach (var entry in profile.Entries)
{
    Logger.LogInfo($"{entry.State}: OnUpdate={entry.UpdateTime:F2}ms, OnFixedUpdate={entry.FixedUpdateTime:F2}ms");
}
```

---

## 🎯 **Phase 4: Integration Features**

### 1. Unity Addressables Support

**Goal**: Integrate with Unity's Addressables system for asset loading in states.

```csharp
public override async void OnEnter(Scene scene)
{
    var handle = Addressables.LoadAssetAsync<GameObject>("Player");
    await handle.Task;
    _player = Instantiate(handle.Result);
}
```

---

### 2. Scene State Persistence

**Goal**: Save/load scene state data between sessions.

```csharp
public class GameState : SceneState, IStatePersistable
{
    public int Score { get; set; }

    public void SaveState(IStateWriter writer)
    {
        writer.Write("score", Score);
    }

    public void LoadState(IStateReader reader)
    {
        Score = reader.Read<int>("score");
    }
}

// Usage
Scenes.SaveStates("save_data.json");
Scenes.LoadStates("save_data.json");
```

---

### 3. Networked State Synchronization

**Goal**: Sync scene states across network for multiplayer.

```csharp
[SceneState("MainScene")]
[NetworkedState] // Auto-sync across network
public class MultiplayerGameState : SceneState
{
    [SyncVar] public int RoundNumber { get; set; }

    [NetworkedMethod]
    public void OnPlayerJoined(Player player)
    {
        // Called on all clients
    }
}
```

---

## 🔬 **Research & Exploration**

### 1. State Machine Integration

Explore integration with formal state machine patterns:
```csharp
public class GameState : SceneState
{
    private StateMachine<GamePhase> _phaseMachine;

    public override void OnEnter(Scene scene)
    {
        _phaseMachine = new StateMachine<GamePhase>()
            .State(GamePhase.Intro)
            .State(GamePhase.Playing)
            .State(GamePhase.GameOver);

        _phaseMachine.TransitionTo(GamePhase.Intro);
    }
}
```

### 2. Reactive Extensions (Rx) Support

Observable state transitions:
```csharp
Scenes.StateTransitions
    .Where(t => t.Transition == SceneStateTransition.Entering)
    .Subscribe(t => Logger.LogInfo($"{t.State.SceneName} entered"));
```

### 3. Behavior Trees for States

Complex state logic using behavior trees:
```csharp
public class AIGameState : SceneState
{
    private BehaviorTree _aiTree;

    public override void OnEnter(Scene scene)
    {
        _aiTree = new BehaviorTree()
            .Sequence(
                new CheckPlayerDistance(),
                new ChasePlayer(),
                new AttackPlayer()
            );
    }

    public override void OnUpdate()
    {
        _aiTree.Tick();
    }
}
```

---

## 📝 **Implementation Priority**

### High Priority (Next Version)
1. **Dependency Ordering** - Widely requested, clear value
2. **Debug Visualization** - Critical for developer experience

### Medium Priority
3. **Scene-Specific Helpers** - After architecture discussion
4. **State History** - Useful for debugging

### Low Priority (Future)
5. **Hot-Reloading** - Nice-to-have for development
6. **Addressables Integration** - If widely adopted
7. **Networked States** - Niche use case

### Research (Experimental)
- State machine patterns
- Reactive extensions
- Behavior trees

---

## 💬 **Feedback & Discussion**

Please provide feedback on:
1. Which features are most valuable to you?
2. Additional features you'd like to see?
3. API design preferences?
4. Use cases we haven't considered?

File issues or discussions at: [GitHub Repository]

---

**Last Updated**: Implementation of Phase 1
**Next Review**: After Phase 2 Item 2 discussion (Scene-Specific Helpers)
