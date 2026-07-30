-- ============================================================
-- 减脂管理工作台 — Phase 2a: 群组 + 邀请 + 分享开关
-- 在 Supabase SQL Editor 中执行
-- ============================================================

-- 1. 群组表
CREATE TABLE IF NOT EXISTS groups (
  id          UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  name        TEXT NOT NULL,
  owner_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  invite_code TEXT NOT NULL UNIQUE,
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- 2. 群组成员表
CREATE TABLE IF NOT EXISTS group_members (
  id        BIGSERIAL PRIMARY KEY,
  group_id  UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(group_id, user_id)
);

-- 3. 分享设置表
CREATE TABLE IF NOT EXISTS shared_data (
  id                 BIGSERIAL PRIMARY KEY,
  user_id            UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  group_id           UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  share_weight       BOOLEAN DEFAULT false,
  share_achievements BOOLEAN DEFAULT false,
  share_checkin      BOOLEAN DEFAULT false,
  updated_at         TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, group_id)
);

-- ====== RLS 策略 ======

-- 启用 RLS
ALTER TABLE groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE shared_data ENABLE ROW LEVEL SECURITY;

-- groups: 任何人都可以读（需要知道群组存在），只有 owner 可以删改
DROP POLICY IF EXISTS groups_select ON groups;
CREATE POLICY groups_select ON groups FOR SELECT
  USING (true);

DROP POLICY IF EXISTS groups_insert ON groups;
CREATE POLICY groups_insert ON groups FOR INSERT
  WITH CHECK (auth.uid() = owner_id);

DROP POLICY IF EXISTS groups_delete ON groups;
CREATE POLICY groups_delete ON groups FOR DELETE
  USING (auth.uid() = owner_id);

DROP POLICY IF EXISTS groups_update ON groups;
CREATE POLICY groups_update ON groups FOR UPDATE
  USING (auth.uid() = owner_id);

-- group_members: 群组成员可以查看，任何人都可以加入（INSERT），owner 可以删除成员
DROP POLICY IF EXISTS gm_select ON group_members;
CREATE POLICY gm_select ON group_members FOR SELECT
  USING (
    auth.uid() IN (
      SELECT user_id FROM group_members gm2 WHERE gm2.group_id = group_members.group_id
    )
    OR
    auth.uid() IN (
      SELECT owner_id FROM groups WHERE id = group_members.group_id
    )
  );

DROP POLICY IF EXISTS gm_insert ON group_members;
CREATE POLICY gm_insert ON group_members FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS gm_delete ON group_members;
CREATE POLICY gm_delete ON group_members FOR DELETE
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT owner_id FROM groups WHERE id = group_members.group_id
    )
  );

-- shared_data: 只能读写自己的；群组成员可以读已分享的数据
DROP POLICY IF EXISTS sd_select ON shared_data;
CREATE POLICY sd_select ON shared_data FOR SELECT
  USING (
    auth.uid() = user_id
    OR
    auth.uid() IN (
      SELECT gm.user_id FROM group_members gm WHERE gm.group_id = shared_data.group_id
    )
  );

DROP POLICY IF EXISTS sd_insert ON shared_data;
CREATE POLICY sd_insert ON shared_data FOR INSERT
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS sd_update ON shared_data;
CREATE POLICY sd_update ON shared_data FOR UPDATE
  USING (auth.uid() = user_id);

DROP POLICY IF EXISTS sd_delete ON shared_data;
CREATE POLICY sd_delete ON shared_data FOR DELETE
  USING (auth.uid() = user_id);

-- ====== 索引 ======
CREATE INDEX IF NOT EXISTS idx_groups_owner ON groups(owner_id);
CREATE INDEX IF NOT EXISTS idx_groups_invite ON groups(invite_code);
CREATE INDEX IF NOT EXISTS idx_gm_user ON group_members(user_id);
CREATE INDEX IF NOT EXISTS idx_gm_group ON group_members(group_id);
CREATE INDEX IF NOT EXISTS idx_sd_user_group ON shared_data(user_id, group_id);
