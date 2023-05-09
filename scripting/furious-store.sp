/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/
#define VIP_FLAGS ADMFLAG_CUSTOM5

#define PLUGIN_VERSION "1.2.9"

#define MAX_BUTTONS 25
#define MAX_FLAGS_LENGTH 21
#define MAX_TABLE_SIZE 64

#define DATA_ITEMS 0
#define DATA_ITEMS_EQUIPPED 1

#define PHOENIXHIT_DEATH 0
#define PHOENIXHIT_SPECTATE 1
#define PHOENIXHIT_LATEJOIN 2

#define PROTECTION_COLOR view_as<int>({13, 117, 244, 50})

/*-- Includes --*/
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#include <colorlib>
#include <autoexecconfig>
#include <afk_manager>
#include <easyspawnprotection>

/*-- Furious Includes --*/
#include <furious/furious-stocks>
#include <furious/furious-store>

#undef REQUIRE_PLUGIN
#include <redie>			// This doesn't need to be a dependency when we're only checking if player is a ghost
#include <furious/furious-statistics>
#include <furious/furious-vip>
#include <furious/furious-playerskins>
#include <furious/furious-resetscore>
#define REQUIRE_PLUGIN

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Config;
ConVar convar_Table_Items;
ConVar convar_Table_Items_Equipped;
ConVar convar_Table_Welcome_Gifts;
ConVar convar_ResetScoreCredits;
ConVar convar_CreditsTimer;
ConVar convar_DefaultCredits;
ConVar convar_EquipmentMenuStatus;
ConVar convar_SprayDistance;
ConVar convar_Sound_Equipped;
ConVar convar_Sound_Unequipped;
ConVar convar_Sound_GainCredits;
ConVar convar_Sound_Spray;
ConVar convar_RandomCredits;
ConVar convar_HoursForCredits;
ConVar convar_RandomCreditsPerHours;
ConVar hTimeCvar, hFreezeTimeCvar;
ConVar convar_ModelTints;
ConVar convar_Sound_PhoenixKitUsed;
ConVar convar_PhoenixKitMenuTime;
ConVar convar_PhoenixKitAllowTime_LateJoin;
ConVar convar_PhoenixKitAllowTime_Spectate;
ConVar convar_PhoenixKitAllowTime_Death;
ConVar convar_PhoenixKitSvgIcon;
ConVar convar_PhoenixKitSpawnProtection_Time;
ConVar convar_PhoenixKitEnabled;
ConVar convar_Sound_DailyReward;

/*-- Globals --*/
Database g_Database;
char g_sCurrentMap[MAX_NAME_LENGTH];
bool g_bLate;

bool g_bFrsResetScore;

Handle g_hTimer_Credits;
ConVar convar_Skybox;

char g_sItem_Name[MAX_STORE_ITEMS][MAX_STORE_ITEM_NAME_LENGTH];
char g_sItem_Type[MAX_STORE_ITEMS][MAX_STORE_ITEM_TYPE_LENGTH];
char g_sItem_Description[MAX_STORE_ITEMS][MAX_STORE_ITEM_DESCRIPTION_LENGTH];
int g_iItem_Price[MAX_STORE_ITEMS];
bool g_bItem_Buyable[MAX_STORE_ITEMS];
bool g_bItem_WelcomePackage[MAX_STORE_ITEMS];
bool g_bItem_IsUsable[MAX_STORE_ITEMS];
char g_sItem_Preview[MAX_STORE_ITEMS][MAX_STORE_ITEM_PREVIEW_LENGTH];
char g_sItem_Flags[MAX_STORE_ITEMS][MAX_FLAGS_LENGTH];
ArrayList g_Item_Build_List[MAX_STORE_ITEMS]; //Spawn Equipment
StringMap g_Item_Build_Lookup[MAX_STORE_ITEMS]; //Spawn Equipment
ArrayList g_Item_Build_Pistol_List;
StringMap g_Item_Build_Pistol_Lookup;
int g_iItem_Charges[MAX_STORE_ITEMS]; //Spawn Equipment / Open Charges
int g_iItem_MaterialID[MAX_STORE_ITEMS] =  { -1, ... }; //Sprays
bool g_bItem_CanBeDefault[MAX_STORE_ITEMS]; //Sprays
char g_sItem_Tag[MAX_STORE_ITEMS][MAX_STORE_ITEM_TAG_LENGTH]; //Tags
char g_sItem_Skybox[MAX_STORE_ITEMS][MAX_STORE_ITEM_SKYBOX_LENGTH]; //Skyboxes
char g_sItem_Model[MAX_STORE_ITEMS][MAX_STORE_ITEM_MODEL_LENGTH]; //Models
char g_sItem_ArmsModel[MAX_STORE_ITEMS][MAX_STORE_ITEM_MODEL_LENGTH]; //ArmsModels
int g_iItem_ModelID[MAX_STORE_ITEMS] =  { -1, ... }; //Models
//int g_iItem_ModelColor[MAX_STORE_ITEMS][4];

int g_iItems;

Menu g_StoreMenu;
Menu g_InventoryMenu;
Menu g_BuyVIPMenu;

WelcomeGiftStatus g_WelcomeGiftStatus[MAXPLAYERS + 1] = {GiftStatus_Pending, ...};

bool g_bIsDisplayedSBPreview[MAXPLAYERS + 1];

char g_sCacheData_SteamID2[MAXPLAYERS + 1][64];
char g_sCacheData_SteamID3[MAXPLAYERS + 1][64];
char g_sCacheData_SteamID64[MAXPLAYERS + 1][96];
int g_iCacheData_AccountID[MAXPLAYERS + 1];

ArrayList g_PlayerItems_Name[MAXPLAYERS + 1];
ArrayList g_PlayerItems_Types[MAXPLAYERS + 1];
StringMap g_PlayerItems_Charges[MAXPLAYERS + 1];
StringMap g_PlayerItems_Equipped[MAXPLAYERS + 1];
Handle g_hTimer_Previews[MAXPLAYERS + 1];

int g_ModelPreviewCamera[MAXPLAYERS + 1];
int g_PreviousModelIndex[MAXPLAYERS + 1];

bool g_bSprayed[MAXPLAYERS + 1];
int g_iSprayTime[MAXPLAYERS + 1] =  { 20, ... };

int g_iButtons[MAXPLAYERS + 1];
StringMap g_FlagNames;
bool g_bSpawnPistols;
Handle g_hSpawnPistol;
Handle g_hDailyRewardDelay;
Handle g_hDailyRewardDay;

bool g_bPhoenixKitUsed[MAXPLAYERS + 1];
bool g_bIsPhoenixKitMenuShown[MAXPLAYERS + 1];
int g_iLastActionEnd[MAXPLAYERS + 1];
StringMap g_PhoenixKitEligible;

int g_iRoundStartTime;

bool g_bIsRoundEnd;

int iCreditsReward[] =
{
	20, 40, 70, 100, 140, 190, 250
};

char g_sMapSpecificItems[][] =
{
	ITEM_DEFINE_SKYBOXES
};

enum struct ModelColors
{
	char name[32];
	int rgb[4];
	int price;
}

ModelColors mcColors[MAX_STORE_ITEMS][32];

enum WelcomeGiftStatus
{
	GiftStatus_Pending = -1,
	GiftStatus_IsNotEligible,
	GiftStatus_IsEligible,
}

int g_iLoadedStats[MAXPLAYERS + 1];
int g_LoadingTrials[MAXPLAYERS + 1];
int g_IsDataLoaded[MAXPLAYERS + 1][2];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Store",
	author = "Drixevel",
	description = "Store module for Furious Clan.",
	version = PLUGIN_VERSION,
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Furious_ResetScore_ResetPlayer");

	RegPluginLibrary("furious_store");

	CreateNative("Furious_Store_GetClientTag", Native_Store_GetClientTag);
	CreateNative("Furious_Store_GetDefaultCredits", Native_Store_GetDefaultCredits);

	CreateNative("Furious_Store_GetClientEquipped", Native_Store_GetClientEquipped);
	CreateNative("Furious_Store_GetClientCharges", Native_Store_GetClientCharges);
	CreateNative("Furious_Store_SetClientCharges", Native_Store_SetClientCharges);

	CreateNative("Furious_Store_SendItemByName", Native_Store_SendItemByName);
	CreateNative("Furious_Store_SendItemByNameToAccount", Native_Store_SendItemByNameToAccount);
	CreateNative("Furious_Store_GiveItem", Native_Store_GiveItem);

	CreateNative("Furious_Store_ShowVipMenu", Native_Store_ShowVipMenu);

	CreateNative("Furious_Store_Phoenix_Kit_Used", Native_PhoenixKitUsed);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.store");
	AutoExecConfig_CreateConVar("sm_furious_store_version", PLUGIN_VERSION, "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_store_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config = AutoExecConfig_CreateConVar("sm_furious_store_config", "configs/furious/furious_store.cfg", "Name of the config file to use.", FCVAR_NOTIFY);
	convar_Table_Items = AutoExecConfig_CreateConVar("sm_furious_store_table_items", "furious_global_store_items", "Name of the database table to use in side the global database for items.", FCVAR_NOTIFY);
	convar_Table_Items_Equipped = AutoExecConfig_CreateConVar("sm_furious_store_table_items_equipped", "furious_global_store_items_equipped", "Name of the database table to use in side the global database for items equipped.", FCVAR_NOTIFY);
	convar_Table_Welcome_Gifts = AutoExecConfig_CreateConVar("sm_furious_store_table_welcome_gifts", "furious_global_store_welcome_gifts", "Name of the database table to use in side the global database for welcome gifts.", FCVAR_NOTIFY);
	convar_ResetScoreCredits = AutoExecConfig_CreateConVar("sm_furious_store_resetscore_credits", "0", "Credits to deduct from clients that want to reset their scores.", FCVAR_NOTIFY, true, 0.0);
	convar_CreditsTimer = AutoExecConfig_CreateConVar("sm_furious_store_credits_timer", "240.0", "Time in seconds to give clients credits.", FCVAR_NOTIFY);
	convar_DefaultCredits = AutoExecConfig_CreateConVar("sm_furious_store_default_credits", "200", "Amount of credits to give clients who connect for the 1st time.", FCVAR_NOTIFY);
	convar_EquipmentMenuStatus = AutoExecConfig_CreateConVar("sm_furious_store_equipmentmenu_status", "1", "Status for the equipment menu.", FCVAR_NOTIFY);
	convar_SprayDistance = AutoExecConfig_CreateConVar("sm_furious_store_spray_distance", "150", "Distance that the spray can be used.", FCVAR_NOTIFY);
	convar_Sound_Equipped = AutoExecConfig_CreateConVar("sm_furious_store_sound_equipped", "", "Sound file to play on item equip.", FCVAR_NOTIFY);
	convar_Sound_Unequipped = AutoExecConfig_CreateConVar("sm_furious_store_sound_unequipped", "", "Sound file to play on unequip.", FCVAR_NOTIFY);
	convar_Sound_GainCredits = AutoExecConfig_CreateConVar("sm_furious_store_credits_sound", "", "Sound to play when a client receives the maximum number of credits randomly.", FCVAR_NOTIFY);
	convar_Sound_Spray = AutoExecConfig_CreateConVar("sm_furious_store_sound_spray", "player/sprayer.mp3", "Sound to play when a client sprays on a surface.", FCVAR_NOTIFY);
	convar_RandomCredits = AutoExecConfig_CreateConVar("sm_furious_store_random_credits", "1-10", "Amount of credits to give to a client at random.", FCVAR_NOTIFY);
	convar_HoursForCredits = AutoExecConfig_CreateConVar("sm_furious_store_hours_for_credits", "2", "Hours to play to give random credits.", FCVAR_NOTIFY);
	convar_RandomCreditsPerHours = AutoExecConfig_CreateConVar("sm_furious_store_random_credits_per_hours", "50-80", "Amount of credits to give to a client at random per hours.", FCVAR_NOTIFY);
	convar_ModelTints = AutoExecConfig_CreateConVar("sm_furious_model_tints_enabled", "0", "Toggle model tints.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_PhoenixKitMenuTime = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_menu_time", "15", "How many seconds should Phoenix Kit menu be shown for?", FCVAR_NOTIFY, true, 5.0, true, 30.0);
	convar_Sound_PhoenixKitUsed = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_sound", "", "Sound file to play when phoenix kit is used", FCVAR_NOTIFY);
	convar_PhoenixKitAllowTime_LateJoin = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_seconds_respawn_allow_time_latejoin", "60", "How many seconds is player allowed to use the kit for, after the spawn protection is over in order to respawn, when got killed?", FCVAR_NOTIFY, true, 0.0, true, 60.0);
	convar_PhoenixKitAllowTime_Spectate = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_seconds_respawn_allow_time_spectate", "30", "How many seconds is player allowed to use the kit for, after the spawn protection is over in order to respawn, when moved to afk?", FCVAR_NOTIFY, true, 0.0, true, 60.0);
	convar_PhoenixKitAllowTime_Death = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_seconds_respawn_allow_time_death", "15", "How many seconds is player allowed to use the kit for, after the spawn protection is over in order to respawn, when dead?", FCVAR_NOTIFY, true, 0.0, true, 60.0);
	convar_PhoenixKitSvgIcon = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_killfeed_icon", "materials/panorama/images/icons/equipment/awp_phoenix_kit_bz.svg", "Killfeed icon path", FCVAR_NOTIFY);
	convar_PhoenixKitSpawnProtection_Time = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_protection_time", "5", "Spawn protection time in seconds for phoenix kit respawn", FCVAR_NOTIFY, true, 0.0, true, 30.0);
	convar_PhoenixKitEnabled = AutoExecConfig_CreateConVar("sm_furious_phoenixkit_enabled", "1", "Is phoenix kit enabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Sound_DailyReward = AutoExecConfig_CreateConVar("sm_furious_store_dailyreward_sound", "physics/metal/chain_impact_soft2.wav", "Sound to client after a successful daily command", FCVAR_NOTIFY);
	AutoExecConfig_ExecuteFile();

	convar_CreditsTimer.AddChangeHook(OnCreditsTimerChange);

	RegConsoleCmd("sm_store", Command_OpenStoreMenu, "Open the store menu.");
	RegConsoleCmd("sm_shop", Command_OpenStoreMenu, "Open the store menu.");
	RegConsoleCmd("sm_market", Command_OpenStoreMenu, "Open the store menu.");
	RegConsoleCmd("sm_spray", Command_OpenSpraysMenu, "Open the sprays menu.");
	RegConsoleCmd("sm_sprays", Command_OpenSpraysMenu, "Open the sprays menu.");
	RegConsoleCmd("sm_skybox", Command_OpenSkyboxMenu, "Open the skybox menu.");
	RegConsoleCmd("sm_skyboxes", Command_OpenSkyboxMenu, "Open the skybox menu.");
	RegConsoleCmd("sm_sky", Command_OpenSkyboxMenu, "Open the skybox menu.");
	RegConsoleCmd("sm_model", Command_OpenModelMenu, "Open the model menu.");
	RegConsoleCmd("sm_models", Command_OpenModelMenu, "Open the model menu.");
	RegConsoleCmd("sm_inv", Command_OpenInventoryMenu, "Open the inventory menu.");
	RegConsoleCmd("sm_inventory", Command_OpenInventoryMenu, "Open the inventory menu.");

	RegConsoleCmd("sm_weapon", Command_SpawnBuilds, "List the current spawn builds.");
	RegConsoleCmd("sm_weapons", Command_SpawnBuilds, "List the current spawn builds.");
	RegConsoleCmd("sm_spawnbuilds", Command_SpawnBuilds, "List the current spawn builds.");
	RegConsoleCmd("sm_guns", Command_SpawnBuilds, "List the current spawn builds.");

	RegConsoleCmd("sm_resetscore", Command_ResetScore, "Reset your own scores.");
	RegConsoleCmd("sm_rs", Command_ResetScore, "Reset your own scores.");

	RegConsoleCmd("sm_credits", Command_DisplayCredits, "Display how many credits you own");

	RegConsoleCmd("sm_phoenixkit", Command_PhoenixKit, "Open Phoenix Kit menu if possible");
	RegConsoleCmd("sm_phoenix", Command_PhoenixKit, "Open Phoenix Kit menu if possible");
	RegConsoleCmd("sm_pk", Command_PhoenixKit, "Open Phoenix Kit menu if possible");
	RegConsoleCmd("sm_respawn", Command_PhoenixKit, "Open Phoenix Kit menu if possible");

	RegConsoleCmd("sm_daily", Command_DailyReward, "Collect your daily reward in credits");

	RegAdminCmd("sm_gift", Command_AddCredits, ADMFLAG_ROOT, "Give a client credits.");
	RegAdminCmd("sm_giftcredits", Command_AddCredits, ADMFLAG_ROOT, "Give a client credits.");
	RegAdminCmd("sm_givecredits", Command_AddCredits, ADMFLAG_ROOT, "Give a client credits.");
	RegAdminCmd("sm_addcredits", Command_AddCredits, ADMFLAG_ROOT, "Give a client credits.");
	RegAdminCmd("sm_parsestoreconfig", Command_ParseStoreConfig, ADMFLAG_ROOT, "Refresh store configs.");
	RegAdminCmd("sm_testphoenixkit", Command_TestPhoenixKit, ADMFLAG_ROOT, "Test phoenix kit menu");

	g_StoreMenu = GenerateStoreMainMenu();
	g_InventoryMenu = GenerateInventoryMainMenu();
	g_BuyVIPMenu = GenerateBuyVIPMenu();

	convar_Skybox = FindConVar("sv_skyname");

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("round_poststart", OnRoundRestart);
	HookEvent("player_death", OnPlayerDeath);

	g_FlagNames = new StringMap();
	g_PhoenixKitEligible = new StringMap();

	CreateTimer(1.0, Timer_Seconds, _, TIMER_REPEAT);
	CreateTimer(0.1, Timer_Milliseconds, _, TIMER_REPEAT);

	AutoExecConfig_CleanFile();
	hTimeCvar = FindConVar("sm_easysp_time");
	hFreezeTimeCvar = FindConVar("mp_freezetime");

	g_hSpawnPistol = RegClientCookie("sm_buildpistol", "Default client's spawn pistol", CookieAccess_Protected);
	g_hDailyRewardDelay = RegClientCookie("sm_dailyreward_delay", "Timestamp of latest credits collection", CookieAccess_Private);
	g_hDailyRewardDay = RegClientCookie("sm_dailyreward", "Collection day of client", CookieAccess_Private);
}

public void OnAllPluginsLoaded()
{
	g_bFrsResetScore = LibraryExists("furious_resetscore");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "furious_resetscore", false))
		g_bFrsResetScore = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "furious_resetscore", false))
		g_bFrsResetScore = false;
}

