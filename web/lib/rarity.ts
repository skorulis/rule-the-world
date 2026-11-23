export const rarities = ["common", "rare", "epic", "legendary", "mythic"] as const;
export type Rarity = (typeof rarities)[number];
