# znelchar format notes

## Outer object

- `_characterData`: string containing escaped JSON.
- `_textureDatas`: optional array of texture entries.

## Texture entry shape

- `_textureName`: file-like texture name (for example `myTexture.png`).
- `_textureData`: base64 payload for texture bytes.

## Known behavior

- Some files have empty `_textureDatas` arrays.
- `_characterData` can itself include nested escaped JSON strings in some properties.
- Additional top-level and nested keys may exist; tooling should preserve unknown keys.
