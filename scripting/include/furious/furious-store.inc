#if defined _furious_store_included
 #endinput
#endif
#define _furious_store_included

#define ITEM_DEFINE_SPAWNEQUIPMENT "spawn_equipment"
#define ITEM_DEFINE_SPRAYS "sprays"
#define ITEM_DEFINE_TAGS "tags"
#define ITEM_DEFINE_SKYBOXES "skyboxes"
#define ITEM_DEFINE_MODELS "models"
#define ITEM_DEFINE_OPENCHARGES "opencharges"
#define ITEM_DEFINE_PHOENIXKIT "phoenixkit"

#define MAX_STORE_ITEMS 256
#define MAX_STORE_ITEM_NAME_LENGTH 256
#define MAX_STORE_ITEM_TYPE_LENGTH 256
#define MAX_STORE_ITEM_DESCRIPTION_LENGTH 256
#define MAX_STORE_ITEM_TAG_LENGTH 256
#define MAX_STORE_ITEM_SKYBOX_LENGTH 256
#define MAX_STORE_ITEM_MODEL_LENGTH 256
#define MAX_STORE_ITEM_PREVIEW_LENGTH 256

native bool Furious_Store_GetClientTag(int client, char[] tag, int size);
native int Furious_Store_GetDefaultCredits();

native bool Furious_Store_GetClientEquipped(int client, const char[] itemtype, char[] itemname, int size);
native int Furious_Store_GetClientCharges(int client, const char[] itemname);
native bool Furious_Store_SetClientCharges(int client, const char[] itemname, const char[] itemtype, int amount);
native int Furious_Store_ShowVipMenu(int client);
native bool Furious_Store_Phoenix_Kit_Used(int client);
native bool Furious_Store_SendItemByName(int client, const char[] itemname);
native bool Furious_Store_SendItemByNameToAccount(int accountid, const char[] itemname);
native bool Furious_Store_GiveItem(int client, const char[] itemname, const char[] itemtype, const char[] itemdescription, int price, int charges);

#if !defined REQUIRE_PLUGIN
public void __pl_furious_store_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_Store_GetClientTag");	
	MarkNativeAsOptional("Furious_Store_GetDefaultCredits");
	MarkNativeAsOptional("Furious_Store_GetClientEquipped");
	MarkNativeAsOptional("Furious_Store_GetClientCharges");
	MarkNativeAsOptional("Furious_Store_SetClientCharges");
	MarkNativeAsOptional("Furious_Store_ShowVipMenu");
	MarkNativeAsOptional("Furious_Store_Phoenix_Kit_Used");
	MarkNativeAsOptional("Furious_Store_SendItemByName");
	MarkNativeAsOptional("Furious_Store_SendItemByNameToAccount");
	MarkNativeAsOptional("Furious_Store_GiveItem");
}
#endif

public SharedPlugin __pl_furious_store =
{
	name = "furious_store",
	file = "furious-store.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
