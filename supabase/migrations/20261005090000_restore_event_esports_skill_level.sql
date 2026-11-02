-- Reconstructed migration: the production schema contains
-- event_esports.skill_level_code, but the archived migration chain
-- does not create it before the optimization migration.

ALTER TABLE public.event_esports
  ADD COLUMN IF NOT EXISTS skill_level_code text;

-- Backfill existing rows if this column was missing.
UPDATE public.event_esports AS ee
SET skill_level_code = COALESCE(
  (
    SELECT sl.code
    FROM public.skill_levels AS sl
    WHERE sl.code = 'intermediate'
    LIMIT 1
  ),
  (
    SELECT sl.code
    FROM public.skill_levels AS sl
    ORDER BY sl.sort_order, sl.code
    LIMIT 1
  )
)
WHERE ee.skill_level_code IS NULL;

-- Restore the foreign key if it is missing.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.event_esports'::regclass
      AND conname = 'event_esports_skill_level_code_fkey'
  ) THEN
    ALTER TABLE public.event_esports
      ADD CONSTRAINT event_esports_skill_level_code_fkey
      FOREIGN KEY (skill_level_code)
      REFERENCES public.skill_levels(code)
      ON DELETE RESTRICT;
  END IF;
END
$$;

ALTER TABLE public.event_esports
  ALTER COLUMN skill_level_code SET NOT NULL;