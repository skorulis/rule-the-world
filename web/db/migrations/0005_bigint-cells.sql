ALTER TABLE "hex_region" ALTER COLUMN "cell" SET DATA TYPE bigint USING ('x' || lpad("cell", 16, '0'))::bit(64)::bigint;--> statement-breakpoint
ALTER TABLE "hex_visit" ALTER COLUMN "cell" SET DATA TYPE bigint USING ('x' || lpad("cell", 16, '0'))::bit(64)::bigint;--> statement-breakpoint
ALTER TABLE "hex_visit_day" ALTER COLUMN "cell" SET DATA TYPE bigint USING ('x' || lpad("cell", 16, '0'))::bit(64)::bigint;--> statement-breakpoint
ALTER TABLE "hex_visit_upload" ALTER COLUMN "cell" SET DATA TYPE bigint USING ('x' || lpad("cell", 16, '0'))::bit(64)::bigint;
