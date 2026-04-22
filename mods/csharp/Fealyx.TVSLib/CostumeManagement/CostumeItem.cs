using System.Collections.Generic;

using UnityEngine;

namespace Fealyx.TVSLib.CostumeManagement;

/// <summary>
/// Represents a custom costume item that can be added to the game.
/// </summary>
public class CostumeItem
{
    public struct BlendshapeParams
    {
        public float? min;
        public float? max;
        public float? multiplier;
        public bool? inverted;
    }

    public delegate void TypeApplicator(CostumeItem item, ZNEAdditionalCostumeData addData);

    public static readonly Dictionary<Type, TypeApplicator> TypeApplicators = new()
    {
        { Type.Accessory, (CostumeItem item, ZNEAdditionalCostumeData addData) => {
            addData._dissolveGroup = ZNEAdditionalCostumeData.DissolveGroup.Accessory;
        } },
        { Type.Bodysuit, (CostumeItem item, ZNEAdditionalCostumeData addData) => {

        } },
        { Type.Bra, (CostumeItem item, ZNEAdditionalCostumeData addData) => {
            addData._dissolveGroup = ZNEAdditionalCostumeData.DissolveGroup.Underwear;
            addData._upperWear = ZNEAdditionalCostumeData.HiddenType.Underwear;
            addData._dissolvePriority = ZNEAdditionalCostumeData.DissolvePriority.Underwear_Top;
            addData._nipplesCovered = true;
            addData._nipplesVisible = false;
            addData._isBreastArmour = true;
        } },
        //{ Type.Eyewear, ApplyEyewear },
        //{ Type.Footwear, ApplyFootwear },
        { Type.Hair, (CostumeItem item, ZNEAdditionalCostumeData addData) => {
            addData._dissolveGroup = ZNEAdditionalCostumeData.DissolveGroup.NotSet;
            addData._dissolvePriority = ZNEAdditionalCostumeData.DissolvePriority.NotSet;
        } },
        //{ Type.Hat, ApplyHat },
        //{ Type.Helmet, ApplyHelmet },
        //{ Type.Legwear, ApplyLegwear },
        //{ Type.Mask, ApplyMask },
        //{ Type.Overwear, ApplyOverwear },
        //{ Type.Pants, ApplyPants },
        //{ Type.Shirt, ApplyShirt },
        //{ Type.Skirt, ApplySkirt },
        //{ Type.Underwear, ApplyUnderwear },
    };

    public enum Type
    {
        Accessory,
        Bodysuit,
        Bra,
        Eyewear,
        Footwear,
        Hair,
        Hat,
        Helmet,
        Legwear,
        Mask,
        Overwear,
        Pants,
        Shirt,
        Skirt,
        Underwear,
    }

    /// <summary>
    /// Unique identifier for this costume. Should be namespaced (e.g., "myplugin.superhero_cape").
    /// </summary>
    public string Id => $"{OwningPlugin?.Info.Metadata.GUID ?? "unknown"}.{Name.ToLower().Replace(" ", "-")}";

    /// <summary>
    /// Display name for the costume.
    /// </summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Description of the costume.
    /// </summary>
    public string Description { get; set; } = string.Empty;

    /// <summary>
    /// Category/slot for this costume (e.g., "Hat", "Shirt", "Pants", "Accessory").
    /// </summary>
    public string Category { get; set; } = string.Empty;

    /// <summary>
    /// Asset bundle containing the costume assets.
    /// Path will be resolved relative to plugin's AssetBundles directory.
    /// </summary>
    public string AssetBundle { get; set; } = string.Empty;

    /// <summary>
    /// Name of the prefab/FBX asset within the bundle.
    /// </summary>
    public string PrefabPath { get; set; } = string.Empty;

    /// <summary>
    /// Optional icon/preview asset name.
    /// </summary>
    public string IconPath { get; set; } = string.Empty;

    /// <summary>
    /// Optional metadata that can be used for custom logic.
    /// </summary>
    public Dictionary<string, object> Metadata { get; set; } = new();

    public Color DefaultColor { get; set; } = Color.white;

    public string MaskName => Category.ToLower(); // TODO: probably not consistent across TVS masks - was just going off of a hair item, here.

    public Dictionary<string, Dictionary<string, BlendshapeParams?>> Morphs { get; set; } = new();

