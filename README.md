# Fealyx/TVS

Exploratory modding initiative for Znel Arts' game, "The Villain Simulator."

This repository is a Rushstack-based monorepo housing multiple projects across several domains:

- `/content/` - Documentation efforts, published as a GitHub Pages site
- `/mods/csharp` - A Visual Studio solution for authoring multiple code-first BepInEx mods
- `/mods/unity` - A Unity Editor project for asset bundle and Thunderkit mod authoring
- `/tools` - Tools to assist with discovery and mod development

Most of the `docs` directories (and more generally, the markdown files everywhere but `/content`) are populated solely with LLM-generated development notes. They can still be useful - but the intent is to collect more refined and directly useful information in the GitHub Pages site.

> **Disclaimer**
> 
> This project is in a very early, incomplete, and rudimentary state. I also have zero prior Unity modding experience - we're just flipping switches and twisting dials, and sometimes cool things happen :)
> 
> Everything is subject to rapid breaking changes, and no work should be interpreted as a best practice or canonical solution.

## Miscellaneous Notes

- We don't have a reliable mechanism to determine the versions of the assemblies which the game uses. When it becomes apparent that a feature set which we are depending on is not present or malfunctions, we should try to narrow the package version and update the `mods/unity` project accordingly.
- An "Interactive License" should be acquired for each additional DAZ 3D asset added to the game. To best adhere to the license's terms, raw assets should be omitted from public repositories, and exclusively distributed in asset bundles ("a reasonable effort to protect the asset").
