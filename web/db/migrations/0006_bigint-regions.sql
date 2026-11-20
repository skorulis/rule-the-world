ALTER TABLE "hex_region" DROP CONSTRAINT "hex_region_region_nonempty";--> statement-breakpoint
ALTER TABLE "hex_region" ALTER COLUMN "region" SET DATA TYPE bigint USING CASE WHEN "region" = 'none' THEN 0 ELSE "region"::bigint END;--> statement-breakpoint
ALTER TABLE "hex_region" ADD CONSTRAINT "hex_region_region_nonnegative" CHECK ("hex_region"."region" >= 0);