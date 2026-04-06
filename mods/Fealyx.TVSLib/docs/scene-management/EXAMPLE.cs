using System.Collections;
using BepInEx;
using UnityEngine;
using UnityEngine.SceneManagement;
using Fealyx.TVSLib;
using Fealyx.TVSLib.SceneManagement;

namespace Examples;

/// <summary>
/// Example plugin demonstrating the TVSLib scene state management system.
/// Shows multiple patterns: manual registration, attribute-based, priorities, and updates.
/// </summary>
[BepInPlugin("com.example.scenedemo", "Scene State Demo", "1.0.0")]
public class SceneStateExample : BaseTVSPlugin
{
    public override void Initialize()
    {
        base.Initialize();

        Logger.LogInfo("=== Scene State Management Demo ===");

        // Method 1: Manual registration
        RegisterStatesManually();

        // Method 2: Attribute-based auto-discovery (commented out to avoid duplicate)
        // Scenes.RegisterAllStates();

        // Check current scene
        Logger.LogInfo($"Current scene: {Scenes.CurrentScene}");
    }

    private void RegisterStatesManually()
    {
        Logger.LogInfo("Registering scene states manually...");

        Scenes.Register(new MainMenuManualState());
        Scenes.Register(new GameManualState());

        Logger.LogInfo($"Registered {Scenes.RegisteredStates.Count} states");
    }
}

// ============================================================================
// EXAMPLE 1: Manual Registration (Override Properties)
// ============================================================================

public class MainMenuManualState : SceneState
{
    public override string SceneName => "MainMenu";
    public override int Priority => 100; // High priority - initialize first

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("=== Main Menu State Entered ===");
        Plugin.Logger.LogInfo($"Scene: {scene.name}, Build Index: {scene.buildIndex}");

        // Initialize menu systems
        InitializeMenuUI();
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo("=== Main Menu State Exiting ===");

        // Cleanup menu resources
        CleanupMenuUI();
    }

    private void InitializeMenuUI()
    {
        Plugin.Logger.LogInfo("Initializing main menu UI...");
        // Load menu assets, set up UI, etc.
    }

    private void CleanupMenuUI()
    {
        Plugin.Logger.LogInfo("Cleaning up main menu UI");
    }
}

public class GameManualState : SceneState
{
    public override string SceneName => "MainScene";
    public override int Priority => 50; // Lower priority than menu

    private float _gameTimer;

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("=== Game State Entered ===");
        _gameTimer = 0f;

        // Initialize game systems
        InitializeGame();
    }

    public override void OnUpdate()
    {
        _gameTimer += Time.deltaTime;

        // Every 5 seconds, log the timer
        if (Mathf.FloorToInt(_gameTimer) % 5 == 0 && _gameTimer % 1 < Time.deltaTime)
        {
            Plugin.Logger.LogInfo($"Game running for {Mathf.FloorToInt(_gameTimer)} seconds");
        }
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo($"=== Game State Exiting (played for {_gameTimer:F1}s) ===");

        // Save game state, cleanup
        SaveGameState();
    }

    private void InitializeGame()
    {
        Plugin.Logger.LogInfo("Initializing game systems...");
        // Load player, spawn enemies, etc.
    }

    private void SaveGameState()
    {
        Plugin.Logger.LogInfo("Saving game state...");
    }
}

// ============================================================================
// EXAMPLE 2: Attribute-Based Registration
// ============================================================================

[SceneState("MainMenu", Priority = 100)]
public class MainMenuAttributeState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("[Attribute] Main menu loaded!");
    }
}

[SceneState("MainScene", Priority = 100)]
public class CoreGameState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("[Attribute] Core game systems initialized");
        // Initialize core systems first (high priority)
    }
}

[SceneState("MainScene", Priority = 50)]
public class GameplayState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("[Attribute] Gameplay systems initialized");
        // Initialize gameplay after core (medium priority)
    }
}

[SceneState("MainScene", Priority = 10)]
public class UIState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("[Attribute] UI initialized");
        // Initialize UI last (low priority)
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo("[Attribute] UI cleanup");
        // UI cleans up first (exit is reverse order)
    }
}

// ============================================================================
// EXAMPLE 3: Update Loops
// ============================================================================

[SceneState("MainScene")]
public class UpdateExampleState : SceneState
{
    private int _frameCount;
    private int _fixedFrameCount;

    public override void OnEnter(Scene scene)
    {
        _frameCount = 0;
        _fixedFrameCount = 0;
        Plugin.Logger.LogInfo("Update example state started");
    }

    public override void OnUpdate()
    {
        _frameCount++;

        // Log every 60 frames (~1 second at 60fps)
        if (_frameCount % 60 == 0)
        {
            Plugin.Logger.LogInfo($"Update called {_frameCount} times, FixedUpdate: {_fixedFrameCount}");
        }
    }

    public override void OnFixedUpdate()
    {
        _fixedFrameCount++;
        // Physics calculations here
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo($"Update example state ended. Updates: {_frameCount}, Fixed: {_fixedFrameCount}");
    }
}

