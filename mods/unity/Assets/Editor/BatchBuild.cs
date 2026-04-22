using System;
using System.IO;
using System.Linq;
using UnityEditor;

namespace TVS.Mods.Unity.Editor
{
    public static class BatchBuild
    {
        private const string OutputArg = "-assetBundleOutputPath";
        private const string TargetArg = "-assetBundleTarget";

        public static void BuildAll()
        {
            BuildAssetBundles();
        }

        public static void BuildAssetBundles()
        {
            var outputPath = GetArgValue(OutputArg) ?? "Builds/AssetBundles/Windows64";
            var targetValue = GetArgValue(TargetArg) ?? BuildTarget.StandaloneWindows64.ToString();

            if (!Enum.TryParse(targetValue, ignoreCase: true, out BuildTarget target))
            {
                throw new ArgumentException($"Invalid Unity BuildTarget: {targetValue}");
            }

            if (!Directory.Exists(outputPath))
            {
                Directory.CreateDirectory(outputPath);
            }

            var manifest = BuildPipeline.BuildAssetBundles(
                outputPath,
                BuildAssetBundleOptions.None,
                target);

            if (manifest == null)
            {
                throw new InvalidOperationException("BuildPipeline.BuildAssetBundles returned null manifest.");
            }

            var builtFiles = Directory.GetFiles(outputPath)
                .Select(Path.GetFileName)
                .OrderBy(name => name)
                .ToArray();

            UnityEngine.Debug.Log($"[BatchBuild] Asset bundle build succeeded. Output: {outputPath}");
            foreach (var file in builtFiles)
            {
                UnityEngine.Debug.Log($"[BatchBuild] - {file}");
            }
        }

        private static string GetArgValue(string key)
        {
            var args = Environment.GetCommandLineArgs();
            for (var i = 0; i < args.Length - 1; i++)
            {
                if (string.Equals(args[i], key, StringComparison.OrdinalIgnoreCase))
                {
                    return args[i + 1];
                }
            }

            return null;
        }
    }
}
