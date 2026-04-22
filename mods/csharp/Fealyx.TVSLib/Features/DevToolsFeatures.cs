using System.Linq;
using HarmonyLib;

using Fealyx.TVSLib.Configuration;

namespace Fealyx.TVSLib.Features;

/// <summary>
/// Developer tool feature definitions.
/// Contains features for debugging and development purposes.
/// </summary>
public static class DevToolsFeatures
{
    /// <summary>
    /// Creates the DevTools feature group with all development tool features.
    /// </summary>
    public static SettingGroup CreateGroup(PluginManager manager)
    {
        return new SettingGroup("DevTools", "Development and debugging tools")
        {
            CreateAssemblyInspectorFeature(manager),
            CreateAssetLoggerFeature(manager),
        };
    }

    private static Feature CreateAssemblyInspectorFeature(PluginManager manager)
    {
        DevTools.AssemblyInspector? inspector = null;

        return new Feature(
            name: "AssemblyInspector",
            description: "Inspect loaded assemblies and their types",
            defaultEnabled: false,
            onEnable: f =>
            {
                inspector = new DevTools.AssemblyInspector(
                    manager.CreateSubLogger("AssemblyInspector")
                );

                var printTypes = f.GetSetting<bool>("PrintTypes").Value;
                inspector.PrintAssemblyInfo(printTypes);
            },
            onDisable: f =>
            {
                inspector = null;
            }
        )
        {
            new Setting<bool>("PrintTypes", "Print types in each assembly", defaultValue: false)
        };
    }

    private static Feature CreateAssetLoggerFeature(PluginManager manager)
    {
        Harmony? harmony = null;

        return new Feature(
            name: "AssetLogger",
            description: "Log asset and resource load events for debugging",
            defaultEnabled: false,
            onEnable: f =>
            {
                harmony = new Harmony("fealyx.tvslib.devtools.assetlogger");
                harmony.PatchAll(typeof(DevTools.AssetLogger));

                var patchCount = harmony.GetPatchedMethods().Count();
                manager.Logger.LogInfo($"AssetLogger enabled ({patchCount} methods patched)");
            },
            onDisable: f =>
            {
                if (harmony != null)
                {
                    harmony.UnpatchSelf();
                    manager.Logger.LogInfo("AssetLogger disabled");
                    harmony = null;
                }
            }
        );
    }

    //private static Feature CreateSceneDebuggerFeature(PluginManager manager)
    //{
    //    return new Feature(
    //        name: "SceneDebugger",
    //        description: "Log scene lifecycle events and transitions",
    //        defaultEnabled: false,
    //        onEnable: f =>
    //        {
    //            // TODO: Implement scene debugging hooks
    //            manager.Logger.LogInfo("Scene debugger enabled");
    //        },
    //        onDisable: f =>
    //        {
    //            // TODO: Clean up scene debugging hooks
    //            manager.Logger.LogInfo("Scene debugger disabled");
    //        }
    //    );
    //}
}
