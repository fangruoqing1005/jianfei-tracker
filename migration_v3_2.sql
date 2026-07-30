-- migration_v3_2.sql
-- 修复：授予 authenticated 角色使用序列的权限
-- group_members 和 shared_data 使用 BIGSERIAL，插入时需要 USE 序列

GRANT USAGE ON SEQUENCE group_members_id_seq TO authenticated;
GRANT USAGE ON SEQUENCE shared_data_id_seq TO authenticated;
