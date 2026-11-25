CREATE TABLE "player_ranking" (
	"user_id" text NOT NULL,
	"region_id" bigint NOT NULL,
	"region_type" text NOT NULL,
	"visit_count" integer NOT NULL,
	"owned_count" integer NOT NULL,
	"rank_number" integer NOT NULL,
	CONSTRAINT "player_ranking_user_id_region_type_region_id_pk" PRIMARY KEY("user_id","region_type","region_id"),
	CONSTRAINT "player_ranking_region_id_positive" CHECK ("player_ranking"."region_id" > 0),
	CONSTRAINT "player_ranking_region_type_valid" CHECK ("player_ranking"."region_type" IN ('global', 'country', 'state', 'suburb')),
	CONSTRAINT "player_ranking_visit_count_nonnegative" CHECK ("player_ranking"."visit_count" >= 0),
	CONSTRAINT "player_ranking_owned_count_nonnegative" CHECK ("player_ranking"."owned_count" >= 0),
	CONSTRAINT "player_ranking_rank_number_positive" CHECK ("player_ranking"."rank_number" > 0)
);
--> statement-breakpoint
ALTER TABLE "player_ranking" ADD CONSTRAINT "player_ranking_user_id_user_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."user"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user" DROP COLUMN "rankings";