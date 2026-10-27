import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

export class Attachments {
  constructor(bucket, client = new S3Client({ requestChecksumCalculation: 'WHEN_REQUIRED' })) {
    if (!bucket) throw new Error('ATTACHMENTS_BUCKET is required');
    this.bucket = bucket;
    this.client = client;
  }
  async upload(key, contentType, size) {
    const uploadUrl = await getSignedUrl(this.client, new PutObjectCommand({
      Bucket: this.bucket, Key: key, ContentType: contentType, ContentLength: size,
      ServerSideEncryption: 'AES256',
    }), { expiresIn: 300, signableHeaders: new Set(['content-type', 'content-length']) });
    return { objectKey: key, uploadUrl, contentType, expiresIn: 300,
      headers: { 'Content-Type': contentType, 'x-amz-server-side-encryption': 'AES256' } };
  }
  download(key) {
    return getSignedUrl(this.client, new GetObjectCommand({ Bucket: this.bucket, Key: key }), { expiresIn: 900 });
  }
}
