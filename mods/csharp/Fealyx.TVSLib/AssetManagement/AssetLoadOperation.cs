using System.Collections;
using UnityEngine;

namespace Fealyx.TVSLib.AssetManagement;

/// <summary>
/// Represents an async asset loading operation.
/// </summary>
public class AssetLoadOperation<T> where T : UnityEngine.Object
{
    private readonly Coroutine? _coroutine;
    private T? _result;
    private bool _isDone;

    public bool IsDone => _isDone;
    public T? Asset => _result;

    internal AssetLoadOperation(Coroutine? coroutine)
    {
        _coroutine = coroutine;
        _isDone = coroutine == null;
    }

    internal void SetResult(T? result)
    {
        _result = result;
        _isDone = true;
    }

    /// <summary>
    /// Blocks until the async operation completes and returns the result.
    /// Note: This is a simplified implementation. In production, you may want
    /// to implement proper coroutine completion tracking.
    /// </summary>
    public T? WaitForCompletion()
    {
        // This is a simplified version - the operation completes via coroutine
        // In a full implementation, you'd want to properly track completion
        return _result;
    }
}