public Action Timer_Seconds(Handle timer)
{
	int random = GetConVarRandom(convar_RandomCreditsPerHours);

	int hours = convar_HoursForCredits.IntValue;

	if (random < 1 || hours < 1)
		return Plugin_Continue;

	float seconds = 3600.0 * hours;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		float fCreditsTimer = Furious_Statistics_GetCreditsTimer(i);
		if (++fCreditsTimer < seconds)
			continue;

		Furious_Statistics_SetCreditsTimer(i, 0.0);
		Furious_Statistics_AddCredits(i, random);

		if (hours > 1)
		{
			if (GetUserFlagBits(i) & VIP_FLAGS)
			{
				static ConVar convar_ExtraCredits = null;

				if (convar_ExtraCredits == null)
				{
					convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");
				}

				CPrintToChat(i, "%T", "vip random credits per hours", i, random, convar_ExtraCredits.IntValue, hours);
			}
			else
			{
				CPrintToChat(i, "%T", "random credits per hours", i, random, hours);
			}
		}
		else
		{
			if (GetUserFlagBits(i) & VIP_FLAGS)
			{
				static ConVar convar_ExtraCredits = null;

				if (convar_ExtraCredits == null)
				{
					convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");
				}

				CPrintToChat(i, "%T", "vip random credits per hour", i, random, convar_ExtraCredits.IntValue);
			}
			else
			{
				CPrintToChat(i, "%T", "random credits per hour", i, random);
			}
		}
	}

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!g_bSprayed[i])
			continue;

		if (--g_iSprayTime[i] == 0)
		{
			g_iSprayTime[i] = 20;
			g_bSprayed[i] = false;
		}
	}

	return Plugin_Continue;
}

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));

	ParseStoreConfig();
	ParseFlagNames();

	char sBuffer[PLATFORM_MAX_PATH];

	convar_Sound_Equipped.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	convar_Sound_Unequipped.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	convar_Sound_GainCredits.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	convar_Sound_Spray.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	convar_Sound_DailyReward.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	convar_Sound_PhoenixKitUsed.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		PrecacheSound(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "sound/%s", sBuffer);
		AddFileToDownloadsTable(sBuffer);
	}

	convar_PhoenixKitSvgIcon.GetString(sBuffer, sizeof(sBuffer));
	if (strlen(sBuffer) > 0)
	{
		AddFileToDownloadsTable(sBuffer);
	}

	PrecacheModel("models/editor/camera.mdl", true);
}

public void OnCreditsTimerChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue))
		return;

	float fNewTime = StringToFloat(newValue);

	StopTimer(g_hTimer_Credits);

	if (fNewTime > 0.0)
		g_hTimer_Credits = CreateTimer(fNewTime, Timer_GiveCredits, _, TIMER_REPEAT);
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue)
		return;

	if (g_Database == null)
		Database.Connect(OnSQLConnect, "furious_global");
	else
		LateLoadClients();

	float fTimer = convar_CreditsTimer.FloatValue;

	StopTimer(g_hTimer_Credits);

	if (fTimer > 0.0)
		g_hTimer_Credits = CreateTimer(fTimer, Timer_GiveCredits, _, TIMER_REPEAT);
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error connecting to the global database: %s", error);

	if (g_Database != null)
	{
		delete db;
		return;
	}

	g_Database = db;
	LogMessage("Connected to global database successfully.");

	g_Database.SetCharset("utf8mb4");

	CreateTimer(0.2, Timer_LateLoad, _, TIMER_FLAG_NO_MAPCHANGE);

	char sTable[MAX_TABLE_SIZE];
	char sQuery[4096];

	Transaction hTransaction = new Transaction();

	convar_Table_Items.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int UNSIGNED NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '', `accountid` int NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `item_name` varchar(64) NOT NULL DEFAULT '', `item_type` varchar(64) NOT NULL DEFAULT '', `item_description` varchar(256) NOT NULL DEFAULT '', `price` int UNSIGNED NOT NULL DEFAULT 0, `charges` int UNSIGNED DEFAULT 0, `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `item_ident` (`accountid`, `item_name`, `item_type`)) ENGINE=InnoDB;", sTable);
	hTransaction.AddQuery(sQuery);

	convar_Table_Items_Equipped.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int UNSIGNED NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '', `accountid` int UNSIGNED NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `ip` varchar(64) NOT NULL DEFAULT '', `item_type` varchar(64) NOT NULL DEFAULT '', `item_name` varchar(64) NOT NULL DEFAULT '', `data` mediumtext NOT NULL DEFAULT '', `map` varchar(64) NOT NULL DEFAULT '' , `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `equipped_ident` (`accountid`, `item_type`, `map`)) ENGINE=InnoDB;", sTable);
	hTransaction.AddQuery(sQuery);

	convar_Table_Welcome_Gifts.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `steam_account_id` int UNSIGNED NULL DEFAULT NULL, `welcome_gift_pending` tinyint UNSIGNED NOT NULL DEFAULT '1' , PRIMARY KEY (`steam_account_id`) USING BTREE) ENGINE = InnoDB;", sTable);
	hTransaction.AddQuery(sQuery);

	g_Database.Execute(hTransaction, INVALID_FUNCTION, SQLTxnFailure_CreateTables);
}

public Action Timer_LateLoad(Handle timer, any data)
{
	LateLoadClients();
	return Plugin_Continue;
}

public void SQLTxnFailure_CreateTables(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	ThrowError("Query Error: %s", error);
}

public Action Timer_GiveCredits(Handle timer)
{
	if (!convar_Status.BoolValue)
		return Plugin_Continue;

	char sRandomCredits[64];
	convar_RandomCredits.GetString(sRandomCredits, sizeof(sRandomCredits));

	char sParts[2][12];
	ExplodeString(sRandomCredits, "-", sParts, 2, 12);

	int min = StringToInt(sParts[0]);
	int max = StringToInt(sParts[1]);

	char sCreditsSound[PLATFORM_MAX_PATH];
	convar_Sound_GainCredits.GetString(sCreditsSound, sizeof(sCreditsSound));

	int random;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		random = GetRandomInt(min, max);
		Furious_Statistics_AddCredits(i, random);

		if (random >= max && strlen(sCreditsSound) > 0)
			EmitSoundToClient(i, sCreditsSound);

		if (GetUserFlagBits(i) & VIP_FLAGS)
		{
			static ConVar convar_ExtraCredits = null;

			if (convar_ExtraCredits == null)
			{
				convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");
			}

			CPrintToChat(i, "%T", "vip store give credits", i, random, convar_ExtraCredits.IntValue);
		}
		else
		{
			CPrintToChat(i, "%T", "store give credits", i, random);
		}
	}

	return Plugin_Continue;
}

void LateLoadClients()
{
	if (g_bLate)
	{
		char auth[64];
		for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth)))
			OnClientAuthorized(i, auth);

		g_bLate = false;
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!convar_Status.BoolValue || IsFakeClient(client))
		return;

	g_iLoadedStats[client] = 0;
	g_LoadingTrials[client] = 0;

	g_IsDataLoaded[client][DATA_ITEMS] = false;
	g_IsDataLoaded[client][DATA_ITEMS_EQUIPPED] = false;

	g_WelcomeGiftStatus[client] = GiftStatus_Pending;

	g_PlayerItems_Name[client] = new ArrayList(ByteCountToCells(MAX_STORE_ITEM_NAME_LENGTH));
	g_PlayerItems_Types[client] = new ArrayList(ByteCountToCells(MAX_STORE_ITEM_TYPE_LENGTH));
	g_PlayerItems_Charges[client] = new StringMap();
	g_PlayerItems_Equipped[client] = new StringMap();

	if (!IsFakeClient(client))
	{
		g_iCacheData_AccountID[client] = GetSteamAccountID(client);

		if (!GetClientAuthId(client, AuthId_Steam2, g_sCacheData_SteamID2[client], sizeof(g_sCacheData_SteamID2[])))
		{
			LogError("Error while verifying client Steam2: Steam is not connected.");
			g_sCacheData_SteamID2[client][0] = '\0';
		}

		if (!GetClientAuthId(client, AuthId_Steam3, g_sCacheData_SteamID3[client], sizeof(g_sCacheData_SteamID3[])))
		{
			LogError("Error while verifying client Steam3: Steam is not connected.");
			g_sCacheData_SteamID3[client][0] = '\0';
		}

		if (!GetClientAuthId(client, AuthId_SteamID64, g_sCacheData_SteamID64[client], sizeof(g_sCacheData_SteamID64[])))
		{
			LogError("Error while verifying client Steam64: Steam is not connected.");
			g_sCacheData_SteamID64[client][0] = '\0';
		}

		bool u;

		if (!g_PhoenixKitEligible.GetValue(g_sCacheData_SteamID64[client], u))
			g_PhoenixKitEligible.SetValue(g_sCacheData_SteamID64[client], true);

		SyncClientCredits(client);
		CreateTimer(3.5 + 0.025 * float(client), Timer_CheckLoading, GetClientSerial(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_CheckLoading(Handle timer, any serial)
{
	int client;

	if ((client = GetClientFromSerial(serial)) == 0)
	{
		return Plugin_Stop;
	}

	if (g_iLoadedStats[client] >= 2)
	{
		return Plugin_Stop;
	}

	g_LoadingTrials[client]++;

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	LogMessage("Loading failed for %s after %i trial(s), retrying again....", name, g_LoadingTrials[client]);

	SyncClientCredits(client);
	return Plugin_Continue;
}

void SyncClientCredits(int client)
{
	if (g_Database == null)
	{
		return;
	}

	char sQuery[4096];

	int serial = GetClientSerial(client);

	if (!g_IsDataLoaded[client][DATA_ITEMS])
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Items.GetString(sTable, sizeof(sTable));

		g_Database.Format(sQuery, sizeof(sQuery), "SELECT `item_name`, `item_type`, `charges` FROM `%s` WHERE `accountid` = '%i';", sTable, g_iCacheData_AccountID[client]);
		g_Database.Query(TQuery_OnPullItems, sQuery, serial);
	}
	else if (!g_IsDataLoaded[client][DATA_ITEMS_EQUIPPED])
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Items_Equipped.GetString(sTable, sizeof(sTable));

		g_Database.Format(sQuery, sizeof(sQuery), "SELECT `item_type`, `item_name`, `data` FROM `%s` WHERE `accountid` = '%i' AND (`map` = '%s' OR `map` = '');", sTable, g_iCacheData_AccountID[client], g_sCurrentMap);
		g_Database.Query(TQuery_OnPullItemsEquipped, sQuery, serial);
	}
}

public void TQuery_OnPullItems(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error pulling client items: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	while (results.FetchRow())
	{
		char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
		results.FetchString(0, sItemName, sizeof(sItemName));

		if (g_PlayerItems_Name[client])
		{
			g_PlayerItems_Name[client].PushString(sItemName);
		}

		if (g_PlayerItems_Types[client])
		{
			char sItemType[MAX_STORE_ITEM_TYPE_LENGTH];
			results.FetchString(1, sItemType, sizeof(sItemType));
			g_PlayerItems_Types[client].PushString(sItemType);
		}

		if (g_PlayerItems_Charges[client])
		{
			g_PlayerItems_Charges[client].SetValue(sItemName, results.FetchInt(2));
		}
	}

	g_IsDataLoaded[client][DATA_ITEMS] = true;
	g_iLoadedStats[client]++;

	if (!g_IsDataLoaded[client][DATA_ITEMS_EQUIPPED])
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Items_Equipped.GetString(sTable, sizeof(sTable));

		char sQuery[4096];

		g_Database.Format(sQuery, sizeof(sQuery), "SELECT `item_type`, `item_name`, `data` FROM `%s` WHERE `accountid` = '%i' AND (`map` = '%s' OR `map` = '');", sTable, g_iCacheData_AccountID[client], g_sCurrentMap);
		g_Database.Query(TQuery_OnPullItemsEquipped, sQuery, data);
	}
}

public void TQuery_OnPullItemsEquipped(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error pulling client items: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	while (results.FetchRow())
	{
		char sItemType[MAX_STORE_ITEM_TYPE_LENGTH];
		results.FetchString(0, sItemType, sizeof(sItemType));

		if (g_PlayerItems_Equipped[client])
		{
			char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
			results.FetchString(1, sItemName, sizeof(sItemName));
			g_PlayerItems_Equipped[client].SetString(sItemType, sItemName);

			if (StrEqual(sItemType, ITEM_DEFINE_SKYBOXES))
				SetClientSkybox(client, true);
			else if (StrEqual(sItemType, ITEM_DEFINE_MODELS))
				SetClientModel(client, true);
		}
	}

	g_IsDataLoaded[client][DATA_ITEMS_EQUIPPED] = true;
	g_iLoadedStats[client]++;
}

void TryGiveWelcomeGift(int client)
{
	if (g_WelcomeGiftStatus[client] == GiftStatus_IsEligible)
	{
		g_WelcomeGiftStatus[client] = GiftStatus_IsNotEligible;
		Furious_Statistics_AddCredits(client, convar_DefaultCredits.IntValue);

		for (int i = 0; i < g_iItems; i++)
		{
			if (g_bItem_WelcomePackage[i])
			{
				GiveItem(client, g_sItem_Name[i], g_sItem_Type[i], g_sItem_Description[i], g_iItem_Price[i], g_iItem_Charges[i]);

				if (StrEqual(g_sItem_Type[i], ITEM_DEFINE_SPAWNEQUIPMENT))
					CPrintToChat(client, "%T", "welcome package received", client, g_sItem_Name[i], g_iItem_Charges[i]);
				else
					CPrintToChat(client, "%T", "welcome item received", client, g_sItem_Name[i]);
			}
		}

		char sTable[MAX_TABLE_SIZE];
		convar_Table_Welcome_Gifts.GetString(sTable, sizeof(sTable));

		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `welcome_gift_pending` = 0 WHERE `steam_account_id` = %u LIMIT 1;", sTable, g_iCacheData_AccountID[client]);
		g_Database.Query(OnWelcomeGift, sQuery);
	}
}

public void OnWelcomeGift(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while giving welcome gift: %s", error);
	}
}

bool IsLateToReceiveWelcomeGift(int client)
{
	if (!convar_Status.BoolValue)
	{
		return false;
	}

	if (!IsClientInGame(client))
	{
		return false;
	}

	if (!IsPlayerAlive(client))
	{
		return false;
	}

	if (Redie_IsClientGhost(client))
	{
		return false;
	}

	return true;
}

