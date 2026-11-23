ALTER TABLE "user" ALTER COLUMN "rankings" SET DEFAULT '[]'::jsonb;--> statement-breakpoint
UPDATE "user" SET "rankings" = '[]'::jsonb WHERE jsonb_typeof("rankings") <> 'array';