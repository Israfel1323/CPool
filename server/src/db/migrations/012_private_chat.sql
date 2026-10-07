-- Private driver <-> passenger chat

ALTER TABLE chat_messages
ADD COLUMN IF NOT EXISTS recipient_id UUID
REFERENCES profiles(id)
ON DELETE CASCADE;

ALTER TABLE chat_messages
ADD COLUMN IF NOT EXISTS read_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_chat_conversation
ON chat_messages(commute_id, sender_id, recipient_id, created_at);

CREATE INDEX IF NOT EXISTS idx_chat_unread
ON chat_messages(recipient_id, read_at, created_at);