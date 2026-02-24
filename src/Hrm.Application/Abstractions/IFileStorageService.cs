namespace Hrm.Application.Abstractions;

public interface IFileStorageService
{
    Task<string> UploadAsync(string bucketName, string objectName, Stream data, string contentType, CancellationToken ct = default);
    Task<Stream> DownloadAsync(string bucketName, string objectName, CancellationToken ct = default);
    Task<string> GetUrlAsync(string bucketName, string objectName, int expiryInSeconds = 3600);
}
