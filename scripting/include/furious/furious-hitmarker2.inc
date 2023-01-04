#if defined _furious_hitmarker2_included
 #endinput
#endif
#define _furious_hitmarker2_included

native bool Furious_HitMarker2_Begin(int client);
native bool Furious_hitmarker2_GetPrefix(int index, char[] prefix, int size);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_hitmarker2_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_HitMarker2_Begin");
	MarkNativeAsOptional("Furious_HitMarker2_End");
}
#endif

public SharedPlugin __pl_furious_hitmarker2 =
{
	name = "furious_hitmarker2",
	file = "furious-hitmarker2.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};