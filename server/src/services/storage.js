import { createClient } from '@supabase/supabase-js';
import crypto from 'crypto';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
);

/**
 * Upload a student's ID card to Supabase Storage.
 *
 * @param {Buffer} fileBuffer
 * @param {string} originalName
 * @param {string} mimeType
 * @param {string} profileId
 * @returns {Promise<string>} File path in Supabase Storage
 */
export async function uploadStudentId(
  fileBuffer,
  originalName,
  mimeType,
  profileId,
  side,
) {
  const extension =
    originalName.split('.').pop()?.toLowerCase() || 'jpg';

  const fileName = `current-id-${side}.${extension}`;

  const filePath = `${profileId}/${fileName}`;

  const { error } = await supabase.storage
    .from('student-ids')
    .upload(filePath, fileBuffer, {
      contentType: mimeType,
      upsert: true,
      cacheControl: '3600',
    });

  if (error) {
    throw new Error(`Upload failed: ${error.message}`);
  }

  return filePath;
}
/**
 * Create a temporary signed URL for a private storage object.
 *
 * @param {string} bucket
 * @param {string} filePath
 * @param {number} expiresIn
 * @returns {Promise<string>}
 */
export async function createSignedStorageUrl(
  bucket,
  filePath,
  expiresIn = 300,
) {
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(filePath, expiresIn);

  if (error) {
    throw new Error(
      `Unable to create signed URL: ${error.message}`,
    );
  }

  if (!data?.signedUrl) {
    throw new Error(
      'Unable to create signed URL: no URL returned.',
    );
  }

  return data.signedUrl;
}