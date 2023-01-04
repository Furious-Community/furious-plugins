#if defined _furious_playerskins_included
 #endinput
#endif
#define _furious_playerskins_included

native bool Furious_PlayerSkins_GetCustomModel(int client, char[] model, int size);
native void Furious_PlayerSkins_SetCustomModel(int client, const char[] model);
native void Furious_PlayerSkins_ResetCustomModel(int client);
native bool Furious_PlayerSkins_GetCustomArms(int client, char[] model, int size);
native void Furious_PlayerSkins_SetCustomArms(int client, const char[] model);
native void Furious_PlayerSkins_ResetCustomArms(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_store_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_PlayerSkins_GetCustomModel");
	MarkNativeAsOptional("Furious_PlayerSkins_SetCustomModel");
	MarkNativeAsOptional("Furious_PlayerSkins_ResetCustomModel");
	MarkNativeAsOptional("Furious_PlayerSkins_GetCustomArms");
	MarkNativeAsOptional("Furious_PlayerSkins_SetCustomArms");
	MarkNativeAsOptional("Furious_PlayerSkins_ResetCustomArms");
}
#endif

public SharedPlugin __pl_furious_playerskins =
{
	name = "furious_playerskins",
	file = "furious-playerskins.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
