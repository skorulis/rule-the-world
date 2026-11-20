CREATE TABLE "hex_visit_upload" (
	"user_id" text NOT NULL,
	"id" text NOT NULL,
	"cell" text NOT NULL,
	"count" integer NOT NULL,
	CONSTRAINT "hex_visit_upload_user_id_id_pk" PRIMARY KEY("user_id","id"),
	CONSTRAINT "hex_visit_upload_count_positive" CHECK ("hex_visit_upload"."count" > 0)
);
--> statement-breakpoint
ALTER TABLE "hex_visit" ADD COLUMN "total" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "hex_visit_upload" ADD CONSTRAINT "hex_visit_upload_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hex_visit" ADD CONSTRAINT "hex_visit_total_nonnegative" CHECK ("hex_visit"."total" >= 0);