using UnityEngine;
using UnityEngine.SceneManagement;

using Fealyx.TVSLib.SceneManagement;
using System;


namespace Fealyx.HairTest;

/**
 * This was a failed effort to inject a new hair item into the character creator by directly modifying
 * the scene hierarchy. Currently left in place for reference.
 * 
 * The failure was due to the fact that the scene hierarchy seems to initialize in a non-deterministic
 * order, making it difficult to find a reliable entry point for modifying the UI before it initializes.
 * 
 * The chosen solution is to instead use a Harmony patch on the ZNECharacterItemPanel.Start() method,
 * which is the main controller for the item lists in the character creator UI.
 **/
// Commented out to stop the framework from loading this state.
// [SceneState("CharacterCreator", Priority = 100)]
public class CharacterCreatorState : SceneState
{
    /**
     * TODO: misc notes:
     *   - TODO: write literally all of the notes in this file into something more usable.
     *   - ZNECharacterItemPanel seems to be the main controller for the character creator item UI.
     *     It has a serialized array of ZNECostumeData SOs which it uses to instantiate buttons for
     *     each item.
     *     - It's `Start()` message is also a bitch to target - finding a canonical entrypoint between
     *       scene load and hierachy initialization - debatably impossible. `Awake()` happens on init,
     *       the scene hierarchy seems to init randomly... So much easier to just Harmony path things.
     **/
    private GameObject? _hairPrefab;
    private Sprite? _hairIcon;
    private ZNECostumeData? _costumeData;
    private ZNECharacterItemPanel? _hairSectionUIController;

    public override void OnReady(Scene scene)
    {
        _hairPrefab = Plugin!.Assets.LoadAsset<GameObject>("hair", "assets/@hairtest/toulousehair.fbx");

        if (_hairPrefab == null)
        {
            Logger.LogError("Failed to load hair prefab.");
            return;
        }

        _hairIcon = Plugin.Assets.LoadAsset<Sprite>("hair", "assets/@hairtest/icon.png");

        if (_hairIcon == null)
        {
            Logger.LogError("Failed to load hair icon.");
            return;
        }

        // The game's prefabs have this component and it's reference to the associated ZNECostumeData SO already baked in.
        // Adding manually here, but it may be worth figuring out how to author the costume data (or a custom precursor) in the FBX itself so it's automatically included when imported as a prefab.
        _costumeData = CreateCostumeData();

        // (Relying on BepInEx's Assembly Publicizer to access the private member)
        _hairPrefab.AddComponent<ZNECostumeDataRef>()._costumeData = _costumeData;
    }

    public override void OnAwake()
    {
        // TODO: check for race conditions - this needs to happen before the panel Start()s. Also may be
        // too early or too late in the scene lifecycle...
        // - We're too early - seems like the scene hierarchy isn't fully available yet.
        var hairUISection = GameObject.Find("/Canvas/Customize-Section/Customize-Panels/Customize-Hair");

        if (hairUISection == null)
        {
            Logger.LogError("Failed to find hair UI section.");
            return;
        }

        // Shim our new item into the hair UI section's controller so it will instantiate a button for it.
        _hairSectionUIController = hairUISection.GetComponent<ZNECharacterItemPanel>();

        var items = new ZNECostumeData[_hairSectionUIController._items.Length + 1];
        Array.Copy(_hairSectionUIController._items, items, _hairSectionUIController._items.Length);
        items[^1] = _costumeData!;

        Logger.LogInfo($"Adding costume data to hair section UI controller: {items.Length} items total.");
    }

