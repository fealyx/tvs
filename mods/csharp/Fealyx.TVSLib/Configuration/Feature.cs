using System;

namespace Fealyx.TVSLib.Configuration;

/// <summary>
/// Represents a toggleable feature with optional settings.
/// Features are always represented as groups with an "Enabled" setting.
/// </summary>
public class Feature : SettingGroup
{
    public Setting<bool> EnabledSetting { get; }
    public bool IsEnabled => EnabledSetting.Value;

    public Action<Feature>? OnDisable;
    public Action<Feature>? OnEnable;
    public Action<Feature>? OnInitialize;

    public Feature(
        string name, 
        string description = "", 
        bool defaultEnabled = false,
        Action<Feature>? onEnable = null,
        Action<Feature>? onDisable = null,
        Action<Feature>? onInitialize = null)
        : base(name, description)
    {
        OnEnable += onEnable;
        OnDisable += onDisable;
        OnInitialize += onInitialize;

        // Create the enabled setting
        EnabledSetting = new Setting<bool>(
            "Enabled", 
            string.IsNullOrEmpty(description) ? $"Enable {name}" : description, 
            defaultEnabled
        );

        AddSetting(EnabledSetting);
    }

    public void Enable()
    {
        if (!IsEnabled)
        {
            EnabledSetting.Value = true;
        }
    }

    public void Disable()
    {
        if (IsEnabled)
        {
            EnabledSetting.Value = false;
        }
    }

    public override void Initialize(SettingGroup group)
    {
        base.Initialize(group);

        // Subscribe to enabled state changes
        EnabledSetting.OnChange += (setting, oldValue) =>
        {
            if (EnabledSetting.Value && !oldValue)
                OnEnable?.Invoke(this);
            else if (!EnabledSetting.Value && oldValue)
                OnDisable?.Invoke(this);
        };

        OnInitialize?.Invoke(this);

        // Auto-enable if currently enabled
        if (IsEnabled)
        {
            OnEnable?.Invoke(this);
        }
    }

    // Fluent API - return Feature for chaining

    /// <summary>
    /// Fluent method to add a setting to this feature.
    /// </summary>
    public new Feature WithSetting<T>(string name, string description, T defaultValue = default!)
    {
        base.WithSetting(name, description, defaultValue);
        return this;
    }

    /// <summary>
    /// Fluent method to add a setting to this feature.
    /// </summary>
    public Feature WithSetting<T>(Setting<T> setting)
    {
        AddSetting(setting);
        return this;
    }

    /// <summary>
    /// Fluent method to add a sub-group to this feature.
    /// </summary>
    public new Feature WithGroup(SettingGroup group)
    {
        AddGroup(group);
        return this;
    }

    /// <summary>
    /// Fluent method to create and add a nested group to this feature.
    /// </summary>
    public new Feature WithGroup(string name, string description, Action<SettingGroup>? configure = null)
    {
        base.WithGroup(name, description, configure);
        return this;
    }
}
