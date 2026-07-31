-- migration_v3_8: AI 分析调用次数限制
-- 每人每天最多 3 次 Edge Function 调用

CREATE TABLE IF NOT EXISTS ai_usage (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
  call_count INTEGER NOT NULL DEFAULT 1,
  last_call_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, usage_date)
);

-- RLS: 用户只能读取自己的用量，不能修改
ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY ai_usage_select ON ai_usage
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- 插入/更新由 Edge Function 通过 service_role 操作，不需要给用户权限
-- 但为了前端也能读取（显示剩余次数），添加只读权限
CREATE POLICY ai_usage_insert ON ai_usage
  FOR INSERT
  TO authenticated
  WITH CHECK (false);  -- 前端不可插入，只由 Edge Function 写入

CREATE POLICY ai_usage_update ON ai_usage
  FOR UPDATE
  TO authenticated
  USING (false);  -- 前端不可更新

-- GRANT sequence
GRANT USAGE ON SEQUENCE ai_usage_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE ai_usage_id_seq TO service_role;

-- 刷新缓存
NOTIFY pgrst, 'reload schema';
