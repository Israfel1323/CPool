-- 025_repair_interests_system.sql
-- Repair migration for the interests feature.
-- Safe to run even if parts of migration 024 already exist.

BEGIN;

CREATE TABLE IF NOT EXISTS interests (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  category TEXT NOT NULL,
  icon TEXT,
  display_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS profile_interests (
  profile_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  interest_id INTEGER NOT NULL REFERENCES interests(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (profile_id, interest_id)
);

CREATE INDEX IF NOT EXISTS idx_profile_interests_profile_id
  ON profile_interests(profile_id);

CREATE INDEX IF NOT EXISTS idx_profile_interests_interest_id
  ON profile_interests(interest_id);

-- Seed the same interest catalogue used by 024.
INSERT INTO interests (name, category, icon, display_order) VALUES
  ('Photography', 'Creative', 'photo_camera', 1),
  ('Drawing', 'Creative', 'draw', 2),
  ('Painting', 'Creative', 'palette', 3),
  ('Music', 'Creative', 'music_note', 4),
  ('Singing', 'Creative', 'mic', 5),
  ('Dancing', 'Creative', 'music_note', 6),
  ('Writing', 'Creative', 'edit', 7),
  ('Filmmaking', 'Creative', 'movie', 8),
  ('Reading', 'Knowledge', 'menu_book', 9),
  ('Books', 'Knowledge', 'auto_stories', 10),
  ('Podcasts', 'Entertainment', 'podcasts', 11),
  ('Movies', 'Entertainment', 'movie', 12),
  ('Anime', 'Entertainment', 'play_circle', 13),
  ('TV Shows', 'Entertainment', 'tv', 14),
  ('Stand-up Comedy', 'Entertainment', 'sentiment_very_satisfied', 15),
  ('Football', 'Sports', 'sports_soccer', 16),
  ('Cricket', 'Sports', 'sports_cricket', 17),
  ('Basketball', 'Sports', 'sports_basketball', 18),
  ('Tennis', 'Sports', 'sports_tennis', 19),
  ('Badminton', 'Sports', 'sports', 20),
  ('Running', 'Sports', 'directions_run', 21),
  ('Cycling', 'Sports', 'directions_bike', 22),
  ('Gym & Fitness', 'Sports', 'fitness_center', 23),
  ('Swimming', 'Sports', 'pool', 24),
  ('Hiking', 'Sports', 'hiking', 25),
  ('Coding', 'Technology', 'code', 26),
  ('AI & Machine Learning', 'Technology', 'psychology', 27),
  ('Web Development', 'Technology', 'web', 28),
  ('App Development', 'Technology', 'phone_android', 29),
  ('Gaming', 'Gaming', 'sports_esports', 30),
  ('Esports', 'Gaming', 'emoji_events', 31),
  ('Startups', 'Business & Finance', 'rocket_launch', 32),
  ('Entrepreneurship', 'Business & Finance', 'business_center', 33),
  ('Investing', 'Business & Finance', 'trending_up', 34),
  ('Stock Market', 'Business & Finance', 'show_chart', 35),
  ('Crypto', 'Business & Finance', 'currency_bitcoin', 36),
  ('Finance', 'Business & Finance', 'account_balance', 37),
  ('History', 'Knowledge', 'history_edu', 38),
  ('Science', 'Knowledge', 'science', 39),
  ('Space', 'Knowledge', 'rocket', 40),
  ('Psychology', 'Knowledge', 'psychology_alt', 41),
  ('Technology', 'Knowledge', 'devices', 42),
  ('Travel', 'Lifestyle', 'travel_explore', 43),
  ('Food', 'Lifestyle', 'restaurant', 44),
  ('Cooking', 'Lifestyle', 'cooking', 45),
  ('Coffee', 'Lifestyle', 'coffee', 46),
  ('Fashion', 'Lifestyle', 'checkroom', 47),
  ('Cars', 'Lifestyle', 'directions_car', 48),
  ('Motorcycles', 'Lifestyle', 'two_wheeler', 49),
  ('Pets', 'Lifestyle', 'pets', 50),
  ('Volunteering', 'Lifestyle', 'volunteer_activism', 51),
  ('Meditation', 'Lifestyle', 'self_improvement', 52),
  ('Entrepreneurship', 'Business & Finance', 'lightbulb', 53),
  ('Public Speaking', 'Knowledge', 'record_voice_over', 54),
  ('Languages', 'Knowledge', 'translate', 55),
  ('Debate', 'Knowledge', 'forum', 56),
  ('Chess', 'Gaming', 'extension', 57),
  ('Board Games', 'Gaming', 'casino', 58),
  ('Football Analytics', 'Sports', 'analytics', 59),
  ('Tech News', 'Technology', 'newspaper', 60),
  ('Open Source', 'Technology', 'code', 61),
  ('Robotics', 'Technology', 'smart_toy', 62),
  ('Cybersecurity', 'Technology', 'security', 63),
  ('UI/UX Design', 'Creative', 'design_services', 64),
  ('Graphic Design', 'Creative', 'brush', 65),
  ('Content Creation', 'Creative', 'video_library', 66),
  ('Social Media', 'Entertainment', 'share', 67),
  ('K-pop', 'Entertainment', 'music_note', 68),
  ('Gaming Streams', 'Gaming', 'live_tv', 69),
  ('Beach & Outdoors', 'Lifestyle', 'beach_access', 70)
ON CONFLICT (name) DO NOTHING;

COMMIT;
