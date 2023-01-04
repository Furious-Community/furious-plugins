#if defined _furious_resetscore_included
 #endinput
#endif
#define _furious_resetscore_included

native void Furious_ResetScore_ResetPlayer(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_resetscore_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_ResetScore_ResetPlayer");
}
#endif

public SharedPlugin __pl_furious_resetscore =
{
	name = "furious_resetscore",
	file = "furious-resetscore.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
