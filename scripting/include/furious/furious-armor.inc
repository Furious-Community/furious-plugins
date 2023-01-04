#if defined _furious_armor_included
 #endinput
#endif
#define _furious_armor_included

native void Furious_Armor_SetBuffer(int client, int buffer, bool round_reset = true);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_armor_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_Armor_SetBuffer");
}
#endif

public SharedPlugin __pl_furious_armor =
{
	name = "furious_armor",
	file = "furious-armor.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
