# Contributing Guidelines

Thank you for your interest in contributing to the modding community documentation! These guidelines help us maintain a high-quality, organized knowledge base.

## Types of Contributions

### 1. Guides
Long-form educational content covering specific topics in depth.

**Location**: `src/guides/<category>/`

**Frontmatter Requirements**:
```yaml
---
layout: guide.html
title: "Your Guide Title"
category: guides/<subcategory>
tags: [tag1, tag2, tag3]
author: Your Name
date: 2026-04-03
draft: false
---
```

**Examples**: Character modding techniques, texture editing workflows, etc.

### 2. Tutorials
Step-by-step walkthroughs with concrete examples.

**Location**: `src/tutorials/`

**Frontmatter Requirements**:
```yaml
---
layout: guide.html
title: "Tutorial: Your Task"
category: tutorials
tags: [tutorial, beginner]
author: Your Name
date: 2026-04-03
contributors: [contributor1, contributor2]
---
```

### 3. Discoveries
Community findings, engine quirks, and file format documentation.

**Location**: `src/discoveries/<subcategory>/`

**Frontmatter Requirements**:
```yaml
---
layout: guide.html
title: "Discovery: Topic"
category: discoveries/<subcategory>
tags: [discovery, format]
author: Your Name
date: 2026-04-03
---
```

### 4. Community Pages
Contributor profiles, announcements, project roadmap.

**Location**: `src/community/`

**Frontmatter Requirements**:
```yaml
---
layout: guide.html
title: "Community Page Title"
category: community
---
```

## Content Categories

**Guides:**
- `guides/getting-started/` - Beginner overviews
- `guides/character-modding/` - Character modification
- `guides/textures-and-materials/` - Texture and material editing

**Tutorials:**
- `src/tutorials/` - Multi-step walkthroughs

**Discoveries:**
- `discoveries/engine-quirks/` - Engine behavior and quirks
- `discoveries/file-formats/` - File format documentation

## Adding Tool Documentation

Tool documentation is automatically collected during builds:

1. Create a `docs/` folder in your tool directory: `tools/mytool/docs/`
2. Add `README.md` and supporting documentation
3. Use Markdown with standard frontmatter
4. Documentation will appear at `/tools/mytool/` on next build

## Writing Guidelines

### Markdown

Use standard Markdown with proper formatting:

```markdown
# Main Heading
## Subheading
### Details

- Bullet points
- Use lists frequently

1. Numbered steps
2. For tutorials

**Bold** and *italic* for emphasis

[Links](https://example.com) to external resources

> Blockquotes for important notes or tips

```code
Code examples
```
```

### Best Practices

1. **Be Clear**: Explain concepts before diving into details
2. **Use Examples**: Include code snippets and screenshots when helpful
3. **Link Related Content**: Cross-reference other guides and discoveries
4. **Keep It Current**: Update docs when tools or processes change
5. **Cite Sources**: Give credit for community findings and shared knowledge

### Tone

- Friendly and welcoming to beginners
- Accurate and technical where needed
- Encouraging and supportive

## Before Submitting

- [ ] Spell-check your content
- [ ] Verify all links work
- [ ] Test code examples if included
- [ ] Frontmatter is complete and valid
- [ ] Content is well-organized with clear headings
- [ ] Cross-link to related content

## Local Preview

To preview your changes locally:

```bash
cd content
npm install
npm run dev
```

Site opens at `http://localhost:8080` with live reload.

## Submission Process

1. Fork the repository
2. Create a feature branch: `git checkout -b add/my-guide`
3. Make your changes
4. Test locally with `npm run dev`
5. Submit a pull request with a clear description
6. Wait for review and feedback

## Review Process

- Community maintainers will review your submission
- You may be asked to clarify or refine content
- Once approved, your contribution is merged and published

## Questions or Issues?

- Open an issue on GitHub to discuss ideas
- Ask questions in pull request discussions
- Check existing documentation before asking What not to contribute

Please don't include:
- Promotional content or spam
- External links to self-promotion
- Inactive or outdated information without clear warnings
- Copyrighted content without permission

## Attribution

All contributors will be credited in:
- Git commit history
- Page metadata (if author/contributors fields used)
- Community page with contributor list

Thank you for making modding more accessible to everyone! 🎉

---

**Questions?** [Open an issue on GitHub](https://github.com/fealyx/tvs/issues)

**Want to suggest an improvement?** We welcome meta-discussions about these guidelines.
