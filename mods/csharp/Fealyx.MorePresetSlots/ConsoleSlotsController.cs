using System.Collections;
using System.Collections.Generic;
using System.Linq;

using BepInEx.Logging;

using TMPro;

using UnityEngine;
using UnityEngine.UI;

namespace Fealyx.MorePresetSlots;

public class ConsoleSlotsController : MonoBehaviour
{
    public static TVSPlugin Plugin => TVSPlugin.Instance;
    public static ManualLogSource Logger => Plugin.Logger;

    private const int BUTTONS_PER_SECTION = 5;
    private const float SECTION_TRANSITION_OFFSET = 480f;

    private ZNELoadSavedPresetsCharacterConsole _lsController = null!;
    private ZNECharacterConsoleController _consoleController = null!;

    private List<int> _activeSectionIndices = new();
    private Dictionary<int, List<PresetSlotMapping>> _sectionToSlotMapping = new();
    private List<CanvasGroup> _allSections = new();
    private List<Button> _allButtons = new();
    private Button[]? _originalButtons;
    private CanvasGroup[]? _originalSections;

    private int _currentSectionArrayIndex = 0;
    private bool _isCondenseEnabled => Plugin.Config.GetSetting<bool>("CondenseConsoleSlots").Value;

    private class PresetSlotMapping
    {
        public int OriginalSlotIndex { get; set; }
        public int ButtonIndex { get; set; }
        public string PresetName { get; set; } = string.Empty;
    }

    protected void Awake()
    {
        Logger.LogDebug("ConsoleSlotsController Awake() called. Initializing references...");

        _lsController = GetComponent<ZNELoadSavedPresetsCharacterConsole>();
        if (_lsController == null)
        {
            Logger.LogError("ZNELoadSavedPresetsCharacterConsole component not found on the GameObject. ConsoleSlotsController requires ZNELoadSavedPresetsCharacterConsole to function.");
            return;
        }

        _consoleController = GetComponent<ZNECharacterConsoleController>();
        if (_consoleController == null)
        {
            Logger.LogError("ZNECharacterConsoleController component not found in parent hierarchy. ConsoleSlotsController requires ZNECharacterConsoleController to function.");
            return;
        }

        Logger.LogDebug("ConsoleSlotsController references initialized successfully.");

        if (!_isCondenseEnabled)
        {
            Logger.LogInfo("CondenseConsoleSlots is disabled. ConsoleSlotsController will not modify UI.");
            return;
        }

        _initializeReferences();
    }

    private void _initializeReferences()
    {
        _originalButtons = _lsController._customButtons;
        _originalSections = _lsController._sections;

        if (_originalButtons == null || _originalButtons.Length == 0)
        {
            Logger.LogError("No custom buttons found in ZNELoadSavedPresetsCharacterConsole.");
            return;
        }

        if (_originalSections == null || _originalSections.Length == 0)
        {
            Logger.LogError("No sections found in ZNELoadSavedPresetsCharacterConsole.");
            return;
        }

        Logger.LogDebug($"Found {_originalButtons.Length} buttons across {_originalSections.Length} sections.");
    }

    public void RebuildCompactLayout()
    {
        if (!_isCondenseEnabled || _originalButtons == null || _originalSections == null)
        {
            return;
        }

        Logger.LogDebug("Rebuilding compact layout...");

        var savedPresets = _loadPresetNames();
        var nonEmptySlots = savedPresets
            .Select((name, index) => (name, index))
            .Where(x => !string.IsNullOrEmpty(x.name))
            .ToList();

        Logger.LogDebug($"Found {nonEmptySlots.Count} non-empty preset slots out of {savedPresets.Count} total.");

        if (nonEmptySlots.Count == 0)
        {
            Logger.LogDebug("No presets found. Setting up minimal UI.");
            _setupEmptyLayout();
            return;
        }

        _buildSectionMappings(nonEmptySlots);
        _expandSectionsAndButtons();
        _applyLayoutToUI(savedPresets);
    }

    private List<string> _loadPresetNames()
    {
        if (!ES3.KeyExists("SavedPresetNames"))
        {
            return new List<string>();
        }

        return ES3.Load<List<string>>("SavedPresetNames");
    }