    public ZNECostumeData CreateCostumeData()
    {
        /**
         * Miscellaneous ZNECostumeData notes:
         *   - GetItem() initializes a QCostume.CostumeItem instance from a "Cloth/{costumeName}" resource.
         *     I don't think we can reasonably override this behavior, short of a Harmony patch. But here
         *     we can just preload the `costumeItem` member to short-circuit the Resource request with our
         *     custom CostumeItem.
         *     - The CostumeItem uses a copy of the ZNEAdditionalCostumeData from the SO.
         *   - Circular relationship between ZNECostumeData SO, prefab, CostumeItem instance:
         *     - The prefab references the ZNECostumeData SO via a ZNECostumeDataRef component on the root GO.
         *     - The SO initializes a CostumeItem instance with `targetObject` pointing back to the prefab.
         *   - TODO: CostumeDatas are registered to the ZNERandomizeData SO
         *   - CostumeDatas appear to be added and removed for the current character by ZNECharacterCustomizer.
         *     - QCostume.CostumeBuilder handles the actual cloning, bone merge of the prefab.
         *   - ZNEClothItemUI displays an item in the accessory lists... TODO: is it the main consumer???
         *     - Translation key takes the form `CC-{displayName}`.
         *     - I think these are just serialized into the CharacterCreator scene?
         *   - ZNECharacter.loadCharacterActualCo() seems to be hard-coded to load accessories using the
         *     "Cloth/{costumeName}" resource path...
         *     - TODO: easiest path might be to use a Harmony patch to shim in logic for our custom CostumeDatas.
         *       This would also make it unecessary to preload the `costumeItem` member.
         *   - TODO: still not seeing a central registry for CostumeDatas. They might explicitly be referenced
         *     from their corresponding ZNEClothItemUI instances in the CC for user manipulation, and then loaded
         *     based on the serialized costumeName from the character data when the character is loaded in the
         *     MainScene.
         **/
    _costumeData = ScriptableObject.CreateInstance<ZNECostumeData>();

        _costumeData.displayName = "ToulouseHair"; // Seems to have spaces auto-injected prior to display?
        _costumeData.costumeName = "Toulouse-Hair"; // Possibly only used for autoloading a Cloth/* resource.
        _costumeData.maskName = "hair";
        _costumeData.defaultColor = Color.black;
        _costumeData.icon = _hairIcon;
        _costumeData._defaultIcon = new Sprite(); // Tooltip: "Used for the auto-generated default custom material icon." // TODO: need to copy a reference to the default-mat-icon sprite.

        // TODO: this needs to examined more closely... Looks like it ties model blendshapes to UI sliders, or possibly provides the data necessary to dynamically generate sliders?
        // TODO: framework feature: could we maybe dynamically add generic position/scale blendshapes at runtime? Maybe easy since they deal with all vertices?
        _costumeData.morphs = new() 
        {
            //new ()
            //{
            //    sliderName = "Expand All",
            //    sliderTags = new()
            //    {
            //        new()
            //        {
            //            dnaTag = "ExpandAll",
            //            min = -1f,
            //            max = 1f,
            //            multiplier = 1f,
            //            inverted = false,
            //        }
            //    }
            //},

            //new ()
            //{
            //    sliderName = "Adjust Back",
            //    sliderTags = new()
            //    {
            //        new()
            //        {
            //            dnaTag = "AdjustBack",
            //            min = -1f,
            //            max = 1f,
            //            multiplier = 1f,
            //            inverted = false,
            //        }
            //    }
            //},
        };

        _costumeData._additionalCostumeData = new()
        {
            // Looks like most properties aren't relevant to hair.

            _helmetHairBlendName = "HideA", // TODO: learn 2 blend
            _helmetHairBlendshapeAmount = 100f,

            // TODO: Faber-Hair-Pigtails is using a "SeraphimBootsThightR" override? Why?
            // _characterBlendshapeOverrides = new BaseCharacterBlendshapeOverrides
            // _characterBlendshapeOverrideWeight = 100f,
        };

        _costumeData.customMaterialTabs = new()
        {

        };

        _costumeData.customMaterials = new()
        {

        };

        // Replicated ZNECostumeData.GetItem() instantiation logic.
        _costumeData.costumeItem = new QCostume.CostumeItem(_hairPrefab, _costumeData.maskName);
        _costumeData.costumeItem.additionalCostumeData = new ZNEAdditionalCostumeData(_costumeData._additionalCostumeData);

        return _costumeData;
    }
}
