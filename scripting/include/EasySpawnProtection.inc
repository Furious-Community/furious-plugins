#if defined _SpawnProtection_Included_
	#endinput
#endif
#define _SpawnProtection_Included_

public SharedPlugin __pl_SpawnProtection =
{
	name = "EasySpawnProtection",
	file = "EasySpawnProtection.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public void __pl_hosties_SetNTVOptional()
{
	MarkNativeAsOptional("ESP_IsSpawnProtected");
	MarkNativeAsOptional("ESP_GiveSpawnProtection");
	MarkNativeAsOptional("ESP_RemoveSpawnProtection");
}

native bool ESP_IsSpawnProtected(int client);
native void ESP_GiveSpawnProtection(int client, int time, int color[4]);
native void ESP_RemoveSpawnProtection(int client);

forward void ESP_OnSpawnProtectionStart();
forward void ESP_OnSpawnProtectionStartClient(int client, int color[4], int time);
forward void ESP_OnSpawnProtectionEndClient(int client);