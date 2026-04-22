using System;
using System.Collections.Generic;
using System.Reflection;

using BepInEx.Logging;

namespace Fealyx.TVSLib.DevTools;

public class AssemblyInspector
{
    public static IReadOnlyList<Assembly> Assemblies {
        get
        {
            if (_assemblies == null)
            {
                _assemblies = AppDomain.CurrentDomain.GetAssemblies();
            }

            return _assemblies;
        }
    }

    private ManualLogSource _logger;
    private static Assembly[]? _assemblies;

    public AssemblyInspector(ManualLogSource? logger = null)
    {
        _logger = logger ?? Logger.CreateLogSource("AssemblyInspector");
    }

    public void PrintAssemblyInfo(bool printTypes = false, bool printMethods = false)
    {
        _logger.LogInfo($"Inspecting {Assemblies.Count} assemblies in the current AppDomain:");

        foreach (var assembly in Assemblies)
        {
            _logger.LogInfo($"  {assembly.GetName().Name} (v{assembly.GetName().Version})");

            if (!printTypes)
                continue;

            var types = assembly.GetTypes();
            foreach (var type in types)
            {
                Console.WriteLine($"    - {type.FullName}");

                if (!printMethods)
                    continue;

                var methods = type.GetMethods(BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Instance | BindingFlags.Static);
                foreach (var method in methods)
                {
                    Console.WriteLine($"      - {method.Name}");
                }
            }
        }
    }
}
