#if defined _redie_included
 #endinput
#endif
#define _redie_included

native bool Redie_IsClientGhost(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_redie_SetNTVOptional()
{
	MarkNativeAsOptional("Redie_IsClientGhost");
}
#endif

public SharedPlugin __pl_redie =
{
	name = "redie",
	file = "redie.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
