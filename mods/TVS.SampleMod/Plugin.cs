using System.Collections.Generic;
using System.IO;
using BepInEx;
using UnityEngine;
using UnityEngine.SceneManagement;

using Fealyx.TVS.Oiia;


namespace TVS.SampleMod;

[BepInPlugin(MyPluginInfo.PLUGIN_GUID, MyPluginInfo.PLUGIN_NAME, MyPluginInfo.PLUGIN_VERSION)]
public class Plugin : BaseUnityPlugin
{
    public static Plugin Instance { get; private set; } = null!;

    public ZNESceneReferences? SceneReferences = null;
    public ZNEMainPlayer? MainPlayer = null;
    public Camera? MainCamera = null;
    public ZNEPlayer? Player = null;
    public ZNEMainMachineLoader? MainMachineLoader = null;
    public ZNEArmchairStageLightsController? DiscoController = null;
    public ZNEMainSceneLightsManager? LightsManager = null;

    public readonly string RootPath = Path.Combine(Paths.PluginPath, MyPluginInfo.PLUGIN_GUID);
    public AssetBundle? AssetBundle = null;
    public Color StageLightAOriginalColor = new Color(0.8f, 0.8f, 0.8f);
    public Color StageLightBOriginalColor = new Color(0.8f, 0.8f, 0.8f);
    public float StageLightAOriginalIntensity = 1f;
    public float StageLightBOriginalIntensity = 1f;

    public bool isOiiaTime = false;
    public bool isLightingModifiedForOiia = false;
    public CatController? OiiaController = null;

    protected void Awake()
    {
        Instance = this;

        Logger.LogInfo($"Loaded {MyPluginInfo.PLUGIN_NAME}");

        LoadAssetBundle();

        SceneManager.sceneLoaded += HandleSceneLoaded;
    }

    protected void Start()
    {
        SceneReferences = ZNESceneReferences.sharedInstance;

        if (SceneReferences == null)
        {
            Logger.LogError("Failed to find ZNESceneReferences in the scene.");
            return;
        }

        MainPlayer = ZNEMainPlayer.sharedInstance;

        if (MainPlayer == null)
        {
            Logger.LogError("Failed to find ZNEMainPlayer in the scene.");
            return;
        }

        MainCamera = MainPlayer.cam;
        Player = MainPlayer.player;
    }

    protected void LoadAssetBundle()
    {
        string path = Path.Combine(RootPath, "assets/oiiacat");

        if (!File.Exists(path))
        {
            Logger.LogError($"AssetBundle file not found at path: {path}");
            return;
        }

        AssetBundle = AssetBundle.LoadFromFile(path);

        if (AssetBundle == null)
        {
            Logger.LogError("Failed to load AssetBundle from file.");
            return;
        }

        Logger.LogInfo("AssetBundle loaded successfully. Contents:");
        foreach (string assetName in AssetBundle.GetAllAssetNames())
        {
            Logger.LogInfo($" - {assetName}");
        }
    }

    protected void HandleSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        Logger.LogInfo($"Scene loaded: {scene.name} (Mode: {mode})");