public void Furious_Statistics_OnGlobalValidated(int client, bool created)
{
	// Don't query when player's gift status has already been determined
	if (g_WelcomeGiftStatus[client] != GiftStatus_Pending)
	{
		return;
	}

	char sTable[MAX_TABLE_SIZE];
	convar_Table_Welcome_Gifts.GetString(sTable, sizeof(sTable));

	char sQuery[256];

	DataPack pack = new DataPack();

	g_Database.Format(sQuery, sizeof(sQuery), "SELECT `welcome_gift_pending` FROM `%s` WHERE `steam_account_id` = %u LIMIT 1;", sTable, g_iCacheData_AccountID[client]);
	g_Database.Query(TQuery_OnGetPendingWelcomeGiftStatus, sQuery, pack);

	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(created);
}

public void TQuery_OnGetPendingWelcomeGiftStatus(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientFromSerial(pack.ReadCell());
	bool created = pack.ReadCell();

	if (client)
	{
		if (results && results.FetchRow())
		{
			delete pack;

			g_WelcomeGiftStatus[client] = view_as<WelcomeGiftStatus>(results.FetchInt(0));

			if (IsLateToReceiveWelcomeGift(client))
			{
				TryGiveWelcomeGift(client);
			}
		}
		else
		{
			// Backup in case there's error or query below fails
			g_WelcomeGiftStatus[client] = GiftStatus_IsNotEligible;

			if (error[0])
			{
				delete pack;

				ThrowError("Query Error: %s", error);
			}

			char sTable[MAX_TABLE_SIZE];
			convar_Table_Welcome_Gifts.GetString(sTable, sizeof(sTable));

			char sQuery[256];

			g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`steam_account_id`, `welcome_gift_pending`) VALUES (%u, %u);", sTable, g_iCacheData_AccountID[client], created);
			g_Database.Query(TQuery_OnCreatePendingWelcomeGiftStatus, sQuery, pack);
		}
	}
	else
	{
		delete pack;

		if (error[0])
		{
			ThrowError("Query Error: %s", error);
		}
	}
}

public void TQuery_OnCreatePendingWelcomeGiftStatus(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);

	if (error[0])
	{
		delete pack;

		ThrowError("Query Error: %s", error);
	}

	pack.Reset();

	int client = GetClientFromSerial(pack.ReadCell());
	bool created = pack.ReadCell();

	delete pack;

	if (client)
	{
		g_WelcomeGiftStatus[client] = created ? GiftStatus_IsEligible : GiftStatus_IsNotEligible;

		if (IsLateToReceiveWelcomeGift(client))
		{
			TryGiveWelcomeGift(client);
		}
	}
}

public void TQuery_OnSaveStoreCredits(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error saving client credits to database: %s", error);
}

public void OnClientDisconnect_Post(int client)
{
	g_WelcomeGiftStatus[client] = GiftStatus_Pending;

	delete g_PlayerItems_Name[client];
	delete g_PlayerItems_Types[client];
	delete g_PlayerItems_Charges[client];
	delete g_PlayerItems_Equipped[client];

	StopTimer(g_hTimer_Previews[client]);

	g_bSprayed[client] = false;
	g_iButtons[client] = 0;
	g_iSprayTime[client] = 20;

	g_bPhoenixKitUsed[client] = false;
	g_bIsPhoenixKitMenuShown[client] = false;
}

/***********************************************************************
* Store
***********************************************************************/

public Action Command_OpenStoreMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	g_StoreMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public Action Command_OpenSkyboxMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	DisplayStoreItemsMenu(client, ITEM_DEFINE_SKYBOXES);
	return Plugin_Handled;
}

public Action Command_OpenModelMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	DisplayStoreItemsMenu(client, ITEM_DEFINE_MODELS);
	return Plugin_Handled;
}

public Action Command_OpenSpraysMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	DisplayStoreItemsMenu(client, ITEM_DEFINE_SPRAYS);
	return Plugin_Handled;
}

Menu GenerateStoreMainMenu()
{
	Menu menu = new Menu(MenuHandle_StoreMainMenu, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_Display);
	menu.SetTitle("Furious Store\n\n ");

	menu.AddItem(ITEM_DEFINE_SPAWNEQUIPMENT, "Spawn Equipment");
	menu.AddItem(ITEM_DEFINE_SPRAYS, "Sprays");
	menu.AddItem(ITEM_DEFINE_TAGS, "Tags");
	menu.AddItem(ITEM_DEFINE_SKYBOXES, "Skyboxes");
	menu.AddItem(ITEM_DEFINE_PHOENIXKIT, "Phoenix Kit");
	menu.AddItem(ITEM_DEFINE_MODELS, "Models\n\n ");
	menu.AddItem("vip", "VIP");
	menu.AddItem(ITEM_DEFINE_OPENCHARGES, "Open Charges\n\n ");

	menu.AddItem("inventory", "Your Inventory");

	return menu;
}

public int MenuHandle_StoreMainMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		menu.SetTitle("Furious Store\nCredits: %i\n\n ", Furious_Statistics_GetCredits(param1));

		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[256];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "inventory"))
				g_InventoryMenu.Display(param1, MENU_TIME_FOREVER);
			else if (StrEqual(sInfo, "vip"))
				g_BuyVIPMenu.Display(param1, MENU_TIME_FOREVER);
			else
				DisplayStoreItemsMenu(param1, sInfo);
		}
	}

	return 0;
}

/***********************************************************************
* Store Items
***********************************************************************/