// ============================================================================
// EXAMPLE 4: Pause/Resume
// ============================================================================

[SceneState("MainScene")]
public class PausableGameState : SceneState
{
    private bool _isPaused;

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Pausable game state started");
        _isPaused = false;
    }

    public override void OnUpdate()
    {
        // Check for pause input
        if (Input.GetKeyDown(KeyCode.P))
        {
            if (!_isPaused)
            {
                Pause();
            }
            else
            {
                Resume();
            }
        }

        // Game logic only runs when not paused
        if (!_isPaused)
        {
            // Game update logic
        }
    }

    public override void OnPause()
    {
        _isPaused = true;
        Plugin.Logger.LogInfo("Game paused");
        // Show pause menu, stop time, etc.
    }

    public override void OnResume()
    {
        _isPaused = false;
        Plugin.Logger.LogInfo("Game resumed");
        // Hide pause menu, resume time, etc.
    }
}

// ============================================================================
// EXAMPLE 5: Asset Loading Integration
// ============================================================================

[SceneState("MainScene")]
public class AssetLoadingGameState : SceneState
{
    private GameObject? _playerPrefab;
    private GameObject? _playerInstance;

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Loading game assets...");

        // Load assets using the asset management system
        _playerPrefab = Plugin.Assets.LoadAsset<GameObject>("player.bundle", "PlayerCharacter");

        if (_playerPrefab != null)
        {
            Plugin.Logger.LogInfo("Player prefab loaded successfully");

            // Spawn player
            _playerInstance = Object.Instantiate(_playerPrefab);
            Plugin.Logger.LogInfo("Player spawned");
        }
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo("Cleaning up game assets...");

        // Destroy spawned objects
        if (_playerInstance != null)
        {
            Object.Destroy(_playerInstance);
            Plugin.Logger.LogInfo("Player destroyed");
        }

        // Unload assets (optional - will auto-cleanup on plugin disposal)
        Plugin.Assets.UnloadBundle("player.bundle");
    }
}

// ============================================================================
// EXAMPLE 6: Coroutines in Scene States
// ============================================================================

[SceneState("MainScene")]
public class CoroutineExampleState : SceneState
{
    private Coroutine? _gameLoopCoroutine;

    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo("Starting game loop coroutine...");
        _gameLoopCoroutine = Plugin.StartCoroutine(GameLoopCoroutine());
    }

    public override void OnExit(Scene scene)
    {
        if (_gameLoopCoroutine != null)
        {
            Plugin.StopCoroutine(_gameLoopCoroutine);
            Plugin.Logger.LogInfo("Game loop coroutine stopped");
        }
    }

    private IEnumerator GameLoopCoroutine()
    {
        while (true)
        {
            Plugin.Logger.LogInfo("Game loop tick");
            yield return new WaitForSeconds(2f);
        }
    }
}

// ============================================================================
// EXAMPLE 7: State Transition Tracking
// ============================================================================

[SceneState("MainScene")]
public class TransitionTrackingState : SceneState
{
    public override void OnEnter(Scene scene)
    {
        Plugin.Logger.LogInfo($"State transition: {Transition} -> Entering");
    }

    public override void OnUpdate()
    {
        // Transition is now Active
        if (Transition == SceneStateTransition.Active)
        {
            // Do active stuff
        }
    }

    public override void OnPause()
    {
        Plugin.Logger.LogInfo($"State transition: {Transition} -> Paused");
    }

    public override void OnResume()
    {
        Plugin.Logger.LogInfo($"State transition: {Transition} -> Active");
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo($"State transition: {Transition} -> Exiting");
    }

    public override void Dispose()
    {
        Plugin.Logger.LogInfo($"State transition: {Transition} -> Exited");
    }
}

// ============================================================================
// EXAMPLE 8: Shared Data Between States
// ============================================================================

// Shared data class
public class GameSessionData
{
    public int Score { get; set; }
    public float PlayTime { get; set; }
    public string PlayerName { get; set; } = "Player";
}

[SceneState("MainMenu", Priority = 100)]
public class MenuDataState : SceneState
{
    private GameSessionData _sessionData = new();

    public override void OnEnter(Scene scene)
    {
        // Load saved data
        Plugin.Logger.LogInfo($"Loading session data: {_sessionData.PlayerName}");
    }

    public override void OnExit(Scene scene)
    {
        // Pass data to next scene or save it
        Plugin.Logger.LogInfo($"Session data: Score={_sessionData.Score}, Time={_sessionData.PlayTime:F1}s");
    }
}

[SceneState("MainScene", Priority = 100)]
public class GameDataState : SceneState
{
    private GameSessionData _sessionData = new();

    public override void OnUpdate()
    {
        _sessionData.PlayTime += Time.deltaTime;

        // Update score based on game events
        // _sessionData.Score += ...
    }

    public override void OnExit(Scene scene)
    {
        Plugin.Logger.LogInfo($"Game session ended: Score={_sessionData.Score}, Time={_sessionData.PlayTime:F1}s");
        // Save or transmit data
    }
}
