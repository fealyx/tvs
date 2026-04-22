using System;
using BepInEx.Configuration;

namespace Fealyx.TVSLib.Configuration;

public abstract class Setting
{
    public string Name { get; }
    public string Description { get; }
    public SettingGroup? Group { get; internal set; }
    public string Section => Group != null ? Group.Section : Configuration.DefaultSection;


    public abstract object GetValue();
    public abstract void SetValue(object value);
    public abstract Type ValueType { get; }
    public abstract void ResetToDefault();

    public Action<Setting, object>? OnChange;

    protected Setting(string name, string description)
    {
        Name = name;
        Description = description;
    }

    public virtual void Initialize(SettingGroup group)
    {
        Group = group;
    }
}

public class Setting<T> : Setting
{
    public Configuration? Config => Group?.Config;
    public ConfigEntry<T> ConfigEntry { get; internal set; } = null!;
    public T DefaultValue { get; }
    public T Value
    {
        get => (T)GetValue();
        set => SetValue(value!);
    }

    public override Type ValueType => typeof(T);

    public new Action<Setting<T>, T>? OnChange;

    private T _lastValue;
    private bool _isInitialized = false;

    public Setting(string name, string description, T defaultValue = default!)
        : base(name, description)
    {
        DefaultValue = defaultValue;
        _lastValue = defaultValue;
    }

    public override void Initialize(SettingGroup group)
    {
        base.Initialize(group);
        ConfigEntry = group.BindSetting(this);
        _lastValue = ConfigEntry.Value;
        ConfigEntry.SettingChanged += _handleConfigEntryChanged;

        _isInitialized = true;
    }

    public override void ResetToDefault() => SetValue(DefaultValue!);

    public override object GetValue()
    {
        if (_isInitialized == false)
            throw new InvalidOperationException("Cannot get value of uninitialized setting");

        return ConfigEntry.Value!;
    }

    public override void SetValue(object value)
    {
        if (_isInitialized == false)
            throw new InvalidOperationException("Cannot set value of uninitialized setting");

        if (value is T typedValue)
            ConfigEntry.Value = typedValue;
        else
            throw new ArgumentException($"Value must be of type {typeof(T)}");
    }

    private void _handleConfigEntryChanged(object sender, EventArgs e)
    {
        OnChange?.Invoke(this, _lastValue);
        _lastValue = Value;
    }
}
