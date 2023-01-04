#if defined _furious_tags_included
 #endinput
#endif
#define _furious_tags_included

native int Furious_Tags_GetPrefixID(int client);
native void Furious_Tags_GetPrefix(int index, char[] prefix, int size);
native void Furious_Tags_GetPrefixColor(int index, char[] prefixcolor, int size);
native void Furious_Tags_GetGroup(int index, char[] group, int size);
native void Furious_Tags_GetHudPrefix(int index, char[] prefix, int size);
native void Furious_Tags_GetHudPrefixColor(int index, char[] prefixcolor, int size);
native void Furious_Tags_GetHudGroup(int index, char[] group, int size);
native void Furious_Tags_ChangeTagMenu(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_tags_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_Tags_GetPrefixID");
	MarkNativeAsOptional("Furious_Tags_GetPrefix");
	MarkNativeAsOptional("Furious_Tags_GetPrefixColor");
	MarkNativeAsOptional("Furious_Tags_GetGroup");
	MarkNativeAsOptional("Furious_Tags_GetHudPrefix");
	MarkNativeAsOptional("Furious_Tags_GetHudPrefixColor");
	MarkNativeAsOptional("Furious_Tags_GetHudGroup");
	MarkNativeAsOptional("Furious_Tags_ChangeTagMenu");
}
#endif

public SharedPlugin __pl_furious_tags =
{
	name = "furious_tags",
	file = "furious-tags.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
