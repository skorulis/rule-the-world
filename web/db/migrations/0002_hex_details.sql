CREATE TABLE "hex_details" (
	"cell" bigint NOT NULL,
	"region_country" bigint,
	"region_state" bigint,
	CONSTRAINT "hex_details_cell_pk" PRIMARY KEY("cell"),
	CONSTRAINT "hex_details_region_country_positive" CHECK ("hex_details"."region_country" > 0),
	CONSTRAINT "hex_details_region_state_positive" CHECK ("hex_details"."region_state" > 0)
);
--> statement-breakpoint
DROP TABLE "hex_region";