        switch (scene.name)
        {
            case "MainScene":
                HandleMainSceneLoaded();
                break;
            default:
                Logger.LogInfo("No specific handling for this scene.");
                break;
        }
    }

    protected void HandleMainSceneLoaded()
    {
        Logger.LogInfo("Main scene loaded. Initializing mod features...");

        MainMachineLoader = ZNEMainMachineLoader.sharedInstance;
        LightsManager = ZNEMainSceneLightsManager.instance;

        if (!MainMachineLoader)
        {
            Logger.LogError("Failed to find ZNEMainMachineLoader in the scene.");
            return;
        }

        if (!LightsManager)
        {
            Logger.LogError("Failed to find ZNEMainSceneLightsManager in the scene.");
            return;
        }

        LeanTween.addListener(4, HandleMachineLoaded);
    }

    protected void HandleMachineLoaded(LTEvent e)
    {
        ZNEMachineController machineController = e.GetData<ZNEMachineController>();
        ZNEMainMachine machineType = MainMachineLoader!.currentMachineType;
        GameObject machineObject = MainMachineLoader.currentMachine;

        Logger.LogInfo($"Machine loaded: {machineType} (Object: {machineObject.name})");

        switch (machineType)
        {
            case ZNEMainMachine.armchair:
                HandleArmchairLoaded((ZNEArmchairMachineController)machineController);
                break;
            default:
                Logger.LogInfo("No specific handling for this machine type.");
                break;
        }
    }

    protected void HandleArmchairLoaded(ZNEArmchairMachineController controller)
    {
        GameObject consoleUIObj = controller.armchairConsoleUI;
        DiscoController = controller.timelineController.discoLightsController;

        Logger.LogInfo($"Armchair console UI found: {consoleUIObj.name}");

        GameObject buttons = consoleUIObj.transform.Find("Buttons").gameObject;
        Transform oiiaButtonTransform = consoleUIObj.transform.Find("OiiaButton");

        if (oiiaButtonTransform)
            return;

        Logger.LogInfo("Failed to find OiiaButton in the console UI. Creating...");

        GameObject lastButton = buttons.transform.GetChild(buttons.transform.childCount - 1).gameObject;
        GameObject oiiaButton = Instantiate(lastButton, buttons.transform);
        oiiaButton.name = "OiiaButton";
        UnityEngine.UI.Button button = oiiaButton.GetComponent<UnityEngine.UI.Button>();

        if (button == null)
        {
            Logger.LogError("Failed to find Button component on OiiaButton. Oiia button will not work :'(");
            return;
        }

        Sprite oiiaButtonSprite = AssetBundle!.LoadAsset<Sprite>("assets/@oiia/textures/ethel-2.png");

        if (oiiaButtonSprite == null)
        {
            Logger.LogError("Failed to load OiiaButton sprite from AssetBundle.");
        }
        else
        {
            oiiaButton.GetComponent<UnityEngine.UI.Image>().sprite = oiiaButtonSprite;
        }

        button.interactable = true;
        button.onClick.AddListener(HandleOiiaButtonClicked);
    }

    protected void HandleOiiaButtonClicked()
    {
        if (isOiiaTime)
        {
            Logger.LogInfo("Stopping oiia time qq");

            OiiaController!.StopOiia();
            DiscoController!.turnOff();
            RestoreStageLights();
            OiiaController.GetComponent<MeshRenderer>().enabled = false;

            isOiiaTime = false;

            return;
        }

        Logger.LogInfo("Oiia time baby!");

        if (!OiiaController)
        {
            GameObject oiiaPrefab = AssetBundle!.LoadAsset<GameObject>("assets/@oiia/prefabs/oiiacat.prefab");

            if (oiiaPrefab == null)
            {
                Logger.LogError("Failed to load OiiaCat prefab from AssetBundle. Oiia time cancelled :'(");
                return;
            }

            GameObject oiiaAnchor = new GameObject("OiiaAnchor");
            oiiaAnchor.transform.position = new Vector3(0.4f, -1f, -205.5f);
            oiiaAnchor.transform.rotation = Quaternion.Euler(0, -100, 0);

            GameObject oiiaObj = Instantiate(oiiaPrefab);
            oiiaObj.transform.SetParent(oiiaAnchor.transform);

            OiiaController = oiiaObj.GetComponent<CatController>();

            if (OiiaController == null)
            {
                Logger.LogError("Failed to find CatController on OiiaCat instance. Oiia time cancelled :'(");
                Destroy(oiiaObj);
                return;
            }

            OiiaController.OnSpin += OiiaStageLights;
            OiiaController.OnIdle += RestoreStageLights;

            // TODO: figure out the asset bundle'd prefab and asmdef mismatch that's prevented the sequence from
            //   surviving the pipeline. We'll just manually reconstruct it, for now.
            if (OiiaController.sequence != null)
            {
                Logger.LogWarning("OiiaCat sequence survived the pipeline!! YOU FIXED IT!!! :D");
            }
            else
            {
                OiiaController.sequence = new List<CatController.OiiaAction>
                {
                    // Element 0
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Spinning,
                        duration = 1.5f,
                        speed = 2f
                    },

                    // Element 1
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Idle,
                        duration = 1.2f
                    },

                    // Element 2
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Spinning,
                        duration = 2.1f,
                        speed = 1f
                    },

                    // Element 3
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Idle,
                        duration = 1.2f
                    },

                    // Element 4
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Spinning,
                        duration = 2.2f,
                        speed = 1f
                    },

                    // Element 5
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Idle,
                        duration = 0.2f
                    },

                    // Element 6
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Spinning,
                        duration = 1.5f,
                        speed = 2f
                    },

                    // Element 5
                    new CatController.OiiaAction
                    {
                        state = CatController.OiiaState.Idle,
                        duration = 3f
                    },
                };
            }
        }
        else
        {
            OiiaController!.GetComponent<MeshRenderer>().enabled = true;
        }

        OiiaController.StartOiia();
        DiscoController!.turnOn();
        isOiiaTime = true;
    }

    protected void OiiaStageLights()
    {
        if (isLightingModifiedForOiia)
            return;

        isLightingModifiedForOiia = true;

        Logger.LogInfo("Oiia is spinning! Changing stage lights...");

        StageLightAOriginalColor = LightsManager!.stageLightA.color;
        StageLightBOriginalColor = LightsManager.stageLightB.color;
        StageLightAOriginalIntensity = LightsManager.stageLightA.intensity;
        StageLightBOriginalIntensity = LightsManager.stageLightB.intensity;

        LightsManager.domeLight.enabled = false;
        LightsManager.lampLight.enabled = false;
        LightsManager.lobbyLight.enabled = false;

        LightsManager.stageLightA.color = Color.green;
        LightsManager.stageLightB.color = Color.green;
        LightsManager.stageLightA.intensity = 2f;
        LightsManager.stageLightB.intensity = 2f;
    }

    protected void RestoreStageLights()
    {
        if (!isLightingModifiedForOiia)
            return;

        isLightingModifiedForOiia = false;

        Logger.LogInfo("Restoring stage lights to their original settings...");

        LightsManager!.stageLightA.color = StageLightAOriginalColor;
        LightsManager.stageLightB.color = StageLightBOriginalColor;
        LightsManager.stageLightA.intensity = StageLightAOriginalIntensity;
        LightsManager.stageLightB.intensity = StageLightBOriginalIntensity;

        LightsManager.domeLight.enabled = true;
        LightsManager.lampLight.enabled = true;
        LightsManager.lobbyLight.enabled = true;
    }
}
