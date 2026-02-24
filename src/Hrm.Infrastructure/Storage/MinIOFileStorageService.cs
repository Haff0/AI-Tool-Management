using Hrm.Application.Abstractions;
using Minio;
using Minio.DataModel.Args;

namespace Hrm.Infrastructure.Storage;

public sealed class MinIOFileStorageService : IFileStorageService
{
    private readonly IMinioClient _minioClient;

    public MinIOFileStorageService(IMinioClient minioClient)
    {
        _minioClient = minioClient;
    }

    public async Task<string> UploadAsync(string bucketName, string objectName, Stream data, string contentType, CancellationToken ct = default)
    {
        var bucketExistsArgs = new BucketExistsArgs().WithBucket(bucketName);
        var found = await _minioClient.BucketExistsAsync(bucketExistsArgs, ct);
        if (!found)
        {
            var makeBucketArgs = new MakeBucketArgs().WithBucket(bucketName);
            await _minioClient.MakeBucketAsync(makeBucketArgs, ct);
        }

        var putObjectArgs = new PutObjectArgs()
            .WithBucket(bucketName)
            .WithObject(objectName)
            .WithStreamData(data)
            .WithObjectSize(data.Length)
            .WithContentType(contentType);

        await _minioClient.PutObjectAsync(putObjectArgs, ct);
        return objectName;
    }

    public async Task<Stream> DownloadAsync(string bucketName, string objectName, CancellationToken ct = default)
    {
        var stream = new MemoryStream();
        var getObjectArgs = new GetObjectArgs()
            .WithBucket(bucketName)
            .WithObject(objectName)
            .WithCallbackStream(s => s.CopyTo(stream));

        await _minioClient.GetObjectAsync(getObjectArgs, ct);
        stream.Position = 0;
        return stream;
    }

    public async Task<string> GetUrlAsync(string bucketName, string objectName, int expiryInSeconds = 3600)
    {
        var presignedArgs = new PresignedGetObjectArgs()
            .WithBucket(bucketName)
            .WithObject(objectName)
            .WithExpiry(expiryInSeconds);

        return await _minioClient.PresignedGetObjectAsync(presignedArgs);
    }
}
