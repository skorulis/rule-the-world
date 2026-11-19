CREATE TABLE "hex_visit" (
	"user_id" text NOT NULL,
	"cell" text NOT NULL,
	"last_visit" timestamp with time zone NOT NULL,
	"score" numeric DEFAULT '0' NOT NULL,
	"last_score" numeric DEFAULT '0' NOT NULL,
	CONSTRAINT "hex_visit_user_id_cell_pk" PRIMARY KEY("user_id","cell"),
	CONSTRAINT "hex_visit_score_nonnegative" CHECK ("hex_visit"."score" >= 0 AND "hex_visit"."score" < 'Infinity'::numeric),
	CONSTRAINT "hex_visit_last_score_range" CHECK ("hex_visit"."last_score" BETWEEN 0 AND 1)
);
--> statement-breakpoint
CREATE TABLE "hex_visit_day" (
	"user_id" text NOT NULL,
	"cell" text NOT NULL,
	"day" date NOT NULL,
	"score" numeric NOT NULL,
	CONSTRAINT "hex_visit_day_user_id_cell_day_pk" PRIMARY KEY("user_id","cell","day"),
	CONSTRAINT "hex_visit_day_score_range" CHECK ("hex_visit_day"."score" BETWEEN 0 AND 1)
);
--> statement-breakpoint
ALTER TABLE "hex_visit" ADD CONSTRAINT "hex_visit_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hex_visit_day" ADD CONSTRAINT "hex_visit_day_user_id_cell_hex_visit_user_id_cell_fk" FOREIGN KEY ("user_id","cell") REFERENCES "public"."hex_visit"("user_id","cell") ON DELETE cascade ON UPDATE no action;