using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;

using BepInEx.Configuration;

namespace Fealyx.TVSLib.Configuration;

public class SettingGroup : IEnumerable
{
    public readonly string Name;
    public readonly string Description;
    public Configuration? Config => Group?.Config;
    public SettingGroup? Group = null;
    public virtual string Section => $"{(Group != null && Group.Section != "" ? $"{Group.Section}." : "")}{Name}";

    public IReadOnlyList<SettingGroup> AllGroups => _allGroups.AsReadOnly();
    public IReadOnlyList<Setting> AllSettings => _allSettings.AsReadOnly();
    public IReadOnlyDictionary<string, SettingGroup> GroupsByName => _groupsByName;
    public IReadOnlyDictionary<string, Setting> SettingsByName => _settingsByName;

    public Action<Setting, object>? OnChange;

    private readonly List<Setting> _allSettings = new();
    private readonly List<SettingGroup> _allGroups = new();
    private readonly Dictionary<string, Setting> _settingsByName = new();
    private readonly Dictionary<string, SettingGroup> _groupsByName = new();
    protected bool _isInitialized = false;

    public SettingGroup(string name, string description = "")
    {
        Name = name;
        Description = description;
    }

    public virtual void Initialize(SettingGroup group)
    {
        Group = group;
        _isInitialized = true;

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
    }

    public virtual ConfigEntry<T> BindSetting<T>(Setting<T> setting)
    {
        // Check if THIS group is initialized
        if (!_isInitialized)
            throw new InvalidOperationException($"Cannot bind setting '{setting.Name}' - group '{Name}' is not initialized");

        // If we have a parent, delegate to it
        if (Group != null)
            return Group.BindSetting(setting);
        
        // If we're the root and not a Configuration, something is wrong
        throw new InvalidOperationException($"Cannot bind setting '{setting.Name}' - reached root group '{Name}' which is not a Configuration");
    }

    public Setting AddSetting(Setting setting)
    {
        if (_isInitialized)
            throw new InvalidOperationException("Cannot add settings to an initialized group");

        setting.Group = this;
        _allSettings.Add(setting);
        _settingsByName[setting.Name] = setting;

        return setting;
    }

    public SettingGroup AddGroup(SettingGroup group)
    {
        if (_isInitialized)
            throw new InvalidOperationException("Cannot add groups to an initialized group");

        group.Group = this;
        _allGroups.Add(group);
        _groupsByName[group.Name] = group;

        return group;
    }

    public Setting<T> GetSetting<T>(string nameOrPath)
    {
        if (_isInitialized == false)
            throw new InvalidOperationException("Cannot get settings from an uninitialized group");

        if (nameOrPath.Contains("."))
        {
            return GetSetting<T>(nameOrPath.Split('.'));
        }

        if (_settingsByName.TryGetValue(nameOrPath, out var setting))
        {
            if (setting is Setting<T> typedSetting)
                return typedSetting;
            else
                throw new InvalidOperationException($"Setting '{nameOrPath}' is not of type {typeof(T).Name}");
        }

        throw new KeyNotFoundException($"Setting '{nameOrPath}' not found in group '{Section}'");
    }

    public Setting<T> GetSetting<T>(string[] pathParts)
    {
        if (_isInitialized == false)
            throw new InvalidOperationException("Cannot get settings from an uninitialized group");

        string settingName = pathParts.Last();
        SettingGroup group = GetGroup(pathParts.Take(pathParts.Length - 1).ToArray());

        if (group._settingsByName.TryGetValue(settingName, out var setting))
        {
            if (setting is Setting<T> typedSetting)
                return typedSetting;
            else
                throw new InvalidOperationException($"Setting '{settingName}' is not of type {typeof(T).Name}");
        }

        throw new KeyNotFoundException($"Setting '{settingName}' not found in group '{group.Section}'");
    }

    public SettingGroup GetGroup(string nameOrPath)
    {
        if (_isInitialized == false)
            throw new InvalidOperationException("Cannot get groups from an uninitialized group");

        if (nameOrPath.Contains("."))
        {
            return GetGroup(nameOrPath.Split('.'));
        }

        if (_groupsByName.TryGetValue(nameOrPath, out var group))
        {
            return group;
        }

        throw new KeyNotFoundException($"Group '{nameOrPath}' not found in group '{Section}'");
    }

    public SettingGroup GetGroup(string[] pathParts)
    {
        if (_isInitialized == false)
            throw new InvalidOperationException("Cannot get groups from an uninitialized group");

        SettingGroup currentGroup = this;

        foreach (var part in pathParts)
        {
            if (currentGroup._groupsByName.TryGetValue(part, out var subgroup))
            {
                currentGroup = subgroup;
            }
            else
            {
                throw new KeyNotFoundException($"Group '{part}' not found in group '{currentGroup.Section}'");
            }
        }

        return currentGroup;
    }

    // Collection initializer support - enables declarative syntax
    public void Add(Setting setting) => AddSetting(setting);
    public void Add(SettingGroup group) => AddGroup(group);

    public IEnumerator GetEnumerator() => _allSettings.Cast<object>()
        .Concat(_allGroups.Cast<object>())
        .GetEnumerator();

    // Fluent API - enables chaining

    /// <summary>
    /// Fluent method to add a setting and return the group for chaining.
    /// </summary>
    public SettingGroup WithSetting<T>(string name, string description, T defaultValue = default!)
    {
        AddSetting(new Setting<T>(name, description, defaultValue));
        return this;
    }

    /// <summary>
    /// Fluent method to add a setting and return the setting for configuration.
    /// </summary>
    public Setting<T> WithSetting<T>(Setting<T> setting)
    {
        AddSetting(setting);
        return setting;
    }

    /// <summary>
    /// Fluent method to add a group and return the group for configuration.
    /// </summary>
    public SettingGroup WithGroup(SettingGroup group)
    {
        AddGroup(group);
        return group;
    }

    /// <summary>
    /// Fluent method to create and add a nested group.
    /// </summary>
    public SettingGroup WithGroup(string name, string description, Action<SettingGroup>? configure = null)
    {
        var group = new SettingGroup(name, description);
        configure?.Invoke(group);
        AddGroup(group);
        return group;
    }

    protected void _handleSettingChanged<T>(Setting setting, T value)
    {
        OnChange?.Invoke(setting, value!);
    }
}