    public GameObject Prefab
    {
        get
        {
            if (_prefab == null)
            {
                if (string.IsNullOrEmpty(PrefabPath))
                {
                    OwningPlugin!.Logger.LogError($"Costume '{Name}' does not have a prefab path specified.");
                    return null!;
                }

                var prefab = OwningPlugin!.Assets.LoadAsset<GameObject>(AssetBundle, PrefabPath);

                if (prefab == null)
                {
                    OwningPlugin.Logger.LogError($"Failed to load prefab for costume '{Name}' from bundle '{AssetBundle}' with path '{PrefabPath}'.");
                    return null!;
                }

                _prefab = prefab;
            }

            return _prefab;
        }
    }

    public Sprite Icon
    {
        get
        {
            if (_icon == null)
            {
                if (string.IsNullOrEmpty(IconPath))
                {
                    OwningPlugin!.Logger.LogWarning($"Costume '{Name}' does not have an icon path specified.");
                    return null!;
                }

                var icon = OwningPlugin!.Assets.LoadAsset<Sprite>(AssetBundle, IconPath);

                if (icon == null)
                {
                    OwningPlugin.Logger.LogError($"Failed to load icon for costume '{Name}' from bundle '{AssetBundle}' with path '{IconPath}'.");
                    return null!;
                }

                _icon = icon;
            }

            return _icon;
        }
    }

    public QCostume.CostumeItem QCostumeItem
    {
        get
        {
            if (_costumeItem == null)
            {
                _costumeItem = new QCostume.CostumeItem(Prefab, MaskName);
                _costumeItem.additionalCostumeData = AdditionalCostumeData;
            }

            return _costumeItem;
        }
    }

    public ZNEAdditionalCostumeData AdditionalCostumeData { get; set; } = new();

    private GameObject _prefab = null!;

    private Sprite _icon = null!;

    private QCostume.CostumeItem _costumeItem = null!;

    /// <summary>
    /// Reference to the owning plugin (set automatically by the framework).
    /// </summary>
    public BaseTVSPlugin? OwningPlugin { get; internal set; }

    public Type[] Types { get; set; } = null!;

    public void ApplyTypes()
    {
        if (Types == null || Types.Length == 0)
        {
            return;
        }

        foreach (var type in Types)
        {
            if (TypeApplicators.TryGetValue(type, out var applicator))
            {
                applicator(this, this.AdditionalCostumeData);
            }
            else
            {
                OwningPlugin?.Logger.LogWarning($"No applicator defined for costume type '{type}' on costume '{Name}'.");
            }
        }
    }

    public ZNECostumeData ToZNECostumeData()
    {
        var zcd = ScriptableObject.CreateInstance<ZNECostumeData>();

        zcd.displayName = Name;
        zcd.costumeName = Id;
        zcd.maskName = MaskName;
        zcd.defaultColor = DefaultColor;
        zcd.icon = Icon;
        zcd._defaultIcon = Icon; // TODO: investigate this further.
        zcd._additionalCostumeData = AdditionalCostumeData;

        zcd.morphs = new();

        foreach (var (sliderName, blendshapes) in Morphs)
        {
            var sliderData = new ZNECostumeData.MorphSliderData()
            {
                sliderName = sliderName,
            };

            foreach (var (name, data) in Morphs[sliderName])
            {
                var sliderTag = new ZNECustomizerSlider.SliderTag()
                {
                    dnaTag = name,
                    min = data?.min ?? 0f,
                    max = data?.max ?? 1f,
                    multiplier = data?.multiplier ?? 1f,
                    inverted = data?.inverted ?? false,
                };

                sliderData.sliderTags.Add(sliderTag);
            }

            zcd.morphs.Add(sliderData);
        }


        zcd.customMaterials = new()
        {
            //new ()
            //{
            //    materialName = "MyCustomMaterial",
            //    shaderName = "Standard",
            //    properties = new()
            //    {
            //        { "_Color", Color.red },
            //        { "_Glossiness", 0.5f },
            //    }
            //}
        };

        zcd.customMaterialTabs = new()
        {
            //new ()
            //{
            //    tabName = "My Custom Materials",
            //    materialNames = new() { "MyCustomMaterial" }
            //}
        };

        return zcd;
    }
}
