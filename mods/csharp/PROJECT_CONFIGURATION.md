# TVS Mods - C# Project Configuration

## Project Structure

This is a **polyglot monorepo** where the C# solution is one project among many. The monorepo root is located at:
```
..\..
```

## Package Management

This solution uses **Central Package Management** via NuGet. Package versions are defined centrally in:
- `Directory.Packages.props` (located alongside the solution file)
- `nuget.config` (located alongside the solution file)

### Important: Do NOT specify versions in project files

When adding package references to `.csproj` files, **never** specify the version attribute:

```xml
<!-- ✅ CORRECT -->
<PackageReference Include="SomePackage" />

<!-- ❌ WRONG - will cause NU1008 error -->
<PackageReference Include="SomePackage" Version="1.2.3" />
```

## Available Dependencies

### BepInEx Packages

All projects that reference `BepInEx.Core` automatically get access to:
- **HarmonyX** - For runtime patching (no need to add separate package reference)
- BepInEx logging and plugin infrastructure
- Unity Engine types (via game references)

### Using Harmony

Harmony (HarmonyX) is **already included** with BepInEx. Simply use:

```csharp
using HarmonyLib;

// No additional package reference needed!
var harmony = new Harmony("your.mod.id");
harmony.PatchAll();
```

## Assembly Publicizer

Projects can use `EnableAssemblyPublicizer` to access private members of game assemblies:

```xml
<PropertyGroup>
  <EnableAssemblyPublicizer>true</EnableAssemblyPublicizer>
</PropertyGroup>

<ItemGroup Condition="Exists('$(TVSManagedDir)\Assembly-CSharp.dll')">
  <Reference Update="Assembly-CSharp">
    <Publicize>true</Publicize>
  </Reference>
</ItemGroup>
```

This allows accessing private fields/methods from the game's code.

## Line Endings

The monorepo uses **LF** (Unix-style) line endings for most files (configured in `.gitattributes` and `.editorconfig`). Only `.bat` and `.cmd` files use CRLF.

## Common Projects

- **Fealyx.TVSLib** - Core framework library for mods
- **TVS.SampleMod** - Example/template mod
- **Fealyx.HairTest** - Test project for custom hair assets

## Target Framework

All projects target **.NET Standard 2.1** with **C# 13.0** features enabled.
