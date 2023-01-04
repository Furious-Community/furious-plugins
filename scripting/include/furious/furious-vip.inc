#if defined _furious_vip_included
 #endinput
#endif
#define _furious_vip_included

enum AddVIPRet
{
	ADDVIP_ALREADY_TRIED_VIP = -2,
	ADDVIP_ALREADY_VIP,
	ADDVIP_CANNOT_BIND,
	ADDVIP_SUCCESS
}

native bool Furious_VIP_IsModelEnabled(int client);
native bool Furious_VIP_IsSpecListEnabled(int client);
native AddVIPRet Furious_VIP_AddVIP(const char[] username, const char[] steamId, int duration, bool tryout = false);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_vip_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_VIP_IsModelEnabled");
	MarkNativeAsOptional("Furious_VIP_IsSpecListEnabled");
	MarkNativeAsOptional("Furious_VIP_AddVIP");
}
#endif

public SharedPlugin __pl_furious_vip =
{
	name = "furious_vip",
	file = "furious-vip.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
