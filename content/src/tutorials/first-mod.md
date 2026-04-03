---
layout: guide.html
title: "Tutorial: Your First Mod"
category: tutorials
tags: [beginner, tutorial, character]
date: 2026-04-03
author: Community
---

# Tutorial: Your First Mod

In this tutorial, we'll create a simple character mod from start to finish.

## Step 1: Extract Assets

First, extract the base character:

```bash
npm run extract -- -InputPath ./game/character.znelchar -OutputDir ./my-first-mod
```

This creates:
- `character.json` - Character data
- `textures/` - Texture files  
- `customIcon.png` - Character icon
- `manifest.json` - Metadata

## Step 2: Edit Character Data

Open `character.json` and modify character properties:

```json
{
  "name": "My Custom Character",
  "colors": {
    "primary": "#FF5733",
    "secondary": "#33FF57"
  }
}
```

## Step 3: Modify Textures

Edit texture files in the `textures/` folder using your favorite image editor.

## Step 4: Validate Your Changes

Run verification to check for issues:

```bash
npm run verify -- -LeftPath ./game/character.znelchar -RightPath ./my-first-mod
```

## Step 5: Pack Your Mod

Pack everything back into a distributable file:

```bash
npm run pack -- -ManifestPath ./my-first-mod/manifest.json -OutputPath ./my-mod.znelchar
```

## Step 6: Test

Test your mod in-game and iterate!

---

Congratulations on your first mod! 🎉

For more advanced techniques, check out the [Character Modding Guide](/guides/character-modding/).