    private void _buildSectionMappings(List<(string name, int index)> nonEmptySlots)
    {
        _activeSectionIndices.Clear();
        _sectionToSlotMapping.Clear();

        int currentSectionIndex = 0;
        int currentButtonIndexInSection = 0;

        for (int i = 0; i < nonEmptySlots.Count; i++)
        {
            if (currentButtonIndexInSection >= BUTTONS_PER_SECTION)
            {
                currentSectionIndex++;
                currentButtonIndexInSection = 0;
            }

            if (!_sectionToSlotMapping.ContainsKey(currentSectionIndex))
            {
                _activeSectionIndices.Add(currentSectionIndex);
                _sectionToSlotMapping[currentSectionIndex] = new List<PresetSlotMapping>();
            }

            _sectionToSlotMapping[currentSectionIndex].Add(new PresetSlotMapping
            {
                OriginalSlotIndex = nonEmptySlots[i].index,
                ButtonIndex = currentButtonIndexInSection,
                PresetName = nonEmptySlots[i].name
            });

            currentButtonIndexInSection++;
        }

        Logger.LogDebug($"Built mappings for {_activeSectionIndices.Count} active sections.");
    }

    private void _setupEmptyLayout()
    {
        _activeSectionIndices.Clear();
        _activeSectionIndices.Add(0);

        for (int i = 0; i < _originalSections!.Length; i++)
        {
            _originalSections[i].gameObject.SetActive(i == 0);
        }

        foreach (var button in _originalButtons!)
        {
            button.interactable = false;
            var textOverlay = button.transform.Find("TextOverlay")?.GetComponent<TextMeshProUGUI>();
            if (textOverlay != null)
            {
                textOverlay.text = "";
            }
        }

        _lsController._leftButton.interactable = false;
        _lsController._rightButton.interactable = false;
    }

    private void _expandSectionsAndButtons()
    {
        int requiredSections = _activeSectionIndices.Count;
        int existingSections = _originalSections!.Length;

        Logger.LogDebug($"Expanding from {existingSections} to {requiredSections} sections.");

        if (requiredSections <= existingSections)
        {
            _allSections = _originalSections.ToList();
            _allButtons = _originalButtons!.ToList();
            return;
        }

        // TODO: Implement section/button creation by copying from template
        // This is stubbed for now - you'll need to implement based on scene observation
        Logger.LogWarning("Section expansion not yet implemented. Using existing sections only.");
        _allSections = _originalSections.ToList();
        _allButtons = _originalButtons!.ToList();
    }

    private void _applyLayoutToUI(List<string> savedPresets)
    {
        // Hide all sections initially
        for (int i = 0; i < _originalSections!.Length; i++)
        {
            bool isActiveSection = _activeSectionIndices.Contains(i);
            _originalSections[i].gameObject.SetActive(isActiveSection);

            if (isActiveSection)
            {
                _originalSections[i].alpha = (i == 0) ? 1f : 0f;
            }
        }

        // Configure buttons for each active section
        int globalButtonIndex = 0;
        for (int sectionIndex = 0; sectionIndex < _originalSections.Length; sectionIndex++)
        {
            if (!_sectionToSlotMapping.ContainsKey(sectionIndex))
            {
                // Disable all buttons in inactive sections
                for (int i = 0; i < BUTTONS_PER_SECTION && globalButtonIndex < _originalButtons!.Length; i++, globalButtonIndex++)
                {
                    _configureButton(_originalButtons[globalButtonIndex], -1, "", false);
                }
                continue;
            }

            var mappings = _sectionToSlotMapping[sectionIndex];
            for (int i = 0; i < BUTTONS_PER_SECTION && globalButtonIndex < _originalButtons!.Length; i++, globalButtonIndex++)
            {
                var mapping = mappings.FirstOrDefault(m => m.ButtonIndex == i);
                if (mapping != null)
                {
                    _configureButton(_originalButtons[globalButtonIndex], mapping.OriginalSlotIndex, mapping.PresetName, true);
                }
                else
                {
                    _configureButton(_originalButtons[globalButtonIndex], -1, "", false);
                }
            }
        }

        _updateNavigationButtons();
        _updateIconsAsync(savedPresets);
    }

    private void _configureButton(Button button, int slotIndex, string presetName, bool isActive)
    {
        button.onClick.RemoveAllListeners();

        if (isActive)
        {
            button.interactable = !_consoleController.tutorialMode;
            button.onClick.AddListener(() => _onButtonClick(slotIndex));

            var textOverlay = button.transform.Find("TextOverlay")?.GetComponent<TextMeshProUGUI>();
            if (textOverlay != null)
            {
                textOverlay.text = presetName;
            }
        }
        else
        {
            button.interactable = false;
            var textOverlay = button.transform.Find("TextOverlay")?.GetComponent<TextMeshProUGUI>();
            if (textOverlay != null)
            {
                textOverlay.text = "";
            }
        }
    }

    private void _onButtonClick(int originalSlotIndex)
    {
        Logger.LogDebug($"Button clicked for slot index: {originalSlotIndex}");
        ZNEMachineSystemHeroLoader.Instance.loadCustomCharacter(originalSlotIndex);
    }

