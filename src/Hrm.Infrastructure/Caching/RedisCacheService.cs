using System.Text.Json;
using Hrm.Application.Abstractions;
using Microsoft.Extensions.Caching.Distributed;

namespace Hrm.Infrastructure.Caching;

public sealed class RedisCacheService : ICacheService
{
    private readonly IDistributedCache _cache;

    public RedisCacheService(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<T?> GetAsync<T>(string key, CancellationToken ct = default)
    {
        var cachedData = await _cache.GetStringAsync(key, ct);
        if (cachedData == null)
        {
            return default;
        }

        return JsonSerializer.Deserialize<T>(cachedData);
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expirationTime = null, CancellationToken ct = default)
    {
        var options = new DistributedCacheEntryOptions();
        if (expirationTime.HasValue)
        {
            options.AbsoluteExpirationRelativeToNow = expirationTime.Value;
        }

        var serializedData = JsonSerializer.Serialize(value);
        await _cache.SetStringAsync(key, serializedData, options, ct);
    }

    public async Task RemoveAsync(string key, CancellationToken ct = default)
    {
        await _cache.RemoveAsync(key, ct);
    }
}
