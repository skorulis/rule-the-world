CREATE TABLE "hex_region" (
	"cell" text PRIMARY KEY NOT NULL,
	"region" text NOT NULL,
	CONSTRAINT "hex_region_region_nonempty" CHECK ("hex_region"."region" <> '')
);
