using System;
using System.IO;

using BepInEx.Configuration;

namespace Fealyx.TVSLib.Configuration;

public class Configuration : SettingGroup
{
    public static readonly string DefaultSection = "General";

    public override string Section => "";
    public ConfigFile ConfigFile { get; }

    public Configuration(ConfigFile config, string description = "")
        : base(config.ConfigFilePath, description)
    {
        ConfigFile = config;
    }

    public Configuration(string name, string description = "")
        : base(name, description)
    {
        ConfigFile = new ConfigFile(Path.Combine(BepInEx.Paths.ConfigPath, name), true);
    }

    public override ConfigEntry<T> BindSetting<T>(Setting<T> setting)
    {
        return ConfigFile.Bind(
            setting.Section,
            setting.Name,
            setting.DefaultValue,
            setting.Description
        );
    }

    public void Initialize()
    {
        foreach (var setting in AllSettings)
        {
            setting.Initialize(this);
            setting.OnChange += _handleSettingChanged;
        }

        foreach (var subgroup in AllGroups)
        {
            subgroup.Initialize(this);
            subgroup.OnChange += _handleSettingChanged;
        }

        _isInitialized = true;
    }

    public override void Initialize(SettingGroup group)
    {
        throw new InvalidOperationException("Cannot initialize a Configuration as a group member.");
    }
}

