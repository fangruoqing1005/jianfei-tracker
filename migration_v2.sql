-- ============================================================
-- 减脂管理工作台 v2 — 多用户数据隔离迁移 SQL
-- 请在 Supabase SQL Editor 中执行此脚本
-- https://supabase.com/dashboard/project/bdtueuwyatnozybbbucd/sql/new
-- ============================================================

-- Step 1: 添加 user_id 列（先设为可空，补数据后再加 NOT NULL）
ALTER TABLE records ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

-- Step 2: 检查现有数据。如果有旧记录且 user_id 为空：
-- 你需要将自己的用户 UUID 填入下方。注册后可在 Supabase Dashboard → Authentication → Users 中查看。
-- 找到你的 user id 后，取消下面这行的注释并替换 'YOUR-USER-ID-HERE'：
-- UPDATE records SET user_id = 'YOUR-USER-ID-HERE' WHERE user_id IS NULL;

-- Step 3: 删除旧的唯一约束（基于 date 的）
ALTER TABLE records DROP CONSTRAINT IF EXISTS records_date_key;

-- Step 4: 添加新的复合唯一约束（基于 user_id + date）
ALTER TABLE records ADD CONSTRAINT records_user_date_key UNIQUE (user_id, date);

-- Step 5: 确保 RLS 已启用
ALTER TABLE records ENABLE ROW LEVEL SECURITY;

-- Step 6: 删除旧的全开放策略
DROP POLICY IF EXISTS allow_all ON records;
DROP POLICY IF EXISTS "Allow all for now" ON records;

-- Step 7: 创建新的数据隔离策略
-- 用户只能增删改查自己的数据
CREATE POLICY "Users can access own records"
  ON records
  FOR ALL
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 可选：如果你希望也允许未登录用户使用（本地模式），
-- 可以取消下面注释。但通常建议只允许已认证用户。
-- CREATE POLICY "Allow insert for anon"
--   ON records FOR INSERT TO anon
--   WITH CHECK (true);
-- ============================================================

-- Step 8: 检查结果
SELECT 'Migration complete! Current table structure:' AS info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'records'
ORDER BY ordinal_position;
