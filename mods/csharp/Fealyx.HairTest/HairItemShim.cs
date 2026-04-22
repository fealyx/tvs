using System;

using UnityEngine;


namespace Fealyx.HairTest;

public class HairItemShim
{
    private TVSPlugin _plugin;
    private GameObject? _hairPrefab;
    private Sprite? _hairIcon;
    private ZNECostumeData? _costumeData;
    private ZNECharacterItemPanel? _itemPanelController;

    public HairItemShim(TVSPlugin plugin)
    {
        _plugin = plugin;
        _hairPrefab = plugin.Assets.LoadAsset<GameObject>("hair", "assets/@hairtest/toulousehair.fbx");

        if (_hairPrefab == null)
        {
            plugin.Logger.LogError("Failed to load hair prefab.");
            return;
        }

        _hairIcon = plugin.Assets.LoadAsset<Sprite>("hair", "assets/@hairtest/icon.png");

        if (_hairIcon == null)
        {
            plugin.Logger.LogError("Failed to load hair icon.");
            return;
        }

        _costumeData = CreateCostumeData();
        _hairPrefab.AddComponent<ZNECostumeDataRef>()._costumeData = _costumeData;
    }

    private ZNECostumeData CreateCostumeData()
    {
        _costumeData = ScriptableObject.CreateInstance<ZNECostumeData>();

        _costumeData.displayName = "ToulouseHair";
        _costumeData.costumeName = "Toulouse-Hair";
        _costumeData.maskName = "hair";
        _costumeData.defaultColor = Color.black;
        _costumeData.icon = _hairIcon;
        _costumeData._defaultIcon = new Sprite();

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
            _helmetHairBlendName = "HideA", // TODO: learn 2 blend
            _helmetHairBlendshapeAmount = 100f,

            // TODO: Faber-Hair-Pigtails is using a "SeraphimBootsThightR" override? Why?
            // _characterBlendshapeOverrides = new BaseCharacterBlendshapeOverrides
            // _characterBlendshapeOverrideWeight = 100f,

            // TODO: Investigate the `UBER - Specular Setup/2 Sided/ Core SEPARATE CUTOUT is missing` error from ZNECharacter.CheckIfShouldUseTwoSidedShader()... Maybe not relevant
            //_useDoubleSidedSkin = true,
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
    
    public void InjectInto(ZNECharacterItemPanel itemPanelController)
    {
        if (_itemPanelController != null)
        {
            _plugin.Logger.LogError("Attempting to inject hair item into multiple item panels. This may cause issues.");
            return;
        }

        _itemPanelController = itemPanelController;

        if (_costumeData == null || _hairIcon == null || _hairPrefab == null)
        {
            _plugin.Logger.LogError("Cannot inject hair item: uninitialized.");
            return;
        }

        _plugin.Logger.LogInfo($"Adding costume data to item panel controller: {itemPanelController._items.Length} items total.");

        var items = new ZNECostumeData[itemPanelController._items.Length + 1];
        Array.Copy(itemPanelController._items, items, itemPanelController._items.Length);
        items[^1] = _costumeData;
        itemPanelController._items = items;

        _plugin.Logger.LogInfo($"Injected hair item. Item panel now has {itemPanelController._items.Length} items.");
    }
}
