#if defined _furious_weapons_included
 #endinput
#endif
#define _furious_weapons_included

native bool Furious_Weapons_IsDropshotKill(int client);


#if !defined REQUIRE_PLUGIN
public void __pl_player_weapons_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_Weapons_IsDropshotKill");
}
#endif

public SharedPlugin __pl_player_weapons =
{
	name = "furious_weapons",
	file = "furious-weapons.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
