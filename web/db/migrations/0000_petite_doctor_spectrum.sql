CREATE TABLE "account" (
	"id" text PRIMARY KEY NOT NULL,
	"account_id" text NOT NULL,
	"provider_id" text NOT NULL,
	"user_id" text NOT NULL,
	"access_token" text,
	"refresh_token" text,
	"id_token" text,
	"access_token_expires_at" timestamp,
	"refresh_token_expires_at" timestamp,
	"scope" text,
	"password" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp NOT NULL
);
--> statement-breakpoint
CREATE TABLE "session" (
	"id" text PRIMARY KEY NOT NULL,
	"expires_at" timestamp NOT NULL,
	"token" text NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp NOT NULL,
	"ip_address" text,
	"user_agent" text,
	"user_id" text NOT NULL,
	CONSTRAINT "session_token_unique" UNIQUE("token")
);
--> statement-breakpoint
CREATE TABLE "user" (
	"id" text PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"email" text NOT NULL,
	"email_verified" boolean DEFAULT false NOT NULL,
	"image" text,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	CONSTRAINT "user_email_unique" UNIQUE("email")
);
--> statement-breakpoint
CREATE TABLE "verification" (
	"id" text PRIMARY KEY NOT NULL,
	"identifier" text NOT NULL,
	"value" text NOT NULL,
	"expires_at" timestamp NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "hex_visit" (
	"user_id" text NOT NULL,
	"cell" bigint NOT NULL,
	"last_visit" timestamp with time zone NOT NULL,
	"score" numeric DEFAULT '0' NOT NULL,
	"total" integer DEFAULT 0 NOT NULL,
	"last_score" numeric DEFAULT '0' NOT NULL,
	CONSTRAINT "hex_visit_user_id_cell_pk" PRIMARY KEY("user_id","cell"),
	CONSTRAINT "hex_visit_total_nonnegative" CHECK ("hex_visit"."total" >= 0),
	CONSTRAINT "hex_visit_score_nonnegative" CHECK ("hex_visit"."score" >= 0 AND "hex_visit"."score" < 'Infinity'::numeric),
	CONSTRAINT "hex_visit_last_score_range" CHECK ("hex_visit"."last_score" BETWEEN 0 AND 1)
);
--> statement-breakpoint
CREATE TABLE "hex_visit_day" (
	"user_id" text NOT NULL,
	"cell" bigint NOT NULL,
	"day" date NOT NULL,
	"score" numeric NOT NULL,
	CONSTRAINT "hex_visit_day_user_id_cell_day_pk" PRIMARY KEY("user_id","cell","day"),
	CONSTRAINT "hex_visit_day_score_range" CHECK ("hex_visit_day"."score" BETWEEN 0 AND 1)
);
--> statement-breakpoint
CREATE TABLE "hex_visit_upload" (
	"user_id" text NOT NULL,
	"id" text NOT NULL,
	"cell" bigint NOT NULL,
	"count" integer NOT NULL,
	CONSTRAINT "hex_visit_upload_user_id_id_pk" PRIMARY KEY("user_id","id"),
	CONSTRAINT "hex_visit_upload_count_positive" CHECK ("hex_visit_upload"."count" > 0)
);
--> statement-breakpoint
CREATE TABLE "hex_region" (
	"cell" bigint PRIMARY KEY NOT NULL,
	"region" bigint NOT NULL,
	"region_type" smallint NOT NULL,
	CONSTRAINT "hex_region_region_nonnegative" CHECK ("hex_region"."region" >= 0),
	CONSTRAINT "hex_region_region_type_range" CHECK ("hex_region"."region_type" BETWEEN 0 AND 2)
);
--> statement-breakpoint
ALTER TABLE "account" ADD CONSTRAINT "account_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "session" ADD CONSTRAINT "session_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hex_visit" ADD CONSTRAINT "hex_visit_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hex_visit_day" ADD CONSTRAINT "hex_visit_day_user_id_cell_hex_visit_user_id_cell_fk" FOREIGN KEY ("user_id","cell") REFERENCES "public"."hex_visit"("user_id","cell") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "hex_visit_upload" ADD CONSTRAINT "hex_visit_upload_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "account_userId_idx" ON "account" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "session_userId_idx" ON "session" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "verification_identifier_idx" ON "verification" USING btree ("identifier");