    private async void _updateIconsAsync(List<string> savedPresets)
    {
        int globalButtonIndex = 0;

        for (int sectionIndex = 0; sectionIndex < _originalSections!.Length; sectionIndex++)
        {
            if (!_sectionToSlotMapping.ContainsKey(sectionIndex))
            {
                globalButtonIndex += BUTTONS_PER_SECTION;
                continue;
            }

            var mappings = _sectionToSlotMapping[sectionIndex];
            for (int i = 0; i < BUTTONS_PER_SECTION && globalButtonIndex < _originalButtons!.Length; i++, globalButtonIndex++)
            {
                var mapping = mappings.FirstOrDefault(m => m.ButtonIndex == i);
                if (mapping != null && mapping.OriginalSlotIndex < savedPresets.Count)
                {
                    var iconImage = _originalButtons[globalButtonIndex].GetComponent<Image>();
                    if (iconImage != null)
                    {
                        var sprite = await ZNECharacter.GetIconFromCharacterData(
                            savedPresets[mapping.OriginalSlotIndex],
                            mapping.OriginalSlotIndex,
                            isVanillaPreset: false
                        );

                        if (sprite != null)
                        {
                            iconImage.sprite = sprite;
                        }
                    }
                }
            }
        }
    }

    private void _updateNavigationButtons()
    {
        if (_activeSectionIndices.Count == 0)
        {
            _lsController._leftButton.interactable = false;
            _lsController._rightButton.interactable = false;
            return;
        }

        int maxSectionArrayIndex = _activeSectionIndices.Count - 1;
        _lsController._leftButton.interactable = _currentSectionArrayIndex > 0;
        _lsController._rightButton.interactable = _currentSectionArrayIndex < maxSectionArrayIndex;
    }

    public void MoveToNextSection()
    {
        if (_activeSectionIndices.Count == 0 || _currentSectionArrayIndex >= _activeSectionIndices.Count - 1)
        {
            return;
        }

        int currentSectionIndex = _activeSectionIndices[_currentSectionArrayIndex];
        _currentSectionArrayIndex++;
        int newSectionIndex = _activeSectionIndices[_currentSectionArrayIndex];

        Logger.LogDebug($"Moving from section {currentSectionIndex} to {newSectionIndex}");

        _lsController._leftButton.interactable = true;
        if (_currentSectionArrayIndex >= _activeSectionIndices.Count - 1)
        {
            _lsController._rightButton.interactable = false;
        }

        StartCoroutine(_transitionSections(currentSectionIndex, newSectionIndex, isMovingRight: true));
    }

    public void MoveToPreviousSection()
    {
        if (_activeSectionIndices.Count == 0 || _currentSectionArrayIndex <= 0)
        {
            return;
        }

        int currentSectionIndex = _activeSectionIndices[_currentSectionArrayIndex];
        _currentSectionArrayIndex--;
        int newSectionIndex = _activeSectionIndices[_currentSectionArrayIndex];

        Logger.LogDebug($"Moving from section {currentSectionIndex} to {newSectionIndex}");

        _lsController._rightButton.interactable = true;
        if (_currentSectionArrayIndex <= 0)
        {
            _lsController._leftButton.interactable = false;
        }

        StartCoroutine(_transitionSections(currentSectionIndex, newSectionIndex, isMovingRight: false));
    }

    private IEnumerator _transitionSections(int fromSectionIndex, int toSectionIndex, bool isMovingRight)
    {
        _lsController._transitioning = true;

        float elapsedTime = 0f;
        float startPos = _lsController._customHeroRoot.anchoredPosition.x;
        float endPos = startPos + (isMovingRight ? -SECTION_TRANSITION_OFFSET : SECTION_TRANSITION_OFFSET);

        CanvasGroup fromSection = _originalSections![fromSectionIndex];
        CanvasGroup toSection = _originalSections[toSectionIndex];

        toSection.alpha = 0f;
        toSection.gameObject.SetActive(true);

        Vector2 pos = _lsController._customHeroRoot.anchoredPosition;

        while (elapsedTime < 0.5f)
        {
            float t = elapsedTime / 0.5f;
            pos.x = Mathf.Lerp(startPos, endPos, t);
            _lsController._customHeroRoot.anchoredPosition = pos;

            toSection.alpha = Mathf.Lerp(0f, 1f, t);
            fromSection.alpha = Mathf.Lerp(1f, 0f, t);

            elapsedTime += Time.deltaTime;
            yield return null;
        }

        pos.x = endPos;
        _lsController._customHeroRoot.anchoredPosition = pos;
        toSection.alpha = 1f;
        fromSection.alpha = 0f;
        fromSection.gameObject.SetActive(false);

        _lsController._transitioning = false;
    }

    public int GetCurrentSectionIndex()
    {
        return _activeSectionIndices.Count > 0 ? _activeSectionIndices[_currentSectionArrayIndex] : 0;
    }
}
