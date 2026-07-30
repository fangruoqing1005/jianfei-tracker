-- migration_v3_5.sql
-- 修复：群组内所有成员应该互相可见（之前只有群主能看所有人）

-- 创建一个 SECURITY DEFINER 函数，绕过 RLS 检查成员关系
-- 这样在 RLS 策略中调用此函数不会产生递归
CREATE OR REPLACE FUNCTION is_group_member(gid UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.group_members 
    WHERE group_id = gid AND user_id = auth.uid()
  );
$$;

-- 删除旧策略
DROP POLICY IF EXISTS gm_select ON public.group_members;

-- 新策略：群组内任意成员都能看到群组内所有成员
CREATE POLICY gm_select ON public.group_members FOR SELECT
  USING (
    user_id = auth.uid()
    OR is_group_member(group_id)
  );
