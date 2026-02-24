namespace Hrm.Application.Abstractions;

public interface ICacheService
{
    Task<T?> GetAsync<T>(string key, CancellationToken ct = default);
    Task SetAsync<T>(string key, T value, TimeSpan? expirationTime = null, CancellationToken ct = default);
    Task RemoveAsync(string key, CancellationToken ct = default);
}
