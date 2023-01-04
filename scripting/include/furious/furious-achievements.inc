#if defined _furious_achievements_included
 #endinput
#endif
#define _furious_achievements_included

#if !defined REQUIRE_PLUGIN
public void __pl_furious_achievements_SetNTVOptional()
{
	//MarkNativeAsOptional("");
}
#endif

public SharedPlugin __pl_furious_achievements =
{
	name = "furious_achievements",
	file = "furious-achievements.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
