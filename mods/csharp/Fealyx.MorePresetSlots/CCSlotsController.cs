using System.Collections.Generic;

using BepInEx.Logging;
using TMPro;
using UnityEngine;
using UnityEngine.UI;


namespace Fealyx.MorePresetSlots;

public class CCSlotsController : MonoBehaviour
{
    public static readonly string ButtonAreaName = "ButtonsArea";
    public static readonly string VanillaPageButtonName = "MainCharacters-Button";
    public static readonly string CustomPageButtonNamePrefix = "Page";

    public static TVSPlugin Plugin => TVSPlugin.Instance;
    public static ManualLogSource Logger => Plugin.Logger;

    public static CCSlotsController CreateAndAttach(ZNELoadSavedPresets zneController)
    {
        if (zneController.GetComponent<CCSlotsController>() != null)
        {
            Logger.LogWarning("CCSlotsController already exists on the provided ZNELoadSavedPresets. Returning existing instance.");
            return zneController.GetComponent<CCSlotsController>();
        }

        return zneController.gameObject.AddComponent<CCSlotsController>();
    }

    private int _currentPageIndex = 0;
    private int _maxButtonPage => Plugin.Config.GetSetting<int>("AdditionalPresetPages").Value;
    private int _buttonsPerPage => Plugin.Config.GetSetting<int>("PageButtonsOnScreen").Value;
    private int _maxTotalButtons => _maxButtonPage * _buttonsPerPage;
    private int _firstButtonIndexOnCurrentPage => _currentPageIndex * _buttonsPerPage;
    private int _lastButtonIndexOnCurrentPage => Mathf.Min(_firstButtonIndexOnCurrentPage + _buttonsPerPage - 1, _maxTotalButtons - 1);

    private Transform _buttonsArea = null!;
    private Transform _paginationButtonsContainer = null!;
    private Button _nextButton = null!;
    private Button _previousButton = null!;
    private List<Button> _pageButtons = new();
    private Button[] _originalPageButtons = [];
    private Transform _vanillaPresetsButton = null!;
    private ZNELoadSavedPresets _zneController = null!;

    protected void Awake()
    {
        Logger.LogDebug("CCSlotsController Awake() called. Initializing references and setting up pagination...");

        _zneController = GetComponent<ZNELoadSavedPresets>();

        if (_zneController == null)
        {
            Logger.LogError("ZNELoadSavedPresets component not found on the GameObject. CCSlotsController requires ZNELoadSavedPresets to function.");
            return;
        }

        foreach (Transform child in _zneController.transform)
        {
            if (child.name == ButtonAreaName)
            {
                _buttonsArea = child;
                break;
            }
        }

        if (_buttonsArea == null)
        {
            Logger.LogError($"Failed to find {ButtonAreaName} in ZNELoadSavedPresets children. CCSlotsController will not function.");
            return;
        }

        // Create a container for all buttons
        _paginationButtonsContainer = new GameObject("PaginationButtonsContainer").transform;
        _paginationButtonsContainer.SetParent(_buttonsArea);

        foreach (Transform child in _buttonsArea)
        {
            if (child.name == VanillaPageButtonName)
            {
                _vanillaPresetsButton = child;
                continue;
            }

            if (child.GetComponent<Button>() == null)
            {
                Logger.LogWarning($"Found child {child.name} in {ButtonAreaName} that does not have a Button component. Skipping.");
                continue;
            }

            if (!child.name.StartsWith(CustomPageButtonNamePrefix))
            {
                Logger.LogWarning($"Found child {child.name} in {ButtonAreaName} that does not follow the expected naming convention (does not start with {CustomPageButtonNamePrefix}). Skipping.");
                continue;
            }

            _pageButtons.Add(child.GetComponent<Button>());
        }

        _originalPageButtons = _pageButtons.ToArray();

        if (_vanillaPresetsButton == null)
        {
            Logger.LogError($"Failed to find {VanillaPageButtonName} in {ButtonAreaName} children. CCSlotsController will not function.");
            return;
        }

        // Move the vanilla presets button to the first position
        _vanillaPresetsButton.SetAsFirstSibling();

        // Move all pre-existing custom page buttons into the pagination container
        //foreach (var pageButton in _pageButtons)
        //    pageButton.transform.SetParent(_paginationButtonsContainer);

        // Create and wire up the previous and next buttons
        //_previousButton = _createButton("PreviousPageButton", "<", _buttonsArea);
        //_previousButton.onClick.AddListener(_previousPage);
        //_previousButton.transform.SetSiblingIndex(_paginationButtonsContainer.GetSiblingIndex() - 1);
        //_nextButton = _createButton("NextPageButton", ">", _buttonsArea);
        //_nextButton.onClick.AddListener(_nextPage);
        //_nextButton.transform.SetSiblingIndex(_paginationButtonsContainer.GetSiblingIndex() + 1);
        _previousButton = _createButton("PreviousPageButton", "<", _buttonsArea);
        _previousButton.onClick.AddListener(_previousPage);
        _previousButton.transform.SetSiblingIndex(1);
        _nextButton = _createButton("NextPageButton", ">", _buttonsArea);
        _nextButton.onClick.AddListener(_nextPage);
        

        // Create buttons for additional pages
        for (int i = _pageButtons.Count; i < _maxTotalButtons; i++)
        {
            var newButton = _createButton($"{CustomPageButtonNamePrefix}{i + 1}", $"{i + 1}", _buttonsArea, isEnabled: false);
            _pageButtons.Add(newButton);
        }

        _nextButton.transform.SetAsLastSibling();

        // Replace the original page buttons list in the Znel controller
        _zneController._customPageButtons = _pageButtons.ToArray();
    }

    protected void Start()
    {
        Logger.LogDebug("CCSlotsController Start() called. Rebuilding page button hierarchy and updating button visibility...");

        _updateButtonVisibility();
    }

    private Button _createButton(string name, string text, Transform parent, bool isEnabled = true)
    {
        var button = Instantiate(_originalPageButtons[0], parent).GetComponent<Button>();
        button.name = name;
        button.onClick.RemoveAllListeners();
        button.GetComponentInChildren<TextMeshProUGUI>().text = text;

        if (!isEnabled)
        {
            button.interactable = false;
            var colors = button.colors;
            colors.disabledColor = new Color(colors.disabledColor.r, colors.disabledColor.g, colors.disabledColor.b, 0.5f);
            button.colors = colors;
        }

        return button;
    }

    private void _nextPage()
    {
        var lastPage = _currentPageIndex;
        _currentPageIndex = Mathf.Min(_currentPageIndex + 1, _maxButtonPage);

        if (lastPage == _currentPageIndex)
            return;

        _updateButtonVisibility();
    }

    private void _previousPage()
    {
        var lastPage = _currentPageIndex;
        _currentPageIndex = Mathf.Max(_currentPageIndex - 1, 0);

        if (lastPage == _currentPageIndex)
            return;

        _updateButtonVisibility();
    }

    private void _updateButtonVisibility()
    {
        for (int i = 0; i < _pageButtons.Count; i++)
            _pageButtons[i].gameObject.SetActive(i >= _firstButtonIndexOnCurrentPage && i <= _lastButtonIndexOnCurrentPage);

        _previousButton.interactable = _currentPageIndex > 0;
        _nextButton.interactable = _currentPageIndex < _maxButtonPage - 1;
    }
}
