-- migration_v3_1.sql
-- 修复 group_members 的 RLS SELECT 策略递归问题
-- 原策略在子查询中再次查询 group_members，可能导致 RLS 递归权限错误

-- 移除旧的递归策略
DROP POLICY IF EXISTS gm_select ON group_members;

-- 新策略：用户可以看到自己是成员的群组，或自己是群主的群组
CREATE POLICY gm_select ON group_members FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    auth.uid() IN (
      SELECT owner_id FROM groups WHERE id = group_members.group_id
    )
  );

-- 确保 authenticated 角色有 group_members 的 SELECT 权限
GRANT SELECT ON public.group_members TO authenticated;
