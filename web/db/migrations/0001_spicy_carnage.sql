ALTER TABLE "hex_region" DROP CONSTRAINT "hex_region_pkey";--> statement-breakpoint
ALTER TABLE "hex_region" ADD CONSTRAINT "hex_region_cell_region_type_pk" PRIMARY KEY("cell","region_type");
