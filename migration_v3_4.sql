-- migration_v3_4.sql
-- 修复 profiles 表权限 + 序列权限

-- 授予 authenticated 角色对 profiles 表的完整读写权限
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;

-- 如果 profiles 表使用了自增序列，授予序列权限
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.sequences WHERE sequence_name = 'profiles_id_seq') THEN
    EXECUTE 'GRANT USAGE ON SEQUENCE profiles_id_seq TO authenticated';
  END IF;
END $$;
