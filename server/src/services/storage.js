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
) {
  const extension =
    originalName.split('.').pop()?.toLowerCase() || 'jpg';

 const fileName = `current-id.${extension}`;

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