void DisplayStoreItemsMenu(int client, const char[] sType)
{
	Menu menu = new Menu(MenuHandle_StoreItemsMenu, MenuAction_Select | MenuAction_Cancel | MenuAction_End);

	if (StrEqual(sType, ITEM_DEFINE_OPENCHARGES))
		menu.SetTitle("Furious Store - %s\nCredits: %i\nYour charges: %i\n\n ", sType, Furious_Statistics_GetCredits(client), Furious_Store_GetClientCharges(client, "Charges"));
	else if (StrEqual(sType, ITEM_DEFINE_PHOENIXKIT))
		menu.SetTitle("Furious Store - %s\nCredits: %i\nYour charges: %i\n\n ", sType, Furious_Statistics_GetCredits(client), Furious_Store_GetClientCharges(client, "PhoenixCharges"));
	else menu.SetTitle("Furious Store - %s\nCredits: %i\n\n ", sType, Furious_Statistics_GetCredits(client));
	menu.ExitBackButton = true;
	if (StrEqual(sType, ITEM_DEFINE_SKYBOXES))
	{
		char sSkybox[MAX_STORE_ITEM_NAME_LENGTH];
		g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_SKYBOXES, sSkybox, sizeof(sSkybox));

		menu.AddItem(sSkybox, "Default Skybox");
	}
	else if (StrEqual(sType, ITEM_DEFINE_MODELS))
	{
		char sModel[MAX_STORE_ITEM_NAME_LENGTH];
		g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_MODELS, sModel, sizeof(sModel));

		menu.AddItem(sModel, "Default Model");
	}
	char sID[12]; char sDisplay[1024]; int draw = ITEMDRAW_DEFAULT;
	for (int i = 0; i < g_iItems; i++)
	{
		if (!StrEqual(g_sItem_Type[i], sType))
			continue;

		IntToString(i, sID, sizeof(sID));
		strcopy(sDisplay, sizeof(sDisplay), g_sItem_Name[i]);

		draw = ITEMDRAW_DEFAULT;
		if (!StrEqual(sType, ITEM_DEFINE_SPAWNEQUIPMENT) && !StrEqual(sType, ITEM_DEFINE_OPENCHARGES) && !StrEqual(sType, ITEM_DEFINE_PHOENIXKIT))
		{
			if (g_PlayerItems_Name[client].FindString(g_sItem_Name[i]) != -1)
			{
				Format(sDisplay, sizeof(sDisplay), "%s (Purchased)", sDisplay);
				draw = ITEMDRAW_DISABLED;
			}

			if (strlen(g_sItem_Flags[i]) > 0 && !CheckCommandAccess(client, "", ReadFlagString(g_sItem_Flags[i]), true))
				draw = ITEMDRAW_DISABLED;
		}

		menu.AddItem(sID, sDisplay, draw);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", "[No Items Available]", ITEMDRAW_DISABLED);

	PushMenuString(menu, "type", sType);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_StoreItemsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[12];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			int iID = StringToInt(sInfo);

			char sType[MAX_STORE_ITEM_TYPE_LENGTH];
			GetMenuString(menu, "type", sType, sizeof(sType));

			if ((StrEqual(sType, ITEM_DEFINE_SKYBOXES) || StrEqual(sType, ITEM_DEFINE_MODELS)) && param2 == 0)
			{
				UnequipItem(param1, sInfo, sType);
				DisplayStoreItemsMenu(param1, sType);
				return 0;
			}

			DisplayItemPurchaseMenu(param1, g_sItem_Name[iID], sType, g_sItem_Description[iID], g_iItem_Price[iID], g_bItem_Buyable[iID], g_iItem_Charges[iID], g_sItem_Preview[iID], iID);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				g_StoreMenu.Display(param1, MENU_TIME_FOREVER);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

/***********************************************************************
* Item Purchase Menu
***********************************************************************/

void DisplayItemPurchaseMenu(int client, const char[] sName, const char[] sType, const char[] sDescription, int iItemCredits, bool buyable, int iCharges, const char[] sPreview, int id)
{
	char sDisplay[512];
	strcopy(sDisplay, sizeof(sDisplay), sName);

	if (StrEqual(sType, ITEM_DEFINE_SPAWNEQUIPMENT))
	{
		Format(sDisplay, sizeof(sDisplay), "%s [%i]", sName, iCharges);

		char sItemName[512];
		for (int i = 0; i < g_Item_Build_List[id].Length; i++)
		{
			g_Item_Build_List[id].GetString(i, sItemName, sizeof(sItemName));
			Format(sDisplay, sizeof(sDisplay), "%s\n-%s", sDisplay, sName);
		}
	}
	else if (StrEqual(sType, ITEM_DEFINE_OPENCHARGES))
		iCharges = 1;

	Menu menu = new Menu(MenuHandle_ItemPurchaseMenu);
	int flags = GetUserFlagBits(client);
	bool isVIP = flags & VIP_FLAGS != 0;
	if ((isVIP || flags & ADMFLAG_RESERVATION) && StrEqual(sType, ITEM_DEFINE_OPENCHARGES))menu.SetTitle("You already have access to these features!");
	else
		menu.SetTitle("Store | %s\n\n \n%s\n\n \n%s\n\n \nPrice: %i | Balance: %i", sType, sDisplay, sDescription, iItemCredits, Furious_Statistics_GetCredits(client));

	char sBuy[64] = "Buy";
	if (strlen(g_sItem_Flags[id]) > 0 && !CheckCommandAccess(client, "", ReadFlagString(g_sItem_Flags[id]), true))
	{
		char sFlagName[32];
		g_FlagNames.GetString(g_sItem_Flags[id], sFlagName, sizeof(sFlagName));

		Format(sBuy, sizeof(sBuy), "%s (Requires %s)", sBuy, strlen(sFlagName) > 0 ? sFlagName : "Permissions");
		buyable = false;
	}

	if (!((isVIP || flags & ADMFLAG_RESERVATION) && StrEqual(sType, ITEM_DEFINE_OPENCHARGES)))menu.AddItem("buy", sBuy, buyable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	else if (!StrEqual(sType, ITEM_DEFINE_OPENCHARGES))menu.AddItem("buy", sBuy, buyable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	/*if (!isVIP && !(flags & ADMFLAG_RESERVATION))
	{
		menu.AddItem("buy", sBuy, buyable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}*/
	menu.AddItem("", "spacer", ITEMDRAW_SPACER);
	if (StrEqual(sType, ITEM_DEFINE_SKYBOXES) || StrEqual(sType, ITEM_DEFINE_MODELS))
		menu.AddItem("live_preview", "Preview");
	//else
	//menu.AddItem("preview", "Preview", strlen(sPreview) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	PushMenuString(menu, "name", sName);
	PushMenuString(menu, "type", sType);
	PushMenuString(menu, "description", sDescription);
	PushMenuInt(menu, "credits", iItemCredits);
	PushMenuInt(menu, "buyable", buyable);
	PushMenuInt(menu, "charges", iCharges);
	PushMenuString(menu, "preview2", sPreview);
	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_ItemPurchaseMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			char sName[MAX_STORE_ITEM_NAME_LENGTH];
			GetMenuString(menu, "name", sName, sizeof(sName));

			char sType[MAX_STORE_ITEM_TYPE_LENGTH];
			GetMenuString(menu, "type", sType, sizeof(sType));

			char sDescription[MAX_STORE_ITEM_DESCRIPTION_LENGTH];
			GetMenuString(menu, "description", sDescription, sizeof(sDescription));

			int iItemCredits = GetMenuInt(menu, "credits");
			bool buyable = view_as<bool>(GetMenuInt(menu, "buyable"));
			int iCharges = GetMenuInt(menu, "charges");

			char sPreview[MAX_STORE_ITEM_PREVIEW_LENGTH];
			GetMenuString(menu, "preview2", sPreview, sizeof(sPreview));

			int id = GetMenuInt(menu, "id");

			if (StrEqual(sInfo, "buy"))
				PurchaseItem(param1, sName, sType, g_sItem_Description[id], iItemCredits, iCharges);
			else if (StrEqual(sInfo, "preview"))
			{
				//CSGO_ShowMOTDPanel(param1, "Preview Window", sPreview, true);
				DisplayItemPurchaseMenu(param1, sName, sType, sDescription, iItemCredits, buyable, iCharges, sPreview, id);
			}
			else if (StrEqual(sInfo, "live_preview"))
			{
				if (g_hTimer_Previews[param1] == null)
				{
					LivePreview(param1, sName, sType, id);
				}

				DisplayItemPurchaseMenu(param1, sName, sType, sDescription, iItemCredits, buyable, iCharges, sPreview, id);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sType[MAX_STORE_ITEM_TYPE_LENGTH];
				GetMenuString(menu, "type", sType, sizeof(sType));

				DisplayStoreItemsMenu(param1, sType);
			}
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

public Action Timer_DisableLivePreview_Skyboxes(Handle timer, any data)
{
	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return Plugin_Stop;
	g_bIsDisplayedSBPreview[client] = false;
	if (!SetClientSkybox(client, true))
		ClearSkybox(client);

	CPrintToChat(client, "%T", "live preview skyboxes end", client);
	g_hTimer_Previews[client] = null;

	return Plugin_Stop;
}

public Action Timer_DisableLivePreview_Models(Handle timer, any data)
{
	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return Plugin_Stop;

	EndModelPreview(client);
	g_hTimer_Previews[client] = null;
	return Plugin_Stop;
}

void EndModelPreview(int client, bool kill = true)
{
	if (!IsClientInGame(client))return;
	PrintToChat(client, "%T", "live preview models end", client);

	SetClientViewEntity(client, client);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);

	if (g_PreviousModelIndex[client] != -1)
	{
		SetEntProp(client, Prop_Send, "m_nModelIndex", g_PreviousModelIndex[client]);
		g_PreviousModelIndex[client] = -1;
	}

	if (g_ModelPreviewCamera[client] != -1)
	{
		if (kill)
		{
			AcceptEntityInput(g_ModelPreviewCamera[client], "Kill");
		}

		g_ModelPreviewCamera[client] = -1;
	}
}

bool SpawnCamera(int client)
{
	int camera = CreateEntityByName("prop_dynamic");

	if (camera != -1)
	{
		SetEntityModel(camera, "models/editor/camera.mdl");

		DispatchSpawn(camera);

		SetEntProp(camera, Prop_Send, "m_nSolidType", 0, 1);
		SetEntProp(camera, Prop_Send, "m_usSolidFlags", 4, 2);

		SetEntityMoveType(camera, MOVETYPE_NOCLIP);
		SetEntityRenderMode(camera, RENDER_NONE);

		float origin[3];
		GetClientAbsOrigin(client, origin);

		float angles[3];
		GetClientEyeAngles(client, angles);

		float fwd[3];
		GetAngleVectors(angles, fwd, NULL_VECTOR, NULL_VECTOR);

		float cameraOrigin[3];
		cameraOrigin[0] = origin[0] + fwd[0] * 120.0;
		cameraOrigin[1] = origin[1] + fwd[1] * 120.0;
		cameraOrigin[2] = origin[2] + 75.0;

		origin[2] += 38.0;

		fwd[0] = origin[0] - cameraOrigin[0];
		fwd[1] = origin[1] - cameraOrigin[1];
		fwd[2] = origin[2] - cameraOrigin[2];

		GetVectorAngles(fwd, angles);
		TeleportEntity(camera, cameraOrigin, angles, NULL_VECTOR);

		g_ModelPreviewCamera[client] = camera;

		SetEntProp(client, Prop_Send, "m_iObserverMode", 6);
		SetClientViewEntity(client, camera);
		return true;
	}

	return false;
}

/***********************************************************************
* Purchase Item
***********************************************************************/

void PurchaseItem(int client, char[] sItemName, const char[] sItemType, const char[] sItemDescription, int iPrice, int iCharges, bool bGiveItem = true)
{
	int iCredits = Furious_Statistics_GetCredits(client);
	if (iCredits < iPrice)
	{
		CPrintToChat(client, "%T", "item purchase not enough credits", client, (iPrice - iCredits));
		g_StoreMenu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	iCredits -= iPrice;
	Furious_Statistics_SetCredits(client, iCredits);

	CPrintToChat(client, "%T", "item purchased", client, sItemName);
	if (bGiveItem)
		GiveItem(client, sItemName, sItemType, sItemDescription, iPrice, iCharges);

	g_StoreMenu.Display(client, MENU_TIME_FOREVER);
}

bool GiveItem(int client, char[] sItemName, const char[] sItemType, const char[] sItemDescription, int iPrice, int iCharges) {
	if (g_Database == null) {
		return false;
	}

	char sItemName2[128];
	Format(sItemName2, sizeof(sItemName2), StrEqual(sItemType, ITEM_DEFINE_PHOENIXKIT) ? "PhoenixCharges" : sItemName);

	int iCurCharges;
	g_PlayerItems_Charges[client].GetValue(sItemName2, iCurCharges);

	if (!(StrEqual(sItemType, ITEM_DEFINE_SPAWNEQUIPMENT) && iCurCharges > 0) && !StrEqual(sItemType, ITEM_DEFINE_PHOENIXKIT) && !StrEqual(sItemType, ITEM_DEFINE_OPENCHARGES)) {
		g_PlayerItems_Name[client].PushString(sItemName);
		g_PlayerItems_Types[client].PushString(sItemType);
	}

	if (StrEqual(sItemType, ITEM_DEFINE_OPENCHARGES)) {
		strcopy(sItemName, MAX_STORE_ITEM_NAME_LENGTH, "Charges");
		iCurCharges = Furious_Store_GetClientCharges(client, "Charges");
	} else if (StrEqual(sItemType, ITEM_DEFINE_PHOENIXKIT)) {
		//strcopy(sItemName, MAX_STORE_ITEM_NAME_LENGTH, "PhoenixCharges");
		iCurCharges = Furious_Store_GetClientCharges(client, "PhoenixCharges");
	}

	char sLookup[512];
	g_PlayerItems_Equipped[client].GetString(sItemType, sLookup, sizeof(sLookup));

	if (strlen(sLookup) > 1 && !StrEqual(sLookup, sItemName) && !StrEqual(sItemType, ITEM_DEFINE_OPENCHARGES) && !StrEqual(sItemType, ITEM_DEFINE_PHOENIXKIT)) {
		CPrintToChat(client, "%T", "item purchased not equipped", client);
	} else {
		g_PlayerItems_Equipped[client].SetString(sItemType, sItemName);
		CPrintToChat(client, "%T", "item purchased equipped", client);
	}

	g_PlayerItems_Charges[client].SetValue(sItemName2, iCurCharges + iCharges);

	if (g_iLoadedStats[client] >= 2) {
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * MAX_NAME_LENGTH + 1;
		char[] sEscapedName = new char[size + 1];
		g_Database.Escape(sName, sEscapedName, size + 1);

		char sTable[MAX_TABLE_SIZE];
		char sQuery[4096];

		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteString(sItemName);
		pack.WriteString(sName);

		convar_Table_Items.GetString(sTable, sizeof(sTable));
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `item_name`, `item_type`, `item_description`, `price`, `charges`) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%s', '%s', '%i', '%i') ON DUPLICATE KEY UPDATE `charges` = '%i';", sTable, sEscapedName, g_iCacheData_AccountID[client], g_sCacheData_SteamID2[client], g_sCacheData_SteamID3[client], g_sCacheData_SteamID64[client], sItemName2, sItemType, sItemDescription, iPrice, (iCurCharges + iCharges), (iCurCharges + iCharges));
		g_Database.Query(Query_GiveItem, sQuery, pack, DBPrio_Low);

		return true;
	}

	return false;
}

public void Query_GiveItem(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();
	
	int userid = pack.ReadCell();

	char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
	pack.ReadString(sItemName, sizeof(sItemName));

	char sName[MAX_STORE_ITEM_NAME_LENGTH];
	pack.ReadString(sName, sizeof(sName));

	delete pack;

	if (results == null) {
		ThrowError("Error while giving item to player: %s", error);
	}

	int client;
	if ((client = GetClientOfUserId(userid)) > 0 && IsClientInGame(client)) {
		CPrintToChat(client, "%T", "item given", client, sItemName);
	}

	LogMessage("Item '%s' has been given to player: %s", sItemName, sName);
}

bool GiveItemToAccount(int accountid, char[] sItemName, const char[] sItemType, const char[] sItemDescription, int iPrice, int iCharges) {
	if (g_Database == null) {
		return false;
	}

	//If the client is already on the server then give it to them by the proper function instead of the offline way.
	int client;
	if ((client = GetClientByAccountID(accountid)) > 0) {
		return GiveItem(client, sItemName, sItemType, sItemDescription, iPrice, iCharges);
	}

	char sItemName2[128];
	Format(sItemName2, sizeof(sItemName2), StrEqual(sItemType, ITEM_DEFINE_PHOENIXKIT) ? "PhoenixCharges" : sItemName);
	
	char sTable[MAX_TABLE_SIZE];
	char sQuery[4096];

	DataPack pack = new DataPack();
	pack.WriteCell(accountid);
	pack.WriteString(sItemName);

	convar_Table_Items.GetString(sTable, sizeof(sTable));
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `item_name`, `item_type`, `item_description`, `price`, `charges`) VALUES ('', '%i', '', '', '', '%s', '%s', '%s', '%i', '%i') ON DUPLICATE KEY UPDATE `charges` = `charges + '%i';", sTable, accountid, sItemName2, sItemType, sItemDescription, iPrice, iCharges, iCharges);
	g_Database.Query(Query_GiveItemToAccount, sQuery, pack, DBPrio_Low);

	return true;
}

public void Query_GiveItemToAccount(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();
	
	int accountid = pack.ReadCell();

	char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
	pack.ReadString(sItemName, sizeof(sItemName));

	delete pack;

	if (results == null) {
		ThrowError("Error while giving item to account: %s", error);
	}

	LogMessage("Item '%s' has been given to account: %i", sItemName, accountid);
}

/***********************************************************************
* Inventory
***********************************************************************/

public Action Command_OpenInventoryMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	g_InventoryMenu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

Menu GenerateInventoryMainMenu()
{
	Menu menu = new Menu(MenuHandle_StoreInventory, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_Display);
	menu.SetTitle("Furious Inventory\n\n ");

	menu.AddItem(ITEM_DEFINE_SPAWNEQUIPMENT, "Spawn Equipment");
	menu.AddItem(ITEM_DEFINE_SPRAYS, "Sprays");
	menu.AddItem(ITEM_DEFINE_TAGS, "Tags");
	menu.AddItem(ITEM_DEFINE_SKYBOXES, "Skyboxes");
	menu.AddItem(ITEM_DEFINE_PHOENIXKIT, "Phoenix Kit");
	menu.AddItem(ITEM_DEFINE_MODELS, "Models\n\n ");

	menu.AddItem("store", "Visit the Store");

	return menu;
}

public int MenuHandle_StoreInventory(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Display:
		menu.SetTitle("%N's Inventory\nCredits: %i\n\n ", param1, Furious_Statistics_GetCredits(param1));

		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[256];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "store"))
			{
				g_StoreMenu.Display(param1, MENU_TIME_FOREVER);
				return 0;
			}

			DisplayInventoryItemsMenu(param1, sInfo);
		}
	}

	return 0;
}

/***********************************************************************
* Item Inventory Menu
***********************************************************************/

void DisplayInventoryItemsMenu(int client, const char[] sType)
{
	Menu menu = new Menu(MenuHandle_InventoryItemsMenu, MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	menu.SetTitle("%N's Inventory - %s\nCredits: %i\n\n ", client, sType, Furious_Statistics_GetCredits(client));

	menu.ExitBackButton = true;

	if (StrEqual(sType, ITEM_DEFINE_PHOENIXKIT))
	{
		char sDisplay[32];
		Format(sDisplay, sizeof(sDisplay), "Your charges: %i", Furious_Store_GetClientCharges(client, "PhoenixCharges"));
		menu.AddItem("", sDisplay, ITEMDRAW_DISABLED);
		menu.Display(client, MENU_TIME_FOREVER);
		return;
	}

	char sID[12];
	for (int i = 0; i < g_iItems; i++)
	{
		if (!StrEqual(g_sItem_Type[i], sType) || g_PlayerItems_Name[client].FindString(g_sItem_Name[i]) == -1)
			continue;

		IntToString(i, sID, sizeof(sID));

		menu.AddItem(sID, g_sItem_Name[i]);
	}

	if (menu.ItemCount == 0)
		menu.AddItem("", "[No Items Available]", ITEMDRAW_DISABLED);

	PushMenuString(menu, "type", sType);

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_InventoryItemsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[12]; char sName[MAX_STORE_ITEM_NAME_LENGTH];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sName, sizeof(sName));

			int iID = StringToInt(sInfo);

			char sType[MAX_STORE_ITEM_TYPE_LENGTH];
			GetMenuString(menu, "type", sType, sizeof(sType));

			DisplayItemEquipMenu(param1, sName, sType, g_sItem_Preview[iID], iID);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				g_InventoryMenu.Display(param1, MENU_TIME_FOREVER);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

/***********************************************************************
* Item Equip Menu
***********************************************************************/

void DisplayItemEquipMenu(int client, const char[] sName, const char[] sType, const char[] sPreview, int id)
{
	char sDisplay[512];
	strcopy(sDisplay, sizeof(sDisplay), sName);

	if (StrEqual(sType, ITEM_DEFINE_SPAWNEQUIPMENT) || StrEqual(sType, ITEM_DEFINE_PHOENIXKIT))
	{
		int charges;
		g_PlayerItems_Charges[client].GetValue(sName, charges);

		Format(sDisplay, sizeof(sDisplay), "%s [%i]", sName, charges);

		if (StrEqual(sType, ITEM_DEFINE_SPAWNEQUIPMENT))
		{
			char sItemName[512];
			for (int i = 0; i < g_Item_Build_List[id].Length; i++)
			{
				g_Item_Build_List[id].GetString(i, sItemName, sizeof(sItemName));
				Format(sDisplay, sizeof(sDisplay), "%s\n-%s", sDisplay, sItemName);
			}
		}
	}

	Menu menu = new Menu(MenuHandle_ItemEquipMenu);
	menu.SetTitle("Inventory | %s\n\n \n%s\n\n \n%s\n\n \nBalance: %i", sType, sDisplay, g_sItem_Description[id], Furious_Statistics_GetCredits(client));
	char sLookup[512];
	g_PlayerItems_Equipped[client].GetString(sType, sLookup, sizeof(sLookup));
	bool bEquipped = StrEqual(sName, sLookup);

	menu.AddItem(bEquipped ? "unequip" : "equip", bEquipped ? "Unequip" : "Equip");

	if (StrEqual(sType, ITEM_DEFINE_MODELS))
		menu.AddItem("model_tints", "Model tints");

	if (StrEqual(sType, ITEM_DEFINE_SKYBOXES) || StrEqual(sType, ITEM_DEFINE_MODELS))
		menu.AddItem("live_preview", "Preview");
	//else
	//menu.AddItem("preview", "Preview", strlen(sPreview) > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);

	PushMenuString(menu, "name", sName);
	PushMenuString(menu, "type", sType);
	PushMenuString(menu, "preview2", sPreview);
	PushMenuInt(menu, "id", id);

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_ItemEquipMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			char sName[MAX_STORE_ITEM_NAME_LENGTH];
			GetMenuString(menu, "name", sName, sizeof(sName));

			char sType[MAX_STORE_ITEM_TYPE_LENGTH];
			GetMenuString(menu, "type", sType, sizeof(sType));

			char sPreview[MAX_STORE_ITEM_PREVIEW_LENGTH];
			GetMenuString(menu, "preview2", sPreview, sizeof(sPreview));

			int id = GetMenuInt(menu, "id");
			if (StrEqual(sInfo, "equip"))
				EquipItem(param1, sName, sType);
			else if (StrEqual(sInfo, "unequip"))
				UnequipItem(param1, sName, sType);
			else if (StrEqual(sInfo, "model_tints"))
			{
				ShowTintsMenu(param1, sName);
			}
			else if (StrEqual(sInfo, "preview"))
			{
				//CSGO_ShowMOTDPanel(param1, "Preview Window", sPreview, true);
				DisplayItemEquipMenu(param1, sName, sType, sPreview, id);
			}
			else if (StrEqual(sInfo, "live_preview"))
			{
				if (g_hTimer_Previews[param1] == null)
				{
					LivePreview(param1, sName, sType, id);
				}

				DisplayItemEquipMenu(param1, sName, sType, sPreview, id);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				char sType[MAX_STORE_ITEM_TYPE_LENGTH];
				GetMenuString(menu, "type", sType, sizeof(sType));

				DisplayInventoryItemsMenu(param1, sType);
			}
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

void ShowTintsMenu(int client, char[] itemname)
{
	char sRGB[40];
	Menu tints = new Menu(MenuHandle_Tints);
	tints.SetTitle("Inventory | models | %s\n \ntints\n \n \nBalance: %i", itemname, Furious_Statistics_GetCredits(client));
	tints.ExitBackButton = true;
	for (int i = 0; i < g_iItems; i++)
	{
		for (int ix = 0; ix < i; ix++)
		if (strlen(mcColors[i][ix].name) && StrEqual(itemname, g_sItem_Name[i]))
		{
			Format(sRGB, sizeof(sRGB), "%i %i %i %i", mcColors[i][ix].rgb[0], mcColors[i][ix].rgb[1], mcColors[i][ix].rgb[2], mcColors[i][ix].rgb[3]);
			tints.AddItem(sRGB, mcColors[i][ix].name); //rgb
			tints.AddItem(mcColors[i][ix].name, "", ITEMDRAW_IGNORE); //color name
			tints.AddItem(itemname, "", ITEMDRAW_IGNORE); //model name
		}
	}
	tints.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_Tints(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sRGB[16], sColor[32], sModel[32];
			menu.GetItem(param2, sRGB, sizeof(sRGB)); //rgb
			menu.GetItem(param2 + 1, sColor, sizeof(sColor)); //color name
			menu.GetItem(param2 + 2, sModel, sizeof(sModel)); //model name
			ShowSingleTint(param1, sRGB, sColor, sModel);
		}
		case MenuAction_Cancel:
		if (param2 == MenuCancel_ExitBack)
			DisplayInventoryItemsMenu(param1, "models");
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

void ShowSingleTint(int client, char[] rgb, char[] colorname, char[] modelname)
{
	char error[1024], sSteam64[32];
	Menu menu = new Menu(MH_singletint);
	menu.SetTitle("Inventory | models | %s | tints\n \n%s (%s)\n \n ", modelname, colorname, rgb);
	menu.AddItem(modelname, "", ITEMDRAW_IGNORE);
	menu.AddItem(colorname, "", ITEMDRAW_IGNORE);
	menu.AddItem(rgb, "", ITEMDRAW_IGNORE);
	SQL_LockDatabase(g_Database);
	DBStatement st = SQL_PrepareQuery(g_Database, "select * from furious_global_store_modeltints where steam64 = ? and model_name = ? and color_name = ? and rgb = ?", error, sizeof(error));
	GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
	SQL_BindParamString(st, 0, sSteam64, false);
	SQL_BindParamString(st, 1, modelname, false);
	SQL_BindParamString(st, 2, colorname, false);
	SQL_BindParamString(st, 3, rgb, false);
	if (!SQL_Execute(st))
	{
		SQL_UnlockDatabase(g_Database);
		SetFailState(error);
	}
	int price = 100;
	for (int i = 0; i < g_iItems; i++)
	for (int ix = 0; ix < i; ix++)
	if (strlen(mcColors[i][ix].name) && StrEqual(modelname, g_sItem_Name[i]) && StrEqual(colorname, mcColors[i][ix].name))
		price = mcColors[i][ix].price;
	char sPrice[8];
	IntToString(price, sPrice, sizeof(sPrice));
	menu.AddItem(sPrice, "", ITEMDRAW_IGNORE);
	char sBuy[32];
	Format(sBuy, sizeof(sBuy), "Buy for %i credits", price);
	SQL_UnlockDatabase(g_Database);
	if (SQL_GetRowCount(st))
	{
		menu.AddItem("buy", sBuy, ITEMDRAW_DISABLED);
		if (CheckEquip(client, rgb, colorname, modelname))
		{
			menu.AddItem("unequip", "Unequip");
		}
		else
			menu.AddItem("equip", "Equip");
	}
	else
	{
		menu.AddItem("buy", sBuy, Furious_Statistics_GetCredits(client) >= price ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
		menu.AddItem("equip", "Equip", ITEMDRAW_DISABLED);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

stock int SetPlayerModelColor(int client)
{
	if (!convar_ModelTints.BoolValue) {
		return 0;
	}
	
	char sPath[PLATFORM_MAX_PATH], sMap[32], error[1024], sSteam64[32], sRGB[16];
	int iColor[4];
	ArrayList exclude = new ArrayList(32);
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_modeltints.cfg");
	KeyValues kv = new KeyValues("ModelTints");
	if (!kv.ImportFromFile(sPath))
		SetFailState("Couldn't import: \"%s\"", sPath);
	kv.JumpToKey("default color");
	kv.GetColor4("rgb", iColor);
	kv.GoBack();
	kv.JumpToKey("map_excluded");
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		delete exclude;
		SetEntityRenderColor(client, iColor[0], iColor[1], iColor[2], iColor[3]);
		LogMessage("No entries in config file");
		return 0;
	}
	GetCurrentMap(sMap, sizeof(sMap));
	do
	{
		char sSection[32];
		kv.GetSectionName(sSection, sizeof(sSection));
		if (StrEqual(sSection, sMap))
		{
			kv.JumpToKey("exclude");
			kv.GotoFirstSubKey();
			do
			{
				kv.GetColor4("rgb", iColor);
				exclude.PushArray(iColor, sizeof(iColor));
			}
			while (kv.GotoNextKey());
			kv.GoBack();
			kv.GoBack();
			kv.GetColor4("default", iColor);
		}
	}
	while (kv.GotoNextKey());
	char sModel[MAX_STORE_ITEM_NAME_LENGTH];
	// TODO NEED TO FIGURE OUT HOW TO GET THE DEFAULT PLAYERMODEL OF THE BOTS
	g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_MODELS, sModel, sizeof(sModel));
	DBStatement st = SQL_PrepareQuery(g_Database, "select rgb from furious_global_store_modeltints where steam64 = ? and model_name = ? and equipped = 1", error, sizeof(error));
	GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
	SQL_BindParamString(st, 0, sSteam64, false);
	SQL_BindParamString(st, 1, sModel, false);
	if (!SQL_Execute(st))
	{
		SQL_UnlockDatabase(g_Database);
		delete kv;
		delete exclude;
		SetFailState(error);
	}
	while (SQL_FetchRow(st))
	{
		SQL_FetchString(st, 0, sRGB, sizeof(sRGB));
		int tempcolor[4], fetchedcolor[4];
		StringToColor(sRGB, fetchedcolor, iColor);
		bool bOld;
		for (int i = 0; i < exclude.Length; i++)
		{
			exclude.GetArray(i, tempcolor, sizeof(tempcolor));
			if (ArrayEqual(fetchedcolor, tempcolor, 4))
			{
				bOld = true;
				break;
			}
		}
		if (!bOld)
			StringToColor(sRGB, iColor, iColor);
	}
	SQL_UnlockDatabase(g_Database);
	delete kv;
	delete exclude;
	SetEntityRenderColor(client, iColor[0], iColor[1], iColor[2], iColor[3]);

	return 0;
}

void Equip(int client, char[] rgb, char[] colorname, char[] modelname)
{
	UnEquip(client, modelname);
	char sSteam64[32], error[1024];
	GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
	SQL_LockDatabase(g_Database);
	DBStatement st = SQL_PrepareQuery(g_Database, "update furious_global_store_modeltints set equipped = 1 where steam64 = ? and model_name = ? and color_name = ? and rgb = ?", error, sizeof(error));
	SQL_BindParamString(st, 0, sSteam64, false);
	SQL_BindParamString(st, 1, modelname, false);
	SQL_BindParamString(st, 2, colorname, false);
	SQL_BindParamString(st, 3, rgb, false);
	if (!SQL_Execute(st))
	{
		SQL_UnlockDatabase(g_Database);
		SetFailState(error);
	}
	SQL_UnlockDatabase(g_Database);
}

bool CheckEquip(int client, char[] rgb, char[] colorname, char[] modelname)
{
	char sSteam64[32], error[1024];
	GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
	SQL_LockDatabase(g_Database);
	DBStatement st = SQL_PrepareQuery(g_Database, "select equipped from furious_global_store_modeltints where steam64 = ? and model_name = ? and color_name = ? and rgb = ? and equipped = 1", error, sizeof(error));
	SQL_BindParamString(st, 0, sSteam64, false);
	SQL_BindParamString(st, 1, modelname, false);
	SQL_BindParamString(st, 2, colorname, false);
	SQL_BindParamString(st, 3, rgb, false);
	if (!SQL_Execute(st))
	{
		SQL_UnlockDatabase(g_Database);
		SetFailState(error);
	}
	if (SQL_GetRowCount(st))
	{
		SQL_UnlockDatabase(g_Database);
		return true;
	}
	SQL_UnlockDatabase(g_Database);
	return false;
}

void UnEquip(int client, char[] modelname)
{
	char sSteam64[32], error[1024];
	GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
	SQL_LockDatabase(g_Database);
	DBStatement st = SQL_PrepareQuery(g_Database, "update furious_global_store_modeltints set equipped = 0 where steam64 = ? and model_name = ?", error, sizeof(error));
	SQL_BindParamString(st, 0, sSteam64, false);
	SQL_BindParamString(st, 1, modelname, false);
	if (!SQL_Execute(st))
	{
		SQL_UnlockDatabase(g_Database);
		SetFailState(error);
	}
	SQL_UnlockDatabase(g_Database);
}

public int MH_singletint(Menu menu, MenuAction action, int param1, int param2)
{
	char sModel[32], sColor[32], sRGB[16], sPrice[8];
	menu.GetItem(0, sModel, sizeof(sModel));
	menu.GetItem(1, sColor, sizeof(sColor));
	menu.GetItem(2, sRGB, sizeof(sRGB));
	menu.GetItem(3, sPrice, sizeof(sPrice));
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));
			if (StrEqual(sItem, "buy"))
			{
				char sSteam64[32], error[1024];
				GetClientAuthId(param1, AuthId_SteamID64, sSteam64, sizeof(sSteam64));
				PurchaseItem(param1, sColor, "modeltint", "", StringToInt(sPrice), 0, false);
				SQL_LockDatabase(g_Database);
				DBStatement st = SQL_PrepareQuery(g_Database, "insert into furious_global_store_modeltints (steam64, color_name, model_name, rgb) values (?, ?, ?, ?)", error, sizeof(error));
				SQL_BindParamString(st, 0, sSteam64, false);
				SQL_BindParamString(st, 1, sColor, false);
				SQL_BindParamString(st, 2, sModel, false);
				SQL_BindParamString(st, 3, sRGB, false);
				if (!SQL_Execute(st))
				{
					SQL_UnlockDatabase(g_Database);
					SetFailState(error);
				}
				SQL_UnlockDatabase(g_Database);
			}
			else if (StrEqual(sItem, "equip"))
			{
				Equip(param1, sRGB, sColor, sModel);
			}
			else if (StrEqual(sItem, "unequip"))
			{
				UnEquip(param1, sModel);
			}
			ShowSingleTint(param1, sRGB, sColor, sModel);
		}
		case MenuAction_Cancel:
		if (param2 == MenuCancel_ExitBack)
		{
			ShowTintsMenu(param1, sModel);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

/***********************************************************************
* Buy VIP Menu
***********************************************************************/

Menu GenerateBuyVIPMenu()
{
	Menu menu = new Menu(MenuHandle_BuyVIP, MenuAction_Select | MenuAction_Cancel | MenuAction_End);
	menu.SetTitle("Store | VIP\n \
					\n\nVIP PERKS:\n \
					- Unlimited Weapon Charges\n \
					- Custom chat tag\n \
					- Speclist\n \
					- Unique Player Model\n \
					- Get out of Jail with !open\n \
					- Vote Map Extend\n \
					- Extra credits earn\n \
					\nPurchase VIP here: \nfurious-clan.com/donate\n\n\n\n\n\n ");

	menu.AddItem("tryout", "5 Days (Tryout) - 1000 credits");
	//	menu.AddItem("30", "30 Days - 10000 credits");

	menu.ExitBackButton = true;

	return menu;
}

public int MenuHandle_BuyVIP(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[256];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			if (StrEqual(sInfo, "tryout"))
			{
				bool isVIP = GetUserFlagBits(param1) & VIP_FLAGS != 0;

				if (isVIP)
				{
					CPrintToChat(param1, "%T", "item tryout not now", param1);
					return 0;
				}

				int iCredits = Furious_Statistics_GetCredits(param1);
				if (iCredits < 1000)
				{
					CPrintToChat(param1, "%T", "item purchase not enough credits", param1, (1000 - iCredits));
					g_StoreMenu.Display(param1, MENU_TIME_FOREVER);
					return 0;
				}

				char name[32];
				GetClientName(param1, name, sizeof(name));

				int duration = 86400 * 5;
				AddVIPRet ret = Furious_VIP_AddVIP(name, g_sCacheData_SteamID2[param1], duration, true);

				switch (ret)
				{
					case ADDVIP_SUCCESS:
					{
						iCredits -= 1000;
						Furious_Statistics_SetCredits(param1, iCredits);

						char sBuffer[64];
						FormatSeconds(float(duration), sBuffer, sizeof(sBuffer), "%D days");

						CPrintToChat(param1, "%T", "item purchase vip tryout", param1, sBuffer);
					}
					case ADDVIP_ALREADY_TRIED_VIP:
					{
						CPrintToChat(param1, "%T", "item tryout already tried", param1);
					}
					default:
					{
						PrintToChat(param1, "Something went wrong, please contact administrator.");
					}
				}
			}
			else if (StrEqual(sInfo, "30"))
			{
				int iCredits = Furious_Statistics_GetCredits(param1);
				if (iCredits < 10000)
				{
					CPrintToChat(param1, "%T", "item purchase not enough credits", param1, (10000 - iCredits));
					g_StoreMenu.Display(param1, MENU_TIME_FOREVER);
					return 0;
				}

				char name[32];
				GetClientName(param1, name, sizeof(name));

				int duration = 86400 * 30;
				AddVIPRet ret = Furious_VIP_AddVIP(name, g_sCacheData_SteamID2[param1], duration, true);

				switch (ret)
				{
					case ADDVIP_SUCCESS:
					{
						iCredits -= 10000;
						Furious_Statistics_SetCredits(param1, iCredits);

						char sBuffer[64];
						FormatSeconds(float(duration), sBuffer, sizeof(sBuffer), "%D days");

						CPrintToChat(param1, "%T", "item purchase vip", param1, sBuffer);
					}
					default:
					{
						PrintToChat(param1, "Something went wrong, please contact administrator.");
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				g_StoreMenu.Display(param1, MENU_TIME_FOREVER);
		}
	}

	return 0;
}

/***********************************************************************
* Equip/Unequip Item
***********************************************************************/

void EquipItem(int client, const char[] sItemName, const char[] sItemType)
{
	g_PlayerItems_Equipped[client].SetString(sItemType, sItemName);

	if (StrEqual(sItemType, ITEM_DEFINE_SKYBOXES))
		SetClientSkybox(client);
	else if (StrEqual(sItemType, ITEM_DEFINE_MODELS))
		SetClientModel(client);

	if (g_iLoadedStats[client] >= 2)
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Items_Equipped.GetString(sTable, sizeof(sTable));

		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * MAX_NAME_LENGTH + 1;
		char[] sEscapedName = new char[size + 1];
		g_Database.Escape(sName, sEscapedName, size + 1);

		char sIP[64];
		GetClientIP(client, sIP, sizeof(sIP));

		bool bUniqueToMap = IsItemUniqueToMap(sItemType);

		char sQuery[4096];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `ip`, `item_type`, `item_name`, `map`) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%s', '%s', '%s') ON DUPLICATE KEY UPDATE `item_name` = '%s', `first_created` = 0;",
			sTable,
			sEscapedName,
			g_iCacheData_AccountID[client],
			g_sCacheData_SteamID2[client],
			g_sCacheData_SteamID3[client],
			g_sCacheData_SteamID64[client],
			sIP,
			sItemType,
			sItemName,
			bUniqueToMap ? g_sCurrentMap : "",
			sItemName
			);
		g_Database.Query(OnEquipItem, sQuery);

		// TODO: 'first_created' is always set to 0, it would be more appropriate if this was moved to when a player first purchased the item,
		// 						either this is just simply remove it completely as it has no impact
	}

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Equipped.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0)
		EmitSoundToClient(client, sSound);

	PrintToConsole(client, "Equipped item '%s' under item type '%s'.", sItemName, sItemType);
	CPrintToChat(client, "%T", "item quipped", client, "equipped", sItemName, g_sCurrentMap);
	DisplayInventoryItemsMenu(client, sItemType);
}

public void OnEquipItem(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while equipping item: %s", error);
	}
}

void UnequipItem(int client, const char[] sItemName, const char[] sItemType)
{
	g_PlayerItems_Equipped[client].Remove(sItemType);

	if (StrEqual(sItemType, ITEM_DEFINE_SKYBOXES))
		ClearSkybox(client);
	else if (StrEqual(sItemType, ITEM_DEFINE_MODELS))
		ClearModel(client);

	if (g_iLoadedStats[client] >= 2)
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Items_Equipped.GetString(sTable, sizeof(sTable));

		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		int size = 2 * MAX_NAME_LENGTH + 1;
		char[] sEscapedName = new char[size + 1];
		g_Database.Escape(sName, sEscapedName, size + 1);

		char sIP[64];
		GetClientIP(client, sIP, sizeof(sIP));

		bool bUniqueToMap = IsItemUniqueToMap(sItemType);

		char sQuery[4096];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `ip`, `item_type`, `item_name`, `map`) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%s', '', '%s') ON DUPLICATE KEY UPDATE `item_name` = '', `first_created` = 0;",
			sTable,
			sEscapedName,
			g_iCacheData_AccountID[client],
			g_sCacheData_SteamID2[client],
			g_sCacheData_SteamID3[client],
			g_sCacheData_SteamID64[client],
			sIP,
			sItemType,
			bUniqueToMap ? g_sCurrentMap : "");
		g_Database.Query(OnUnequipItem, sQuery);

		// TODO: 'first_created' is always set to 0, it would be more appropriate if this was moved to when a player first purchased the item,
		// 						either this is just simply remove it completely as it has no impact
	}

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Unequipped.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0)
		EmitSoundToClient(client, sSound);

	PrintToConsole(client, "Unequipped item '%s' under item type '%s'.", sItemName, sItemType);
	CPrintToChat(client, "%T", "item quipped", client, "unequipped", sItemName, g_sCurrentMap);
	DisplayInventoryItemsMenu(client, sItemType);
}

public void OnUnequipItem(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while unequipping item: %s", error);
	}
}

stock bool IsItemUniqueToMap(const char[] sItemType)
{
	for (int i; i < sizeof(g_sMapSpecificItems); i++)
	{
		if (StrEqual(g_sMapSpecificItems[i], sItemType))
			return true;
	}

	return false;
}

/***********************************************************************
* Parse Store Config
***********************************************************************/

void ParseStoreConfig()
{
	char sConfig[256];
	convar_Config.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_store");
	int sections;

	if (kv.ImportFromFile(sPath))
	{
		g_iItems = 0;

		if (kv.JumpToKey(ITEM_DEFINE_SPAWNEQUIPMENT) && kv.GotoFirstSubKey())
		{
			char sMaps[256];
			char sName[MAX_STORE_ITEM_NAME_LENGTH]; char sEntity[MAX_NAME_LENGTH];
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], MAX_STORE_ITEM_NAME_LENGTH);

				if (StrEqual(g_sItem_Name[g_iItems], "Pistols"))
					continue;

				strcopy(g_sItem_Type[g_iItems], MAX_STORE_ITEM_TYPE_LENGTH, ITEM_DEFINE_SPAWNEQUIPMENT);
				kv.GetString("description", g_sItem_Description[g_iItems], MAX_STORE_ITEM_DESCRIPTION_LENGTH);
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				kv.GetString("preview", g_sItem_Preview[g_iItems], MAX_STORE_ITEM_PREVIEW_LENGTH);
				kv.GetString("flags", g_sItem_Flags[g_iItems], MAX_FLAGS_LENGTH);
				g_iItem_Charges[g_iItems] = kv.GetNum("charges");
				kv.GetString("map_restrict", sMaps, sizeof(sMaps));
				g_bItem_IsUsable[g_iItems] = StrContains(sMaps, g_sCurrentMap) == -1;
				g_Item_Build_List[g_iItems] = new ArrayList(ByteCountToCells(MAX_STORE_ITEM_NAME_LENGTH));
				g_Item_Build_Lookup[g_iItems] = new StringMap();

				if (KvJumpToKey(kv, "build") && kv.GotoFirstSubKey(false))
				{
					do
					{
						kv.GetSectionName(sName, sizeof(sName));
						kv.GetString(NULL_STRING, sEntity, sizeof(sEntity));

						g_Item_Build_List[g_iItems].PushString(sName);
						g_Item_Build_Lookup[g_iItems].SetString(sName, sEntity);

					}
					while (kv.GotoNextKey(false));
					kv.GoBack();
					kv.GoBack();
				}

				g_iItems++;
			}
			while (kv.GotoNextKey());
			kv.GoBack();

			g_Item_Build_Pistol_List = new ArrayList(ByteCountToCells(MAX_STORE_ITEM_NAME_LENGTH));
			g_Item_Build_Pistol_Lookup = new StringMap();

			if (kv.JumpToKey("Pistols") && kv.GotoFirstSubKey(false))
			{
				g_bSpawnPistols = true;
				do
				{
					kv.GetSectionName(sName, sizeof(sName));
					kv.GetString(NULL_STRING, sEntity, sizeof(sEntity));

					g_Item_Build_Pistol_List.PushString(sName);
					g_Item_Build_Pistol_Lookup.SetString(sName, sEntity);
				}
				while (kv.GotoNextKey(false));
				kv.GoBack();
			}

			sections++;
		}
		kv.Rewind();

		if (kv.JumpToKey(ITEM_DEFINE_SPRAYS) && kv.GotoFirstSubKey())
		{
			char sMaterial[PLATFORM_MAX_PATH]; char sDownload[PLATFORM_MAX_PATH];
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], MAX_STORE_ITEM_NAME_LENGTH);
				strcopy(g_sItem_Type[g_iItems], MAX_STORE_ITEM_TYPE_LENGTH, ITEM_DEFINE_SPRAYS);
				kv.GetString("description", g_sItem_Description[g_iItems], MAX_STORE_ITEM_DESCRIPTION_LENGTH);
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				kv.GetString("preview", g_sItem_Preview[g_iItems], MAX_STORE_ITEM_PREVIEW_LENGTH);
				kv.GetString("flags", g_sItem_Flags[g_iItems], MAX_FLAGS_LENGTH);
				kv.GetString("material", sMaterial, sizeof(sMaterial));

				g_bItem_CanBeDefault[g_iItems] = view_as<bool>(kv.GetNum("defaultable", 0));

				if (strlen(sMaterial) > 0)
				{
					g_iItem_MaterialID[g_iItems] = PrecacheDecal(sMaterial, true);

					FormatEx(sDownload, sizeof(sDownload), "materials/%s.vmt", sMaterial);
					AddFileToDownloadsTable(sDownload);

					FormatEx(sDownload, sizeof(sDownload), "materials/%s.vtf", sMaterial);
					AddFileToDownloadsTable(sDownload);
				}

				g_iItems++;
			}
			while (kv.GotoNextKey());

			sections++;
		}
		kv.Rewind();

		if (kv.JumpToKey(ITEM_DEFINE_TAGS) && kv.GotoFirstSubKey())
		{
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], MAX_STORE_ITEM_NAME_LENGTH);
				strcopy(g_sItem_Type[g_iItems], MAX_STORE_ITEM_TYPE_LENGTH, ITEM_DEFINE_TAGS);
				kv.GetString("description", g_sItem_Description[g_iItems], MAX_STORE_ITEM_DESCRIPTION_LENGTH);
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				kv.GetString("preview", g_sItem_Preview[g_iItems], MAX_STORE_ITEM_PREVIEW_LENGTH);
				kv.GetString("flags", g_sItem_Flags[g_iItems], MAX_FLAGS_LENGTH);
				kv.GetString("tag", g_sItem_Tag[g_iItems], MAX_STORE_ITEM_TAG_LENGTH);

				g_iItems++;
			}
			while (kv.GotoNextKey());

			sections++;
		}
		kv.Rewind();

		if (kv.JumpToKey(ITEM_DEFINE_SKYBOXES) && kv.GotoFirstSubKey())
		{
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], MAX_STORE_ITEM_NAME_LENGTH);
				strcopy(g_sItem_Type[g_iItems], MAX_STORE_ITEM_TYPE_LENGTH, ITEM_DEFINE_SKYBOXES);
				kv.GetString("description", g_sItem_Description[g_iItems], MAX_STORE_ITEM_DESCRIPTION_LENGTH);
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				kv.GetString("preview", g_sItem_Preview[g_iItems], MAX_STORE_ITEM_PREVIEW_LENGTH);
				kv.GetString("flags", g_sItem_Flags[g_iItems], MAX_FLAGS_LENGTH);
				kv.GetString("name", g_sItem_Skybox[g_iItems], MAX_STORE_ITEM_SKYBOX_LENGTH);

				g_iItems++;
			}
			while (kv.GotoNextKey());

			sections++;
		}
		kv.Rewind();

		if (kv.JumpToKey(ITEM_DEFINE_MODELS) && kv.GotoFirstSubKey())
		{
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], MAX_STORE_ITEM_NAME_LENGTH);
				strcopy(g_sItem_Type[g_iItems], MAX_STORE_ITEM_TYPE_LENGTH, ITEM_DEFINE_MODELS);
				kv.GetString("description", g_sItem_Description[g_iItems], MAX_STORE_ITEM_DESCRIPTION_LENGTH);
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				kv.GetString("preview", g_sItem_Preview[g_iItems], MAX_STORE_ITEM_PREVIEW_LENGTH);
				kv.GetString("flags", g_sItem_Flags[g_iItems], MAX_FLAGS_LENGTH);
				kv.GetString("model", g_sItem_Model[g_iItems], MAX_STORE_ITEM_MODEL_LENGTH);
				kv.GetString("armsmodel", g_sItem_ArmsModel[g_iItems], MAX_STORE_ITEM_MODEL_LENGTH);
				//kv.GetColor4("default_tint", g_iItem_ModelColor[g_iItems]);
				if (kv.JumpToKey("tints") && kv.GotoFirstSubKey())
				{
					int i;
					do
					{
						kv.GetSectionName(mcColors[g_iItems][i].name, sizeof(mcColors[][].name));
						kv.GetColor4("rgb", mcColors[g_iItems][i].rgb);
						mcColors[g_iItems][i].price = kv.GetNum("price", 100);
						i++;
					} while (kv.GotoNextKey());
					kv.GoBack();
					kv.GoBack();
				}

				if (strlen(g_sItem_Model[g_iItems]) > 0)
				{
					g_iItem_ModelID[g_iItems] = PrecacheModel(g_sItem_Model[g_iItems], true);
					AddFileToDownloadsTable(g_sItem_Model[g_iItems]);
					ParseMaterialsFile(g_sItem_Model[g_iItems]);
				}

				if (strlen(g_sItem_ArmsModel[g_iItems]) > 0)
				{
					PrecacheModel(g_sItem_ArmsModel[g_iItems], true);
					AddFileToDownloadsTable(g_sItem_ArmsModel[g_iItems]);
					ParseMaterialsFile(g_sItem_ArmsModel[g_iItems]);
				}
				g_iItems++;
			}
			while (kv.GotoNextKey());
			sections++;
		}
		kv.Rewind();

		if (kv.JumpToKey(ITEM_DEFINE_OPENCHARGES) && kv.GotoFirstSubKey())
		{
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], MAX_STORE_ITEM_NAME_LENGTH);
				strcopy(g_sItem_Type[g_iItems], MAX_STORE_ITEM_TYPE_LENGTH, ITEM_DEFINE_OPENCHARGES);
				kv.GetString("description", g_sItem_Description[g_iItems], MAX_STORE_ITEM_DESCRIPTION_LENGTH);
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				kv.GetString("preview", g_sItem_Preview[g_iItems], MAX_STORE_ITEM_PREVIEW_LENGTH);
				kv.GetString("flags", g_sItem_Flags[g_iItems], MAX_FLAGS_LENGTH);
				g_iItem_Charges[g_iItems] = kv.GetNum("charges");

				g_iItems++;
			}
			while (kv.GotoNextKey());

			sections++;
		}
		kv.Rewind();

		if (kv.JumpToKey(ITEM_DEFINE_PHOENIXKIT) && kv.GotoFirstSubKey())
		{
			do
			{
				kv.GetSectionName(g_sItem_Name[g_iItems], sizeof(g_sItem_Name[]));
				strcopy(g_sItem_Type[g_iItems], sizeof(g_sItem_Type[]), ITEM_DEFINE_PHOENIXKIT);
				kv.GetString("description", g_sItem_Description[g_iItems], sizeof(g_sItem_Description[]));
				g_iItem_Price[g_iItems] = kv.GetNum("price");
				g_bItem_Buyable[g_iItems] = view_as<bool>(kv.GetNum("buyable", 1));
				g_bItem_WelcomePackage[g_iItems] = view_as<bool>(kv.GetNum("welcome_gift", 0));
				g_iItem_Charges[g_iItems] = kv.GetNum("charges");
				g_iItems++;
			}
			while (kv.GotoNextKey());
			sections++;
		}
		kv.Rewind();
	}

	LogMessage("Store config parsed. [%i sections loaded]", sections);
	delete kv;
}

void ParseFlagNames()
{
	//char sConfig[256];
	//convar_Config.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_flags.cfg");

	KeyValues kv = new KeyValues("furious_flags");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		g_FlagNames.Clear();

		char sFlag[MAX_FLAGS_LENGTH]; char sFlagName[32];
		do
		{
			kv.GetSectionName(sFlag, sizeof(sFlag));
			kv.GetString("name", sFlagName, sizeof(sFlagName));
			g_FlagNames.SetString(sFlag, sFlagName);
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Furious flag names parsed. [%i sections loaded]", g_FlagNames.Size);
	delete kv;
}

void ParseMaterialsFile(char[] model)
{
	int len = strlen(model) + 5;
	char[] path = new char[len];

	strcopy(path, len, model);
	ReplaceString(path, len, ".mdl", "_mat.txt");

	if (!FileExists(path))
	{
		return;
	}

	File file = OpenFile(path, "rt");

	if (file)
	{
		char material[PLATFORM_MAX_PATH];
		while (file.ReadLine(material, sizeof(material)))
		{
			if (material[0] == '\0' || material[0] == '/')
			{
				continue;
			}

			if (!FileExists(material))
			{
				LogMessage("Warning: a material file \"%s\" doesn't exist and thus players won't be able to download it.", material);
				continue;
			}

			AddFileToDownloadsTable(material);
		}

		delete file;
	}
}

/***********************************************************************
* Sprays
***********************************************************************/

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (client == 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Continue;

	if (IsFakeClient(client))
		return Plugin_Continue;

	int button;
	for (int i = 0; i < MAX_BUTTONS; i++)
	{
		button = (1 << i);

		if ((buttons & button))
		{
			if (!(g_iButtons[client] & button))
				OnButtonPress(client, button);
		}
	}

	g_iButtons[client] = buttons;

	if (g_hTimer_Previews[client] != null && g_ModelPreviewCamera[client] != -1 && !g_bIsDisplayedSBPreview[client])
	{
		if (buttons & (IN_FORWARD | IN_BACK | IN_MOVERIGHT | IN_MOVELEFT))
		{
			EndModelPreview(client);
			StopTimer(g_hTimer_Previews[client]);
		}
	}

	return Plugin_Continue;
}

void OnButtonPress(int client, int button)
{
	if (button & IN_USE)
		CreateSpray(client);
}

void CreateSpray(int client)
{
	float vecOrigin[3];
	GetClientEyePosition(client, vecOrigin);

	float vecEyePoint[3];
	GetPlayerEyeViewPoint(client, vecEyePoint);

	float vecPoints[3];
	MakeVectorFromPoints(vecEyePoint, vecOrigin, vecPoints);

	if (GetVectorLength(vecPoints) > convar_SprayDistance.FloatValue)
		return;

	if (g_bSprayed[client])
	{
		CPrintToChat(client, "%T", "sprayed already this round", client, g_iSprayTime[client]);
		return;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "You must be alive to spray on the walls.");
		return;
	}

	char sSprayName[MAX_STORE_ITEM_NAME_LENGTH];
	g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_SPRAYS, sSprayName, sizeof(sSprayName));

	if (strlen(sSprayName) == 0)
	{
		GetRandomDefaultSpray(sSprayName, sizeof(sSprayName));

		if (strlen(sSprayName) == 0)
			return;
	}

	int index = GetSprayMaterial(sSprayName);

	if (index == -1)
		return;

	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", vecEyePoint);
	TE_WriteNum("m_nIndex", index);
	TE_SendToAll();

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Spray.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0)
		EmitSoundToAll(sSound, client);

	g_bSprayed[client] = true;
}

void GetRandomDefaultSpray(char[] buffer, int size)
{
	int[] ids = new int[g_iItems];
	int count;

	for (int i = 0; i < g_iItems; i++)
	{
		if (g_bItem_CanBeDefault[i])
			ids[count++] = i;
	}

	strcopy(buffer, size, g_sItem_Name[GetRandomInt(0, count)]);
}

int GetSprayMaterial(const char[] sSprayName)
{
	for (int i = 0; i < g_iItems; i++)
	{
		if (!StrEqual(g_sItem_Name[i], sSprayName))
			continue;

		return g_iItem_MaterialID[i];
	}

	return -1;
}

bool GetPlayerEyeViewPoint(int iClient, float fPosition[3])
{
	float vecOrigin[3];
	GetClientEyePosition(iClient, vecOrigin);

	float vecAngles[3];
	GetClientEyeAngles(iClient, vecAngles);

	Handle hTrace = TR_TraceRayFilterEx(vecOrigin, vecAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer2);
	bool hit = TR_DidHit(hTrace);

	if (hit)
		TR_GetEndPosition(fPosition, hTrace);

	delete hTrace;
	return hit;
}

public bool TraceEntityFilterPlayer2(int iEntity, int iContentsMask)
{
	return iEntity > MaxClients;
}

/***********************************************************************
* Tags
***********************************************************************/

public int Native_Store_GetClientTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char sTagName[MAX_STORE_ITEM_NAME_LENGTH];
	bool bExists = g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_TAGS, sTagName, sizeof(sTagName));

	if (!bExists || strlen(sTagName) == 0)
		return bExists;

	char sTag[MAX_STORE_ITEM_TAG_LENGTH];
	if (!GetTagName(sTagName, sTag, sizeof(sTag)) || strlen(sTag) == 0)
		return false;

	SetNativeString(2, sTag, GetNativeCell(3));
	return true;
}

bool GetTagName(const char[] sTagName, char[] sTag, int iSize)
{
	for (int i = 0; i < g_iItems; i++)
	{
		if (!StrEqual(g_sItem_Name[i], sTagName))
			continue;

		strcopy(sTag, iSize, g_sItem_Tag[i]);
		return true;
	}

	return false;
}


/***********************************************************************
* Skyboxes
***********************************************************************/

bool SetClientSkybox(int client, bool bNoMessage = false)
{
	char sSkyboxName[MAX_STORE_ITEM_NAME_LENGTH];
	bool bExists = g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_SKYBOXES, sSkyboxName, sizeof(sSkyboxName));

	if (!bExists || strlen(sSkyboxName) == 0)
	{
		if (!bNoMessage)
			CPrintToChat(client, "You don't have a skybox equipped currently.");

		return bExists;
	}

	char sSkybox[MAX_STORE_ITEM_SKYBOX_LENGTH];
	if (!GetSkyboxName(sSkyboxName, sSkybox, sizeof(sSkybox)))
	{
		if (!bNoMessage)
			CPrintToChat(client, "Error setting your skybox, please contact an administrator.");

		return bExists;
	}

	SendConVarValue(client, convar_Skybox, sSkybox);
	return bExists;
}

void ClearSkybox(int client)
{
	char sSkybox[MAX_STORE_ITEM_SKYBOX_LENGTH];
	convar_Skybox.GetString(sSkybox, sizeof(sSkybox));
	SendConVarValue(client, convar_Skybox, sSkybox);
}

bool GetSkyboxName(const char[] sSkyboxName, char[] sSkybox, int iSize)
{
	for (int i = 0; i < g_iItems; i++)
	{
		if (!StrEqual(g_sItem_Name[i], sSkyboxName))
			continue;

		strcopy(sSkybox, iSize, g_sItem_Skybox[i]);
		return true;
	}

	return false;
}

/***********************************************************************
* Models
***********************************************************************/

bool SetClientModel(int client, bool bNoMessage = false)
{
	char sModelName[MAX_STORE_ITEM_NAME_LENGTH];
	bool bExists = g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_MODELS, sModelName, sizeof(sModelName));

	if (!bExists || strlen(sModelName) == 0)
	{
		if (!bNoMessage)
			CPrintToChat(client, "You don't have a model equipped currently.");

		return bExists;
	}

	char sModel[MAX_STORE_ITEM_MODEL_LENGTH], sArmsModel[MAX_STORE_ITEM_MODEL_LENGTH];
	if (!GetModel(sModelName, sModel, sizeof(sModel), sArmsModel, sizeof(sArmsModel)))
	{
		if (!bNoMessage)
			CPrintToChat(client, "Error setting your model, please contact an administrator.");

		return bExists;
	}

	if (strlen(sModel) > 0)
	{
		Furious_PlayerSkins_SetCustomModel(client, sModel);
	}

	if (strlen(sArmsModel) > 0)
	{
		Furious_PlayerSkins_SetCustomArms(client, sArmsModel);
	}

	if (!bNoMessage)
	{
		CPrintToChat(client, "%T", "model equipped", client, sModelName);
	}

	return bExists;
}

void ClearModel(int client, bool bNoMessage = false)
{
	Furious_PlayerSkins_ResetCustomModel(client);
	Furious_PlayerSkins_ResetCustomArms(client);

	if (!bNoMessage)
	{
		CPrintToChat(client, "%T", "model unequipped", client);
	}
}

bool GetModel(const char[] sModelName, char[] sModel, int iModelSize, char[] sArmsModel, int iArmsModelSize)
{
	for (int i = 0; i < g_iItems; i++)
	{
		if (!StrEqual(g_sItem_Name[i], sModelName))
			continue;

		strcopy(sModel, iModelSize, g_sItem_Model[i]);
		strcopy(sArmsModel, iArmsModelSize, g_sItem_ArmsModel[i]);

		return true;
	}

	return false;
}

/***********************************************************************
* Reset Score
***********************************************************************/

public Action Command_ResetScore(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	int iCredits = Furious_Statistics_GetCredits(client);
	int iDeduct = convar_ResetScoreCredits.IntValue;

	if (iCredits >= iDeduct)
	{
		iCredits -= iDeduct;
		Furious_Statistics_SetCredits(client, iCredits);

		if (g_bFrsResetScore)
			Furious_ResetScore_ResetPlayer(client);

		CPrintToChat(client, "%T", "reset score", client, iDeduct);
	}
	else
		CPrintToChat(client, "%T", "reset score not enough credits", client, iDeduct);

	return Plugin_Handled;
}

public int Native_Store_GetDefaultCredits(Handle plugin, int numParams)
{
	return convar_DefaultCredits.IntValue;
}

public int Native_Store_GetClientEquipped(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int size;
	GetNativeStringLength(2, size); size++;

	char[] sItemType = new char[size];
	GetNativeString(2, sItemType, size);

	char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
	if (!g_PlayerItems_Equipped[client].GetString(sItemType, sItemName, sizeof(sItemName)))
		return false;

	return SetNativeString(3, sItemName, GetNativeCell(4)) == SP_ERROR_NONE;
}

public int Native_Store_GetClientCharges(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client == 0 || !IsClientInGame(client) || IsFakeClient(client))
		return -1;

	int size;
	GetNativeStringLength(2, size); size++;

	char[] sItemName = new char[size];
	GetNativeString(2, sItemName, size);

	int charges;
	if (!g_PlayerItems_Charges[client].GetValue(sItemName, charges))
		return 0;

	return charges;
}

public int Native_Store_SetClientCharges(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	int size;

	GetNativeStringLength(2, size); size++;
	char[] sItemName = new char[size];
	GetNativeString(2, sItemName, size);

	GetNativeStringLength(3, size); size++;
	char[] sItemType = new char[size];
	GetNativeString(3, sItemType, size);

	int new_charges = GetNativeCell(4);

	g_PlayerItems_Charges[client].SetValue(sItemName, new_charges);

	if (new_charges <= 0)
		g_PlayerItems_Charges[client].Remove(sItemName);

	if (new_charges < 0)
		new_charges = 0;

	if (g_iLoadedStats[client] >= 2)
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_Items.GetString(sTable, sizeof(sTable));

		char sQuery[4096];
		g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `charges` = '%i' WHERE `accountid` = '%i' AND `item_name` = '%s' AND `item_type` = '%s';", sTable, new_charges, g_iCacheData_AccountID[client], sItemName, sItemType);
		g_Database.Query(TQuery_UpdateCharges, sQuery);
	}

	return true;
}

public int Native_Store_SendItemByName(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	
	char sItemName[MAX_STORE_ITEM_NAME_LENGTH], sItemType[MAX_STORE_ITEM_TYPE_LENGTH], sDescription[MAX_STORE_ITEM_DESCRIPTION_LENGTH];
	GetNativeString(2, sItemName, sizeof(sItemName));
	
	int index = GetItemID(sItemName);
	if (index == -1) {
		ThrowNativeError(SP_ERROR_NATIVE, "Item index not found.");
	}
	
	GetItemType(index, sItemType, sizeof(sItemType));
	GetItemDescription(index, sDescription, sizeof(sDescription));
	
	int iPrice = GetItemPrice(index);
	int iCharges = GetItemCharges(index);
	
	return GiveItem(client, sItemName, sItemType, sDescription, iPrice, iCharges);
}

public int Native_Store_SendItemByNameToAccount(Handle plugin, int numParams) {
	int accountid = GetNativeCell(1);
	
	char sItemName[MAX_STORE_ITEM_NAME_LENGTH], sItemType[MAX_STORE_ITEM_TYPE_LENGTH], sDescription[MAX_STORE_ITEM_DESCRIPTION_LENGTH];
	GetNativeString(2, sItemName, sizeof(sItemName));
	
	int index = GetItemID(sItemName);
	if (index == -1) {
		ThrowNativeError(SP_ERROR_NATIVE, "Item index not found.");
	}
	
	GetItemType(index, sItemType, sizeof(sItemType));
	GetItemDescription(index, sDescription, sizeof(sDescription));
	int iPrice = GetItemPrice(index);
	int iCharges = GetItemCharges(index);
	
	return GiveItemToAccount(accountid, sItemName, sItemType, sDescription, iPrice, iCharges);
}

public int Native_Store_GiveItem(Handle plugin, int numParams) {
	int client = GetNativeCell(1);
	char sItemName[MAX_STORE_ITEM_NAME_LENGTH], sItemType[MAX_STORE_ITEM_TYPE_LENGTH], sDescription[MAX_STORE_ITEM_DESCRIPTION_LENGTH];

	GetNativeString(2, sItemName, sizeof(sItemName));
	GetNativeString(3, sItemType, sizeof(sItemType));
	GetNativeString(4, sDescription, sizeof(sDescription));

	int iPrice = GetNativeCell(5);
	int iCharges = GetNativeCell(6);

	return GiveItem(client, sItemName, sItemType, sDescription, iPrice, iCharges);
}

public int Native_Store_ShowVipMenu(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (!IsClientInGame(client) || client == 0 || IsFakeClient(client))
		return -1;

	g_BuyVIPMenu.Display(client, MENU_TIME_FOREVER);

	return 1;
}

public int Native_PhoenixKitUsed(Handle plugin, int numParams)
{
	return g_bPhoenixKitUsed[GetNativeCell(1)];
}

public Action Command_AddCredits(int client, int args)
{
	if (!convar_Status.BoolValue || !client || !IsClientInGame(client))
		return Plugin_Handled;

	char sArg1[MAX_NAME_LENGTH];
	GetCmdArg(1, sArg1, sizeof(sArg1));

	char sArg2[12];
	GetCmdArg(2, sArg2, sizeof(sArg2));
	int give = StringToInt(sArg2);

	int target = FindTarget(client, sArg1, true, true);

	if (target != -1)
	{
		CPrintToChat(client, "%T", "store admin give credits", client, give, target);

		if (GetUserFlagBits(target) & VIP_FLAGS)
		{
			static ConVar convar_ExtraCredits = null;

			if (convar_ExtraCredits == null)
			{
				convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");
			}

			CPrintToChat(target, "%T", "vip store admin receive credits", target, client, convar_ExtraCredits.IntValue, give);
		}
		else
		{
			CPrintToChat(target, "%T", "store admin receive credits", target, client, give);
		}

		CPrintToChatAll("%t", "store admin send credits global", client, target, give);

		Furious_Statistics_AddCredits(target, give);
	}

	return Plugin_Handled;
}

public Action Command_ParseStoreConfig(int client, int args)
{
	ParseStoreConfig();
	return Plugin_Handled;
}

public Action Command_TestPhoenixKit(int client, int args)
{
	ShowPhoenixKitMenu(client, 1);
	return Plugin_Handled;
}

public Action Command_DisplayCredits(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	int target = client;

	if (args > 0)
		target = GetCmdArgTarget(client, 1, true, false);

	if (target == -1)
		return Plugin_Handled;

	CPrintToChatAll("%t", "credits amount owned", target, Furious_Statistics_GetCredits(target), Furious_Statistics_GetCreditsEarned(target));
	return Plugin_Handled;
}

public Action Command_PhoenixKit(int client, int args)
{
	if (client == 0 || !IsClientInGame(client))
		return Plugin_Handled;

	if (!PhoenixKitEligible(client))
	{
		CPrintToChat(client, "%t", "phoenix kit command");
	}
	return Plugin_Handled;
}

public Action Command_DailyReward(int client, int args)
{
	if (!client || !AreClientCookiesCached(client))
		return Plugin_Handled;

	char sCollectDelay[12];
	GetClientCookie(client, g_hDailyRewardDelay, sCollectDelay, sizeof(sCollectDelay));
	int iCollectTime = StringToInt(sCollectDelay);
	int iCurrentTime = GetTime();
	int iDelayTime = iCurrentTime - iCollectTime;

	if (iDelayTime > 86400)
	{
		char sCollectDay[12];
		GetClientCookie(client, g_hDailyRewardDay, sCollectDay, sizeof(sCollectDay));
		int iCollectDay = StringToInt(sCollectDay);

		if (iCollectDay == 6)
		{
			CPrintToChat(client, "%t", "daily reward credits collected last day", iCreditsReward[iCollectDay], client);
			Format(sCollectDay, sizeof(sCollectDay), "%i", 0);
		}
		else
		{
			CPrintToChat(client, "%t", "daily reward credits collected", iCreditsReward[iCollectDay], iCollectDay + 1);
			Format(sCollectDay, sizeof(sCollectDay), "%i", iCollectDay + 1);
		}

		Furious_Statistics_AddCredits(client, iCreditsReward[iCollectDay]);

		char sTime[32];
		IntToString(iCurrentTime, sTime, sizeof(sTime));
		SetClientCookie(client, g_hDailyRewardDelay, sTime);
		SetClientCookie(client, g_hDailyRewardDay, sCollectDay);
	}
	else
	{
		char sTime[32];
		int iSeconds = (86400 - iDelayTime) % (24 * 3600);
		int iHour = iSeconds / 3600;
		iSeconds %= 3600;
		int iMinutes = iSeconds / 60;
		iSeconds %= 60;

		Format(sTime, sizeof(sTime), "%i hours, %i minutes, %i seconds", iHour, iMinutes, iSeconds);
		CPrintToChat(client, "%t", "daily reward already collected", sTime);
	}

	return Plugin_Handled;
}

public Action Command_SpawnBuilds(int client, int args)
{
	if (!convar_Status.BoolValue || !convar_EquipmentMenuStatus.BoolValue || client == 0)
		return Plugin_Handled;

	DisplaySpawnBuildsMenu(client);
	return Plugin_Handled;
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);

	if (g_bPhoenixKitUsed[client] && convar_PhoenixKitSpawnProtection_Time.IntValue > 0)
		ESP_GiveSpawnProtection(client, convar_PhoenixKitSpawnProtection_Time.IntValue, PROTECTION_COLOR);

	if (!convar_Status.BoolValue || client == 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client))
		return;

	if (Redie_IsClientGhost(client))
	{
		return;
	}

	TryGiveWelcomeGift(client);

	if (IsClientInGame(client))
		CreateTimer(float(hTimeCvar.IntValue + hFreezeTimeCvar.IntValue + 2), Timer_SetColor, userid, TIMER_FLAG_NO_MAPCHANGE);

	if (convar_EquipmentMenuStatus.BoolValue && IsPlayerAlive(client))
		CreateTimer(0.5, Timer_DisplayBuildMenu, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SetColor(Handle timer, any userid)
{
	//SetPlayerModelColor(GetClientOfUserId(userid));
	return Plugin_Continue;
}

public Action Timer_DisplayBuildMenu(Handle timer, any data)
{
	int client = GetClientFromSerial(data);

	if (client == 0 || IsFakeClient(client))
		return Plugin_Stop;

	if (Redie_IsClientGhost(client))
		return Plugin_Stop;

	if (convar_Status.BoolValue && convar_EquipmentMenuStatus.BoolValue && client > 0 && IsPlayerAlive(client))
		DisplaySpawnBuildsMenu(client, true);

	if (!AreClientCookiesCached(client))
		return Plugin_Stop;

	char sCookie[32];
	GetClientCookie(client, g_hSpawnPistol, sCookie, sizeof(sCookie));

	int weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY);
	if (IsValidEntity(weapon))
		AcceptEntityInput(weapon, "kill");

	GivePlayerItem(client, StrEqual(sCookie, "") ? "weapon_glock" : sCookie);

	return Plugin_Stop;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	g_bIsRoundEnd = true;
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bSprayed[i] = false;
		g_iSprayTime[i] = 20;
		g_bPhoenixKitUsed[i] = false;
		g_iLastActionEnd[i] = 0;
		g_bIsPhoenixKitMenuShown[i] = false;

		if (IsClientInGame(i) && !IsFakeClient(i))
			g_PhoenixKitEligible.SetValue(g_sCacheData_SteamID64[i], true);

		if (g_hTimer_Previews[i] != null && g_ModelPreviewCamera[i] != -1)
		{
			EndModelPreview(i, false);
			StopTimer(g_hTimer_Previews[i]);
		}
	}
}

public void OnRoundRestart(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;

	if (convar_EquipmentMenuStatus.BoolValue)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !IsPlayerAlive(i) || IsFakeClient(i))
				continue;

			DisplaySpawnBuildsMenu(i, true);
		}
	}
}

void DisplaySpawnBuildsMenu(int client, bool check = false)
{
	if (client == 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (GetClientTeam(client) == CS_TEAM_SPECTATOR)
	{
		CPrintToChat(client, "%t", "cant use guns while spectator");
		return;
	}

	if (!IsPlayerAlive(client))
	{
		CPrintToChat(client, "%t", "cant use guns while dead");
		return;
	}

	if (Redie_IsClientGhost(client))
	{
		CPrintToChat(client, "%t", "cant use guns while redie");
		return;
	}

	bool isVIP = GetUserFlagBits(client) & VIP_FLAGS != 0;

	char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
	g_PlayerItems_Equipped[client].GetString(ITEM_DEFINE_SPAWNEQUIPMENT, sItemName, sizeof(sItemName));

	int primary = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY);

	if (!check || !IsValidEntity(primary) && check)
	{
		Menu menu = new Menu(MenuHandle_SpawnBuilds);
		menu.SetTitle("Spawn Builds");

		char sDisplay[512];

		if (isVIP)
		{
			int weaponsCount = 0;
			for (int i = 0; i < g_iItems; i++)
			{
				if (!StrEqual(g_sItem_Type[i], ITEM_DEFINE_SPAWNEQUIPMENT))
					continue;

				weaponsCount++;
			}

			int weaponsCounter = 0;
			for (int i = 0; i < g_iItems; i++)
			{
				if (!StrEqual(g_sItem_Type[i], ITEM_DEFINE_SPAWNEQUIPMENT))
					continue;

				strcopy(sItemName, sizeof(sItemName), g_sItem_Name[i]);

				Format(sDisplay, sizeof(sDisplay), "%s%s", sItemName, ++weaponsCounter >= weaponsCount ? "\n \n" : "");
				menu.AddItem(sItemName, sDisplay, g_bItem_IsUsable[i] ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
			}
		}
		else
		{
			char sItemType[MAX_STORE_ITEM_TYPE_LENGTH]; int charges;

			int weaponsCount = 0;
			for (int i = 0; i < g_PlayerItems_Name[client].Length; i++)
			{
				g_PlayerItems_Name[client].GetString(i, sItemName, sizeof(sItemName));
				g_PlayerItems_Types[client].GetString(i, sItemType, sizeof(sItemType));
				g_PlayerItems_Charges[client].GetValue(sItemName, charges);

				if (!StrEqual(sItemType, ITEM_DEFINE_SPAWNEQUIPMENT))
					continue;

				if (charges > 0)
				{
					weaponsCount++;
				}
			}

			int weaponsCounter = 0;
			for (int i = 0; i < g_PlayerItems_Name[client].Length; i++)
			{
				g_PlayerItems_Name[client].GetString(i, sItemName, sizeof(sItemName));
				g_PlayerItems_Types[client].GetString(i, sItemType, sizeof(sItemType));
				g_PlayerItems_Charges[client].GetValue(sItemName, charges);

				if (!StrEqual(sItemType, ITEM_DEFINE_SPAWNEQUIPMENT))
					continue;

				int id = GetItemID(sItemName, sItemType);
				bool isUsable = id != -1 && g_bItem_IsUsable[id];

				if (charges > 0)
				{
					Format(sDisplay, sizeof(sDisplay), "[%i] %s%s", charges, sItemName, ++weaponsCounter >= weaponsCount ? "\n \n" : "");
					menu.AddItem(sItemName, sDisplay, isUsable ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
				}
			}
		}

		if (g_bSpawnPistols)
			menu.AddItem("pistols", "Change Pistol");

		if (menu.ItemCount == 1)
		{
			char buffer[255];
			menu.GetTitle(buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "%s\nYou're out of weapons!", buffer);
			menu.SetTitle(buffer);
			menu.AddItem("StoreBuilds", "Go to the Store\n \n");
		}
		menu.Display(client, MENU_TIME_FOREVER);
	}
}

public int MenuHandle_SpawnBuilds(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sItemName[MAX_STORE_ITEM_NAME_LENGTH];
			menu.GetItem(param2, sItemName, sizeof(sItemName));

			if (StrEqual(sItemName, "StoreBuilds"))
				DisplayStoreItemsMenu(param1, ITEM_DEFINE_SPAWNEQUIPMENT);

			else if (StrEqual(sItemName, "pistols"))
				DisplaySpawnPistols(param1);

			else GiveClientSpawnBuild(param1, sItemName);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

void DisplaySpawnPistols(int client)
{
	Menu menu = new Menu(MenuHandle_SpawnPistols);
	menu.SetTitle("Change Pistol");
	for (int i = 0; i < g_Item_Build_Pistol_List.Length; ++i)
	{
		char sInfo[128], sDisplay[128], sCookie[128];

		g_Item_Build_Pistol_List.GetString(i, sDisplay, sizeof(sDisplay));
		g_Item_Build_Pistol_Lookup.GetString(sDisplay, sInfo, sizeof(sInfo));
		if (AreClientCookiesCached(client))
			GetClientCookie(client, g_hSpawnPistol, sCookie, sizeof(sCookie));
		Format(sDisplay, sizeof(sInfo), "[%s] %s", StrEqual(sCookie, sInfo) ? "X" : "", sDisplay);
		menu.AddItem(sInfo, sDisplay);
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_SpawnPistols(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (AreClientCookiesCached(param1))
			{
				char sInfo[128];
				menu.GetItem(param2, sInfo, sizeof(sInfo));
				SetClientCookie(param1, g_hSpawnPistol, sInfo);
				DisplaySpawnPistols(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				DisplaySpawnBuildsMenu(param1);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

void GiveClientSpawnBuild(int client, const char[] sItemName)
{
	if (client == 0 || client > MaxClients || !IsClientConnected(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || strlen(sItemName) == 0)
		return;

	bool isVIP = GetUserFlagBits(client) & VIP_FLAGS != 0;

	char sTable[MAX_TABLE_SIZE];
	convar_Table_Items.GetString(sTable, sizeof(sTable));

	int charges;
	g_PlayerItems_Charges[client].GetValue(sItemName, charges);

	if (charges < 1 && !isVIP)
		return;

	int weapon;
	for (int i = 0; i < 4; i++)
	{
		if (i == CS_SLOT_KNIFE)
			continue;

		weapon = GetPlayerWeaponSlot(client, i);

		if (IsValidEntity(weapon))
		{
			CS_DropWeapon(client, weapon, false, true);
			AcceptEntityInput(weapon, "Kill");
		}
	}

	int id = GetItemID(sItemName, ITEM_DEFINE_SPAWNEQUIPMENT);
	if (id == -1)
	{
		PrintToChat(client, "Error setting your spawn equipment, please contact an administrator.");
		return;
	}

	char sItem[64]; char sEntity[64];
	for (int i = 0; i < g_Item_Build_List[id].Length; i++)
	{
		g_Item_Build_List[id].GetString(i, sItem, sizeof(sItem));
		g_Item_Build_Lookup[id].GetString(sItem, sEntity, sizeof(sEntity));

		if (strlen(sEntity) > 0 && StrContains(sEntity, "weapon_") != -1)
			GivePlayerItem(client, sEntity);
	}

	char sCookie[32];
	if (AreClientCookiesCached(client))
		GetClientCookie(client, g_hSpawnPistol, sCookie, sizeof(sCookie));
	GivePlayerItem(client, StrEqual(sCookie, "") ? "weapon_glock" : sCookie);

	CPrintToChat(client, "%T", "spawn equipment build equipped", client, sItemName);

	if (!isVIP)
	{
		charges--;
		g_PlayerItems_Charges[client].SetValue(sItemName, charges);

		CPrintToChat(client, "%T", "spawn equipment charges remaining", client, charges);

		if (g_iLoadedStats[client] >= 2)
		{
			char sQuery[4096];
			g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `charges` = '%i' WHERE `accountid` = '%i' AND `item_name` = '%s' AND `item_type` = '%s';", sTable, charges, g_iCacheData_AccountID[client], sItemName, ITEM_DEFINE_SPAWNEQUIPMENT);
			g_Database.Query(TQuery_UpdateCharges, sQuery);
		}
	}
}

void LivePreview(int client, char[] name, char[] type, int id)
{
	int serial = GetClientSerial(client);

	if (StrEqual(type, ITEM_DEFINE_SKYBOXES))
	{
		char sSkybox[MAX_STORE_ITEM_SKYBOX_LENGTH];
		GetSkyboxName(name, sSkybox, sizeof(sSkybox));

		SendConVarValue(client, convar_Skybox, sSkybox);

		StopTimer(g_hTimer_Previews[client]);
		g_bIsDisplayedSBPreview[client] = true;
		g_hTimer_Previews[client] = CreateTimer(5.0, Timer_DisableLivePreview_Skyboxes, serial);

		CPrintToChat(client, "%T", "live preview skyboxes start", client);
	}
	else if (StrEqual(type, ITEM_DEFINE_MODELS))
	{
		int flags = GetEntityFlags(client);

		if (!(flags & FL_ONGROUND))
		{
			CPrintToChat(client, "%t", "live preview models not on ground", client);
			return;
		}

		float velocity[3];
		GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

		if (GetVectorLength(velocity, true) > 25.0)
		{
			CPrintToChat(client, "%t", "live preview models moving", client);
			return;
		}

		if (SpawnCamera(client))
		{
			g_PreviousModelIndex[client] = GetEntProp(client, Prop_Send, "m_nModelIndex");
			SetEntProp(client, Prop_Send, "m_nModelIndex", g_iItem_ModelID[id]);

			StopTimer(g_hTimer_Previews[client]);
			g_hTimer_Previews[client] = CreateTimer(5.0, Timer_DisableLivePreview_Models, serial);

			PrintToChat(client, "%T", "live preview models start", client);
		}
	}
}

public void TQuery_UpdateCharges(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error updating client charges: %s", error);
}

public void TQuery_RemoveItem(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error removing player item: %s", error);
}

stock int GetItemID(const char[] sItemName, const char[] sItemType = "")
{
	for (int i = 0; i < g_iItems; i++)
	{
		if (strlen(sItemType) > 0 && !StrEqual(sItemType, g_sItem_Type[i])) {
			continue;
		}

		if (StrEqual(sItemName, g_sItem_Name[i]))
			return i;
	}

	return -1;
}

stock void GetItemType(int index, char[] type, int size) {
	strcopy(type, size, g_sItem_Type[index]);
}

stock void GetItemDescription(int index, char[] type, int size) {
	strcopy(type, size, g_sItem_Description[index]);
}

stock int GetItemPrice(int index) {
	return g_iItem_Price[index];
}

stock int GetItemCharges(int index) {
	return g_iItem_Price[index];
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iRoundStartTime = GetTime();
	g_bIsRoundEnd = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (PhoenixKitEligible(client))
	{
		ShowPhoenixKitMenu(client, PHOENIXHIT_LATEJOIN);
		return;
	}

	g_PhoenixKitEligible.SetValue(g_sCacheData_SteamID64[client], false);
}

void ShowPhoenixKitMenu(int client, int mode)
{
	if (!convar_PhoenixKitEnabled.BoolValue || g_bIsRoundEnd)
		return;

	int charges = Furious_Store_GetClientCharges(client, "PhoenixCharges");
	bool eligible;
	g_PhoenixKitEligible.GetValue(g_sCacheData_SteamID64[client], eligible);

	if (g_bPhoenixKitUsed[client] || !IsClientInGame(client) || IsFakeClient(client) || charges < 0 || g_bIsPhoenixKitMenuShown[client] || g_bIsRoundEnd || !eligible)
		return;

	g_bIsPhoenixKitMenuShown[client] = true;

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(mode);
	pack.WriteCell(convar_PhoenixKitMenuTime.IntValue);

	g_iLastActionEnd[client] = 60;

	TriggerTimer(CreateTimer(1.0, Timer_PhoenixKit, pack, TIMER_FLAG_NO_MAPCHANGE), true);
}

public Action Timer_PhoenixKit(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientFromSerial(pack.ReadCell());
	int mode = pack.ReadCell();
	int time = pack.ReadCell();

	int charges = Furious_Store_GetClientCharges(client, "PhoenixCharges");

	if (client == 0 || g_bIsRoundEnd || g_bPhoenixKitUsed[client] || IsFakeClient(client) || !g_bIsPhoenixKitMenuShown[client] || time == 0 || (g_iLastActionEnd[client] < 60 && g_iLastActionEnd[client] != 1))
	{
		g_iLastActionEnd[client] = 0;
		delete pack;
		return Plugin_Stop;
	}
	pack.Reset(true);

	Menu menu = new Menu(MenuHandle_PhoenixKit);
	menu.ExitButton = false;
	char sMode[8];
	IntToString(mode, sMode, sizeof(sMode));
	menu.AddItem(sMode, "", ITEMDRAW_IGNORE);
	switch (mode)
	{
		case PHOENIXHIT_DEATH:
		menu.SetTitle("Ouch! .. wanna try again? (%i sec)\n ", time);
		case PHOENIXHIT_SPECTATE:
		menu.SetTitle("You were moved to spectate\nFor being AFK (%i sec)\n ", time);
		case PHOENIXHIT_LATEJOIN:
		menu.SetTitle("A round is already in progress (%i sec)\n ", time);
	}

	char sDisplay[64];
	Format(sDisplay, sizeof(sDisplay), "Use Phoenix Kit (%ix left)", charges);
	menu.AddItem("phoenix", sDisplay, charges > 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	if (charges <= 0)
	{
		menu.AddItem("refill", "Refill Phoenix Kit");
	}
	menu.AddItem("spacer", "", ITEMDRAW_SPACER);
	menu.AddItem("spacer", "", ITEMDRAW_SPACER);
	menu.AddItem("close", "Close");
	menu.Display(client, 1);

	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(mode);
	pack.WriteCell(--time);
	CreateTimer(1.0, Timer_PhoenixKit, pack, TIMER_FLAG_NO_MAPCHANGE);

	return Plugin_Stop;
}

public int MenuHandle_PhoenixKit(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			menu.GetItem(param2, sItem, sizeof(sItem));

			if (StrEqual(sItem, "phoenix"))
			{
				char sSound[PLATFORM_MAX_PATH];
				convar_Sound_PhoenixKitUsed.GetString(sSound, sizeof(sSound));

				if (strlen(sSound) > 0)
					EmitSoundToClient(param1, sSound);

				//CPrintToChatAll("%t", "phoenix kit used", param1);

				char sMode[8];
				menu.GetItem(0, sMode, sizeof(sMode));

				switch (StringToInt(sMode))
				{
					case PHOENIXHIT_DEATH:
					CPrintToChatAll("%t", "phoenix kit death", param1);
					case PHOENIXHIT_SPECTATE:
					CPrintToChatAll("%t", "phoenix kit spectate", param1);
					case PHOENIXHIT_LATEJOIN:
					CPrintToChatAll("%t", "phoenix kit latejoin", param1);
				}

				g_iLastActionEnd[param1] = 0;
				g_bPhoenixKitUsed[param1] = true;

				if (IsClientInGame(param1) && !IsPlayerAlive(param1))
				{
					if (GetClientTeam(param1) == CS_TEAM_SPECTATOR)
						CS_SwitchTeam(param1, CS_TEAM_T);
					CS_RespawnPlayer(param1);
				}

				Furious_Store_SetClientCharges(param1, "PhoenixCharges", ITEM_DEFINE_PHOENIXKIT, Furious_Store_GetClientCharges(param1, "PhoenixCharges") - 1);

				/*Event event = CreateEvent("player_death", true);

				event.SetString("weapon", "awp_phoenix_kit_bz");
				event.SetInt("userid", GetClientUserId(param1));
				event.SetInt("attacker", 37);
				event.SetInt("assister", 0);
				event.SetBool("headshot", false);
				event.SetBool("penetrated", false);
				event.SetBool("revenge", false);
				event.SetBool("dominated", false);

				for (int i = 1; i <= MaxClients; i++)if (IsClientInGame(i) && !IsFakeClient(i))
					event.FireToClient(i);

				event.Cancel();*/
			}
			else if (StrEqual(sItem, "refill"))
			{
				DisplayStoreItemsMenu(param1, ITEM_DEFINE_PHOENIXKIT);
				g_iLastActionEnd[param1] = 1;
			}
			else if (StrEqual(sItem, "close"))
			{
				g_iLastActionEnd[param1] = 1;
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

public Action Timer_Milliseconds(Handle timer)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (g_iLastActionEnd[i])
		{
			++g_iLastActionEnd[i];
		}
		else if (g_iLastActionEnd[i] > 120)
			g_iLastActionEnd[i] = 0;
	}

	return Plugin_Continue;
}

public Action AFKM_OnAFKEvent(const char[] name, int client)
{
	static ConVar convar_SpawnProtectionTime;
	convar_SpawnProtectionTime = FindConVar("sm_easysp_time");
	if (GetTime() - g_iRoundStartTime <= convar_PhoenixKitAllowTime_Spectate.IntValue + (convar_SpawnProtectionTime == null ? 0 : convar_SpawnProtectionTime.IntValue))
	{
		ShowPhoenixKitMenu(client, PHOENIXHIT_SPECTATE);
		return Plugin_Continue;
	}
	g_PhoenixKitEligible.SetValue(g_sCacheData_SteamID64[client], false);
	return Plugin_Continue;
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	static ConVar convar_SpawnProtectionTime;
	convar_SpawnProtectionTime = FindConVar("sm_easysp_time");

	int iSeconds = convar_PhoenixKitAllowTime_Death.IntValue + (convar_SpawnProtectionTime == null ? 0 : convar_SpawnProtectionTime.IntValue);

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (GetTime() - g_iRoundStartTime > iSeconds && IsClientInGame(client) && !IsFakeClient(client))
	{
		g_PhoenixKitEligible.SetValue(g_sCacheData_SteamID64[client], false);
		return;
	}

	ShowPhoenixKitMenu(client, PHOENIXHIT_DEATH);
}

bool PhoenixKitEligible(int client)
{
	static ConVar convar_GraceTime;
	convar_GraceTime = FindConVar("mp_join_grace_time");

	static ConVar convar_SpawnProtectionTime;
	convar_SpawnProtectionTime = FindConVar("sm_easysp_time");

	return GetTime() - g_iRoundStartTime > convar_GraceTime.IntValue && GetTime() - g_iRoundStartTime <= convar_PhoenixKitAllowTime_LateJoin.IntValue + (convar_SpawnProtectionTime == null ? 0 : convar_SpawnProtectionTime.IntValue) && g_iRoundStartTime != 0 && !IsPlayerAlive(client);
}