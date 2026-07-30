-- migration_v3_6.sql
-- 为 profiles 表添加 AI 分析风格偏好

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS analysis_style TEXT DEFAULT 'gentle';
-- 可选值: gentle(温柔), firm(严厉), cheer(鼓励), pro(专业)
