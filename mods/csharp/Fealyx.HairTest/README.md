This is a temporary experimental project exploring methods and mechanisms for defining and injecting custom clothing items into the Znel systems. The work done here informs the design and implementation of the TVSLib costume framework, as well as documentation efforts to record the discoveries and vanilla implementations which do not rely on TVSLib.

# Status

Basic character creator and persistence research is complete.

A lot of the `ZNECostumeData` and `ZNEAdditionalCostumeData` structures are still not well understood - we need to look more into the blendshape and material metadata, in particular.

Loading persisted costume data into the main menu and gameplay scenes is on-bat.

## Character Creator Integration

Basic integration with the character creator has been achieved with the resolution of a stable and reliable method to inject custom items into the item-list controllers.

### Discovery

The original lists of items appear to have been populated by hand (serialized arrays of costume data Scriptable Object references) within the Unity Editor and serialized into the scene. When the controllers `Start()`, they populate new UI elements (from a UI prefab) within the list UI to represent each item, and connect them with the functionality to add the item to the costume builder - as well as to manage materials and "morph sliders" - controls for the model's blendshapes.

All of this makes modifying the controller's array of items the ideal point of injection for custom items, as it minimizes the amount of code and logic that needs to be replicated to just that of the data structures.

For our purposes, it really does seem that the UI controllers are the primary entry point - they're the bridging point between data and logic.

### Efforts

#### CharacterCreatorState.cs
`CharacterCreatorState.cs` was an effort to traverse the scene hierarchy when the character creator scene loaded (leveraging TVSLib's `SceneState` utilities for that purpose) in order to locate the relevant `ZNECharacterItemPanel` which is responsible for controlling the Hair items list.

This proved difficult - there doesn't seem to be an easy way to effectively time the traversal attempt. When the scene is loaded and it's hierarchy deserialized would be ideal - but objects in the traversal path are not all active at that time, meaning we would have to rely on much heavier and convoluted traversal techniques than just feeding `GameObject.Find()` a path.

Compounding the issue is the fact that as soon as a controller's game object is activated, it's `Start()` message will execute within the same frame, making waiting for the path to become easily traversable implausible... as soon as there is a clear path, it is too late to benefit from a simple injection.

Most of the original research notes for both the technique and the data structures are present in this file.

#### Patches/CharacterItemPanelPatches.cs

The solution to the above complications was to patch the `ZNECharacterItemPanel.Start()` method directly by leveraging Harmony. No messy traversal or timing issues to worry about - just run the damned code immediately before `ZNECharacterItemPanel.Start()` executes.

Probably should have just started with this approach to begin with. But, you know, I may not make the same mistake twice. Probably.

This technique has been integrated into the TVSLib costume framework - plugin-registered costumes should now load properly into the appropriate lists within the character creator.

There doesn't seem to be any need to explore other techniques or approaches at this time - there are no obvious drawbacks to this method, and it has only one failure mode in the case of breaking changes to the game's code, which should be easily identified and rectified.

## Character Peristence Integration

It doesn't appear that any work is needed here, at this time. Custom items added to the character creator appear to be properly serialized and deserialized by the existing character persistence system without issue, because we're already pretty much directly leveraging the existing data structures and systems.

It may become necessary to modify the persistence systems to patch in support for more advanced functionality and features which are not directly supported by the game... but for replicating vanilla functionality and data, we're good to go.

## Gameplay (and Main Menu) Integration

Ongoing work.

There's a couple standount candidates for initial work:

- We could just straight up patch and short-circuit `Resources.Load()` when it tries to load any first-party items. It's pretty blunt and heavy-handed, but also totally surefire and direct for ensuring that custom items are handled exactly the same as vanilla ones across the entire logic flow. This really doesn't seem like a terrible evil for our early efforts.
  - Also possibly relevant to a whole bunch of other applications beyond just costumes, so it could be a pretty powerful and versatile patch to have in place. For the framework, that is - it might make less sense in a vanilla mod. But we could totally integrate the framework's asset management system with the patch to unify the asset loading and management and overrides across the board, which would be pretty freakin sleek.
- `ZNECharacter.loadCharacterActualCo()` - this coroutine appears to be what actually loads the character's costume items into a scene. It could be a bit of a more targeted point of injection - but not without it's own complications just due to being a coroutine. Would patching before/after be sufficient? Can we even directly patch internal logic? Replicating an entire replacement seems fairly unacceptable, to me - substituting entire blocks of logic seems like a long-term nightmare on principal.

