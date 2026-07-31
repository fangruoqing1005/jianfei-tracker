-- migration_v3_7: 修复 groups 表邀请码暴露问题
-- 问题: groups_select 策略使用 USING(true)，任何人可枚举所有群组和邀请码
-- 方案: 回收公开读权限，创建 SECURITY DEFINER 函数供加入群组时按邀请码查找

-- Step 1: 创建按邀请码查找群组的函数（非成员只能通过此函数查找）
CREATE OR REPLACE FUNCTION lookup_group_by_code(code TEXT)
RETURNS TABLE(id UUID, name TEXT, owner_id UUID, invite_code TEXT)
LANGUAGE sql SECURITY DEFINER SET search_path = ''
AS $$
  SELECT g.id, g.name, g.owner_id, g.invite_code
  FROM public.groups g
  WHERE g.invite_code = code
  LIMIT 1;
$$;

-- Step 2: 授权认证用户执行此函数
GRANT EXECUTE ON FUNCTION lookup_group_by_code(TEXT) TO authenticated;

-- Step 3: 删除旧的公开策略
DROP POLICY IF EXISTS groups_select ON groups;

-- Step 4: 新策略：只有群组成员可以读取群组信息
-- 注意：创建者也必须是成员才能看到自己的群组（但创建时已自动加入）
CREATE POLICY groups_select ON groups
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() IN (
      SELECT gm.user_id FROM group_members gm WHERE gm.group_id = id
    )
  );

-- Step 5: 创建者可以管理自己的群组（更新名称等）
DROP POLICY IF EXISTS groups_update ON groups;
CREATE POLICY groups_update ON groups
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- Step 6: 创建者可以解散自己的群组
DROP POLICY IF EXISTS groups_delete ON groups;
CREATE POLICY groups_delete ON groups
  FOR DELETE
  TO authenticated
  USING (auth.uid() = owner_id);

-- Step 7: 刷新 schema 缓存
NOTIFY pgrst, 'reload schema';
