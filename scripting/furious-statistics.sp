/*-- Pragmas --*/
#pragma semicolon 1
#pragma newdecls required

/*-- Defines --*/
#define PLUGIN_VERSION "1.3.3"

#define VIP_FLAGS ADMFLAG_CUSTOM5

#define OVERLAY_RAMPAGE 1
#define OVERLAY_RANKUP	2
#define OVERLAY_TIERUP	3

#define MAX_QUERY_SIZE 8192
#define MAX_TABLE_SIZE 64
#define WEAPON_STATISTICS_SIZE 4096

#define TOP_RANKS_NUMBER 10

#define DATA_GLOBAL 0
#define DATA_SEASONAL 1
#define DATA_SEASONAL2 2
#define DATA_MAPBASED 3

#define MESSAGE_WELCOME 1
#define MESSAGE_WELCOMEBACK 2

/*-- Includes --*/
#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <geoip>
#include <colorlib>
#include <autoexecconfig>
#include <json>
#include <unixtime_sourcemod>
#include <socket>

/*-- Furious Includes --*/
#include <furious/furious-stocks>
#include <furious/furious-statistics>

#undef REQUIRE_PLUGIN
#include <furious/furious-tags>
#include <furious/furious-weapons>
#include <furious/furious-vip>
#define REQUIRE_PLUGIN

/*-- ConVars --*/
ConVar convar_Status;
ConVar convar_Config_Ranks;
ConVar convar_Config_Tiers;
ConVar convar_Table_GlobalData;
ConVar convar_Table_GlobalStatistics;
ConVar convar_Table_GlobalMapStatistics;
ConVar convar_Table_ServerSeasons;
ConVar convar_Table_ServerMaps;
ConVar convar_Table_ServerSessions;
ConVar convar_RoundClampStatistics;
ConVar convar_MinimumPlayersStatistics;
ConVar convar_NoBotsStatistics;
ConVar convar_Rampage_Overlay;
ConVar convar_Rampage_Points;
ConVar convar_SaveOnRoundEnd;
ConVar convar_SaveOnPlayerDeath;
ConVar convar_Sound_Rampage;
ConVar convar_Sound_Connect;
ConVar convar_Sound_Reconnect;
ConVar convar_Sound_RankEnabled;
ConVar convar_Sound_RankDisabled;
ConVar convar_RankEnabled_Status;
ConVar convar_RankEnabled_Channel;
ConVar convar_RankEnabled_Coordinate_X;
ConVar convar_RankEnabled_Coordinate_Y;
ConVar convar_RankEnabled_Color;
ConVar convar_RankDisabled_Status;
ConVar convar_RankDisabled_Channel;
ConVar convar_RankDisabled_Coordinate_X;
ConVar convar_RankDisabled_Coordinate_Y;
ConVar convar_RankDisabled_Color;
ConVar convar_ResetRankCredits;
ConVar convar_LosePointsOnSuicide;
ConVar convar_ConnectMessage;
ConVar convar_DisconnectMessage;
ConVar convar_SeasonChangeTime;

/*-- Forwards --*/
Handle g_Forward_OnGlobalsValidated;
Handle g_Forward_OnSeasonChange;
Handle g_Forward_StatsMe_OnSeasonStats;
Handle g_Forward_OnConnectGlobal;
Handle g_Forward_OnConnectServer;
Handle g_Forward_OnSeasonRetrieved;
Handle g_Forward_SeasonTable_OnCreateTable;
Handle g_Forward_SeasonTable_OnResetData;
Handle g_Forward_OnSeasonalStatsReset;

/*-- Globals --*/
Database g_Database_Global;
Database g_Database_Server;

bool g_bFrsTags;
bool g_bFrsWeapons;
bool g_bFrsVIP;

char g_sCurrentMap[MAX_NAME_LENGTH];
bool g_bLate;
bool g_bBetweenRounds;
bool g_bRanked;
ArrayList g_WeaponsList;

float g_fStartTime;
int g_iCachedPlayers;
ArrayList g_MapCount;

StringMap g_RanksData;
ArrayList g_RanksList;
StringMap g_TiersData;
ArrayList g_TiersList;

bool g_bActiveSeason;
int g_iSeason;
int g_iNextSeason;
ArrayList g_Seasons;

int g_iCooldown[MAXPLAYERS + 1];
Handle g_hTimer_Playtime[MAXPLAYERS + 1];
Menu g_StatisticsMenu[MAXPLAYERS + 1];
bool g_bToggleStatistics[MAXPLAYERS + 1];
int g_iLocalKillstreak[MAXPLAYERS + 1];
bool g_bRampage[MAXPLAYERS + 1];

StringMap g_SessionCache;
ArrayList g_SessionIDs;

int g_LastKnownRank[MAXPLAYERS + 1];
float g_LastKnownPoints[MAXPLAYERS + 1];
bool g_bSpecHud[MAXPLAYERS + 1] =  { true, ... };
bool g_HudSkipClient[MAXPLAYERS + 1] =  { true, ... };
bool g_bCountFirstHit[MAXPLAYERS + 1];
Handle g_SpecTimer[MAXPLAYERS + 1];

int g_iTempVipIcons[] =  { 13465768, 23465768, 33465768, 43465768, 53465768, 63465768, 73465768, 83465768, 93465768, 103465768, 113465768, 123465768, 133465768 };
int g_iTempVipIconIdIndex;

int g_iCheckRankTries[MAXPLAYERS + 1];

//* Global Stats *//
int g_iStatistics_Global_Credits[MAXPLAYERS + 1];
int g_iStatistics_Global_CreditsEarned[MAXPLAYERS + 1];
float g_fStatistics_Global_CreditsTimer[MAXPLAYERS + 1];
int g_iStatistics_Global_Kills[MAXPLAYERS + 1];
int g_iStatistics_Global_Deaths[MAXPLAYERS + 1];
int g_iStatistics_Global_Assists[MAXPLAYERS + 1];
int g_iStatistics_Global_Headshots[MAXPLAYERS + 1];
float g_fStatistics_Global_Points[MAXPLAYERS + 1];
int g_iStatistics_Global_Longest_Killstreak[MAXPLAYERS + 1];
int g_iStatistics_Global_Hits[MAXPLAYERS + 1];
int g_iStatistics_Global_Shots[MAXPLAYERS + 1];
float g_fStatistics_Global_KDR[MAXPLAYERS + 1];
float g_fStatistics_Global_Accuracy[MAXPLAYERS + 1];
float g_fStatistics_Global_Playtime[MAXPLAYERS + 1];
int g_iStatistics_Global_FirstCreated[MAXPLAYERS + 1];

//* Seasonal Statistics *//
int g_iStatistics_Seasonal_Kills[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_Deaths[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_Assists[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_Headshots[MAXPLAYERS + 1];
float g_fStatistics_Seasonal_Points[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_Longest_Killstreak[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_Hits[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_Shots[MAXPLAYERS + 1];
float g_fStatistics_Seasonal_KDR[MAXPLAYERS + 1];
float g_fStatistics_Seasonal_Accuracy[MAXPLAYERS + 1];
float g_fStatistics_Seasonal_Playtime[MAXPLAYERS + 1];
JSON_Object g_hStatistics_Seasonal_WeaponsStatistics[MAXPLAYERS + 1];
int g_iStatistics_Seasonal_LastUpdated[MAXPLAYERS + 1];

//* Map Statistics *//
int g_iStatistics_Mapbased_Kills[MAXPLAYERS + 1];
int g_iStatistics_Mapbased_Deaths[MAXPLAYERS + 1];
int g_iStatistics_Mapbased_Assists[MAXPLAYERS + 1];
int g_iStatistics_Mapbased_Headshots[MAXPLAYERS + 1];
float g_fStatistics_Mapbased_Points[MAXPLAYERS + 1];
int g_iStatistics_Mapbased_Longest_Killstreak[MAXPLAYERS + 1];
int g_iStatistics_Mapbased_Hits[MAXPLAYERS + 1];
int g_iStatistics_Mapbased_Shots[MAXPLAYERS + 1];
float g_fStatistics_Mapbased_KDR[MAXPLAYERS + 1];
float g_fStatistics_Mapbased_Accuracy[MAXPLAYERS + 1];

//* Cached Data *//
int g_iCacheData_Rank[MAXPLAYERS + 1];
int g_iCacheData_Points[MAXPLAYERS + 1];
int g_iCacheData_Tier[MAXPLAYERS + 1];
float g_fCacheData_PointsGain[MAXPLAYERS + 1];
float g_fCacheData_PointsLoss[MAXPLAYERS + 1];
char g_sCacheData_TierTag[MAXPLAYERS + 1][512];
char g_sCacheData_SteamID2[MAXPLAYERS + 1][64];
char g_sCacheData_SteamID3[MAXPLAYERS + 1][64];
char g_sCacheData_SteamID64[MAXPLAYERS + 1][96];
int g_iCacheData_AccountID[MAXPLAYERS + 1];

//* Session Statistics *//
int g_iStatistics_Sessionbased_Kills[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_Deaths[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_Assists[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_Headshots[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_Hits[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_Shots[MAXPLAYERS + 1];
float g_fStatistics_Sessionbased_KDR[MAXPLAYERS + 1];
float g_fStatistics_Sessionbased_Accuracy[MAXPLAYERS + 1];
float g_fStatistics_Sessionbased_PointsGained[MAXPLAYERS + 1];
float g_fStatistics_Sessionbased_PointsLost[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_RanksGained[MAXPLAYERS + 1];
int g_iStatistics_Sessionbased_RanksLost[MAXPLAYERS + 1];

//
bool bStoppedTimer[MAXPLAYERS + 1];

int g_iAwaitingMessageOnAuthorized[MAXPLAYERS + 1];

Handle g_hSeasonChangeSocket;
Handle g_hSocketListeners[16];

enum struct WinPanel {
	int client;
	bool loaded;

	int kills;
	int assists;
	int position;
	float points;

	void Init(int client) {
		this.client = client;
		this.Clear();
	}

	void Clear() {
		this.loaded = false;
		this.kills = 0;
		this.assists = 0;
		this.position = 0;
		this.points = 0.0;
	}

	bool Snapshot() {
		if (this.loaded) {
			return false;
		}

		this.loaded = true;
		this.kills = g_iStatistics_Seasonal_Kills[this.client];
		this.assists = g_iStatistics_Seasonal_Assists[this.client];
		this.position = g_iCacheData_Rank[this.client];
		this.points = g_fStatistics_Seasonal_Points[this.client];

		return true;
	}

	void Delete() {
		this.client = 0;
		this.Clear();
	}
}

WinPanel g_WinPanel[MAXPLAYERS + 1];

int g_PersonalDataPublicLevelOffset = -1;

int g_iLoadedStats[MAXPLAYERS + 1];
int g_LoadingTrials[MAXPLAYERS + 1];
int g_IsDataLoaded[MAXPLAYERS + 1][4];
int g_HudColorTimes[MAXPLAYERS + 1];
int g_LastSpectated[MAXPLAYERS + 1];

/*-- Plugin Info --*/
public Plugin myinfo =
{
	name = "[Furious] Player Statistics",
	author = "Drixevel",
	description = "Player Statistics module for Furious Clan.",
	version = PLUGIN_VERSION,
	url = "http://furious-clan.com/"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("Furious_Tags_GetPrefixID");
	MarkNativeAsOptional("Furious_Tags_GetHudPrefix");
	MarkNativeAsOptional("Furious_Tags_GetHudPrefixColor");
	MarkNativeAsOptional("Furious_Tags_GetHudGroup");
	MarkNativeAsOptional("Furious_VIP_IsSpecListEnabled");

	RegPluginLibrary("furious_statistics");

	CreateNative("Furious_Statistics_GetTier", Native_Server_GetTier);
	CreateNative("Furious_Statistics_GetRank", Native_Server_GetRank);
	CreateNative("Furious_Statistics_GetTierUnique", Native_Server_GetTierUnique);
	CreateNative("Furious_Statistics_GetPoints", Native_Server_GetPoints);
	CreateNative("Furious_Statistics_GetTierTag", Native_Server_GetTierTag);
	CreateNative("Furious_Statistics_GetPlaytime", Native_Server_GetPlaytime);
	CreateNative("Furious_Statistics_SetSpecHud", Native_SetSpecHud);
	CreateNative("Furious_Statistics_AddCredits", Native_Statistics_AddCredits);
	CreateNative("Furious_Statistics_AddCreditsToAccount", Native_Statistics_AddCreditsToAccount);
	CreateNative("Furious_Statistics_GetCredits", Native_Statistics_GetCredits);
	CreateNative("Furious_Statistics_SetCredits", Native_Statistics_SetCredits);
	CreateNative("Furious_Statistics_GetCreditsEarned", Native_Statistics_GetCreditsEarned);
	CreateNative("Furious_Statistics_SetCreditsEarned", Native_Statistics_SetCreditsEarned);
	CreateNative("Furious_Statistics_GetCreditsTimer", Native_Statistics_GetCreditsTimer);
	CreateNative("Furious_Statistics_SetCreditsTimer", Native_Statistics_SetCreditsTimer);
	CreateNative("Furious_Statistics_AddSeasonalPoints", Native_Statistics_AddSeasonalPoints);
	CreateNative("Furious_Statistics_GetRankPointsGain", Native_Statistics_GetRankPointsGain);
	CreateNative("Furious_Statistics_IsRankedEnabled", Native_Statistics_IsRankedEnabled);
	CreateNative("Furious_Statistics_GetGlobalDatabase", Native_Statistics_GetGlobalDatabase);
	CreateNative("Furious_Statistics_GetServerDatabase", Native_Statistics_GetServerDatabase);
	CreateNative("Furious_Statistics_GetSeason", Native_Statistics_GetSeason);
	CreateNative("Furious_Statistics_IsSeasonActive", Native_Statistics_IsSeasonActive);

	g_Forward_OnGlobalsValidated = CreateGlobalForward("Furious_Statistics_OnGlobalValidated", ET_Ignore, Param_Cell, Param_Cell);
	g_Forward_OnSeasonChange = CreateGlobalForward("Furious_Statistics_OnSeasonChange", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	g_Forward_StatsMe_OnSeasonStats = CreateGlobalForward("Furious_Statistics_StatsMe_OnSeasonStats", ET_Event, Param_Cell, Param_String, Param_Cell, Param_CellByRef);
	g_Forward_OnConnectGlobal = CreateGlobalForward("Furious_Statistics_OnConnectGlobal", ET_Ignore);
	g_Forward_OnConnectServer = CreateGlobalForward("Furious_Statistics_OnConnectServer", ET_Ignore);
	g_Forward_OnSeasonRetrieved = CreateGlobalForward("Furious_Statistics_OnSeasonRetrieved", ET_Ignore, Param_Cell);
	g_Forward_SeasonTable_OnCreateTable = CreateGlobalForward("Furious_Statistics_SeasonTable_OnCreateTable", ET_Ignore, Param_String, Param_Cell, Param_CellByRef);
	g_Forward_SeasonTable_OnResetData = CreateGlobalForward("Furious_Statistics_SeasonTable_OnResetData", ET_Ignore, Param_Cell, Param_String, Param_Cell, Param_CellByRef);
	g_Forward_OnSeasonalStatsReset = CreateGlobalForward("Furious_Statistics_OnSeasonalStatsReset", ET_Ignore, Param_Cell);

	g_bLate = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("furious.phrases");

	AutoExecConfig_SetFile("frs.statistics");
	convar_Status = AutoExecConfig_CreateConVar("sm_furious_statistics_status", "1", "Status of the plugin.\n(1 = on, 0 = off)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Config_Ranks = AutoExecConfig_CreateConVar("sm_furious_statistics_config_ranks", "configs/furious/furious_ranks.cfg", "Name of the ranks config to use.", FCVAR_NOTIFY);
	convar_Config_Tiers = AutoExecConfig_CreateConVar("sm_furious_statistics_config_tiers", "configs/furious/furious_tiers.cfg", "Name of the tiers config to use.", FCVAR_NOTIFY);
	convar_Table_GlobalData = AutoExecConfig_CreateConVar("sm_furious_statistics_table_server_data", "furious_global_server_data", "Name of the database table to use in side the global database for server settings.", FCVAR_NOTIFY);
	convar_Table_GlobalStatistics = AutoExecConfig_CreateConVar("sm_furious_statistics_global_table", "furious_global_statistics", "Name of the global statistics table under the global database.", FCVAR_NOTIFY);
	convar_Table_GlobalMapStatistics = AutoExecConfig_CreateConVar("sm_furious_statistics_global_maps_table", "furious_global_map_statistics", "Name of the database table to save statistics to.", FCVAR_NOTIFY);
	convar_Table_ServerSeasons = AutoExecConfig_CreateConVar("sm_furious_statistics_table_season", "furious_server_season_", "Name of the seasons database table prefix to use. (Season is concatenate on the end)", FCVAR_NOTIFY);
	convar_Table_ServerMaps = AutoExecConfig_CreateConVar("sm_furious_statistics_table_map", "furious_server_maps_", "Name of the maps database table prefix to use. (Season is concatenate on the end)", FCVAR_NOTIFY);
	convar_Table_ServerSessions = AutoExecConfig_CreateConVar("sm_furious_statistics_table_sessions", "furious_server_sessions_", "Name of the sessions database table prefix to use. (Season is concatenate on the end)", FCVAR_NOTIFY);
	convar_RoundClampStatistics = AutoExecConfig_CreateConVar("sm_furious_statistics_round_clamp", "1", "ONLY gather statistics while rounds are active.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_MinimumPlayersStatistics = AutoExecConfig_CreateConVar("sm_furious_statistics_minimum_players", "1", "Required amount of players minimum for statistics to be recorded.", FCVAR_NOTIFY, true, 1.0);
	convar_NoBotsStatistics = AutoExecConfig_CreateConVar("sm_furious_statistics_nobots", "0", "If bots are allowed to affect stats for players or not.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Rampage_Overlay = AutoExecConfig_CreateConVar("sm_furious_statistics_rampage_overlay", "overlays/frs-rampage", "Overlay to show for rampage mode.", FCVAR_NOTIFY);
	convar_Rampage_Points = AutoExecConfig_CreateConVar("sm_furious_statistics_rampage_points", "1", "Extra points to give players during rampage mode.", FCVAR_NOTIFY, true, 0.0);
	convar_SaveOnRoundEnd = AutoExecConfig_CreateConVar("sm_furious_statistics_save_round_end", "1", "Save statistics on round end.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_SaveOnPlayerDeath = AutoExecConfig_CreateConVar("sm_furious_statistics_save_player_death", "1", "Save statistics on player death.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Sound_Rampage = AutoExecConfig_CreateConVar("sm_furious_statistics_rampage_sound", "buttons/light_power_on_switch_01.wav", "Sound to play in rampage mode.", FCVAR_NOTIFY);
	convar_Sound_Connect = AutoExecConfig_CreateConVar("sm_furious_statistics_sound_connect", "", "Sound to play on first time connect.", FCVAR_NOTIFY);
	convar_Sound_Reconnect = AutoExecConfig_CreateConVar("sm_furious_statistics_sound_reconnect", "", "Sound to play on reconnect.", FCVAR_NOTIFY);
	convar_Sound_RankEnabled = AutoExecConfig_CreateConVar("sm_furious_statistics_sound_ranking_enabled", "", "Sound to play on ranking enabled.", FCVAR_NOTIFY);
	convar_Sound_RankDisabled = AutoExecConfig_CreateConVar("sm_furious_statistics_sound_ranking_disabled", "", "Sound to play on ranking disabled.", FCVAR_NOTIFY);
	convar_RankEnabled_Status = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankenabled_status", "1", "Whether to show this hud sync or not.", FCVAR_NOTIFY);
	convar_RankEnabled_Channel = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankenabled_channel", "0", "Which channel to use.", FCVAR_NOTIFY, true, 0.0, true, 6.0);
	convar_RankEnabled_Coordinate_X = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankenabled_x", "-1.0", "X coordinate for this hud message.", FCVAR_NOTIFY);
	convar_RankEnabled_Coordinate_Y = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankenabled_y", "-1.0", "Y coordinate for this hud message.", FCVAR_NOTIFY);
	convar_RankEnabled_Color = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankenabled_color", "255 255 255", "Color for this hud message.", FCVAR_NOTIFY);
	convar_RankDisabled_Status = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankdisabled_status", "1", "Whether to show this hud sync or not.", FCVAR_NOTIFY);
	convar_RankDisabled_Channel = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankdisabled_channel", "0", "Which channel to use.", FCVAR_NOTIFY, true, 0.0, true, 6.0);
	convar_RankDisabled_Coordinate_X = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankdisabled_x", "-1.0", "X coordinate for this hud message.", FCVAR_NOTIFY);
	convar_RankDisabled_Coordinate_Y = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankdisabled_y", "-1.0", "Y coordinate for this hud message.", FCVAR_NOTIFY);
	convar_RankDisabled_Color = AutoExecConfig_CreateConVar("sm_furious_statistics_hud_rankdisabled_color", "255 255 255", "Color for this hud message.", FCVAR_NOTIFY);
	convar_ResetRankCredits = AutoExecConfig_CreateConVar("sm_furious_statistics_resetrank_credits", "1000", "Credits to deduct from clients that want to reset their rank.", FCVAR_NOTIFY, true, 0.0);
	convar_LosePointsOnSuicide = AutoExecConfig_CreateConVar("sm_furious_statistics_lose_points_on_suicide", "0", "Wether or not the player lose points from suicide/world damage", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_ConnectMessage = AutoExecConfig_CreateConVar("sm_furious_statistics_enable_connect_message", "1", "Toggle connect message", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_DisconnectMessage = AutoExecConfig_CreateConVar("sm_furious_statistics_enable_disconnect_message", "1", "Toggle disconnect message", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_SeasonChangeTime = AutoExecConfig_CreateConVar("sm_furious_statistics_season_change_time", "12", "On which hour of the day should season change?", FCVAR_NOTIFY, true, 0.0, true, 23.0);
	AutoExecConfig_ExecuteFile();

	convar_MinimumPlayersStatistics.AddChangeHook(ConVarChanged_MinimumPlayers);

	g_hSeasonChangeSocket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketBind(g_hSeasonChangeSocket, "0.0.0.0", 50000);
	SocketListen(g_hSeasonChangeSocket, OnSocketIncoming);

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("weapon_fire", OnWeaponFire);
	HookEvent("player_disconnect", OnPlayerDisconnect);
	HookEvent("round_freeze_end", OnRoundFreezeEnd);
	HookEvent("round_start", OnRoundStart);
	HookEvent("round_end", OnRoundEnd);
	HookEvent("cs_win_panel_match", OnMatchEnd);
	HookEvent("cs_win_panel_round", OnWinPanel);

	RegConsoleCmd("sm_statsme", Command_OpenStatisticsMenu, "Opens the statistics menu.");
	RegConsoleCmd("sm_stats", Command_OpenStatisticsMenu, "Opens the statistics menu.");
	RegConsoleCmd("sm_session", Command_OpenStatisticsMenu, "Opens the sessions menu.");
	RegConsoleCmd("sm_top", Command_OpenTopRanksMenu, "Opens top ranks menu.");
	RegConsoleCmd("sm_timeplayed", Command_TimePlayed, "Displays how much time you've spent on the server.");
	RegConsoleCmd("sm_played", Command_TimePlayed, "Displays how much time you've spent on the server.");
	RegConsoleCmd("sm_playtime", Command_TimePlayed, "Displays how much time you've spent on the server.");
	RegConsoleCmd("sm_weaponme", Command_OpenWeaponsMenu, "Opens weapons menu.");
	RegConsoleCmd("sm_spec", Command_SwitchToSpectate, "Puts you into spectator.");
	RegConsoleCmd("sm_spectate", Command_SwitchToSpectate, "Puts you into spectator.");
	RegConsoleCmd("sm_afk", Command_SwitchToSpectate, "Puts you into spectator.");
	RegConsoleCmd("sm_brb", Command_SwitchToSpectate, "Puts you into spectator.");
	RegConsoleCmd("sm_place", Command_PrintRankInfo, "Prints rank information to all for a player.");
	RegConsoleCmd("sm_rank", Command_PrintRankInfo, "Prints rank information to yourself for a player.");
	RegConsoleCmd("sm_next", Command_Next, "Shows the top 10 clients above your rank.");
	RegConsoleCmd("sm_tiers", Command_PrintTiers, "Print the list of tiers in chat.");
	RegConsoleCmd("sm_ranks", Command_PrintTiers, "Print the list of tiers in chat.");
	RegConsoleCmd("sm_status", Command_Status, "Displays the amount of players in the database.");
	RegConsoleCmd("sm_resetrank", Command_ResetRank, "Reset your seasonal rank on this server.");
	RegConsoleCmd("sm_resetmyrank", Command_ResetRank, "Reset your seasonal rank on this server.");
	RegConsoleCmd("sm_season", Command_Season, "Displays the current season and the next season in chat.");
	RegConsoleCmd("sm_toptime", Command_TopTime, "Displays the 10 most active players.");

	RegConsoleCmd("sm_ctop", Command_TopCountries, "Displays the best countries by players with the most points.");
	RegConsoleCmd("sm_countrytop", Command_TopCountries, "Displays the best countries by players with the most points.");
	RegConsoleCmd("sm_topcountry", Command_TopCountries, "Displays the best countries by players with the most points.");

	RegConsoleCmd("sm_crank", Command_CountryRank, "Display your current rank for your country.");
	RegConsoleCmd("sm_countryrank", Command_CountryRank, "Display your current rank for your country.");
	RegConsoleCmd("sm_rankcountry", Command_CountryRank, "Display your current rank for your country.");

	RegAdminCmd("sm_playtimedebug", Command_PlaytimeDebug, ADMFLAG_ROOT, "Debugger for testing client playtime.");
	RegAdminCmd("sm_savestats", Command_SaveStats, ADMFLAG_ROOT, "Save your own statistics manually.");
	RegAdminCmd("sm_toggleranked", Command_ToggleRanked, ADMFLAG_ROOT, "Toggle on/off the statistics tracking.");
	RegAdminCmd("sm_overlays", Command_TestOverlays, ADMFLAG_ROOT, "Test and debug overlays in the plugin.");
	RegAdminCmd("sm_testoverlays", Command_TestOverlays, ADMFLAG_ROOT, "Test and debug overlays in the plugin.");
	RegAdminCmd("sm_reloadranks", Command_ReloadRanks, ADMFLAG_ROOT, "Reloads ranks data.");
	RegAdminCmd("sm_reloadtiers", Command_ReloadTiers, ADMFLAG_ROOT, "Reloads tiers data.");
	RegAdminCmd("sm_testspechud", Command_TestSpecHud, ADMFLAG_ROOT, "Test the spectator hud.");
	RegAdminCmd("sm_testsocket", Command_TestSocket, ADMFLAG_ROOT, "Test socket");
	RegAdminCmd("sm_testwinpanel", Command_TestWinPanel, ADMFLAG_ROOT, "Test Win Panel");

	g_WeaponsList = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));

	g_RanksData = new StringMap();
	g_RanksList = new ArrayList();
	g_TiersData = new StringMap();
	g_TiersList = new ArrayList();

	g_MapCount = new ArrayList();

	g_SessionCache = new StringMap();
	g_SessionIDs = new ArrayList();

	g_Seasons = new ArrayList(ByteCountToCells(64));
	g_Seasons.PushString("12-01");
	g_Seasons.PushString("03-01");
	g_Seasons.PushString("06-01");
	g_Seasons.PushString("09-01");

	TriggerTimer(CreateTimer(120.0, Timer_DisplayNextSeason, _, TIMER_REPEAT), true);
	TriggerTimer(CreateTimer(0.1, Timer_VipScoreboardIcon, _, TIMER_REPEAT), true);

	AutoExecConfig_CleanFile();

	g_PersonalDataPublicLevelOffset = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");

	for(int i = 1; i <= MaxClients; i++) {
		if (IsClientConnected(i)) {
			OnClientConnected(i);
		}

		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnAllPluginsLoaded()
{
	g_bFrsTags = LibraryExists("furious_tags");
	g_bFrsWeapons = LibraryExists("furious_weapons");
	g_bFrsVIP = LibraryExists("furious_vip");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "furious_tags"))
		g_bFrsTags = true;
	else if (StrEqual(name, "furious_weapons"))
		g_bFrsWeapons = true;
	else if (StrEqual(name, "furious_vip"))
		g_bFrsVIP = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "furious_tags"))
		g_bFrsTags = false;
	else if (StrEqual(name, "furious_weapons"))
		g_bFrsWeapons = false;
	else if (StrEqual(name, "furious_vip"))
		g_bFrsVIP = false;
}

public Action Timer_DisplayNextSeason(Handle timer)
{
	if (!convar_Status.BoolValue)
		return Plugin_Continue;

	char sTime[128];
	FormatTime(sTime, sizeof(sTime), "%A, %B %d, %Y at %R", g_iNextSeason);

	CPrintToChatAll("%t", "next season timer print", sTime);

	return Plugin_Continue;
}

public Action Timer_VipScoreboardIcon(Handle timer)
{
	if (++g_iTempVipIconIdIndex == sizeof(g_iTempVipIcons))
		g_iTempVipIconIdIndex = 0;
	
	return Plugin_Continue;
}

public void ConVarChanged_MinimumPlayers(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StrEqual(oldValue, newValue))
		return;

	ValidateRankCheck();
}

public void OnMapEnd()
{
	if (!convar_Status.BoolValue)
		return;

	char sQuery[MAX_QUERY_SIZE];
	char sTable[MAX_TABLE_SIZE];

	convar_Table_GlobalMapStatistics.GetString(sTable, sizeof(sTable));

	float fTime = GetEngineTime();
	fTime -= g_fStartTime;

	if (g_Database_Global != null)
	{
		g_Database_Global.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `map_playtime` = `map_playtime` + '%f', `last_updated` = '%i' WHERE `map` = '%s';", sTable, fTime, GetTime(), g_sCurrentMap);
		g_Database_Global.Query(OnUpdateMapData, sQuery);
	}

	g_fStartTime = 0.0;

	Transaction trans = new Transaction();

	if (g_MapCount.Length > 0)
	{
		GetTableString_Maps(sTable, sizeof(sTable));

		for (int i = 0; i < g_MapCount.Length; i++)
		{
			g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `playcount` = `playcount` + 1 WHERE `accountid` = '%i' AND `map` = '%s';", sTable, g_MapCount.Get(i), g_sCurrentMap);
			trans.AddQuery(sQuery);
		}

		g_MapCount.Clear();
	}

	if (g_SessionIDs.Length > 0)
	{
		GetTableString_Sessions(sTable, sizeof(sTable));

		int iAccountID, iLocalRanksGained, iLocalRanksLost;
		float fLocalPointsGained, fLocalPointsLost;
		char sAccountID[64], sName[MAX_NAME_LENGTH], sSteamID2[64], sSteamID3[64], sSteamID64[64];
		StringMap trie;

		for (int i = 0; i < g_SessionIDs.Length; i++)
		{
			iAccountID = g_SessionIDs.Get(i);

			IntToString(iAccountID, sAccountID, sizeof(sAccountID));

			if (g_SessionCache.GetValue(sAccountID, trie) && trie != null)
			{
				trie.GetString("Name", sName, sizeof(sName));
				trie.GetString("SteamID2", sSteamID2, sizeof(sSteamID2));
				trie.GetString("SteamID3", sSteamID3, sizeof(sSteamID3));
				trie.GetString("SteamID64", sSteamID64, sizeof(sSteamID64));
				trie.GetValue("RanksGained", iLocalRanksGained);
				trie.GetValue("RanksLost", iLocalRanksLost);
				trie.GetValue("PointsGained", fLocalPointsGained);
				trie.GetValue("PointsLost", fLocalPointsLost);

				g_Database_Server.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `ranks_gained`, `ranks_lost`, `points_gained`, `points_lost`, `map`, `first_created`) VALUES ('%s', '%i', '%s', '%s', '%s', '%i', '%i', '%f', '%f', '%s', '%i');", sTable, sName, iAccountID, sSteamID2, sSteamID3, sSteamID64, iLocalRanksGained, iLocalRanksLost, fLocalPointsGained, fLocalPointsLost, g_sCurrentMap, GetTime());
				trans.AddQuery(sQuery);

				delete trie;
				g_SessionCache.Remove(sAccountID);
			}
		}

		g_SessionCache.Clear();
		g_SessionIDs.Clear();
	}

	g_Database_Server.Execute(trans, onSuccess_Sessions, onError_Sessions);

	for (int i = 1; i <= MaxClients; i++) {
		g_WinPanel[i].loaded = false;
	}
}

public void OnUpdateMapData(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while updating map data: %s", error);
}

public void onSuccess_Sessions(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	LogMessage("Sessions data has been uploaded.");
}

public void onError_Sessions(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	ThrowError("Error saving sessions data at query %i: %s", failIndex, error);
}

public void OnMapStart()
{
	GetCurrentMap(g_sCurrentMap, sizeof(g_sCurrentMap));

	char sBuffer[PLATFORM_MAX_PATH];

	PrecacheSoundF(sBuffer, sizeof(sBuffer), convar_Sound_Rampage);
	PrecacheSoundF(sBuffer, sizeof(sBuffer), convar_Sound_Connect);
	PrecacheSoundF(sBuffer, sizeof(sBuffer), convar_Sound_Reconnect);
	PrecacheSoundF(sBuffer, sizeof(sBuffer), convar_Sound_RankEnabled);
	PrecacheSoundF(sBuffer, sizeof(sBuffer), convar_Sound_RankDisabled);

	ParseMapData();
	ParseWeaponsList();
	ParseRanksConfig();
	ParseTiersConfig();

	int resourceEnt = GetPlayerResourceEntity();

	if (resourceEnt != -1)
	{
		SDKHook(resourceEnt, SDKHook_ThinkPost, OnClientResourceEntityPostThink);
	}
}

void ParseMapData()
{
	g_fStartTime = GetEngineTime();

	if (g_Database_Global != null)
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_GlobalMapStatistics.GetString(sTable, sizeof(sTable));

		int time = GetTime();

		char sQuery[MAX_QUERY_SIZE];
		g_Database_Global.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`map`, `map_loads`, `first_created`, `last_updated`) VALUES ('%s', '1', '%i', '%i') ON DUPLICATE KEY UPDATE `map_loads` = `map_loads` + '1', `last_updated` = '%i';", sTable, g_sCurrentMap, time, time, time);
		g_Database_Global.Query(TQuery_InsertNewMap, sQuery);
	}
}

public void TQuery_InsertNewMap(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while updating map: %s", error);
}

public void OnConfigsExecuted()
{
	if (!convar_Status.BoolValue)
		return;

	if (g_Database_Global == null)
		Database.Connect(OnSQLConnect_Global, "furious_global");
	else
		SeasonCheck();

	if (g_Database_Server == null)
		Database.Connect(OnSQLConnect_Server, "furious_server");

	if (g_bLate)
		ValidateRankCheck();
}

public void OnSQLConnect_Global(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error connecting to the global database: %s", error);

	if (g_Database_Global != null)
	{
		delete db;
		return;
	}

	g_Database_Global = db;
	LogMessage("Connected to global database successfully.");

	Call_StartForward(g_Forward_OnConnectGlobal);
	Call_Finish();

	g_Database_Global.SetCharset("utf8mb4");

	char sQuery[MAX_QUERY_SIZE];
	char sTable[MAX_TABLE_SIZE];

	//Create the database tables inside of global.
	convar_Table_GlobalData.GetString(sTable, sizeof(sTable));
	g_Database_Global.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int UNSIGNED NOT NULL AUTO_INCREMENT, `hostname` varchar(128) NOT NULL DEFAULT '', `ip` varchar(64) NOT NULL DEFAULT '', `season_number` int UNSIGNED NOT NULL DEFAULT 0, `next_season` int UNSIGNED NOT NULL DEFAULT 0, `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `ip` (`ip`)) ENGINE=InnoDB;", sTable);
	g_Database_Global.Query(OnCreateTable, sQuery, DBPrio_Low);

	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));
	g_Database_Global.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int UNSIGNED NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '', `accountid` int UNSIGNED NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `ip` varchar(64) NOT NULL DEFAULT '', `country` varchar(64) NOT NULL DEFAULT '', `clan_tag` varchar(32) NOT NULL DEFAULT '', `clan_name` varchar(32) NOT NULL DEFAULT '', `credits` int UNSIGNED NOT NULL DEFAULT 0, `credits_earned` int UNSIGNED NOT NULL DEFAULT 0, `credits_timer` float NOT NULL DEFAULT 0.0 , `kills` int UNSIGNED NOT NULL DEFAULT 0, `deaths` int UNSIGNED NOT NULL DEFAULT 0, `assists` int UNSIGNED NOT NULL DEFAULT 0, `headshots` int UNSIGNED NOT NULL DEFAULT 0, `points` float NOT NULL DEFAULT 0.0, `longest_killstreak` int UNSIGNED NOT NULL DEFAULT 0, `hits` int UNSIGNED NOT NULL DEFAULT 0, `shots` int UNSIGNED NOT NULL DEFAULT 0, `kdr` float NOT NULL DEFAULT 0.0, `accuracy` float NOT NULL DEFAULT 0.0, `playtime` float NOT NULL DEFAULT 0.0, `converted` int UNSIGNED NOT NULL DEFAULT 0, `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `joined_times` int(12) NOT NULL DEFAULT 0, PRIMARY KEY (`id`), UNIQUE KEY `steamid2` (`steamid2`)) ENGINE=InnoDB;", sTable);
	g_Database_Global.Query(OnCreateTable, sQuery, DBPrio_Low);
	
	convar_Table_GlobalMapStatistics.GetString(sTable, sizeof(sTable));
	g_Database_Global.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` ( `id` int UNSIGNED NOT NULL AUTO_INCREMENT, `map` varchar(32) NOT NULL DEFAULT '', `map_loads` int UNSIGNED NOT NULL DEFAULT 0, `map_playtime` float NOT NULL DEFAULT 0.0, `first_created` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, `last_updated` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP, PRIMARY KEY (`id`), UNIQUE KEY `map` (`map`)) ENGINE=InnoDB;", sTable);
	g_Database_Global.Query(OnCreateTable, sQuery, DBPrio_Low);

	//Insert the server into the servers table.
	convar_Table_GlobalData.GetString(sTable, sizeof(sTable));

	char sHostname[MAX_NAME_LENGTH];
	FindConVar("hostname").GetString(sHostname, sizeof(sHostname));

	char sIP[64];
	GetServerIP(sIP, sizeof(sIP), true);

	char sCurrent[64];
	FormatTime(sCurrent, sizeof(sCurrent), "%m-%d");

	int iTime = GetTime();

	g_Database_Global.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`hostname`, `ip`, `first_created`, `last_updated`) VALUES ('%s', '%s', '%i', '%i') ON DUPLICATE KEY UPDATE `hostname` = '%s';", sTable, sHostname, sIP, iTime, iTime, sHostname);
	g_Database_Global.Query(TQuery_OnUpdateServerSettings, sQuery);

	//Check for the season after we have valid SQL queries.
	SeasonCheck();
}

public void OnCreateTable(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while creating table: %s", error);
	}
}

public void OnSQLConnect_Server(Database db, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error connecting to the server database: %s", error);

	if (g_Database_Server != null)
	{
		delete db;
		return;
	}

	g_Database_Server = db;
	LogMessage("Connected to server database successfully.");

	Call_StartForward(g_Forward_OnConnectServer);
	Call_Finish();

	g_Database_Server.SetCharset("utf8mb4");
}

bool ParseWeaponsList()
{
	char sPath[PLATFORM_MAX_PATH];
	FormatEx(sPath, sizeof(sPath), "scripts/items/items_game.txt");

	KeyValues kv = new KeyValues("items_game");

	if (kv.ImportFromFile(sPath) && kv.JumpToKey("items") && kv.GotoFirstSubKey())
	{
		g_WeaponsList.Clear();

		char sWeapon[MAX_NAME_LENGTH];
		do
		{
			kv.GetString("name", sWeapon, sizeof(sWeapon));

			if (StrContains(sWeapon, "weapon_") == 0 && g_WeaponsList.FindString(sWeapon) == -1)
				g_WeaponsList.PushString(sWeapon);
		}
		while (kv.GotoNextKey());
	}
	else
	{
		LogError("Error parsing items list from items_game.txt.");
		delete kv;
		return false;
	}

	delete kv;
	LogMessage("Successfully parsed items_game.txt for %i weapons.", g_WeaponsList.Length);
	return true;
}

public void TQuery_OnUpdateServerSettings(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error saving server settings to database: %s", error);
}

public void Transaction_OnCreateTables_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	g_bActiveSeason = true;

	if (g_bLate)
	{
		char auth[64];
		for (int i = 1; i <= MaxClients; i++)
		if (IsClientConnected(i) && GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth)))
			OnClientAuthorized(i, auth);

		g_bLate = false;
	}
}

public void Transaction_OnCreateTables_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	g_bActiveSeason = false;
	ThrowError("Error loading current season '%i': [%i] %s", g_iSeason, failIndex, error);
}

public void OnClientPostAdminCheck(int client)
{
	if (convar_ConnectMessage.BoolValue && g_Database_Server != null)
	{
		if (!g_IsDataLoaded[client][DATA_SEASONAL2])
		{
			CreateTimer(1.0, Timer_RecheckRank, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
			return;
		}
		PerformJoinMessage(client);
	}

	if (g_iAwaitingMessageOnAuthorized[client] == MESSAGE_WELCOME)
	{
		CreateTimer(2.0, Timer_DelayWelcome, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (g_iAwaitingMessageOnAuthorized[client] == MESSAGE_WELCOMEBACK)
	{
		CreateTimer(2.0, Timer_DelayWelcomeBack, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_RecheckRank(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (!client || IsFakeClient(client))
		return Plugin_Stop;

	if (++g_iCheckRankTries[client] == 5)
	{
		g_iCheckRankTries[client] = 0;
		return Plugin_Stop;
	}

	if (!g_IsDataLoaded[client][DATA_SEASONAL2])
		return Plugin_Continue;

	PerformJoinMessage(client);
	return Plugin_Stop;
}

public void TQuery_CheckTopTen2(Database db, DBResultSet results, const char[] error, any serial)
{
	int client = GetClientFromSerial(serial);

	if (client == 0)
		return;

	char sStar[48];
	if (GetUserFlagBits(client))
	{
		int index = Furious_Tags_GetPrefixID(client);
		char sPrefix[32], sColor[16];
		Furious_Tags_GetPrefix(index, sPrefix, sizeof(sPrefix));
		Furious_Tags_GetPrefixColor(index, sColor, sizeof(sColor));
		Format(sStar, sizeof(sStar), "%s%s", sColor, sPrefix);
	}

	while (results.FetchRow())
	{
		char sSteam64[2][32];
		results.FetchString(0, sSteam64[0], sizeof(sSteam64[]));

		GetClientAuthId(client, AuthId_SteamID64, sSteam64[1], sizeof(sSteam64[]));

		if (StrEqual(sSteam64[0], sSteam64[1]))
		{
			CPrintToChatAll("%t", "join message top 10", sStar, client, g_iCacheData_Rank[client], g_iCacheData_Points[client], g_iCacheData_Rank[client]);
			return;
		}
	}

	CPrintToChatAll("%t", "join message", sStar, client, g_iCacheData_Rank[client], g_iCacheData_Points[client]);
}

public void OnClientConnected(int client)
{
	if (!convar_Status.BoolValue || IsFakeClient(client))
		return;

	g_iLocalKillstreak[client] = 0;
	g_bToggleStatistics[client] = false;
	g_bRampage[client] = false;

	g_iLoadedStats[client] = 0;
	g_LoadingTrials[client] = 0;

	g_IsDataLoaded[client][DATA_GLOBAL] = false;
	g_IsDataLoaded[client][DATA_SEASONAL] = false;
	g_IsDataLoaded[client][DATA_SEASONAL2] = false;
	g_IsDataLoaded[client][DATA_MAPBASED] = false;

	g_HudColorTimes[client] = 0;
	g_LastSpectated[client] = 0;

	g_bSpecHud[client] = true;

	g_iStatistics_Global_Credits[client] = 0;
	g_iStatistics_Global_CreditsEarned[client] = 0;
	g_fStatistics_Global_CreditsTimer[client] = 0.0;
	g_iStatistics_Global_Kills[client] = 0;
	g_iStatistics_Global_Deaths[client] = 0;
	g_iStatistics_Global_Assists[client] = 0;
	g_iStatistics_Global_Headshots[client] = 0;
	g_fStatistics_Global_Points[client] = 0.0;
	g_iStatistics_Global_Longest_Killstreak[client] = 0;
	g_iStatistics_Global_Hits[client] = 0;
	g_iStatistics_Global_Shots[client] = 0;
	g_fStatistics_Global_KDR[client] = 0.0;
	g_fStatistics_Global_Accuracy[client] = 0.0;
	g_fStatistics_Global_Playtime[client] = 0.0;
	g_iStatistics_Global_FirstCreated[client] = 0;

	g_iStatistics_Seasonal_Kills[client] = 0;
	g_iStatistics_Seasonal_Deaths[client] = 0;
	g_iStatistics_Seasonal_Assists[client] = 0;
	g_iStatistics_Seasonal_Headshots[client] = 0;
	g_fStatistics_Seasonal_Points[client] = 0.0;
	g_iStatistics_Seasonal_Longest_Killstreak[client] = 0;
	g_iStatistics_Seasonal_Hits[client] = 0;
	g_iStatistics_Seasonal_Shots[client] = 0;
	g_fStatistics_Seasonal_KDR[client] = 0.0;
	g_fStatistics_Seasonal_Accuracy[client] = 0.0;
	g_fStatistics_Seasonal_Playtime[client] = 0.0;
	g_iStatistics_Seasonal_LastUpdated[client] = 0;

	g_iStatistics_Mapbased_Kills[client] = 0;
	g_iStatistics_Mapbased_Deaths[client] = 0;
	g_iStatistics_Mapbased_Assists[client] = 0;
	g_iStatistics_Mapbased_Headshots[client] = 0;
	g_fStatistics_Mapbased_Points[client] = 0.0;
	g_iStatistics_Mapbased_Longest_Killstreak[client] = 0;
	g_iStatistics_Mapbased_Hits[client] = 0;
	g_iStatistics_Mapbased_Shots[client] = 0;
	g_fStatistics_Mapbased_KDR[client] = 0.0;
	g_fStatistics_Mapbased_Accuracy[client] = 0.0;

	g_iCacheData_Points[client] = 0;
	g_iCacheData_Rank[client] = 0;
	g_iCacheData_Tier[client] = 0;
	g_fCacheData_PointsGain[client] = 0.0;
	g_fCacheData_PointsLoss[client] = 0.0;
	g_sCacheData_TierTag[client][0] = '\0';

	g_iStatistics_Sessionbased_Kills[client] = 0;
	g_iStatistics_Sessionbased_Deaths[client] = 0;
	g_iStatistics_Sessionbased_Assists[client] = 0;
	g_iStatistics_Sessionbased_Headshots[client] = 0;
	g_iStatistics_Sessionbased_Hits[client] = 0;
	g_iStatistics_Sessionbased_Shots[client] = 0;
	g_fStatistics_Sessionbased_KDR[client] = 0.0;
	g_fStatistics_Sessionbased_Accuracy[client] = 0.0;
	g_fStatistics_Sessionbased_PointsGained[client] = 0.0;
	g_fStatistics_Sessionbased_PointsLost[client] = 0.0;
	g_iStatistics_Sessionbased_RanksGained[client] = 0;
	g_iStatistics_Sessionbased_RanksLost[client] = 0;

	g_iCheckRankTries[client] = 0;

	g_iAwaitingMessageOnAuthorized[client] = 0;

	g_hStatistics_Seasonal_WeaponsStatistics[client] = new JSON_Object();

	g_WinPanel[client].Init(client);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!convar_Status.BoolValue || IsFakeClient(client))
		return;

	int iAccountID = g_iCacheData_AccountID[client] = GetSteamAccountID(client);

	char sAccountID[64];
	IntToString(iAccountID, sAccountID, sizeof(sAccountID));

	StringMap trie;
	if (g_SessionCache.GetValue(sAccountID, trie) && trie != null)
	{
		trie.GetValue("Kills", g_iStatistics_Sessionbased_Kills[client]);
		trie.GetValue("Deaths", g_iStatistics_Sessionbased_Deaths[client]);
		trie.GetValue("Assists", g_iStatistics_Sessionbased_Assists[client]);
		trie.GetValue("Headshots", g_iStatistics_Sessionbased_Headshots[client]);
		trie.GetValue("Hits", g_iStatistics_Sessionbased_Hits[client]);
		trie.GetValue("Shots", g_iStatistics_Sessionbased_Shots[client]);
		trie.GetValue("KDR", g_fStatistics_Sessionbased_KDR[client]);
		trie.GetValue("Accuracy", g_fStatistics_Sessionbased_Accuracy[client]);
		trie.GetValue("PointsGained", g_fStatistics_Sessionbased_PointsGained[client]);
		trie.GetValue("PointsLost", g_fStatistics_Sessionbased_PointsLost[client]);
		trie.GetValue("RanksGained", g_iStatistics_Sessionbased_RanksGained[client]);
		trie.GetValue("RanksLost", g_iStatistics_Sessionbased_RanksLost[client]);

		delete trie;
		g_SessionCache.Remove(sAccountID);

		int index = g_SessionIDs.FindValue(iAccountID);
		g_SessionIDs.Erase(index);
	}

	g_MapCount.Push(iAccountID);

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

	int serial = GetClientSerial(client);
	CreateTimer(2.5 + 0.025 * float(client), Timer_CheckLoading, serial, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

	StopTimer(g_SpecTimer[client]);
	g_SpecTimer[client] = CreateTimer(0.1, Timer_DisplaySpectatorHud, serial, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamageAlivePost, Player_OnTakeDamageAlivePost);
}

public Action Timer_CheckLoading(Handle timer, any serial)
{
	int client;

	if ((client = GetClientFromSerial(serial)) == 0)
		return Plugin_Stop;

	if (g_iLoadedStats[client] >= 4)
		return Plugin_Stop;

	g_LoadingTrials[client]++;

	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	LogMessage("Loading failed for %s after %i trial(s), retrying again....", name, g_LoadingTrials[client]);

	SyncClientStatistics(client);
	return Plugin_Continue;
}

void SyncClientStatistics(int client)
{
	char sTable[MAX_TABLE_SIZE];
	char sQuery[MAX_QUERY_SIZE];

	int serial = GetClientSerial(client);

	if (g_Database_Global != null && !g_IsDataLoaded[client][DATA_GLOBAL])
	{
		convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

		g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT `credits`, `credits_earned`, `credits_timer`, `kills`, `deaths`, `assists`, `headshots`, `points`, `longest_killstreak`, `hits`, `shots`, `kdr`, `accuracy`, `playtime`, `first_created`, `joined_times` FROM `%s` WHERE `steamid2` = '%s';", sTable, g_sCacheData_SteamID2[client]);
		g_Database_Global.Query(TQuery_PullClientGlobalData, sQuery, serial);
	}
	else if (g_Database_Server != null && g_bActiveSeason)
	{
		if (!g_IsDataLoaded[client][DATA_SEASONAL])
		{
			GetTableString_Season(sTable, sizeof(sTable));

			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `kills`, `deaths`, `assists`, `headshots`, `points`, `longest_killstreak`, `hits`, `shots`, `kdr`, `accuracy`, `playtime`, `weapons_statistics`, `last_updated` FROM `%s` WHERE `accountid` = '%i';", sTable, g_iCacheData_AccountID[client]);
			g_Database_Server.Query(TQuery_PullClientSeasonData, sQuery, serial);
		}
		else if (!g_IsDataLoaded[client][DATA_SEASONAL2])
		{
			GetTableString_Season(sTable, sizeof(sTable));

			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT s.points, (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank, (SELECT COUNT(*) as total FROM `%s`) as total FROM `%s` as s WHERE s.accountid = '%i';", sTable, sTable, sTable, g_iCacheData_AccountID[client]);
			g_Database_Server.Query(TQuery_PullClientSeasonData2, sQuery, serial);
		}
		else if (!g_IsDataLoaded[client][DATA_MAPBASED])
		{
			GetTableString_Maps(sTable, sizeof(sTable));

			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `kills`, `deaths`, `assists`, headshots, points, longest_killstreak, hits, shots, kdr, accuracy, playtime FROM `%s` WHERE accountid = '%i' AND map = '%s';", sTable, g_iCacheData_AccountID[client], g_sCurrentMap);
			g_Database_Server.Query(TQuery_PullClientMapBasedData, sQuery, serial);
		}
	}
}

public void TQuery_PullClientGlobalData(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error pulling client global statistics: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	if (results.FetchRow())
	{
		g_iStatistics_Global_Credits[client] = results.FetchInt(0);
		g_iStatistics_Global_CreditsEarned[client] = results.FetchInt(1);
		g_fStatistics_Global_CreditsTimer[client] = results.FetchFloat(2);
		g_iStatistics_Global_Kills[client] = results.FetchInt(3);
		g_iStatistics_Global_Deaths[client] = results.FetchInt(4);
		g_iStatistics_Global_Assists[client] = results.FetchInt(5);
		g_iStatistics_Global_Headshots[client] = results.FetchInt(6);
		g_fStatistics_Global_Points[client] = results.FetchFloat(7);
		g_iStatistics_Global_Longest_Killstreak[client] = results.FetchInt(8);
		g_iStatistics_Global_Hits[client] = results.FetchInt(9);
		g_iStatistics_Global_Shots[client] = results.FetchInt(10);
		g_fStatistics_Global_KDR[client] = results.FetchFloat(11);
		g_fStatistics_Global_Accuracy[client] = results.FetchFloat(12);
		g_fStatistics_Global_Playtime[client] = results.FetchFloat(13);
		g_iStatistics_Global_FirstCreated[client] = results.FetchInt(14);

		if (results.FetchInt(15) == 0)
		{
			Call_StartForward(g_Forward_OnGlobalsValidated);
			Call_PushCell(client);
			Call_PushCell(true);
			Call_Finish();

			g_iAwaitingMessageOnAuthorized[client] = MESSAGE_WELCOME;
		}
		else
		{
			Call_StartForward(g_Forward_OnGlobalsValidated);
			Call_PushCell(client);
			Call_PushCell(false);
			Call_Finish();

			g_iAwaitingMessageOnAuthorized[client] = MESSAGE_WELCOMEBACK;
		}

		g_IsDataLoaded[client][DATA_GLOBAL] = true;
		g_iLoadedStats[client]++;
		
		if (IsClientInGame(client) && IsPlayerAlive(client)) {
			g_WinPanel[client].Snapshot();
		}
	}
	else
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		LogMessage("%s - cannot fetch global statistics.", name);
	}

	ValidateClientGlobalData(client);
}

void ValidateClientGlobalData(int client)
{
	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sName[MAX_NAME_LENGTH], sEscapedName[1 + MAX_NAME_LENGTH * 2];
	GetClientName(client, sName, sizeof(sName));
	g_Database_Global.Escape(sName, sEscapedName, sizeof(sEscapedName));

	char sIP[64];
	GetClientIP(client, sIP, sizeof(sIP));

	int iTime = GetTime();

	char sCountry[64];
	GeoipCountry(sIP, sCountry, sizeof(sCountry));

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `ip`, `country`, `clan_tag`, `clan_name`, `credits`, `first_created`, `last_updated`) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%s', '', '', '0', '%i', '%i') ON DUPLICATE KEY UPDATE `name` = '%s', `accountid` = '%i', `steamid3` = '%s', `steamid64` = '%s', `ip` = '%s', `country` = '%s', `last_updated` = '%i', `joined_times` = `joined_times` + 1;", sTable, sEscapedName, g_iCacheData_AccountID[client], g_sCacheData_SteamID2[client], g_sCacheData_SteamID3[client], g_sCacheData_SteamID64[client], sIP, sCountry, iTime, iTime, sEscapedName, g_iCacheData_AccountID[client], g_sCacheData_SteamID3[client], g_sCacheData_SteamID64[client], sIP, sCountry, iTime);
	g_Database_Global.Query(TQuery_OnGlobalUpdate, sQuery, GetClientSerial(client));
}

public void TQuery_OnGlobalUpdate(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error on updating client global data or creating it: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
	{
		return;
	}

	if (results.AffectedRows == 1)
	{
		int time = GetTime();
		g_iStatistics_Global_FirstCreated[client] = time;
	}

	if (g_Database_Server != null && g_bActiveSeason)
	{
		if (!g_IsDataLoaded[client][DATA_SEASONAL])
		{
			char sTable[MAX_TABLE_SIZE];
			GetTableString_Season(sTable, sizeof(sTable));

			char sQuery[MAX_QUERY_SIZE];
			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `kills`, `deaths`, `assists`, `headshots`, `points`, `longest_killstreak`, `hits`, `shots`, `kdr`, `accuracy`, `playtime`, `weapons_statistics`, `last_updated` FROM `%s` WHERE `accountid` = '%i';", sTable, g_iCacheData_AccountID[client]);
			g_Database_Server.Query(TQuery_PullClientSeasonData, sQuery, data);
		}
		else if (!g_IsDataLoaded[client][DATA_SEASONAL2])
		{
			char sTable[MAX_TABLE_SIZE];
			GetTableString_Season(sTable, sizeof(sTable));

			char sQuery[MAX_QUERY_SIZE];
			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT s.points, (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank, (SELECT COUNT(*) as total FROM `%s`) as total FROM `%s` as s WHERE s.accountid = '%i';", sTable, sTable, sTable, g_iCacheData_AccountID[client]);
			g_Database_Server.Query(TQuery_PullClientSeasonData2, sQuery, data);
		}
		else if (!g_IsDataLoaded[client][DATA_MAPBASED])
		{
			char sTable[MAX_TABLE_SIZE];
			GetTableString_Maps(sTable, sizeof(sTable));

			char sQuery[MAX_QUERY_SIZE];
			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `kills`, `deaths`, `assists`, headshots, points, longest_killstreak, hits, shots, kdr, accuracy, playtime FROM `%s` WHERE accountid = '%i' AND map = '%s';", sTable, g_iCacheData_AccountID[client], g_sCurrentMap);
			g_Database_Server.Query(TQuery_PullClientMapBasedData, sQuery, data);
		}
	}
}

public Action Timer_DelayWelcomeBack(Handle timer, any data)
{
	int client = GetClientFromSerial(data);
	if (!client || IsFakeClient(client))
		return Plugin_Stop;

	CPrintToChat(client, "%T", "join advert", client, client);

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Reconnect.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0)
		EmitSoundToAll(sSound);

	return Plugin_Stop;
}

public Action Timer_DelayWelcome(Handle timer, any data)
{

	int client = GetClientFromSerial(data);
	if (!client || IsFakeClient(client))
		return Plugin_Stop;

	CPrintToChat(client, "%T", "join advert new player", client, client);
	if (convar_ConnectMessage.BoolValue)
		CPrintToChatAll("%t", "join message new player", client);

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Connect.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0)
		EmitSoundToAll(sSound);

	return Plugin_Stop;
}

public void TQuery_PullClientSeasonData(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error pulling client season statistics: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	if (results.FetchRow())
	{
		g_iStatistics_Seasonal_Kills[client] = results.FetchInt(0);
		g_iStatistics_Seasonal_Deaths[client] = results.FetchInt(1);
		g_iStatistics_Seasonal_Assists[client] = results.FetchInt(2);
		g_iStatistics_Seasonal_Headshots[client] = results.FetchInt(3);
		g_fStatistics_Seasonal_Points[client] = results.FetchFloat(4);
		g_iStatistics_Seasonal_Longest_Killstreak[client] = results.FetchInt(5);
		g_iStatistics_Seasonal_Hits[client] = results.FetchInt(6);
		g_iStatistics_Seasonal_Shots[client] = results.FetchInt(7);
		g_fStatistics_Seasonal_KDR[client] = results.FetchFloat(8);
		g_fStatistics_Seasonal_Accuracy[client] = results.FetchFloat(9);
		g_fStatistics_Seasonal_Playtime[client] = results.FetchFloat(10);

		char sWeaponsData[WEAPON_STATISTICS_SIZE];
		results.FetchString(11, sWeaponsData, sizeof(sWeaponsData));

		if (strlen(sWeaponsData) > 0)
		{
			g_hStatistics_Seasonal_WeaponsStatistics[client] = json_decode(sWeaponsData);
		}

		g_iStatistics_Seasonal_LastUpdated[client] = results.FetchInt(11);

		StringMap overlay_data;
		g_iCacheData_Tier[client] = CalculateTier(RoundToFloor(g_fStatistics_Seasonal_Points[client]), overlay_data);

		if (overlay_data != null)
		{
			char sTag[128];
			overlay_data.GetString("tag", sTag, sizeof(sTag));
			strcopy(g_sCacheData_TierTag[client], 512, sTag);

			char sPointsPerKill[PLATFORM_MAX_PATH];
			overlay_data.GetString("points_per_kill", sPointsPerKill, sizeof(sPointsPerKill));

			char sPointsPerDeath[PLATFORM_MAX_PATH];
			overlay_data.GetString("points_per_death", sPointsPerDeath, sizeof(sPointsPerDeath));

			g_fCacheData_PointsGain[client] = StringToFloat(sPointsPerKill);
			g_fCacheData_PointsLoss[client] = StringToFloat(sPointsPerDeath);
		}

		g_IsDataLoaded[client][DATA_SEASONAL] = true;
		g_iLoadedStats[client]++;
	}
	else
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		LogMessage("%s - cannot fetch seasonal statistics.", name);
	}

	if (g_Database_Server != null && g_bActiveSeason)
	{
		if (!g_IsDataLoaded[client][DATA_SEASONAL2])
		{
			char sTable[MAX_TABLE_SIZE];
			GetTableString_Season(sTable, sizeof(sTable));

			char sQuery[MAX_QUERY_SIZE];
			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT s.points, (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank, (SELECT COUNT(*) as total FROM `%s`) as total FROM `%s` as s WHERE s.accountid = '%i';", sTable, sTable, sTable, g_iCacheData_AccountID[client]);
			g_Database_Server.Query(TQuery_PullClientSeasonData2, sQuery, data);
		}
		else if (!g_IsDataLoaded[client][DATA_MAPBASED])
		{
			char sTable[MAX_TABLE_SIZE];
			GetTableString_Maps(sTable, sizeof(sTable));

			char sQuery[MAX_QUERY_SIZE];
			g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `kills`, `deaths`, `assists`, headshots, points, longest_killstreak, hits, shots, kdr, accuracy, playtime FROM `%s` WHERE accountid = '%i' AND map = '%s';", sTable, g_iCacheData_AccountID[client], g_sCurrentMap);
			g_Database_Server.Query(TQuery_PullClientMapBasedData, sQuery, data);
		}
	}
}

public void TQuery_PullClientSeasonData2(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error pulling client season statistics (2): %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	if (results.FetchRow())
	{
		int iPoints = results.FetchInt(0);
		int iRank = results.FetchInt(1);
		g_iCachedPlayers = results.FetchInt(2);

		g_iCacheData_Points[client] = iPoints;
		g_iCacheData_Rank[client] = iRank;

		g_IsDataLoaded[client][DATA_SEASONAL2] = true;
		g_iLoadedStats[client]++;
	}
	else
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		LogMessage("%s - cannot fetch seasonal statistics (2).", name);
	}

	if (g_Database_Server != null && g_bActiveSeason && !g_IsDataLoaded[client][DATA_MAPBASED])
	{
		char sTable[MAX_TABLE_SIZE];
		GetTableString_Maps(sTable, sizeof(sTable));

		char sQuery[MAX_QUERY_SIZE];
		g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `kills`, `deaths`, `assists`, headshots, points, longest_killstreak, hits, shots, kdr, accuracy, playtime FROM `%s` WHERE accountid = '%i' AND map = '%s';", sTable, g_iCacheData_AccountID[client], g_sCurrentMap);
		g_Database_Server.Query(TQuery_PullClientMapBasedData, sQuery, data);
	}
}

public void TQuery_PullClientMapBasedData(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error pulling client season statistics (2): %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	if (results.FetchRow())
	{
		g_iStatistics_Mapbased_Kills[client] = results.FetchInt(0);
		g_iStatistics_Mapbased_Deaths[client] = results.FetchInt(1);
		g_iStatistics_Mapbased_Assists[client] = results.FetchInt(2);
		g_iStatistics_Mapbased_Headshots[client] = results.FetchInt(3);
		g_fStatistics_Mapbased_Points[client] = results.FetchFloat(4);
		g_iStatistics_Mapbased_Longest_Killstreak[client] = results.FetchInt(5);
		g_iStatistics_Mapbased_Hits[client] = results.FetchInt(6);
		g_iStatistics_Mapbased_Shots[client] = results.FetchInt(7);
		g_fStatistics_Mapbased_KDR[client] = results.FetchFloat(8);
		g_fStatistics_Mapbased_Accuracy[client] = results.FetchFloat(9);

		g_IsDataLoaded[client][DATA_MAPBASED] = true;
		g_iLoadedStats[client]++;
	}
	else
	{
		char name[MAX_NAME_LENGTH];
		GetClientName(client, name, sizeof(name));
		LogMessage("%s - cannot fetch map-based statistics.", name);
	}

	ValidateClientServerData(client);
}

void ValidateClientServerData(int client)
{
	char sQuery[MAX_QUERY_SIZE];
	char sTable[MAX_TABLE_SIZE];

	char sName[MAX_NAME_LENGTH], sEscapedName[1 + MAX_NAME_LENGTH * 2];
	GetClientName(client, sName, sizeof(sName));
	g_Database_Server.Escape(sName, sEscapedName, sizeof(sEscapedName));

	int serial = GetClientSerial(client);

	char sWeaponsData[WEAPON_STATISTICS_SIZE];
	g_hStatistics_Seasonal_WeaponsStatistics[client].Encode(sWeaponsData, sizeof(sWeaponsData));

	int iTime = GetTime();

	GetTableString_Season(sTable, sizeof(sTable));

	DataPack data = new DataPack();

	data.WriteCell(serial);
	data.WriteString(sName);
	data.WriteCell(iTime);

	g_Database_Server.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `weapons_statistics`, `first_created`, `last_updated`) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%i', '%i') ON DUPLICATE KEY UPDATE `name` = '%s', `last_updated` = '%i';", sTable, sEscapedName, g_iCacheData_AccountID[client], g_sCacheData_SteamID2[client], g_sCacheData_SteamID3[client], g_sCacheData_SteamID64[client], sWeaponsData, iTime, iTime, sEscapedName, iTime);
	g_Database_Server.Query(TQuery_SyncClient_Season, sQuery, data);
}

public void TQuery_SyncClient_Season(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
		ThrowError("Error updating client for the season: %s", error);

	data.Reset();

	int serial = data.ReadCell();

	char sName[MAX_NAME_LENGTH], sEscapedName[1 + MAX_NAME_LENGTH * 2];
	data.ReadString(sName, sizeof(sName));
	g_Database_Server.Escape(sName, sEscapedName, sizeof(sEscapedName));

	int iTime = data.ReadCell();

	delete data;

	int client;
	if ((client = GetClientFromSerial(serial)) > 0)
	{
		g_iStatistics_Seasonal_LastUpdated[client] = iTime;

		StringMap overlay_data;
		g_iCacheData_Tier[client] = CalculateTier(RoundToFloor(g_fStatistics_Seasonal_Points[client]), overlay_data);

		if (overlay_data != null)
		{
			char sTag[128];
			overlay_data.GetString("tag", sTag, sizeof(sTag));
			strcopy(g_sCacheData_TierTag[client], 512, sTag);

			char sPointsPerKill[PLATFORM_MAX_PATH];
			overlay_data.GetString("points_per_kill", sPointsPerKill, sizeof(sPointsPerKill));

			char sPointsPerDeath[PLATFORM_MAX_PATH];
			overlay_data.GetString("points_per_death", sPointsPerDeath, sizeof(sPointsPerDeath));

			g_fCacheData_PointsGain[client] = StringToFloat(sPointsPerKill);
			g_fCacheData_PointsLoss[client] = StringToFloat(sPointsPerDeath);
		}
	}

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Maps(sTable, sizeof(sTable));

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Server.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`name`, `accountid`, `steamid2`, `steamid3`, `steamid64`, `map`, `first_created`, `last_updated`) VALUES ('%s', '%i', '%s', '%s', '%s', '%s', '%i', '%i') ON DUPLICATE KEY UPDATE `name` = '%s', `last_updated` = '%i';", sTable, sEscapedName, g_iCacheData_AccountID[client], g_sCacheData_SteamID2[client], g_sCacheData_SteamID3[client], g_sCacheData_SteamID64[client], g_sCurrentMap, iTime, iTime, sEscapedName, iTime);
	g_Database_Server.Query(TQuery_SyncClient_Map, sQuery, serial);
}

public void TQuery_SyncClient_Map(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error updating client for the map: %s", error);
}

public void OnClientCommandKeyValues_Post(int client, KeyValues kv)
{
	if (!convar_Status.BoolValue || IsFakeClient(client) || g_Database_Global == null)
		return;

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sClantag[32];
	kv.GetString("tag", sClantag, sizeof(sClantag));

	char sClanname[32];
	kv.GetString("name", sClanname, sizeof(sClanname));

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `clan_tag` = '%s', `clan_name` = '%s', `last_updated` = '%i' WHERE `accountid` = '%i';", sTable, sClantag, sClanname, GetTime(), g_iCacheData_AccountID[client]);
	g_Database_Global.Query(TQuery_OnClanDataUpdate, sQuery);
}

public void TQuery_OnClanDataUpdate(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error on updating client global clan data: %s", error);
}

public void OnClientDisconnect(int client)
{
	if (!convar_Status.BoolValue || IsFakeClient(client) || !IsClientAuthorized(client))
		return;

	if (IsClientInGame(client))
	{
		SaveClientGlobalData(client);
		SaveClientServerData(client);
		SaveClientSessionData(client);
	}
}

public void OnClientDisconnect_Post(int client)
{
	g_iCooldown[client] = -1;
	StopTimer(g_hTimer_Playtime[client]);

	delete g_StatisticsMenu[client];

	if (g_hStatistics_Seasonal_WeaponsStatistics[client] != null)
	{
		g_hStatistics_Seasonal_WeaponsStatistics[client].Cleanup();
		delete g_hStatistics_Seasonal_WeaponsStatistics[client];
	}

	g_WinPanel[client].Delete();
}

void SaveClientGlobalData(int client, Transaction trans = null)
{
	if (g_iLoadedStats[client] < 4)
	{
		return;
	}

	if (g_Database_Global == null || !IsClientAuthorized(client))
		return;

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sName[MAX_NAME_LENGTH], sEscapedName[1 + MAX_NAME_LENGTH * 2];
	GetClientName(client, sName, sizeof(sName));
	g_Database_Global.Escape(sName, sEscapedName, sizeof(sEscapedName));

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `name` = '%s', `credits` = '%i', `credits_earned` = '%i', `credits_timer` = '%f', `kills` = '%i', `deaths` = '%i', `assists` = '%i', `headshots` = '%i', `points` = '%f', `longest_killstreak` = '%i', `hits` = '%i', `shots` = '%i', `kdr` = '%f', `accuracy` = '%f', `last_updated` = '%i' WHERE `accountid` = '%i';",
		sTable,
		sEscapedName,
		g_iStatistics_Global_Credits[client],
		g_iStatistics_Global_CreditsEarned[client],
		g_fStatistics_Global_CreditsTimer[client],
		g_iStatistics_Global_Kills[client],
		g_iStatistics_Global_Deaths[client],
		g_iStatistics_Global_Assists[client],
		g_iStatistics_Global_Headshots[client],
		g_fStatistics_Global_Points[client],
		g_iStatistics_Global_Longest_Killstreak[client],
		g_iStatistics_Global_Hits[client],
		g_iStatistics_Global_Shots[client],
		g_fStatistics_Global_KDR[client],
		g_fStatistics_Global_Accuracy[client],
		GetTime(),
		g_iCacheData_AccountID[client]);

	if (trans != null)
		trans.AddQuery(sQuery);
	else
		g_Database_Global.Query(TQuery_OnSaveGlobalStats, sQuery);
}

public void TQuery_OnSaveGlobalStats(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while saving client global statisitcs: %s", error);
}

void SaveClientServerData(int client, Transaction trans = null)
{
	if (g_iLoadedStats[client] < 4 || !g_IsDataLoaded[client][DATA_SEASONAL])
	{
		return;
	}

	if (g_Database_Server == null)
		return;

	char sName[MAX_NAME_LENGTH], sEscapedName[1 + MAX_NAME_LENGTH * 2];
	GetClientName(client, sName, sizeof(sName));
	g_Database_Server.Escape(sName, sEscapedName, sizeof(sEscapedName));

	char sWeaponsStatistics[WEAPON_STATISTICS_SIZE];
	if (g_hStatistics_Seasonal_WeaponsStatistics[client] != null)
	{
		g_hStatistics_Seasonal_WeaponsStatistics[client].Encode(sWeaponsStatistics, sizeof(sWeaponsStatistics));
		Format(sWeaponsStatistics, sizeof(sWeaponsStatistics), ", `weapons_statistics` = '%s'", sWeaponsStatistics);
	}
	LogMessage("----------------------client: %N", client);
	LogMessage(sWeaponsStatistics);

	int iAccountID = g_iCacheData_AccountID[client];
	int time = GetTime();

	char sQuery[MAX_QUERY_SIZE];
	char sTable[MAX_TABLE_SIZE];

	GetTableString_Season(sTable, sizeof(sTable));
	Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `name` = '%s', `kills` = '%i', `deaths` = '%i', `assists` = '%i', `headshots` = '%i', `points` = '%f', `longest_killstreak` = '%i', `hits` = '%i', `shots` = '%i', `kdr` = '%f', `accuracy` = '%f'%s, `last_updated` = '%i' WHERE `accountid` = '%i';",
		sTable,
		sEscapedName,
		g_iStatistics_Seasonal_Kills[client],
		g_iStatistics_Seasonal_Deaths[client],
		g_iStatistics_Seasonal_Assists[client],
		g_iStatistics_Seasonal_Headshots[client],
		g_fStatistics_Seasonal_Points[client],
		g_iStatistics_Seasonal_Longest_Killstreak[client],
		g_iStatistics_Seasonal_Hits[client],
		g_iStatistics_Seasonal_Shots[client],
		g_fStatistics_Seasonal_KDR[client],
		g_fStatistics_Seasonal_Accuracy[client],
		strlen(sWeaponsStatistics) > 0 ? sWeaponsStatistics : "",
		time,
		iAccountID);

	if (trans != null)
		trans.AddQuery(sQuery);
	else
		g_Database_Server.Query(TQuery_OnSaveServerSeason, sQuery);

	GetTableString_Maps(sTable, sizeof(sTable));
	Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `name` = '%s', `kills` = '%i', `deaths` = '%i', `assists` = '%i', `headshots` = '%i', `points` = '%f', `longest_killstreak` = '%i', `hits` = '%i', `shots` = '%i', `kdr` = '%f', `accuracy` = '%f', `last_updated` = '%i' WHERE `accountid` = '%i' AND `map` = '%s';",
		sTable,
		sEscapedName,
		g_iStatistics_Mapbased_Kills[client],
		g_iStatistics_Mapbased_Deaths[client],
		g_iStatistics_Mapbased_Assists[client],
		g_iStatistics_Mapbased_Headshots[client],
		g_fStatistics_Mapbased_Points[client],
		g_iStatistics_Mapbased_Longest_Killstreak[client],
		g_iStatistics_Mapbased_Hits[client],
		g_iStatistics_Mapbased_Shots[client],
		g_fStatistics_Mapbased_KDR[client],
		g_fStatistics_Mapbased_Accuracy[client],
		time,
		iAccountID,
		g_sCurrentMap);

	if (trans != null)
		trans.AddQuery(sQuery);
	else
		g_Database_Server.Query(TQuery_OnSaveServerMap, sQuery);
}

public void TQuery_OnSaveServerSeason(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while saving server season statistics: %s", error);
}

public void TQuery_OnSaveServerMap(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while saving server map statistics: %s", error);
}

void SaveClientSessionData(int client)
{
	if (g_iLoadedStats[client] < 4)
	{
		return;
	}

	int iAccountID = g_iCacheData_AccountID[client];

	char sName[MAX_NAME_LENGTH];
	GetClientName(client, sName, sizeof(sName));

	char sAccountID[64];
	IntToString(iAccountID, sAccountID, sizeof(sAccountID));

	StringMap trie = new StringMap();

	trie.SetString("Name", sName);
	trie.SetString("SteamID2", g_sCacheData_SteamID2[client]);
	trie.SetString("SteamID3", g_sCacheData_SteamID3[client]);
	trie.SetString("SteamID64", g_sCacheData_SteamID64[client]);

	trie.SetValue("Kills", g_iStatistics_Sessionbased_Kills[client]);
	trie.SetValue("Deaths", g_iStatistics_Sessionbased_Deaths[client]);
	trie.SetValue("Assists", g_iStatistics_Sessionbased_Assists[client]);
	trie.SetValue("Headshots", g_iStatistics_Sessionbased_Headshots[client]);
	trie.SetValue("Hits", g_iStatistics_Sessionbased_Hits[client]);
	trie.SetValue("Shots", g_iStatistics_Sessionbased_Shots[client]);
	trie.SetValue("KDR", g_fStatistics_Sessionbased_KDR[client]);
	trie.SetValue("Accuracy", g_fStatistics_Sessionbased_Accuracy[client]);
	trie.SetValue("PointsGained", g_fStatistics_Sessionbased_PointsGained[client]);
	trie.SetValue("PointsLost", g_fStatistics_Sessionbased_PointsLost[client]);
	trie.SetValue("RanksGained", g_iStatistics_Sessionbased_RanksGained[client]);
	trie.SetValue("RanksLost", g_iStatistics_Sessionbased_RanksLost[client]);

	g_SessionCache.SetValue(sAccountID, trie);
	g_SessionIDs.Push(iAccountID);
}

void CalculateAccuracyStatsForPlayer(int client, int iGlobalShots, int iSeasonalShots, int iMapbasedShots, int iSessionbasedShots)
{
	g_fStatistics_Global_Accuracy[client] = CalculateAccuracy(g_iStatistics_Global_Hits[client], iGlobalShots);
	g_fStatistics_Seasonal_Accuracy[client] = CalculateAccuracy(g_iStatistics_Seasonal_Hits[client], iSeasonalShots);
	g_fStatistics_Mapbased_Accuracy[client] = CalculateAccuracy(g_iStatistics_Mapbased_Hits[client], iMapbasedShots);
	g_fStatistics_Sessionbased_Accuracy[client] = CalculateAccuracy(g_iStatistics_Sessionbased_Hits[client], iSessionbasedShots);
}

public void Player_OnTakeDamageAlivePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	// Only count towards stats if attacker is the inflictor
	if (attacker != inflictor)
		return;

	if (!convar_Status.BoolValue || g_bBetweenRounds || !g_bRanked || (convar_NoBotsStatistics.BoolValue && IsFakeClient(victim)))
		return;

	if (attacker > 0 && attacker <= MaxClients && !IsFakeClient(attacker))
	{
		// Their current weapon will be doing the damage, since they're the inflictor
		int iActiveWeapon = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");

		// Something went wrong...
		if (iActiveWeapon == INVALID_ENT_REFERENCE)
		{
			return;
		}

		char sWeapon[64];
		GetEntityClassname(iActiveWeapon, sWeapon, sizeof(sWeapon));

		CSWeaponID weaponID = CS_ItemDefIndexToID(GetEntProp(iActiveWeapon, Prop_Send, "m_iItemDefinitionIndex"));

		if (GetEntProp(iActiveWeapon, Prop_Send, "m_bBurstMode", 1)
			|| (weaponID == CSWeapon_XM1014
			|| weaponID == CSWeapon_M3
			|| weaponID == CSWeapon_MAG7
			|| weaponID == CSWeapon_SAWEDOFF
			|| weaponID == CSWeapon_NOVA))
		{
			if (g_bCountFirstHit[attacker])
			{
				g_bCountFirstHit[attacker] = false;

				g_iStatistics_Global_Hits[attacker]++;
				g_iStatistics_Seasonal_Hits[attacker]++;
				g_iStatistics_Mapbased_Hits[attacker]++;
				g_iStatistics_Sessionbased_Hits[attacker]++;

				CalculateAccuracyStatsForPlayer(attacker,
					g_iStatistics_Global_Shots[attacker],
					g_iStatistics_Seasonal_Shots[attacker],
					g_iStatistics_Mapbased_Shots[attacker],
					g_iStatistics_Sessionbased_Shots[attacker]);

				IncrementWeaponDataValue(attacker, sWeapon, "hits");
			}
		}
		else
		{
			g_iStatistics_Global_Hits[attacker]++;
			g_iStatistics_Seasonal_Hits[attacker]++;
			g_iStatistics_Mapbased_Hits[attacker]++;
			g_iStatistics_Sessionbased_Hits[attacker]++;

			CalculateAccuracyStatsForPlayer(attacker,
				g_iStatistics_Global_Shots[attacker],
				g_iStatistics_Seasonal_Shots[attacker],
				g_iStatistics_Mapbased_Shots[attacker],
				g_iStatistics_Sessionbased_Shots[attacker]);

			IncrementWeaponDataValue(attacker, sWeapon, "hits");
		}
	}
}

public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client < 1 || !IsClientInGame(client) || IsFakeClient(client)) {
		return;
	}

	g_WinPanel[client].Snapshot();
}

public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int assister = GetClientOfUserId(event.GetInt("assister"));

	if (!convar_Status.BoolValue || !g_bRanked || client < 1 || (convar_NoBotsStatistics.BoolValue && IsFakeClient(client)))
		return;

	if (!IsFakeClient(client))
	{
		// This will allow the HUD to update
		PrintHintText(client, "");

		g_LastSpectated[client] = 0;

		g_iStatistics_Global_Deaths[client]++;
		g_fStatistics_Global_KDR[client] = CalculateKDR(g_iStatistics_Global_Kills[client], g_iStatistics_Global_Deaths[client]);

		g_iStatistics_Seasonal_Deaths[client]++;
		g_fStatistics_Seasonal_KDR[client] = CalculateKDR(g_iStatistics_Seasonal_Kills[client], g_iStatistics_Seasonal_Deaths[client]);

		g_iStatistics_Mapbased_Deaths[client]++;
		g_fStatistics_Mapbased_KDR[client] = CalculateKDR(g_iStatistics_Mapbased_Kills[client], g_iStatistics_Mapbased_Deaths[client]);

		g_iStatistics_Sessionbased_Deaths[client]++;
		g_fStatistics_Sessionbased_KDR[client] = CalculateKDR(g_iStatistics_Sessionbased_Kills[client], g_iStatistics_Sessionbased_Deaths[client]);

		if (client != attacker || convar_LosePointsOnSuicide.BoolValue)
		{
			g_fStatistics_Global_Points[client] -= g_fCacheData_PointsLoss[client];
			g_fStatistics_Seasonal_Points[client] -= g_fCacheData_PointsLoss[client];
			g_fStatistics_Mapbased_Points[client] -= g_fCacheData_PointsLoss[client];
			g_fStatistics_Sessionbased_PointsLost[client] += g_fCacheData_PointsLoss[client];

			if (client != attacker)
				CPrintToChat(client, "%T", "kill points loss", client, RoundToFloor(g_fCacheData_PointsLoss[client]), attacker);
			else
				CPrintToChat(client, "%T", "kill points loss suicide", client, RoundToFloor(g_fCacheData_PointsLoss[client]));
		}

		g_iLocalKillstreak[client] = 0;

		if (g_bRampage[client])
		{
			g_bRampage[client] = false;
			CPrintToChat(client, "%T", "rampage end", client);
		}

		SaveDeathStatistics(client);
	}

	if (attacker > 0 && !IsFakeClient(attacker) && client != attacker)
	{
		g_iStatistics_Global_Kills[attacker]++;
		g_fStatistics_Global_KDR[attacker] = CalculateKDR(g_iStatistics_Global_Kills[attacker], g_iStatistics_Global_Deaths[attacker]);

		char sWeapon[64];
		GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));

		if (StrContains(sWeapon, "knife") != -1 || StrContains(sWeapon, "bayonet") != -1)
		{
			if (!g_bRampage[attacker])
				ShowClientOverlay(attacker, OVERLAY_RAMPAGE, 3.0);

			g_bRampage[attacker] = true;
		}

		float fPointsGain = g_fCacheData_PointsGain[attacker];

		if (g_bRampage[attacker])
			CPrintToChat(attacker, "%T", "kill points gain rampage", attacker, RoundToFloor(fPointsGain), client, convar_Rampage_Points.IntValue);
		else if (((g_bFrsWeapons && !Furious_Weapons_IsDropshotKill(attacker) || !g_bFrsWeapons) && (convar_Status.BoolValue && g_bRanked)))
			CPrintToChat(attacker, "%T", "kill points gain", attacker, RoundToFloor(fPointsGain), client);

		g_fStatistics_Global_Points[attacker] += fPointsGain + (g_bRampage[attacker] ? convar_Rampage_Points.IntValue : 0);

		g_iStatistics_Seasonal_Kills[attacker]++;
		g_fStatistics_Seasonal_KDR[attacker] = CalculateKDR(g_iStatistics_Seasonal_Kills[attacker], g_iStatistics_Seasonal_Deaths[attacker]);
		g_fStatistics_Seasonal_Points[attacker] += fPointsGain + (g_bRampage[attacker] ? convar_Rampage_Points.IntValue : 0);

		g_iStatistics_Mapbased_Kills[attacker]++;
		g_fStatistics_Mapbased_KDR[attacker] = CalculateKDR(g_iStatistics_Mapbased_Kills[attacker], g_iStatistics_Mapbased_Deaths[attacker]);
		g_fStatistics_Mapbased_Points[attacker] += fPointsGain + (g_bRampage[attacker] ? convar_Rampage_Points.IntValue : 0);

		g_iStatistics_Sessionbased_Kills[attacker]++;
		g_fStatistics_Sessionbased_KDR[attacker] = CalculateKDR(g_iStatistics_Sessionbased_Kills[attacker], g_iStatistics_Sessionbased_Deaths[attacker]);
		g_fStatistics_Sessionbased_PointsGained[attacker] += fPointsGain + (g_bRampage[attacker] ? convar_Rampage_Points.IntValue : 0);

		g_iStatistics_Global_Credits[attacker] += RoundToFloor(fPointsGain);
		g_iStatistics_Global_CreditsEarned[attacker] += RoundToFloor(fPointsGain);

		if (GetUserFlagBits(attacker) & VIP_FLAGS) {
			static ConVar convar_ExtraCredits = null;

			if (convar_ExtraCredits == null) {
				convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");
			}

			int extra = convar_ExtraCredits.IntValue;

			g_iStatistics_Global_Credits[attacker] += extra;
			g_iStatistics_Global_CreditsEarned[attacker] += extra;

			CPrintToChat(attacker, "%T", "vip credits added", attacker, RoundToFloor(fPointsGain), extra);
		} else {
			CPrintToChat(attacker, "%T", "credits added", attacker, RoundToFloor(fPointsGain));
		}

		g_iLocalKillstreak[attacker]++;

		if (g_iLocalKillstreak[attacker] > g_iStatistics_Global_Longest_Killstreak[attacker])
			g_iStatistics_Global_Longest_Killstreak[attacker] = g_iLocalKillstreak[attacker];

		if (g_iLocalKillstreak[attacker] > g_iStatistics_Seasonal_Longest_Killstreak[attacker])
			g_iStatistics_Seasonal_Longest_Killstreak[attacker] = g_iLocalKillstreak[attacker];

		if (g_iLocalKillstreak[attacker] > g_iStatistics_Mapbased_Longest_Killstreak[attacker])
			g_iStatistics_Mapbased_Longest_Killstreak[attacker] = g_iLocalKillstreak[attacker];

		if (event.GetBool("headshot"))
		{
			g_iStatistics_Global_Headshots[attacker]++;
			g_iStatistics_Seasonal_Headshots[attacker]++;
			g_iStatistics_Mapbased_Headshots[attacker]++;
			g_iStatistics_Sessionbased_Headshots[attacker]++;
		}

		IncrementWeaponDataValue(attacker, sWeapon, "kills");

		if (convar_SaveOnPlayerDeath.BoolValue)
			UpdateClientPositions(attacker, true);
	}

	if (assister > 0 && !IsFakeClient(assister) && client != assister)
	{
		g_iStatistics_Global_Assists[assister]++;
		g_fStatistics_Global_Points[assister] += 1.0;

		g_iStatistics_Seasonal_Assists[assister]++;
		g_fStatistics_Seasonal_Points[assister] += 1.0;

		g_iStatistics_Mapbased_Assists[assister]++;
		g_fStatistics_Mapbased_Points[assister] += 1.0;

		g_iStatistics_Sessionbased_Assists[assister]++;
		g_fStatistics_Sessionbased_PointsGained[assister] += 1.0;

		CPrintToChat(assister, "%T", "assist points", assister, client);
	}
}

public Action Timer_ResetOverlayForClient(Handle timer, any data)
{
	int client;
	if ((client = GetClientFromSerial(data)) > 0)
	{
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		ClientCommand(client, "r_screenoverlay \"\"");
		SetCommandFlags("r_screenoverlay", iFlags);
	}

	return Plugin_Continue;
}

public void OnWeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!convar_Status.BoolValue || g_bBetweenRounds || !g_bRanked || client < 1 || IsFakeClient(client))
		return;

	g_iStatistics_Global_Shots[client]++;
	g_iStatistics_Seasonal_Shots[client]++;
	g_iStatistics_Mapbased_Shots[client]++;
	g_iStatistics_Sessionbased_Shots[client]++;

	CalculateAccuracyStatsForPlayer(client,
		g_iStatistics_Global_Shots[client],
		g_iStatistics_Seasonal_Shots[client],
		g_iStatistics_Mapbased_Shots[client],
		g_iStatistics_Sessionbased_Shots[client]);

	char sWeapon[64];
	GetClientWeapon(client, sWeapon, sizeof(sWeapon));

	IncrementWeaponDataValue(client, sWeapon, "shots");

	// Only count first shotgun hit
	g_bCountFirstHit[client] = true;
}

void IncrementWeaponDataValue(int client, const char[] sWeapon, const char[] sStat)
{
	if (g_hStatistics_Seasonal_WeaponsStatistics[client] == null || strlen(sWeapon) == 0 || strlen(sStat) == 0)
		return;

	JSON_Object hWeaponObj = g_hStatistics_Seasonal_WeaponsStatistics[client].GetObject(sWeapon);

	if (hWeaponObj == null)
	{
		hWeaponObj = new JSON_Object();
		hWeaponObj.SetInt("kills", 0);
		hWeaponObj.SetInt("hits", 0);
		hWeaponObj.SetInt("shots", 0);

		g_hStatistics_Seasonal_WeaponsStatistics[client].SetObject(sWeapon, hWeaponObj);
	}

	int stat = hWeaponObj.GetInt(sStat);

	stat++;

	hWeaponObj.SetInt(sStat, stat);
}

public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!convar_Status.BoolValue || client < 1 || client > MaxClients || IsFakeClient(client))
		return;

	if (g_iLoadedStats[client] < 4)
	{
		return;
	}

	char sReason[64];
	event.GetString("reason", sReason, sizeof(sReason));
	char sStar[48];
	if (GetUserFlagBits(client))
	{
		int index = Furious_Tags_GetPrefixID(client);
		char sPrefix[32], sColor[16];
		Furious_Tags_GetPrefix(index, sPrefix, sizeof(sPrefix));
		Furious_Tags_GetPrefixColor(index, sColor, sizeof(sColor));
		Format(sStar, sizeof(sStar), "%s%s", sColor, sPrefix);
	}

	if (convar_DisconnectMessage.BoolValue)
		CPrintToChatAll("%t", "disconnect message", sStar, client, g_sCacheData_SteamID2[client], sReason);

	float time = GetClientTime(client);
	int iAccountID = g_iCacheData_AccountID[client];

	char sTable[MAX_TABLE_SIZE];
	char sQuery[MAX_QUERY_SIZE];

	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));
	g_Database_Global.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `playtime` = `playtime` + '%f' WHERE `accountid` = '%i';", sTable, time, iAccountID);
	g_Database_Global.Query(TQuery_UpdatePlaytime, sQuery);

	Transaction trans = new Transaction();

	GetTableString_Season(sTable, sizeof(sTable));
	g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `playtime` = `playtime` + '%f' WHERE `accountid` = '%i';", sTable, time, iAccountID);
	trans.AddQuery(sQuery);

	GetTableString_Maps(sTable, sizeof(sTable));
	g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `playtime` = `playtime` + '%f' WHERE `accountid` = '%i' AND `map` = '%s';", sTable, time, iAccountID, g_sCurrentMap);
	trans.AddQuery(sQuery);

	g_Database_Server.Execute(trans, _, onError_SavePlayetimes);
}

public void TQuery_UpdatePlaytime(Database db, DBResultSet results, const char[] error, any dat)
{
	if (results == null)
		ThrowError("Error while updating client playtime: %s", error);
}

public void onError_SavePlayetimes(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	ThrowError("Error while saving client playtime statistics at query %i: %s", failIndex, error);
}

public void OnRoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;

	g_bBetweenRounds = false;
	ValidateRankCheck();
}

void ValidateRankCheck()
{
	int iCurrent = CountFuriousClients();
	int iRequired = convar_MinimumPlayersStatistics.IntValue;

	g_bRanked = iCurrent >= iRequired;
	AnnounceRankStatus(iCurrent, iRequired);
}

void AnnounceRankStatus(int current, int required)
{
	if (g_bRanked)
	{
		CPrintToChatAll("%t", "ranking enabled print");

		char sRankSound[PLATFORM_MAX_PATH];
		convar_Sound_RankEnabled.GetString(sRankSound, sizeof(sRankSound));

		if (strlen(sRankSound) > 0)
			EmitSoundToAll(sRankSound);

		if (convar_RankEnabled_Status.BoolValue)
		{
			char sChannel[12];
			convar_RankEnabled_Channel.GetString(sChannel, sizeof(sChannel));

			char sCoordinate_X[12];
			convar_RankEnabled_Coordinate_X.GetString(sCoordinate_X, sizeof(sCoordinate_X));

			char sCoordinate_Y[12];
			convar_RankEnabled_Coordinate_Y.GetString(sCoordinate_Y, sizeof(sCoordinate_Y));

			char sColor[64];
			convar_RankEnabled_Color.GetString(sColor, sizeof(sColor));

			char sRankHudSync[256];
			FormatEx(sRankHudSync, sizeof(sRankHudSync), "%t", "ranking enabled hud sync");

			int entity; char output[64];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i))
					continue;

				entity = CreateEntityByName("game_text");

				if (IsValidEntity(entity))
				{
					DispatchKeyValue(entity, "channel", sChannel);
					DispatchKeyValue(entity, "color", sColor);
					DispatchKeyValue(entity, "message", sRankHudSync);
					DispatchKeyValue(entity, "x", sCoordinate_X);
					DispatchKeyValue(entity, "y", sCoordinate_Y);
					DispatchSpawn(entity);

					SetVariantString("!activator");
					AcceptEntityInput(entity, "display", i);

					Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", 10.0);
					SetVariantString(output);
					AcceptEntityInput(entity, "AddOutput");
					AcceptEntityInput(entity, "FireUser1");
				}
			}
		}
	}
	else
	{
		CPrintToChatAll("%t", "ranking disabled print", current, required);

		char sRankSound[PLATFORM_MAX_PATH];
		convar_Sound_RankDisabled.GetString(sRankSound, sizeof(sRankSound));

		if (strlen(sRankSound) > 0)
			EmitSoundToAll(sRankSound);

		if (convar_RankDisabled_Status.BoolValue)
		{
			char sChannel[12];
			convar_RankDisabled_Channel.GetString(sChannel, sizeof(sChannel));

			char sCoordinate_X[12];
			convar_RankDisabled_Coordinate_X.GetString(sCoordinate_X, sizeof(sCoordinate_X));

			char sCoordinate_Y[12];
			convar_RankDisabled_Coordinate_Y.GetString(sCoordinate_Y, sizeof(sCoordinate_Y));

			char sColor[64];
			convar_RankDisabled_Color.GetString(sColor, sizeof(sColor));

			char sRankHudSync[256];
			FormatEx(sRankHudSync, sizeof(sRankHudSync), "%t", "ranking disabled hud sync", current, required);

			int entity; char output[64];
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || IsFakeClient(i))
					continue;

				entity = CreateEntityByName("game_text");

				if (IsValidEntity(entity))
				{
					DispatchKeyValue(entity, "channel", sChannel);
					DispatchKeyValue(entity, "color", sColor);
					DispatchKeyValue(entity, "message", sRankHudSync);
					DispatchKeyValue(entity, "x", sCoordinate_X);
					DispatchKeyValue(entity, "y", sCoordinate_Y);
					DispatchSpawn(entity);

					SetVariantString("!activator");
					AcceptEntityInput(entity, "display", i);

					Format(output, sizeof(output), "OnUser1 !self:kill::%.1f:1", 10.0);
					SetVariantString(output);
					AcceptEntityInput(entity, "AddOutput");
					AcceptEntityInput(entity, "FireUser1");
				}
			}
		}
	}
}

int CountFuriousClients()
{
	int iCount;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= 1)
			continue;

		iCount++;
	}

	return iCount;
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	//Cache current values to show differences in the win panel.
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}

		g_WinPanel[i].Snapshot();
	}
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!convar_Status.BoolValue)
		return;

	g_bBetweenRounds = true;

	if (!convar_RoundClampStatistics.BoolValue)
		g_bBetweenRounds = false;

	if (convar_SaveOnRoundEnd.BoolValue)
		SyncAllClientStats();
}

public void OnMatchEnd(Event event, const char[] name, bool dontBroadcast)
{
	char sMap[64];
	if (GetNextMap(sMap, sizeof(sMap)))
	{
		CPrintToChatAll("%t", "next map line");
		CPrintToChatAll("%t", "next map name", sMap);
		CPrintToChatAll("%t", "next map line");
	}
}

void SyncAllClientStats()
{
	Transaction trans;

	if (g_Database_Global != null)
	{
		trans = new Transaction();

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			SaveClientGlobalData(i, trans);
		}

		g_Database_Global.Execute(trans);
	}

	if (g_Database_Server != null)
	{
		trans = new Transaction();

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i))
				continue;

			SaveClientServerData(i, trans);
		}

		g_Database_Server.Execute(trans);
	}
}

public Action Command_OpenStatisticsMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	char sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	char sSearch[64];
	if (StrEqual(sCommand, "sm_statsme"))
		strcopy(sSearch, sizeof(sSearch), g_sCacheData_SteamID2[client]);
	else
	{
		g_bToggleStatistics[client] = StrEqual(sCommand, "sm_session");

		GetCmdArg(1, sSearch, sizeof(sSearch));

		if (args == 0 || strlen(sSearch) == 0)
			strcopy(sSearch, sizeof(sSearch), g_sCacheData_SteamID2[client]);
	}

	ShowStatisticsMenu(client, sSearch);

	return Plugin_Handled;
}

void ShowStatisticsMenu(int client, const char[] sSearch)
{
	if (!client)
	{
		return;
	}

	if (!IsClientInGame(client))
	{
		return;
	}

	bool bIsSteamID = StrContains(sSearch, "STEAM_") != -1;
	int target = FindTargetEx(client, sSearch, true, false);

	int size = 2 * strlen(sSearch) + 1;
	char[] sSearchE = new char[size];
	g_Database_Global.Escape(sSearch, sSearchE, size);

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sSearchPost[64];
	Format(sSearchPost, sizeof(sSearchPost), bIsSteamID ? "s.steamid2 = '%s'" : "s.name LIKE '%%%s%%'", sSearchE);

	DataPack pack = new DataPack();

	if (target > 0)
	{
		pack.WriteCell(GetClientSerial(client));
		pack.WriteCell(GetClientSerial(target));

		char sQuery[512];
		Format(sQuery, sizeof(sQuery), "SELECT s.country, (SELECT COUNT(*) as rank_country FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills) AND country = s.country) + 1 as rank_country, (SELECT COUNT(*) as total_country FROM `%s` WHERE country = s.country) as total_country FROM `%s` as s WHERE %s;", sTable, sTable, sTable, sSearchPost);
		g_Database_Global.Query(OnParseCountry_Online, sQuery, pack);
	}
	else
	{
		pack.WriteCell(GetClientSerial(client));
		pack.WriteCell(bIsSteamID);
		pack.WriteString(sSearch);
		pack.WriteString(sSearchPost);

		char sQuery[512];
		Format(sQuery, sizeof(sQuery), "SELECT s.country, (SELECT COUNT(*) as rank_country FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills) AND country = s.country) + 1 as rank_country, (SELECT COUNT(*) as total_country FROM `%s` WHERE country = s.country) as total_country FROM `%s` as s WHERE %s;", sTable, sTable, sTable, sSearchPost);
		g_Database_Global.Query(OnParseCountry_Offline, sQuery, pack);
	}
}

public void OnParseCountry_Offline(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int serial = pack.ReadCell();
	bool bIsSteamID = pack.ReadCell();

	char sSearch[64];
	pack.ReadString(sSearch, sizeof(sSearch));

	char sSearchPost[64];
	pack.ReadString(sSearchPost, sizeof(sSearchPost));

	if (results == null)
	{
		delete pack;
		ThrowError("Error while parsing target country for statistics: %s", error);
	}

	if (GetClientFromSerial(serial) == 0)
	{
		delete pack;
		return;
	}

	char sCountry[64];
	int iRank_Country;
	int iTotal_Country;

	if (results.FetchRow())
	{
		results.FetchString(0, sCountry, sizeof(sCountry));
		iRank_Country = results.FetchInt(1);
		iTotal_Country = results.FetchInt(2);
	}

	pack.Reset();
	pack.WriteCell(serial);
	pack.WriteCell(bIsSteamID);
	pack.WriteString(sSearch);
	pack.WriteString(sCountry);
	pack.WriteCell(iRank_Country);
	pack.WriteCell(iTotal_Country);

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), "SELECT s.name, s.accountid, s.steamid2, s.steamid64, s.last_updated, s.points, s.kills, s.deaths, s.assists, s.headshots, s.kdr, s.accuracy, s.playtime, s.weapons_statistics, (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank, (SELECT COUNT(*) as total FROM `%s`) as total FROM `%s` as s WHERE %s;", sTable, sTable, sTable, sSearchPost);
	g_Database_Server.Query(TQuery_PullMenuStatistics, sQuery, pack);
}

public void OnParseCountry_Online(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (results == null)
	{
		delete pack;
		ThrowError("Error while parsing target country for statistics: %s", error);
	}

	pack.Reset();

	int serial = pack.ReadCell();
	int serial2 = pack.ReadCell();

	delete pack;

	int client;
	if ((client = GetClientFromSerial(serial)) == 0)
		return;

	int target;
	if ((target = GetClientFromSerial(serial2)) == 0)
	{
		CPrintToChat(client, "Target is no longer available.");
		return;
	}

	char sName[MAX_NAME_LENGTH];
	GetClientName(target, sName, sizeof(sName));

	int iLastUpdated = g_iStatistics_Seasonal_LastUpdated[target];
	int iPoints = RoundToFloor(g_fStatistics_Seasonal_Points[target]);
	int iKills = g_iStatistics_Seasonal_Kills[target];
	int iDeaths = g_iStatistics_Seasonal_Deaths[target];
	int iAssists = g_iStatistics_Seasonal_Assists[target];
	int iHeadshots = g_iStatistics_Seasonal_Headshots[target];
	float fKDR = g_fStatistics_Seasonal_KDR[target];
	float fAccuracy = g_fStatistics_Seasonal_Accuracy[target];

	char sWeaponsData[WEAPON_STATISTICS_SIZE];
	json_encode(g_hStatistics_Seasonal_WeaponsStatistics[target], sWeaponsData, sizeof(sWeaponsData));

	int iRank = g_iCacheData_Rank[target];

	char sCountry[64];
	int iRank_Country;
	int iTotal_Country;

	if (results.FetchRow())
	{
		results.FetchString(0, sCountry, sizeof(sCountry));
		iRank_Country = results.FetchInt(1);
		iTotal_Country = results.FetchInt(2);
	}

	GenerateStatisticsMenu(client, target, sName, g_iCacheData_AccountID[client], g_sCacheData_SteamID2[client], g_sCacheData_SteamID64[client], iLastUpdated, iPoints, iKills, iDeaths, iAssists, iHeadshots, fKDR, fAccuracy, sWeaponsData, iRank, sCountry, iRank_Country, iTotal_Country);
}

public void TQuery_PullMenuStatistics(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (results == null)
	{
		delete pack;
		ThrowError("Error pulling client season statistics for display: %s", error);
	}

	pack.Reset();

	int client = GetClientFromSerial(pack.ReadCell());
	bool bIsSteamID = view_as<bool>(pack.ReadCell());

	char sSearch[64];
	pack.ReadString(sSearch, sizeof(sSearch));

	char sCountry[64];
	pack.ReadString(sCountry, sizeof(sCountry));

	int iRank_Country = pack.ReadCell();
	int iTotal_Country = pack.ReadCell();

	delete pack;

	if (client == 0)
		return;

	if (results == null)
	{
		CPrintToChat(client, "%T", bIsSteamID ? "steamid not in database" : "player not found", client, sSearch);
		return;
	}

	int iRows = results.RowCount;

	if (iRows == 0)
	{
		CPrintToChat(client, "%T", bIsSteamID ? "steamid not in database" : "player not found", client, sSearch);
		return;
	}
	else if (iRows > 1)
	{
		CPrintToChat(client, "%T", "found more than one", client, sSearch);
		return;
	}

	if (results.FetchRow())
	{
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, sizeof(sName));

		int iAccountID = results.FetchInt(1);

		char sSteamID2[64];
		results.FetchString(2, sSteamID2, sizeof(sSteamID2));

		char sSteamID64[64];
		results.FetchString(3, sSteamID64, sizeof(sSteamID64));

		int iLastUpdated = results.FetchInt(4);
		int iPoints = results.FetchInt(5);
		int iKills = results.FetchInt(6);
		int iDeaths = results.FetchInt(7);
		int iAssists = results.FetchInt(8);
		int iHeadshots = results.FetchInt(9);
		float fKDR = results.FetchFloat(10);
		float fAccuracy = results.FetchFloat(11);

		char sWeaponsData[WEAPON_STATISTICS_SIZE];
		results.FetchString(13, sWeaponsData, sizeof(sWeaponsData));

		int iRank = results.FetchInt(14);
		g_iCachedPlayers = results.FetchInt(15);

		GenerateStatisticsMenu(client, 0, sName, iAccountID, sSteamID2, sSteamID64, iLastUpdated, iPoints, iKills, iDeaths, iAssists, iHeadshots, fKDR, fAccuracy, sWeaponsData, iRank, sCountry, iRank_Country, iTotal_Country);
	}
}

void GenerateStatisticsMenu(int client, int target, const char[] sName, int iAccountID, const char[] sSteamID2, const char[] sSteamID64, int iLastUpdated, int iPoints, int iKills, int iDeaths, int iAssists, int iHeadshots, float fKDR, float fAccuracy, const char[] sWeaponsData, int iRank, const char[] sCountry, int iRank_Country, int iTotal_Country)
{
	char sFirstCreated[128];

	if (target > 0)
		FormatTime(sFirstCreated, sizeof(sFirstCreated), "%A, %B %d, %Y", g_iStatistics_Global_FirstCreated[target]);
	else
		FormatEx(sFirstCreated, sizeof(sFirstCreated), "Not Online");

	char sLastUpdated[128];
	FormatTime(sLastUpdated, sizeof(sLastUpdated), "%A, %B %d, %Y", iLastUpdated);

	float fTime;

	if (target > 0)
	{
		fTime = g_fStatistics_Global_Playtime[target] + GetClientTime(target);
		ShowStatsMenu(client, target, sName, iAccountID, sSteamID2, sSteamID64, sFirstCreated, sLastUpdated, fTime, iPoints, iKills, iDeaths, iAssists, iHeadshots, fKDR, fAccuracy, sWeaponsData, iRank, sCountry, iRank_Country, iTotal_Country);
	}
	else
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientSerial(client));
		pack.WriteString(sName);
		pack.WriteCell(iAccountID);
		pack.WriteString(sSteamID2);
		pack.WriteString(sSteamID64);
		pack.WriteString(sFirstCreated);
		pack.WriteString(sLastUpdated);
		pack.WriteCell(iPoints);
		pack.WriteCell(iKills);
		pack.WriteCell(iDeaths);
		pack.WriteCell(iAssists);
		pack.WriteCell(iHeadshots);
		pack.WriteFloat(fKDR);
		pack.WriteFloat(fAccuracy);
		pack.WriteString(sWeaponsData);
		pack.WriteCell(iRank);
		pack.WriteString(sCountry);
		pack.WriteCell(iRank_Country);
		pack.WriteCell(iTotal_Country);

		char sTable[MAX_TABLE_SIZE];
		convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

		char sQuery[MAX_QUERY_SIZE];
		g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT `playtime` FROM `%s` WHERE `steamid2` = '%s';", sTable, sSteamID2);
		g_Database_Global.Query(TQuery_PullMenuPlaytime, sQuery, pack);
	}
}

public void TQuery_PullMenuPlaytime(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		delete data;
		ThrowError("Error pulling client global playtime for display: %s", error);
	}

	data.Reset();

	int client = GetClientFromSerial(data.ReadCell());

	char sName[MAX_NAME_LENGTH];
	data.ReadString(sName, sizeof(sName));

	int iAccountID = data.ReadCell();

	char sSteamID2[64];
	data.ReadString(sSteamID2, sizeof(sSteamID2));

	char sSteamID64[64];
	data.ReadString(sSteamID64, sizeof(sSteamID64));

	char sFirstCreated[128];
	data.ReadString(sFirstCreated, sizeof(sFirstCreated));

	char sLastUpdated[128];
	data.ReadString(sLastUpdated, sizeof(sLastUpdated));

	int iPoints = data.ReadCell();
	int iKills = data.ReadCell();
	int iDeaths = data.ReadCell();
	int iAssists = data.ReadCell();
	int iHeadshots = data.ReadCell();
	float fKDR = data.ReadFloat();
	float fAccuracy = data.ReadFloat();

	char sWeaponsData[WEAPON_STATISTICS_SIZE];
	data.ReadString(sWeaponsData, sizeof(sWeaponsData));

	int iRank = data.ReadCell();

	char sCountry[64];
	data.ReadString(sCountry, sizeof(sCountry));

	int iRank_Country = data.ReadCell();
	int iTotal_Country = data.ReadCell();

	if (client == 0)
		return;

	if (results.FetchRow())
	{
		float fTime = results.FetchFloat(0);
		ShowStatsMenu(client, client, sName, iAccountID, sSteamID2, sSteamID64, sFirstCreated, sLastUpdated, fTime, iPoints, iKills, iDeaths, iAssists, iHeadshots, fKDR, fAccuracy, sWeaponsData, iRank, sCountry, iRank_Country, iTotal_Country);
	}
}

void ShowStatsMenu(int client, int target = 0, const char[] sName, int iAccountID, const char[] sSteamID2, const char[] sSteamID64, const char[] sFirstCreated, const char[] sLastUpdated, float fTime, int iPoints, int iKills, int iDeaths, int iAssists, int iHeadshots, float fKDR, float fAccuracy, const char[] sWeaponsData, int iRank, const char[] sCountry, int iRank_Country, int iTotal_Country)
{
	char sPlaytime[128];
	FormatSeconds(fTime, sPlaytime, sizeof(sPlaytime), "%D days %H hours %M minutes");

	delete g_StatisticsMenu[client];
	g_StatisticsMenu[client] = new Menu(MenuHandle_Statistics, MenuAction_Select | MenuAction_Cancel | MenuAction_End | MenuAction_DrawItem | MenuAction_DisplayItem);
	g_StatisticsMenu[client].SetTitle("%s\n%s\nCountry: %s\nFirst Seen: %s\nLast Seen: %s\nTotal Playtime: %s\n \n", sName, sSteamID2, sCountry, sFirstCreated, sLastUpdated, sPlaytime);

	g_StatisticsMenu[client].AddItem("season", "Season Stats");
	g_StatisticsMenu[client].AddItem("session", "Session Stats");
	g_StatisticsMenu[client].AddItem("weapon", "Weapon Stats");

	PushMenuInt(g_StatisticsMenu[client], "target", (target > 0) ? GetClientSerial(target) : 0);
	PushMenuString(g_StatisticsMenu[client], "name", sName);
	PushMenuInt(g_StatisticsMenu[client], "accountid", iAccountID);
	PushMenuString(g_StatisticsMenu[client], "steamid2", sSteamID2);
	PushMenuString(g_StatisticsMenu[client], "steamid64", sSteamID64);
	PushMenuInt(g_StatisticsMenu[client], "points", iPoints);
	PushMenuInt(g_StatisticsMenu[client], "kills", iKills);
	PushMenuInt(g_StatisticsMenu[client], "deaths", iDeaths);
	PushMenuInt(g_StatisticsMenu[client], "assists", iAssists);
	PushMenuInt(g_StatisticsMenu[client], "headshots", iHeadshots);
	PushMenuFloat(g_StatisticsMenu[client], "kdr", fKDR);
	PushMenuFloat(g_StatisticsMenu[client], "accuracy", fAccuracy);
	PushMenuString(g_StatisticsMenu[client], "weapons_statistics", sWeaponsData);
	PushMenuInt(g_StatisticsMenu[client], "rank", iRank);
	PushMenuString(g_StatisticsMenu[client], "country", sCountry);
	PushMenuInt(g_StatisticsMenu[client], "rank_country", iRank_Country);
	PushMenuInt(g_StatisticsMenu[client], "total_country", iTotal_Country);

	g_StatisticsMenu[client].Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_Statistics(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			char sInfo[32]; int style;
			menu.GetItem(param2, sInfo, sizeof(sInfo), style);

			int target = GetClientFromSerial(GetMenuInt(menu, "target"));

			return (StrEqual(sInfo, "session") && target < 0) ? ITEMDRAW_DISABLED : style;
		}
		case MenuAction_DisplayItem:
		{
			char sInfo[32]; char sDisplay[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			char sItemDisplay[512];
			if (StrEqual(sInfo, "season"))
			{
				int iRank = GetMenuInt(menu, "rank");
				int iPoints = GetMenuInt(menu, "points");
				int iKills = GetMenuInt(menu, "kills");
				int iDeaths = GetMenuInt(menu, "deaths");
				int iAssists = GetMenuInt(menu, "assists");
				int iHeadshots = GetMenuInt(menu, "headshots");
				int iRank_Country = GetMenuInt(menu, "rank_country");
				float fKDR = GetMenuFloat(menu, "kdr");
				float fAccuracy = GetMenuFloat(menu, "accuracy");

				char sCountry[64];
				GetMenuString(menu, "country", sCountry, sizeof(sCountry));

				float session = GetClientTime(param1);
				float season_time = g_fStatistics_Seasonal_Playtime[param1] + session;

				char sSeasonTime[128];
				FormatSeconds(season_time, sSeasonTime, sizeof(sSeasonTime), "%D days %H hours %M minutes");

				char sSeasonStats[256];
				int cells = Format(sSeasonStats, sizeof(sSeasonStats), "Season %d Stats\nPlaytime: %s\nRank: %i Server | %i %s\nPoints: %i\nKills: %i | Deaths: %i\nKDR: %.2f\nAccuracy: %.2f\nHeadshots: %i | Assists: %i",
					g_iSeason,
					sSeasonTime,
					iRank,
					iRank_Country,
					sCountry,
					iPoints,
					iKills,
					iDeaths,
					fKDR,
					fAccuracy,
					iHeadshots,
					iAssists);

				Call_StartForward(g_Forward_StatsMe_OnSeasonStats);
				Call_PushCell(param1);
				Call_PushStringEx(sSeasonStats, sizeof(sSeasonStats), SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
				Call_PushCell(sizeof(sSeasonStats));
				Call_PushCellRef(cells);
				Call_Finish();

				FormatEx(sItemDisplay, sizeof(sItemDisplay), "%s", g_bToggleStatistics[param1] ? "Season Stats" : sSeasonStats);
				return RedrawMenuItem(sItemDisplay);
			}
			else if (StrEqual(sInfo, "session"))
			{
				int target;
				if ((target = GetClientFromSerial(GetMenuInt(menu, "target"))) == 0)
				{
					g_StatisticsMenu[param1].Display(param1, MENU_TIME_FOREVER);
					return 0;
				}

				char sSessionStats[256];
				Format(sSessionStats, sizeof(sSessionStats), "Session Stats\nRanks Gained: %i\nPoints Gained: %i\nKills: %i | Deaths: %i\nAssists: %i\nKDR: %.2f\nHeadshots: %i\nAccuracy: %.2f", g_iStatistics_Sessionbased_RanksGained[target], RoundToFloor(g_fStatistics_Sessionbased_PointsGained[target]), g_iStatistics_Sessionbased_Kills[target], g_iStatistics_Sessionbased_Deaths[target], g_iStatistics_Sessionbased_Assists[target], g_fStatistics_Sessionbased_KDR[target], g_iStatistics_Sessionbased_Headshots[target], g_fStatistics_Sessionbased_Accuracy[target]);

				FormatEx(sItemDisplay, sizeof(sItemDisplay), "%s", !g_bToggleStatistics[param1] ? "Session Stats" : sSessionStats);
				return RedrawMenuItem(sItemDisplay);
			}
		}
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[32]; char sDisplay[32];
			menu.GetItem(param2, sInfo, sizeof(sInfo), _, sDisplay, sizeof(sDisplay));

			if (StrEqual(sInfo, "season"))
			{
				g_bToggleStatistics[param1] = false;
				g_StatisticsMenu[param1].Display(param1, MENU_TIME_FOREVER);
			}
			else if (StrEqual(sInfo, "session"))
			{
				g_bToggleStatistics[param1] = true;
				g_StatisticsMenu[param1].Display(param1, MENU_TIME_FOREVER);
			}
			else if (StrEqual(sInfo, "weapon"))
			{
				char sName[MAX_NAME_LENGTH];
				GetMenuString(menu, "name", sName, sizeof(sName));

				char sWeaponsData[WEAPON_STATISTICS_SIZE];
				GetMenuString(menu, "weapons_statistics", sWeaponsData, sizeof(sWeaponsData));

				DisplayWeaponStats(param1, sName, sWeaponsData, true);
			}
		}
	}

	return 0;
}

void DisplayWeaponStats(int client, const char[] name, const char[] json_data, bool info = false)
{
	Menu menu = new Menu(MenuHandle_WeaponStatistics);
	menu.SetTitle("%s Weapon Stats\n\n ", name);

	JSON_Object hJSON = json_decode(json_data);

	if (hJSON == null)
	{
		delete menu;

		if (info && g_StatisticsMenu[client] != null)
			g_StatisticsMenu[client].Display(client, MENU_TIME_FOREVER);

		return;
	}

	char sWeapon[MAX_NAME_LENGTH]; char sDisplay[MAX_NAME_LENGTH]; JSON_Object hWeaponObject;
	for (int i = 0; i < g_WeaponsList.Length; i++)
	{
		g_WeaponsList.GetString(i, sWeapon, sizeof(sWeapon));

		hWeaponObject = hJSON.GetObject(sWeapon);

		if (hWeaponObject == null)
			continue;

		strcopy(sDisplay, sizeof(sDisplay), sWeapon);
		ReplaceString(sDisplay, sizeof(sDisplay), "weapon_", "");
		sDisplay[0] = CharToUpper(sDisplay[0]);

		menu.AddItem(sWeapon, sDisplay);
	}

	//This cleans up the hWeaponObject handles as well. (See line 694 in json.inc)
	hJSON.Cleanup();
	delete hJSON;

	if (menu.ItemCount == 0)
		menu.AddItem("", "[No Data Available]", ITEMDRAW_DISABLED);

	PushMenuString(menu, "name", name);
	PushMenuString(menu, "json_data", json_data);
	PushMenuInt(menu, "info", info);

	menu.ExitBackButton = info;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_WeaponStatistics(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sWeapon[MAX_NAME_LENGTH];
			menu.GetItem(param2, sWeapon, sizeof(sWeapon));

			char name[MAX_NAME_LENGTH];
			GetMenuString(menu, "name", name, sizeof(name));

			char json_data[WEAPON_STATISTICS_SIZE];
			GetMenuString(menu, "json_data", json_data, sizeof(json_data));

			bool info = view_as<bool>(GetMenuInt(menu, "info"));

			OpenWeaponStatisticsMenu(param1, sWeapon, name, json_data, info);
		}

		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				g_StatisticsMenu[param1].Display(param1, MENU_TIME_FOREVER);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

//TODO: Save cached weapons data globally for all menus to use.
enum struct WeaponsData
{
	char name[MAX_NAME_LENGTH];
	char data[WEAPON_STATISTICS_SIZE];
	bool info;
}

WeaponsData g_WeaponsData[MAXPLAYERS + 1];

void OpenWeaponStatisticsMenu(int client, const char[] weapon, const char[] name, const char[] json_data, bool info)
{
	char sDisplay[MAX_NAME_LENGTH];
	strcopy(sDisplay, sizeof(sDisplay), weapon);
	ReplaceString(sDisplay, sizeof(sDisplay), "weapon_", "");
	sDisplay[0] = CharToUpper(sDisplay[0]);

	char sTitle[256];
	FormatEx(sTitle, sizeof(sTitle), "%s Weapon Stats\n➥ %s\n ", name, sDisplay);

	Panel menu = new Panel();
	menu.SetTitle(sTitle);

	JSON_Object hJSON = json_decode(json_data);

	if (hJSON == null)
	{
		delete menu;

		if (info && g_StatisticsMenu[client] != null)
			g_StatisticsMenu[client].Display(client, MENU_TIME_FOREVER);

		return;
	}

	JSON_Object hWeaponObject = hJSON.GetObject(weapon);

	if (hWeaponObject == null)
	{
		delete menu;

		if (info && g_StatisticsMenu[client] != null)
			g_StatisticsMenu[client].Display(client, MENU_TIME_FOREVER);

		return;
	}

	int kills = hWeaponObject.GetInt("kills");
	int hits = hWeaponObject.GetInt("hits");
	int shots = hWeaponObject.GetInt("shots");

	//This cleans up the hWeaponObject handles as well. (See line 694 in json.inc)
	hJSON.Cleanup();
	delete hJSON;

	char sItem[256];
	FormatEx(sItem, sizeof(sItem), "Kills: %i\n ", kills);
	menu.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Accuracy: %i%%\n ", RoundFloat(CalculateAccuracy(hits, shots)));
	menu.DrawText(sItem);

	FormatEx(sItem, sizeof(sItem), "Hits: %i | Shots: %i\n ", hits, shots);
	menu.DrawText(sItem);

	menu.DrawItem("Back\n ");
	menu.DrawItem("Exit");

	strcopy(g_WeaponsData[client].name, MAX_NAME_LENGTH, name);
	strcopy(g_WeaponsData[client].data, WEAPON_STATISTICS_SIZE, json_data);
	g_WeaponsData[client].info = info;

	menu.Send(client, MenuHandler_WeaponStatistics, MENU_TIME_FOREVER);
}

public int MenuHandler_WeaponStatistics(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (param2 == 1)
			{
				char name[MAX_NAME_LENGTH];
				strcopy(name, sizeof(name), g_WeaponsData[param1].name);

				char json_data[WEAPON_STATISTICS_SIZE];
				strcopy(json_data, sizeof(json_data), g_WeaponsData[param1].data);

				bool info = g_WeaponsData[param1].info;

				DisplayWeaponStats(param1, name, json_data, info);
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

public Action Command_OpenTopRanksMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	int iAmount = 10;

	char sArg[12];
	GetCmdArgString(sArg, sizeof(sArg));

	if (strlen(sArg) > 0)
		iAmount = StringToInt(sArg);

	if (iAmount > 50)
		iAmount = 50;

	DisplayTopRanksMenu(client, iAmount);
	return Plugin_Handled;
}

void DisplayTopRanksMenu(int client, int amount)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || amount == 0 || amount > 50)
		return;

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(amount);

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `name`, `steamid2`, `kdr`, `points` FROM `%s` ORDER BY `points` DESC LIMIT 0,%i;", sTable, amount);
	g_Database_Server.Query(TQuery_DisplayTopRanksMenu, sQuery, pack);
}

public void TQuery_DisplayTopRanksMenu(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		delete data;
		ThrowError("Error on pulling ranks data to show top menu: %s", error);
	}

	data.Reset();

	int client = GetClientFromSerial(data.ReadCell());
	int amount = data.ReadCell();

	delete data;

	if (client == 0)
		return;

	Menu menu = new Menu(MenuHandle_DisplayTopRanksMenu);
	menu.SetTitle("Top %i ranks:", amount);

	char sDisplay[256];
	while (results.FetchRow())
	{
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, sizeof(sName));

		char sSteamID2[64];
		results.FetchString(1, sSteamID2, sizeof(sSteamID2));

		float fKDR = results.FetchFloat(2);
		int iPoints = results.FetchInt(3);

		FormatEx(sDisplay, sizeof(sDisplay), "%s - Points: %i (KDR %.2f)", sName, iPoints, fKDR);
		menu.AddItem(sSteamID2, sDisplay);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandle_DisplayTopRanksMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!convar_Status.BoolValue)
				return 0;

			char sInfo[64];
			menu.GetItem(param2, sInfo, sizeof(sInfo));

			ShowStatisticsMenu(param1, sInfo);
		}

		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

public Action Command_TimePlayed(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	int time = GetTime();

	if (g_iCooldown[client] > time)
	{
		CPrintToChat(client, "Please wait a couple seconds before using this command again.");
		return Plugin_Handled;
	}

	if (args == 0)
	{
		float session = GetClientTime(client);
		float total_time = g_fStatistics_Global_Playtime[client] + session;

		char sTotalTime[128];
		FormatSeconds(total_time, sTotalTime, sizeof(sTotalTime), "%D days %H hours %M minutes");

		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		CPrintToChatAll("%t", "time played", sName, sTotalTime);
		g_iCooldown[client] = time + 3;

		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArgString(sTarget, sizeof(sTarget));
	int target = FindTargetEx(client, sTarget, true, false);

	if (target > 0)
	{
		float session = GetClientTime(target);
		float season_time = g_fStatistics_Seasonal_Playtime[target] + session;

		char sSeasonTime[128];
		FormatSeconds(season_time, sSeasonTime, sizeof(sSeasonTime), "%D days %H hours %M minutes");

		char sName[MAX_NAME_LENGTH];
		GetClientName(target, sName, sizeof(sName));

		CPrintToChatAll("%t", "time played", sName, sSeasonTime);
		g_iCooldown[client] = time + 3;

		return Plugin_Handled;
	}

	char sSearch[512];

	if (IsStringNumeric(sTarget))
		g_Database_Global.Format(sSearch, sizeof(sSearch), "`%s` = '%i'", strlen(sTarget) > 10 ? "steamid64" : "accountid", StringToInt(sTarget));
	else if (StrContains(sTarget, "STEAM_", false) == 0)
		g_Database_Global.Format(sSearch, sizeof(sSearch), "`steamid2` = '%s'", sTarget);
	else
		g_Database_Global.Format(sSearch, sizeof(sSearch), "`name` = '%s'", sTarget);

	char sTable[MAX_TABLE_SIZE];
	char sQuery[MAX_QUERY_SIZE];

	GetTableString_Season(sTable, sizeof(sTable));
	Format(sQuery, sizeof(sQuery), "SELECT `name`, `playtime` FROM `%s` WHERE %s;", sTable, sSearch);
	g_Database_Server.Query(TQuery_OnParsePlaytime, sQuery, GetClientSerial(client));

	g_iCooldown[client] = time + 3;

	return Plugin_Handled;
}

public void TQuery_OnParsePlaytime(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
	{
		int client;
		if ((client = GetClientFromSerial(data)) > 0)
			CPrintToChat(client, "%T", "profile target not found", client);

		ThrowError("Error displaying target playtime to client: %s", error);
	}

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	if (results.RowCount == 0)
	{
		CPrintToChat(client, "%T", "profile target not found", client);
		return;
	}

	if (results.FetchRow())
	{
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, sizeof(sName));

		float playtime = results.FetchFloat(1);

		char sSeasonTime[128];
		FormatSeconds(playtime, sSeasonTime, sizeof(sSeasonTime), "%D days %H hours %M minutes");

		CPrintToChatAll("%t", "time played", sName, sSeasonTime);
	}
}

public Action Command_OpenWeaponsMenu(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	char sSearch[64];
	GetCmdArg(1, sSearch, sizeof(sSearch));

	if (args == 0 || strlen(sSearch) == 0)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(client, sName, sizeof(sName));

		char sWeaponsData[WEAPON_STATISTICS_SIZE];
		g_hStatistics_Seasonal_WeaponsStatistics[client].Encode(sWeaponsData, sizeof(sWeaponsData));

		DisplayWeaponStats(client, sName, sWeaponsData);

		return Plugin_Handled;
	}

	int target = FindTargetEx(client, sSearch, true, false);

	int size = 2 * strlen(sSearch) + 1;
	char[] sSearchE = new char[size];
	g_Database_Global.Escape(sSearch, sSearchE, size);

	bool bIsSteamID = StrContains(sSearch, "STEAM_") != -1;

	char sSearchBuffer[128];
	Format(sSearchBuffer, sizeof(sSearchBuffer), bIsSteamID ? "`steamid2` = '%s'" : "`name` LIKE '%%%s%%'", sSearchE);

	if (target > 0)
	{
		char sName[MAX_NAME_LENGTH];
		GetClientName(target, sName, sizeof(sName));

		char sWeaponsData[WEAPON_STATISTICS_SIZE];
		g_hStatistics_Seasonal_WeaponsStatistics[target].Encode(sWeaponsData, sizeof(sWeaponsData));

		DisplayWeaponStats(client, sName, sWeaponsData);
	}
	else
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientSerial(client));
		pack.WriteCell(bIsSteamID);
		pack.WriteString(sSearchE);

		char sTable[MAX_TABLE_SIZE];
		GetTableString_Season(sTable, sizeof(sTable));

		char sQuery[MAX_QUERY_SIZE];
		Format(sQuery, sizeof(sQuery), "SELECT `name`, `weapons_statistics` FROM `%s` WHERE %s;", sTable, sSearchBuffer);
		g_Database_Server.Query(TQuery_PullWeaponStatistics, sQuery, pack);
	}

	return Plugin_Handled;
}

public void TQuery_PullWeaponStatistics(Database db, DBResultSet results, const char[] error, any data)
{
	DataPack pack = view_as<DataPack>(data);
	pack.Reset();

	int client = GetClientFromSerial(pack.ReadCell());

	bool bIsSteamID = pack.ReadCell();

	char sSearch[64];
	pack.ReadString(sSearch, sizeof(sSearch));

	delete pack;

	if (!client)
	{
		return;
	}

	if (results == null)
	{
		CPrintToChat(client, "%T", bIsSteamID ? "steamid not in database" : "player not found", client, sSearch);
		return;
	}

	int iRows = results.RowCount;

	if (iRows == 0)
	{
		CPrintToChat(client, "%T", bIsSteamID ? "steamid not in database" : "player not found", client, sSearch);
		return;
	}
	else if (iRows > 1)
	{
		CPrintToChat(client, "%T", "found more than one", client, sSearch);
		return;
	}

	if (results.FetchRow())
	{
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, sizeof(sName));

		char sWeaponsData[WEAPON_STATISTICS_SIZE];
		results.FetchString(1, sWeaponsData, sizeof(sWeaponsData));

		DisplayWeaponStats(client, sName, sWeaponsData);
	}
}

public Action Command_SwitchToSpectate(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (IsClientInGame(client) && GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		CPrintToChat(client, "%T", "moved to spectate", client);

		if (GetAlivePlayers(GetClientTeam(client)) == 1 && g_bActiveSeason)
		{
			g_fStatistics_Global_Points[client] -= g_fCacheData_PointsLoss[client];

			g_fStatistics_Seasonal_Points[client] -= g_fCacheData_PointsLoss[client];

			g_fStatistics_Mapbased_Points[client] -= g_fCacheData_PointsLoss[client];

			g_fStatistics_Sessionbased_PointsLost[client] += g_fCacheData_PointsLoss[client];
		}
	}

	return Plugin_Handled;
}

int GetAlivePlayers(int team = 0)
{
	int count;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || (team > 0 && GetClientTeam(i) != team))
			continue;

		count++;
	}

	return count;
}

public Action Command_TopTime(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	int time = GetTime();

	if (g_iCooldown[client] > time)
	{
		CPrintToChat(client, "Please wait a couple seconds before using this command again.");
		return Plugin_Handled;
	}

	char sTable[MAX_TABLE_SIZE];
	char sQuery[MAX_QUERY_SIZE];

	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));
	g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT `name`, `playtime` FROM `%s` ORDER BY `playtime` DESC LIMIT 10", sTable);

	g_Database_Global.Query(TQuery_TopTime, sQuery, GetClientSerial(client));

	return Plugin_Handled;
}

public void TQuery_TopTime(Database db, DBResultSet results, const char[] error, any serial)
{
	int client = GetClientFromSerial(serial);
	if (!client)
		return;

	Menu menu = new Menu(MH_TopTime);
	menu.ExitButton = false;
	menu.ExitBackButton = false;

	int i = 1;
	char sTitle[2048];

	strcopy(sTitle, sizeof(sTitle), "Players with most time\n(All Furious servers combined)\n ");

	while (results.FetchRow())
	{
		char sName[128];
		int iTime;

		results.FetchString(0, sName, sizeof(sName));
		iTime = results.FetchInt(1);

		int iDays, iHours, iMinutes;
		FormatSeconds2(iTime, iDays, iHours, iMinutes);

		Format(sTitle, sizeof(sTitle), "%s\n%i. %s - %id %ih %im", sTitle, i, sName, iDays, iHours, iMinutes);
		++i;
	}

	Format(sTitle, sizeof(sTitle), "%s\n ", sTitle);

	menu.SetTitle(sTitle);

	menu.AddItem("", "Exit");
	menu.AddItem("", "Show top 10 ranks");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MH_TopTime(Menu menu, MenuAction action, int arg1, int arg2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			switch (arg2)
			{
				case 1:DisplayTopRanksMenu(arg1, 10);
			}
		}
		case MenuAction_End:delete menu;
	}

	return 0;
}

void ParseRanksConfig()
{
	char sConfig[PLATFORM_MAX_PATH];
	convar_Config_Ranks.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_ranks");

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		ClearTrieSafe(g_RanksData);
		g_RanksList.Clear();

		char sRank[64]; char sKey[64]; char sValue[PLATFORM_MAX_PATH];
		do
		{
			kv.GetSectionName(sRank, sizeof(sRank));

			if (strlen(sRank) > 0 && kv.GotoFirstSubKey(false))
			{
				StringMap local_trie = new StringMap();

				do
				{
					kv.GetSectionName(sKey, sizeof(sKey));
					kv.GetString(NULL_STRING, sValue, sizeof(sValue));

					local_trie.SetString(sKey, sValue);

					if (StrEqual(sKey, "sound") && strlen(sValue) > 0)
					{
						PrecacheSound(sValue);

						if (StrContains(sValue, "sound/") != 0)
							Format(sValue, sizeof(sValue), "sound/%s", sValue);

						AddFileToDownloadsTable(sValue);
					}

				}
				while (kv.GotoNextKey(false));

				g_RanksData.SetValue(sRank, local_trie);
				g_RanksList.Push(StringToInt(sRank));

				kv.GoBack();
			}
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Ranks config parsed. [%i sections loaded]", g_RanksList.Length);
	delete kv;
}

void SaveDeathStatistics(int client)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		return;

	if (g_iLoadedStats[client] < 4)
		return;

	char sTable[MAX_TABLE_SIZE];
	char sQuery[MAX_QUERY_SIZE];
	Transaction trans = new Transaction();

	int iAccountID = g_iCacheData_AccountID[client];

	GetTableString_Season(sTable, sizeof(sTable));
	g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `deaths` = '%i', `kdr` = '%f' WHERE `accountid` = '%i';",
		sTable,
		g_iStatistics_Seasonal_Deaths[client],
		g_fStatistics_Seasonal_KDR[client],
		iAccountID);
	trans.AddQuery(sQuery);

	GetTableString_Maps(sTable, sizeof(sTable));
	g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `deaths` = '%i', `kdr` = '%f' WHERE `accountid` = '%i';",
		sTable,
		g_iStatistics_Mapbased_Deaths[client],
		g_fStatistics_Mapbased_KDR[client],
		iAccountID);
	trans.AddQuery(sQuery);

	g_Database_Server.Execute(trans, Transaction_OnUpdateClientDeaths_Success, Transaction_OnUpdateClientDeaths_Failure);
}

public void Transaction_OnUpdateClientDeaths_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{

}

public void Transaction_OnUpdateClientDeaths_Failure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	ThrowError("Error updating client deaths: [%i] %s", failIndex, error);
}

void UpdateClientPositions(int client, bool bOverlay = true)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client) || IsFakeClient(client))
		return;

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	int iAccountID = g_iCacheData_AccountID[client];

	char sQuery[MAX_QUERY_SIZE];
	Transaction trans = new Transaction();

	g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `kills` = '%i', `points` = '%f', `kdr` = '%f' WHERE `accountid` = '%i';",
		sTable,
		g_iStatistics_Seasonal_Kills[client],
		g_fStatistics_Seasonal_Points[client],
		g_fStatistics_Seasonal_KDR[client],
		iAccountID);
	trans.AddQuery(sQuery);

	g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT s.points, (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank, (SELECT COUNT(*) as total FROM `%s`) as total FROM `%s` as s WHERE s.accountid = '%i';",
		sTable,
		sTable,
		sTable,
		iAccountID);
	trans.AddQuery(sQuery);

	DataPack dPack = new DataPack();
	WritePackCell(dPack, GetClientSerial(client));
	WritePackCell(dPack, bOverlay);

	g_Database_Server.Execute(trans, Transaction_OnUpdateClientRank_Success, Transaction_OnUpdateClientRank_Failure, dPack);
}

public void Transaction_OnUpdateClientRank_Success(Database db, DataPack data, int numQueries, DBResultSet[] results, any[] queryData)
{
	data.Reset();

	int client = GetClientFromSerial(data.ReadCell());
	bool bOverlay = view_as<bool>(data.ReadCell());

	delete data;

	if (client == 0)
		return;

	if (results[1] != null && results[1].FetchRow())
	{
		int iPoints = results[1].FetchInt(0);
		int iCurrentRank = results[1].FetchInt(1);
		g_iCachedPlayers = results[1].FetchInt(2);

		StringMap overlay_data;
		CalculateRank(iCurrentRank, overlay_data);

		if (iCurrentRank < g_iCacheData_Rank[client])
		{
			if (bOverlay)
			{
				if (overlay_data != null)
					ShowClientOverlay(client, OVERLAY_RANKUP, 3.0, overlay_data, iCurrentRank);
				else
					LogError("Invalid Overlay data handle for client %N.", client);
			}

			g_iStatistics_Sessionbased_RanksGained[client] += (g_iCacheData_Rank[client] - iCurrentRank);
		}
		else if (iCurrentRank > g_iCacheData_Rank[client])
		{
			g_iStatistics_Sessionbased_RanksLost[client] += (iCurrentRank - g_iCacheData_Rank[client]);
		}

		g_iCacheData_Rank[client] = iCurrentRank;

		overlay_data = null;
		int iNewTier = CalculateTier(iPoints, overlay_data);

		if (g_iCacheData_Tier[client] < iNewTier)
		{
			g_iCacheData_Tier[client] = iNewTier;

			if (overlay_data != null)
			{
				char sTag[128];
				GetTrieString(overlay_data, "tag", sTag, sizeof(sTag));
				strcopy(g_sCacheData_TierTag[client], 512, sTag);

				char sPointsPerKill[PLATFORM_MAX_PATH];
				GetTrieString(overlay_data, "points_per_kill", sPointsPerKill, sizeof(sPointsPerKill));

				char sPointsPerDeath[PLATFORM_MAX_PATH];
				GetTrieString(overlay_data, "points_per_death", sPointsPerDeath, sizeof(sPointsPerDeath));

				g_fCacheData_PointsGain[client] = StringToFloat(sPointsPerKill);
				g_fCacheData_PointsLoss[client] = StringToFloat(sPointsPerDeath);

				CPrintToChat(client, "%t", "tier up", sTag, RoundToFloor(g_fCacheData_PointsGain[client]), RoundToFloor(g_fCacheData_PointsLoss[client]));

				char sTable[MAX_TABLE_SIZE];
				GetTableString_Season(sTable, sizeof(sTable));

				char sQuery[MAX_QUERY_SIZE];
				g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `steamid64` FROM `%s` ORDER BY `points` DESC LIMIT 10;", sTable);
				g_Database_Server.Query(TQuery_CheckTopTen, sQuery, GetClientSerial(client));
			}

			if (bOverlay)
				ShowClientOverlay(client, OVERLAY_TIERUP, 3.0, overlay_data, g_iCacheData_Tier[client]);
		}

		else if (g_iCacheData_Tier[client] > iNewTier)
		{
			g_iCacheData_Tier[client] = iNewTier;

			if (overlay_data != null)
			{
				char sTag[128];
				GetTrieString(overlay_data, "tag", sTag, sizeof(sTag));
				strcopy(g_sCacheData_TierTag[client], 512, sTag);

				char sPointsPerKill[PLATFORM_MAX_PATH];
				GetTrieString(overlay_data, "points_per_kill", sPointsPerKill, sizeof(sPointsPerKill));

				char sPointsPerDeath[PLATFORM_MAX_PATH];
				GetTrieString(overlay_data, "points_per_death", sPointsPerDeath, sizeof(sPointsPerDeath));

				g_fCacheData_PointsGain[client] = StringToFloat(sPointsPerKill);
				g_fCacheData_PointsLoss[client] = StringToFloat(sPointsPerDeath);

				CPrintToChat(client, "%T", "tier down", client, g_iCacheData_Tier[client], RoundToFloor(g_fCacheData_PointsGain[client]), RoundToFloor(g_fCacheData_PointsLoss[client]));
			}
		}
	}
}

public void TQuery_CheckTopTen(Database db, DBResultSet results, const char[] error, any serial)
{
	int client = GetClientFromSerial(serial);

	if (!client)
		return;

	while (results.FetchRow())
	{
		char sSteam64[2][32];
		results.FetchString(0, sSteam64[0], sizeof(sSteam64[]));


		GetClientAuthId(client, AuthId_SteamID64, sSteam64[1], sizeof(sSteam64[]));

		if (StrEqual(sSteam64[0], sSteam64[1]))
		{
			CPrintToChatAll("%t", "tier up allchat", client, g_sCacheData_TierTag[client]);
			return;
		}
	}
}

public void Transaction_OnUpdateClientRank_Failure(Database db, DataPack data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	delete data;
	ThrowError("Error updating client ranking and tier: [%i] %s", failIndex, error);
}

void ShowClientOverlay(int client, int overlay, float timer = 3.0, StringMap local_trie = null, int data = -1)
{
	char sOverlay[PLATFORM_MAX_PATH];
	char sTextCenter[256];
	char sTextHint[256];
	char sTextPrint[256];
	char sSound[PLATFORM_MAX_PATH];

	switch (overlay)
	{
		case OVERLAY_RAMPAGE:
		{
			convar_Rampage_Overlay.GetString(sOverlay, sizeof(sOverlay));
			FormatEx(sTextHint, sizeof(sTextHint), "%t", "rampage center text", client);
			FormatEx(sTextPrint, sizeof(sTextPrint), "%t", "rampage on", client);
			convar_Sound_Rampage.GetString(sSound, sizeof(sSound));
		}

		case OVERLAY_RANKUP:
		{
			if (local_trie == null)
				ThrowError("Error showing rankup overlay: invalid local handle");

			local_trie.GetString("overlay", sOverlay, sizeof(sOverlay));
			local_trie.GetString("text_center", sTextCenter, sizeof(sTextCenter));
			local_trie.GetString("text_hint", sTextHint, sizeof(sTextHint));
			local_trie.GetString("text_print", sTextPrint, sizeof(sTextPrint));
			local_trie.GetString("sound", sSound, sizeof(sSound));

			if (data != -1)
			{
				char sRank[32];
				IntToString(data, sRank, sizeof(sRank));
				ReplaceString(sTextCenter, sizeof(sTextCenter), "{RANK}", sRank);
				ReplaceString(sTextHint, sizeof(sTextHint), "{RANK}", sRank);
				ReplaceString(sTextPrint, sizeof(sTextPrint), "{RANK}", sRank);
			}
		}

		case OVERLAY_TIERUP:
		{
			if (local_trie == null)
				ThrowError("Error showing tierup overlay: invalid local handle");

			local_trie.GetString("overlay", sOverlay, sizeof(sOverlay));
			local_trie.GetString("text_center", sTextCenter, sizeof(sTextCenter));
			local_trie.GetString("text_hint", sTextHint, sizeof(sTextHint));
			local_trie.GetString("text_print", sTextPrint, sizeof(sTextPrint));
			local_trie.GetString("sound", sSound, sizeof(sSound));

			if (data != -1)
			{
				char sTier[32];
				IntToString(data, sTier, sizeof(sTier));
				ReplaceString(sTextCenter, sizeof(sTextCenter), "{TIER}", sTier);
				ReplaceString(sTextHint, sizeof(sTextHint), "{TIER}", sTier);
				ReplaceString(sTextPrint, sizeof(sTextPrint), "{TIER}", sTier);
			}
		}
	}

	DataPack pack = new DataPack();
	CreateDataTimer(timer, Timer_DisplayOverlayToClient, pack, TIMER_FLAG_NO_MAPCHANGE);
	WritePackCell(pack, GetClientSerial(client));
	WritePackString(pack, sOverlay);
	WritePackString(pack, sTextCenter);
	WritePackString(pack, sTextHint);
	WritePackString(pack, sTextPrint);
	WritePackString(pack, sSound);
}

public Action Timer_DisplayOverlayToClient(Handle timer, DataPack data)
{
	data.Reset();

	int client = GetClientFromSerial(data.ReadCell());

	char sOverlay[PLATFORM_MAX_PATH];
	data.ReadString(sOverlay, sizeof(sOverlay));

	char sTextCenter[PLATFORM_MAX_PATH];
	data.ReadString(sTextCenter, sizeof(sTextCenter));

	char sTextHint[PLATFORM_MAX_PATH];
	data.ReadString(sTextHint, sizeof(sTextHint));

	char sTextPrint[PLATFORM_MAX_PATH];
	data.ReadString(sTextPrint, sizeof(sTextPrint));

	char sSound[PLATFORM_MAX_PATH];
	data.ReadString(sSound, sizeof(sSound));

	if (client > 0)
	{
		if (strlen(sOverlay) > 0)
		{
			int iFlags = GetCommandFlags("r_screenoverlay");
			SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
			ClientCommand(client, "r_screenoverlay \"%s\"", sOverlay);
			SetCommandFlags("r_screenoverlay", iFlags);

			CreateTimer(3.0, Timer_ResetOverlayForClient, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
		}

		if (strlen(sTextCenter) > 0)
			PrintCenterText(client, sTextCenter);

		if (strlen(sTextHint) > 0)
			PrintHintText(client, sTextHint);

		if (strlen(sTextPrint) > 0)
			CPrintToChat(client, sTextPrint);

		if (strlen(sSound) > 0)
			EmitSoundToClient(client, sSound);
	}

	return Plugin_Continue;
}

void ParseTiersConfig()
{
	char sConfig[PLATFORM_MAX_PATH];
	convar_Config_Tiers.GetString(sConfig, sizeof(sConfig));

	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), sConfig);

	KeyValues kv = new KeyValues("furious_tiers");
	int sections;

	if (kv.ImportFromFile(sPath) && kv.GotoFirstSubKey())
	{
		ClearTrieSafe(g_TiersData);
		g_TiersList.Clear();

		char sRequiredPoints[64]; StringMap local_trie; char sKey[64]; char sValue[PLATFORM_MAX_PATH];
		do
		{
			kv.GetSectionName(sRequiredPoints, sizeof(sRequiredPoints));

			if (strlen(sRequiredPoints) > 0 && kv.GotoFirstSubKey(false))
			{
				local_trie = new StringMap();

				do
				{
					kv.GetSectionName(sKey, sizeof(sKey));
					kv.GetString(NULL_STRING, sValue, sizeof(sValue));

					local_trie.SetString(sKey, sValue);

					if (StrEqual(sKey, "sound") && strlen(sValue) > 0)
					{
						PrecacheSound(sValue);

						if (StrContains(sValue, "sound/") != 0)
							Format(sValue, sizeof(sValue), "sound/%s", sValue);

						AddFileToDownloadsTable(sValue);
					}

					if (StrEqual(sKey, "icon") && strlen(sValue) > 0) {
						int resourceEnt = GetPlayerResourceEntity();

						if (resourceEnt != -1) {
							char sBuffer[PLATFORM_MAX_PATH];
							Format(sBuffer, sizeof(sBuffer), "materials/panorama/images/icons/xp/level%i.png", StringToInt(sValue));
							AddFileToDownloadsTable(sBuffer);
						}
					}

				}
				while (kv.GotoNextKey(false));

				g_TiersData.SetValue(sRequiredPoints, local_trie);
				g_TiersList.Push(StringToInt(sRequiredPoints));

				kv.GoBack();
			}

			sections++;
		}
		while (kv.GotoNextKey());
	}

	LogMessage("Tiers config parsed. [%i sections loaded]", sections);
	delete kv;
}

void CalculateRank(int rank, Handle & overlay_data)
{
	char sRank[12];
	IntToString(rank, sRank, sizeof(sRank));
	g_RanksData.GetValue(sRank, overlay_data);

	if (overlay_data == null)
		g_RanksData.GetValue("default", overlay_data);
}

int CalculateTier(int points, Handle & overlay_data = null)
{
	int iTier = -1;
	int iRequiredPoints;

	for (int i = 0; i < g_TiersList.Length; i++)
	{
		iRequiredPoints = g_TiersList.Get(i);

		if (points >= iRequiredPoints)
			iTier = iRequiredPoints;
	}

	char sTier[12];
	IntToString(iTier, sTier, sizeof(sTier));

	g_TiersData.GetValue(sTier, overlay_data);

	return iTier;
}

int GetTierKey(int points, const char[] key, char[] value, int size)
{
	int iTier = CalculateTier(points);

	char sTier[12];
	IntToString(iTier, sTier, sizeof(sTier));

	StringMap local_trie;
	g_TiersData.GetValue(sTier, local_trie);

	if (local_trie == null)
		return -1;

	local_trie.GetString(key, value, size);

	return iTier;
}

public Action Command_PrintRankInfo(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	char sCommand[64];
	GetCmdArg(0, sCommand, sizeof(sCommand));

	bool bIsPlace = StrContains(sCommand, "place") != -1;

	char sSearch[64];
	GetCmdArg(1, sSearch, sizeof(sSearch));

	if (args == 0 || strlen(sSearch) == 0)
		strcopy(sSearch, sizeof(sSearch), g_sCacheData_SteamID2[client]);

	int size = 2 * strlen(sSearch) + 1;
	char[] sSearch2 = new char[size];
	g_Database_Server.Escape(sSearch, sSearch2, size);

	bool bIsSteamID = StrContains(sSearch2, "STEAM_") != -1;

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(bIsPlace);
	pack.WriteCell(bIsSteamID);
	pack.WriteString(sSearch2);

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	char sSearchBuffer[128];
	FormatEx(sSearchBuffer, sizeof(sSearchBuffer), bIsSteamID ? "s.steamid2 = '%s'" : "s.name LIKE '%%%s%%'", sSearch2);

	Transaction trans = new Transaction();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		SaveClientServerData(i, trans);
	}

	char sQuery[MAX_QUERY_SIZE];
	Format(sQuery, sizeof(sQuery), "SELECT s.name, s.kills, s.deaths, s.points, s.kdr, s.accuracy, (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank, (SELECT COUNT(*) as total FROM `%s`) as total FROM `%s` as s WHERE %s;",
		sTable,
		sTable,
		sTable,
		sSearchBuffer);
	trans.AddQuery(sQuery, pack);

	g_Database_Server.Execute(trans, onSuccess_ShowRank, onFailed_ShowRank);

	return Plugin_Handled;
}

public void onSuccess_ShowRank(Database db, any data, int numQueries, DBResultSet[] results, DataPack[] queryData)
{
	int check = numQueries - 1;

	queryData[check].Reset();

	int client = GetClientFromSerial(queryData[check].ReadCell());
	bool bIsPlace = view_as<bool>(queryData[check].ReadCell());
	bool bIsSteamID = view_as<bool>(queryData[check].ReadCell());

	char sSearch[64];
	queryData[check].ReadString(sSearch, sizeof(sSearch));

	delete queryData[check];

	if (client == 0)
		return;

	if (results[check] == null)
	{
		CPrintToChat(client, "%T", bIsSteamID ? "steamid not in database" : "player not found", client, sSearch);
		return;
	}

	if (results[check].RowCount > 1)
	{
		CPrintToChat(client, "%T", "found more than one", client, sSearch);
		return;
	}

	char sName[MAX_NAME_LENGTH];
	int iKills, iDeaths, iPoints, iRank, iTotal;
	float fKDR, fAccuracy;
	if (results[check].FetchRow())
	{
		results[check].FetchString(0, sName, sizeof(sName));
		iKills = results[check].FetchInt(1);
		iDeaths = results[check].FetchInt(2);
		iPoints = results[check].FetchInt(3);
		fKDR = results[check].FetchFloat(4);
		fAccuracy = results[check].FetchFloat(5);
		iRank = results[check].FetchInt(6);
		iTotal = results[check].FetchInt(7);

		if (iRank == 0)
			iRank = 1;
	}

	StringMap overlay_data;
	CalculateTier(iPoints, overlay_data);

	char sTag[128];
	if (overlay_data != null)
		overlay_data.GetString("tag", sTag, sizeof(sTag));

	switch (bIsPlace)
	{
		case true:
		{
			CPrintToChatAll("%t", "rank message 1", sName, iRank, iTotal, strlen(sTag) > 0 ? sTag : "N/A", iPoints);
			CPrintToChatAll("%t", "rank message 2", iKills, iDeaths, fKDR, fAccuracy);
		}
		case false:
		{
			CPrintToChat(client, "%T", "rank message 1", client, sName, iRank, iTotal, strlen(sTag) > 0 ? sTag : "N/A", iPoints);
			CPrintToChat(client, "%T", "rank message 2", client, iKills, iDeaths, fKDR, fAccuracy);
		}
	}
}

public void onFailed_ShowRank(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData)
{
	LogError("Error while showing rank at query %i: %s", failIndex, error);
}

public Action Command_Next(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	int iAmount = 10;

	if (args > 0)
	{
		char sAmount[12];
		GetCmdArgString(sAmount, sizeof(sAmount));
		iAmount = StringToInt(sAmount);

		if (iAmount <= 0 || iAmount > 10)
			iAmount = 10;
	}

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientSerial(client));
	pack.WriteCell(iAmount);

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `name`, `points` FROM `%s` WHERE `points` > %f OR (`points` = %f AND `kills` > %d) ORDER BY `points` ASC;",
		sTable,
		g_fStatistics_Seasonal_Points[client],
		g_fStatistics_Seasonal_Points[client],
		g_iStatistics_Seasonal_Kills[client]);
	g_Database_Server.Query(TQuery_OnGetNextData, sQuery, pack);

	return Plugin_Handled;
}

public void TQuery_OnGetNextData(Database db, DBResultSet results, const char[] error, DataPack data)
{
	if (results == null)
	{
		delete data;
		ThrowError("Error pulling client next data: %s", error);
	}

	data.Reset();

	int client = GetClientFromSerial(data.ReadCell());
	int iAmount = data.ReadCell();

	delete data;

	if (client == 0)
		return;

	int iRank = results.RowCount + 1;

	char sName[MAX_NAME_LENGTH];
	char sDisplay[512];

	char sTitle[128];
	Format(sTitle, sizeof(sTitle), "%i - Next Players", iAmount);

	Panel panel = new Panel();
	panel.SetTitle(sTitle);

	Format(sDisplay, sizeof(sDisplay), "  %i %i - %N", iRank, RoundFloat(g_fStatistics_Seasonal_Points[client]), client);

	panel.DrawText(sDisplay);

	while (results.FetchRow() && iAmount > 0)
	{
		iAmount--;

		results.FetchString(0, sName, sizeof(sName));

		float fPoints = results.FetchFloat(1);

		Format(sDisplay, sizeof(sDisplay), "  %i %i +%i %s", --iRank, RoundFloat(fPoints), RoundFloat(fPoints - g_fStatistics_Seasonal_Points[client]), sName);

		panel.DrawText(sDisplay);
	}

	panel.DrawItem("exit");
	panel.Send(client, VoidPanel, MENU_TIME_FOREVER);
	delete panel;
}

public int VoidPanel(Menu menu, MenuAction action, int param1, int param2)
{
	delete menu;
	return 0;
}

public Action Command_PrintTiers(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	int iTierPoints; char sTierPoints[12]; StringMap local_trie; char sTag[128]; char sPointsPerKill[PLATFORM_MAX_PATH]; char sPointsPerDeath[PLATFORM_MAX_PATH];
	for (int i = 0; i < g_TiersList.Length; i++)
	{
		iTierPoints = g_TiersList.Get(i);

		IntToString(iTierPoints, sTierPoints, sizeof(sTierPoints));
		g_TiersData.GetValue(sTierPoints, local_trie);

		if (local_trie == null)
			continue;

		local_trie.GetString("tag", sTag, sizeof(sTag));
		local_trie.GetString("points_per_kill", sPointsPerKill, sizeof(sPointsPerKill));
		local_trie.GetString("points_per_death", sPointsPerDeath, sizeof(sPointsPerDeath));

		CReplyToCommand(client, "%T", "tiers list format", client, sTag, iTierPoints, RoundToFloor(StringToFloat(sPointsPerKill)), RoundToFloor(StringToFloat(sPointsPerDeath)));
	}

	return Plugin_Handled;
}

public Action Command_Status(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	if (IsClientInGame(client))
	{
		char sTable[MAX_TABLE_SIZE];
		convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

		char sQuery[MAX_QUERY_SIZE];
		g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT COUNT(*) FROM `%s`;", sTable);
		g_Database_Global.Query(TQuery_OnGetGlobalCount, sQuery, GetClientSerial(client));
	}

	return Plugin_Handled;
}

public void TQuery_OnGetGlobalCount(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error retrieving global player count: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	if (results.FetchRow())
		CPrintToChat(client, "%T", "status message", client, results.FetchInt(0));
}

void GetTableString_Season(char[] sTable, int size)
{
	convar_Table_ServerSeasons.GetString(sTable, size);
	Format(sTable, size, "%s%i", sTable, g_iSeason);
}

void GetTableString_Maps(char[] sTable, int size)
{
	convar_Table_ServerMaps.GetString(sTable, size);
	Format(sTable, size, "%s%i", sTable, g_iSeason);
}

void GetTableString_Sessions(char[] sTable, int size)
{
	convar_Table_ServerSessions.GetString(sTable, size);
	Format(sTable, size, "%s%i", sTable, g_iSeason);
}

public Action Timer_DisplaySpectatorHud(Handle timer, any serial)
{
	if (!convar_Status.BoolValue)
		return Plugin_Continue;

	int client;
	if ((client = GetClientFromSerial(serial)) == 0)
		return Plugin_Continue;

	int specCount = 0;
	int observerMode, spectated, i;

	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i) || client == i || !g_bSpecHud[i])
			continue;

		observerMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

		if (observerMode != 4 && observerMode != 5)
			continue;

		spectated = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

		if (spectated > 0 && spectated == client && IsPlayerAlive(client))
		{
			specCount++;
		}
	}

	if (g_bFrsVIP && specCount > 0 && IsPlayerAlive(client) && Furious_VIP_IsSpecListEnabled(client) && GetUserFlagBits(client) & VIP_FLAGS)
	{
		static char buffer[512], name[32];
		int pos = 0;

		for (i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i) || i == client || !g_bSpecHud[i])
				continue;

			observerMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

			if (observerMode != 4 && observerMode != 5)
				continue;

			spectated = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

			if (spectated > 0 && spectated == client)
			{
				GetClientName(i, name, sizeof(name));
				pos += Format(buffer[pos], sizeof(buffer) - pos, "%s. ", name);
			}
		}

		PrintHintText(client, "%T", "spectator hud 2", client, buffer);
	}

	float fTime = GetClientTime(client);
	float fTotal = g_fStatistics_Global_Playtime[client] + fTime;

	char sTime[256];
	FormatSeconds(fTime, sTime, sizeof(sTime), "%Dd %Hh %Mm %Ss");

	char sTotal[256];
	FormatSeconds(fTotal, sTotal, sizeof(sTotal), "%Dd %Hh %Mm %Ss");

	char sPrefix[96]; char sPrefixColor[96]; char sGroup[96];

	if (g_bFrsTags)
	{
		int index = Furious_Tags_GetPrefixID(client);

		if (index > -1)
		{
			Furious_Tags_GetHudPrefix(index, sPrefix, sizeof(sPrefix));
			Furious_Tags_GetHudPrefixColor(index, sPrefixColor, sizeof(sPrefixColor));
			Furious_Tags_GetHudGroup(index, sGroup, sizeof(sGroup));
		}
	}

	char sTag[512];
	FormatEx(sTag, sizeof(sTag), "<span color='%s'>%s%s</span>", sPrefixColor, sPrefix, sGroup);

	int rank = g_iCacheData_Rank[client], lastKnownRank = g_LastKnownRank[client];
	float points = g_fStatistics_Seasonal_Points[client], lastKnownPoints = g_LastKnownPoints[client];

	char sRank[MAXPLAYERS + 1][128], sPoints[MAXPLAYERS + 1][128];

	if (rank > lastKnownRank)
	{
		g_HudColorTimes[client] = 3;
		Format(sRank[client], sizeof(sRank[]), "<font color='#ff657a'>%i▼</font>", rank);
	}
	else if (rank < lastKnownRank)
	{
		g_HudColorTimes[client] = 3;
		Format(sRank[client], sizeof(sRank[]), "<font color='#65ff89'>%i▲</font>", rank);
	}

	if (points > lastKnownPoints)
	{
		g_HudColorTimes[client] = 3;
		Format(sPoints[client], sizeof(sPoints[]), "<font color='#65ff89'>%i▲</font>", RoundToFloor(points));
	}
	else if (points < lastKnownPoints)
	{
		g_HudColorTimes[client] = 3;
		Format(sPoints[client], sizeof(sPoints[]), "<font color='#ff657a'>%i▼</font>", RoundToFloor(points));
	}

	if (strlen(sRank[client]) == 0)
		Format(sRank[client], sizeof(sRank[]), "%i", rank);
	if (strlen(sPoints[client]) == 0)
		Format(sPoints[client], sizeof(sPoints[]), "%i", RoundToFloor(points));

	for (i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || !IsClientObserver(i) || i == client || !g_bSpecHud[i] || bStoppedTimer[i])
			continue;

		observerMode = GetEntProp(i, Prop_Send, "m_iObserverMode");

		if (observerMode != 4 && observerMode != 5)
			continue;

		spectated = GetEntPropEnt(i, Prop_Send, "m_hObserverTarget");

		if ((spectated > 0 && spectated == client) && IsPlayerAlive(client))
		{
			if (points > lastKnownPoints || rank < lastKnownRank)
			{
				bStoppedTimer[i] = true;
				CreateTimer(2.5, Timer_ReEnableHud, GetClientSerial(i));
			}
			if (--g_HudColorTimes[client] >= 0 && g_LastSpectated[i] == spectated)
			{
				PrintHintText(i, "%T", "spectator hud colored", i, sTag, "", client, specCount, sRank[client], g_iCachedPlayers, sPoints[client], sTotal);
			}
			else
			{
				PrintHintText(i, "%T", "spectator hud", i, sTag, "", client, specCount, rank, g_iCachedPlayers, RoundToFloor(points), sTotal);
			}

			g_LastSpectated[i] = spectated;
		}
	}

	if (!g_HudSkipClient[client] && IsPlayerAlive(client))
	{
		if (--g_HudColorTimes[client] >= 0)
		{
			PrintHintText(client, "%T", "spectator hud colored", client, sTag, "", client, specCount, sRank[client], g_iCachedPlayers, sPoints[client], sTotal);
		}
		else
		{
			PrintHintText(client, "%T", "spectator hud", client, sTag, "", client, specCount, rank, g_iCachedPlayers, RoundToFloor(points), sTotal);
		}
	}

	g_LastKnownRank[client] = rank;
	g_LastKnownPoints[client] = points;

	return Plugin_Continue;
}

public Action Timer_ReEnableHud(Handle timer, any serial)
{
	bStoppedTimer[GetClientFromSerial(serial)] = false;
	return Plugin_Continue;
}

public Action Command_PlaytimeDebug(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || StopTimer(g_hTimer_Playtime[client]))
		return Plugin_Handled;

	g_hTimer_Playtime[client] = CreateTimer(1.0, Timer_DisplayPlaytimeDebug, client,	// It's safe to pass client index here since timer gets killed on client disconnect
		 TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Handled;
}

public Action Timer_DisplayPlaytimeDebug(Handle timer, any client)
{
	float fTime = GetClientTime(client);
	float fTotal = g_fStatistics_Global_Playtime[client] + fTime;

	PrintHintText(client, "%.2f + %.2f = %.2f", g_fStatistics_Global_Playtime[client], fTime, fTotal);
	return Plugin_Continue;
}

public Action Command_SaveStats(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	SaveClientGlobalData(client);
	SaveClientServerData(client);

	PrintToChat(client, "Stats have been saved.");

	return Plugin_Handled;
}

public Action Command_ToggleRanked(int client, int args)
{
	if (!convar_Status.BoolValue || client == 0)
		return Plugin_Handled;

	g_bRanked = !g_bRanked;
	AnnounceRankStatus(0, 0);

	return Plugin_Handled;
}

public Action Command_TestOverlays(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	if (args == 0)
	{
		OpenTestOverlaysMenu(client);
		return Plugin_Handled;
	}

	char sOverlay[12];
	GetCmdArg(1, sOverlay, sizeof(sOverlay));
	int overlay = StringToInt(sOverlay);

	char sData[32];
	GetCmdArg(2, sData, sizeof(sData));
	int data = StringToInt(sData);

	StringMap overlay_data;
	switch (overlay)
	{
		case OVERLAY_RANKUP:
		{
			CalculateRank(data, overlay_data);

			if (overlay_data == null)
			{
				PrintToChat(client, "Error while pulling overlay data for the rank %i.", data);
				return Plugin_Handled;
			}
		}
		case OVERLAY_TIERUP:
		{
			CalculateTier(data, overlay_data);

			if (overlay_data == null)
			{
				PrintToChat(client, "Error while pulling overlay data for the tier %i.", data);
				return Plugin_Handled;
			}
		}
	}

	PrintToChat(client, "Showing overlay: %i", overlay);
	ShowClientOverlay(client, overlay, 0.1, overlay_data);

	return Plugin_Handled;
}

void OpenTestOverlaysMenu(int client)
{
	Menu menu = new Menu(MenuHandler_TestOverlays);
	menu.SetTitle("Pick a type:");

	menu.AddItem("1", "Rampage");
	menu.AddItem("2", "Rankup");
	menu.AddItem("3", "Tierup");

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TestOverlays(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sOverlay[12];
			menu.GetItem(param2, sOverlay, sizeof(sOverlay));
			int overlay = StringToInt(sOverlay);

			switch (overlay)
			{
				case OVERLAY_RAMPAGE:
				{
					ShowClientOverlay(param1, OVERLAY_RAMPAGE, 0.1);
					OpenTestOverlaysMenu(param1);
				}
				case OVERLAY_RANKUP:OpenTestOverlaysRankupMenu(param1);
				case OVERLAY_TIERUP:OpenTestOverlaysTierupMenu(param1);
			}
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

void OpenTestOverlaysRankupMenu(int client)
{
	Menu menu = new Menu(MenuHandler_TestOverlays_Rankup);
	menu.SetTitle("Pick a rank ID:");

	char sID[12];
	for (int i = 0; i < g_RanksList.Length; i++)
	{
		IntToString(g_RanksList.Get(i), sID, sizeof(sID));
		menu.AddItem(sID, sID);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TestOverlays_Rankup(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			menu.GetItem(param2, sID, sizeof(sID));
			int rank = StringToInt(sID);

			StringMap overlay_data;
			CalculateRank(rank, overlay_data);

			if (overlay_data == null)
			{
				PrintToChat(param1, "Error while pulling overlay data for the rank %i.", rank);
				OpenTestOverlaysRankupMenu(param1);
				return 0;
			}

			PrintToChat(param1, "Showing rankup overlay: %i", rank);
			ShowClientOverlay(param1, OVERLAY_RANKUP, 0.1, overlay_data);

			OpenTestOverlaysRankupMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				OpenTestOverlaysMenu(param1);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

void OpenTestOverlaysTierupMenu(int client)
{
	Menu menu = new Menu(MenuHandler_TestOverlays_Tierup);
	menu.SetTitle("Pick a Tier ID:");

	char sID[12];
	for (int i = 0; i < g_TiersList.Length; i++)
	{
		IntToString(g_TiersList.Get(i), sID, sizeof(sID));
		menu.AddItem(sID, sID);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TestOverlays_Tierup(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sID[12];
			menu.GetItem(param2, sID, sizeof(sID));
			int tier = StringToInt(sID);

			StringMap overlay_data;
			CalculateTier(tier, overlay_data);

			if (overlay_data == null)
			{
				PrintToChat(param1, "Error while pulling overlay data for the tier %i.", tier);
				OpenTestOverlaysTierupMenu(param1);
				return 0;
			}

			PrintToChat(param1, "Showing tierup overlay: %i", tier);
			ShowClientOverlay(param1, OVERLAY_TIERUP, 0.1, overlay_data);

			OpenTestOverlaysTierupMenu(param1);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
				OpenTestOverlaysMenu(param1);
		}
		case MenuAction_End:
		delete menu;
	}

	return 0;
}

public Action Command_ReloadRanks(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	ParseRanksConfig();
	ReplyToCommand(client, "Ranks data has been reloaded.");
	return Plugin_Handled;
}

public Action Command_ReloadTiers(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	ParseTiersConfig();
	ReplyToCommand(client, "Tiers data has been reloaded.");
	return Plugin_Handled;
}

public Action Command_TestSpecHud(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	g_HudSkipClient[client] = !g_HudSkipClient[client];
	ReplyToCommand(client, "The spectator hud is now %s in first person.", g_HudSkipClient[client] ? "disabled" : "enabled");
	return Plugin_Handled;
}

public int Native_Server_GetTier(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return 0;
	
	return g_iCacheData_Tier[client];
}

public int Native_Server_GetRank(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return 0;
	
	return g_iCacheData_Rank[client];
}

public int Native_Server_GetTierUnique(Handle plugin, int numParams) {
	int points = GetNativeCell(1);

	StringMap local_trie;
	CalculateTier(points, local_trie);

	if (local_trie == null) {
		return 0;
	}

	char sUnique[128];
	local_trie.GetString("unique", sUnique, sizeof(sUnique));

	SetNativeString(2, sUnique, GetNativeCell(3));
	return 0;
}

public int Native_Server_GetPoints(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return 0;
	
	return g_iCacheData_Points[client];
}

public int Native_Server_GetTierTag(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return false;

	SetNativeString(2, g_sCacheData_TierTag[client], GetNativeCell(3));
	return true;
}

public int Native_Server_GetPlaytime(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return 0;

	return view_as<int>(GetClientTime(client) + g_fStatistics_Global_Playtime[client]);
}

public int Native_SetSpecHud(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return false;

	g_bSpecHud[client] = GetNativeCell(2);
	return true;
}

public int Native_Statistics_AddCredits(Handle plugin, int numParams) {
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients) {	
		return ThrowNativeError(SP_ERROR_NATIVE, "Client must be valid.");
	}

	int value = GetNativeCell(2);
	g_iStatistics_Global_Credits[client] += value;
	g_iStatistics_Global_CreditsEarned[client] += value;

	if (GetNativeCell(3)) {
		if (GetUserFlagBits(client) & VIP_FLAGS) {
			static ConVar convar_ExtraCredits = null;

			if (convar_ExtraCredits == null) {
				convar_ExtraCredits = FindConVar("sm_furious_vip_extra_credits");
			}

			int extra = convar_ExtraCredits.IntValue;

			g_iStatistics_Global_Credits[client] += extra;
			g_iStatistics_Global_CreditsEarned[client] += extra;

			CPrintToChat(client, "%T", "vip credits added", client, value, extra);
		} else {
			CPrintToChat(client, "%T", "credits added", client, value);
		}
	}

	LogMessage("%N has received %i credits.", client, value);

	return SP_ERROR_NONE;
}

public int Native_Statistics_AddCreditsToAccount(Handle plugin, int numParams) {
	int accountid = GetNativeCell(1);
	int value = GetNativeCell(2);

	if (value < 1) {
		return ThrowNativeError(SP_ERROR_NATIVE, "Value must be more than 0.");
	}

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	DataPack pack = new DataPack();
	pack.WriteCell(accountid);
	pack.WriteCell(value);

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET credits = credits + '%i' WHERE id = '%i';", sTable, value, accountid);
	g_Database_Global.Query(OnUpdateCreditsOffline, sQuery, pack, DBPrio_Low);

	return SP_ERROR_NONE;
}

public void OnUpdateCreditsOffline(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();

	int accountid = pack.ReadCell();
	int value = pack.ReadCell();

	delete pack;

	if (results == null) {
		ThrowError("Error while updating credits for offline account: %s", error);
	}

	LogMessage("Account ID %i has received %i credits while offline.", accountid, value);
}

public int Native_Statistics_GetCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	return g_iStatistics_Global_Credits[client];
}

public int Native_Statistics_SetCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	int value = GetNativeCell(2);
	g_iStatistics_Global_Credits[client] = value;

	if (GetNativeCell(3))
		CPrintToChat(client, "%T", "credits set", client, value);

	return 1;
}

public int Native_Statistics_GetCreditsEarned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	return g_iStatistics_Global_CreditsEarned[client];
}

public int Native_Statistics_SetCreditsEarned(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	g_iStatistics_Global_CreditsEarned[client] = GetNativeCell(2);

	return 1;
}

public int Native_Statistics_GetCreditsTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	return view_as<int>(g_fStatistics_Global_CreditsTimer[client]);
}

public int Native_Statistics_SetCreditsTimer(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	g_fStatistics_Global_CreditsTimer[client] = view_as<float>(GetNativeCell(2));

	return 1;
}

public int Native_Statistics_AddSeasonalPoints(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	g_fStatistics_Seasonal_Points[client] += GetNativeCell(2);

	return 1;
}

public int Native_Statistics_GetRankPointsGain(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	if (client < 1 || client > MaxClients)
		return -1;

	return RoundFloat(g_fCacheData_PointsGain[client]);
}

public int Native_Statistics_IsRankedEnabled(Handle plugin, int numParams)
{
	return g_bRanked && !g_bBetweenRounds && convar_Status.BoolValue;
}

public int Native_Statistics_GetGlobalDatabase(Handle plugin, int numParams)
{
	if (g_Database_Global == null)
	{
		return view_as<int>(INVALID_HANDLE);
	}

	return view_as<int>(CloneHandle(g_Database_Global, plugin));
}

public int Native_Statistics_GetServerDatabase(Handle plugin, int numParams)
{
	if (g_Database_Server == null)
	{
		return view_as<int>(INVALID_HANDLE);
	}

	return view_as<int>(CloneHandle(g_Database_Server, plugin));
}

public int Native_Statistics_GetSeason(Handle plugin, int numParams)
{
	return g_iSeason;
}

public int Native_Statistics_IsSeasonActive(Handle plugin, int numParams)
{
	return g_bActiveSeason;
}

public Action Command_ResetRank(int client, int args)
{
	if (!convar_Status.BoolValue || client < 1 || !IsClientInGame(client))
		return Plugin_Handled;

	int iCredits = g_iStatistics_Global_Credits[client];
	int iDeduct = convar_ResetRankCredits.IntValue;

	if (iCredits >= iDeduct)
	{
		static char buffer[256];

		if (iDeduct == 0)
			Format(buffer, sizeof(buffer), "Do you want to reset your seasonal statistics?");
		else
			Format(buffer, sizeof(buffer), "Do you want to reset your seasonal statistics for %i credits?", iDeduct);

		SendConfirmationMenu(client, Confirmation_ResetRank, buffer, _, iDeduct);
	}
	else
		CPrintToChat(client, "%T", "reset rank not enough credits", client, iDeduct);

	return Plugin_Handled;
}

public void Confirmation_ResetRank(int client, ConfirmationResponses response, int deduct)
{
	if (response == Confirm_Yes)
	{
		g_iStatistics_Global_Credits[client] -= deduct;

		ResetSeasonalData(client);
		CPrintToChat(client, "%T", "reset rank", client, deduct);
	}
}

void ResetSeasonalData(int client)
{
	if (!g_bActiveSeason)
	{
		CPrintToChat(client, "%T", "season not active", client);
		return;
	}

	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	char sQuery[MAX_QUERY_SIZE];
	int cells = g_Database_Server.Format(sQuery, sizeof(sQuery), "UPDATE `%s` SET `kills` = '0', `deaths` = '0', `assists` = '0', `headshots` = '0', `points` = '0', `longest_killstreak` = '0', `hits` = '0', `shots` = '0', `kdr` = '0.0', `accuracy` = '0.0', `playtime` = '0.0', `weapons_statistics` = '{ }'", sTable);

	Call_StartForward(g_Forward_SeasonTable_OnResetData);
	Call_PushCell(client);
	Call_PushStringEx(sQuery[cells], sizeof(sQuery) - cells, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(sQuery) - cells);
	Call_PushCellRef(cells);
	Call_Finish();

	Format(sQuery[cells], sizeof(sQuery) - cells, " WHERE `accountid` = '%i';", g_iCacheData_AccountID[client]);

	g_Database_Server.Query(TQuery_OnResetSeasonalStats, sQuery, GetClientSerial(client));
}

public void TQuery_OnResetSeasonalStats(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error resetting client seasonal statistics: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) > 0)
	{
		g_iStatistics_Seasonal_Kills[client] = 0;
		g_iStatistics_Seasonal_Deaths[client] = 0;
		g_iStatistics_Seasonal_Assists[client] = 0;
		g_iStatistics_Seasonal_Headshots[client] = 0;
		g_fStatistics_Seasonal_Points[client] = 0.0;
		g_iStatistics_Seasonal_Longest_Killstreak[client] = 0;
		g_iStatistics_Seasonal_Hits[client] = 0;
		g_iStatistics_Seasonal_Shots[client] = 0;
		g_fStatistics_Seasonal_KDR[client] = 0.0;
		g_fStatistics_Seasonal_Accuracy[client] = 0.0;
		g_fStatistics_Seasonal_Playtime[client] = 0.0;

		if (g_hStatistics_Seasonal_WeaponsStatistics[client] != null)
		{
			g_hStatistics_Seasonal_WeaponsStatistics[client].Cleanup();
			delete g_hStatistics_Seasonal_WeaponsStatistics[client];
		}

		g_hStatistics_Seasonal_WeaponsStatistics[client] = new JSON_Object();

		g_iCacheData_Points[client] = 0;
		g_iCacheData_Rank[client] = 0;
		g_iCacheData_Tier[client] = 0;
		g_fCacheData_PointsGain[client] = 0.0;
		g_fCacheData_PointsLoss[client] = 0.0;
		g_sCacheData_TierTag[client][0] = '\0';

		Call_StartForward(g_Forward_OnSeasonalStatsReset);
		Call_PushCell(client);
		Call_Finish();

		CPrintToChat(client, "%T", "seasonal statistics reset", client, g_iSeason);
	}
}

public Action Command_Season(int client, int args)
{
	if (!convar_Status.BoolValue || !IsClientInGame(client))
		return Plugin_Continue;

	char sTime[128];
	FormatTime(sTime, sizeof(sTime), "%A, %B %d, %Y at %R", g_iNextSeason);

	CPrintToChat(client, "%T", "print current and next season", client, g_iSeason, g_iSeason + 1, sTime);

	return Plugin_Handled;
}

public void OnClientResourceEntityPostThink(int entity)
{
	if (g_PersonalDataPublicLevelOffset == -1)
		return;

	int icon = -1;
	char sIcon[PLATFORM_MAX_PATH];

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (GetUserFlagBits(i) & VIP_FLAGS)
		{
			SetEntData(entity, g_PersonalDataPublicLevelOffset + (i * 4), g_iTempVipIcons[g_iTempVipIconIdIndex]);
			continue;
		}

		icon = -1;

		GetTierKey(RoundToFloor(g_fStatistics_Seasonal_Points[i]), "icon", sIcon, sizeof(sIcon));

		if ((icon = StringToInt(sIcon)) > 0) {
			SetEntData(entity, g_PersonalDataPublicLevelOffset + (i * 4), icon);
		}
	}
}

void FormatSeconds2(int starting, int & days, int & hours, int & minutes)
{
	days = starting / (24 * 3600);
	starting = starting % (24 * 3600);
	hours = starting / 3600;
	starting %= 3600;
	minutes = starting / 60;
}

void SeasonCheck()
{
	if (g_Database_Global == null)
		ThrowError("Error while checking for seasons: Not Connected to Global Database");

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalData.GetString(sTable, sizeof(sTable));

	char sIP[128];
	GetServerIP(sIP, sizeof(sIP), true);

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT `season_number`, `next_season`, `last_updated` FROM `%s` WHERE `ip` = '%s';", sTable, sIP);
	g_Database_Global.Query(TQuery_OnSeasonsCheck, sQuery);
}

public void TQuery_OnSeasonsCheck(Database db, DBResultSet results, const char[] error, any data)
{
	if (db == null)
		ThrowError("Error while checking for seasons: %s", error);

	bool bFetch;
	bFetch = results.FetchRow();

	char sCurrent[64];
	FormatTime(sCurrent, sizeof(sCurrent), "%m-%d");

	char sCurrent2[64];
	FormatTime(sCurrent2, sizeof(sCurrent2), "%Y-%m-%d");

	char sYear[64];
	FormatTime(sYear, sizeof(sYear), "%Y");

	int iYear = StringToInt(sYear);
	int iLastUpdate;

	if (bFetch && (g_iSeason = results.FetchInt(0)) != 0)
		iLastUpdate = results.FetchInt(2);

	int iCurrentTimeStamp = GetTime();
	int iNearestTimeStamp = 99999999999999999999;

	for (int i = 0; i < g_Seasons.Length; ++i)
	{
		char sDate[64], sPart[2][32], sDateF[64];
		g_Seasons.GetString(i, sDate, sizeof(sDate));
		ExplodeString(sDate, "-", sPart, sizeof(sPart), sizeof(sPart[]), true);

		int iMonth = StringToInt(sPart[0]);
		int iDay = StringToInt(sPart[1]);

		int iTimeStamp1 = TimeToUnix(iYear, iMonth, iDay, convar_SeasonChangeTime.IntValue - 1, 0, 0, UT_TIMEZONE_UTC);
		FormatTime(sDateF, sizeof(sDateF), "%Y-%m-%d", iTimeStamp1);

		if (iTimeStamp1 > iCurrentTimeStamp && iTimeStamp1 < iNearestTimeStamp && iTimeStamp1 > iLastUpdate)
			iNearestTimeStamp = iTimeStamp1;

		int iTimeStamp2 = TimeToUnix(iYear + 1, iMonth, iDay, convar_SeasonChangeTime.IntValue - 1, 0, 0, UT_TIMEZONE_UTC);
		FormatTime(sDateF, sizeof(sDateF), "%Y-%m-%d", iTimeStamp2);

		if (iTimeStamp2 > iCurrentTimeStamp && iTimeStamp2 < iNearestTimeStamp && iTimeStamp2 > iLastUpdate)
			iNearestTimeStamp = iTimeStamp2;
	}

	if (bFetch && g_iSeason != 0)
	{
		g_iNextSeason = results.FetchInt(1);

		char sLastUpdate[64];
		FormatTime(sLastUpdate, sizeof(sLastUpdate), "%m-%d", iLastUpdate);

		if (g_Seasons.FindString(sCurrent) != -1 && g_iNextSeason <= iCurrentTimeStamp && iLastUpdate < iCurrentTimeStamp)
		{
			// SEASON UP!
			g_iSeason++;

			char sIP[64];
			GetServerIP(sIP, sizeof(sIP));

			Call_StartForward(g_Forward_OnSeasonChange);
			Call_PushCell(g_iSeason);
			Call_PushString(sIP);
			Call_PushCell(FindConVar("hostport").IntValue);
			Call_Finish();
		}
	}
	else
	{
		g_iSeason = 1;
	}

	Call_StartForward(g_Forward_OnSeasonRetrieved);
	Call_PushCell(g_iSeason);
	Call_Finish();

	// Queries won't fail if tables already exist so have this here. This is also so that g_bActiveSeason is set to true
	TryCreateSeasonalMapAndSessionTables();

	g_iNextSeason = iNearestTimeStamp;

	char sTime[128];
	FormatTime(sTime, sizeof(sTime), "%A, %B %d, %Y", g_iNextSeason);

	LogMessage("Current Season: %i - Next Season Date: %s", g_iSeason, sTime);

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalData.GetString(sTable, sizeof(sTable));

	char sHostname[MAX_NAME_LENGTH];
	FindConVar("hostname").GetString(sHostname, sizeof(sHostname));

	char sIP[64];
	GetServerIP(sIP, sizeof(sIP), true);

	int iTime = GetTime();

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "INSERT INTO `%s` (`hostname`, `ip`, `season_number`, `next_season`, `first_created`, `last_updated`) VALUES ('%s', '%s', '%i', '%i', '%i', '%i') ON DUPLICATE KEY UPDATE `hostname` = '%s', `season_number` = '%i', `next_season` = '%i', `last_updated` = '%i';", sTable, sHostname, sIP, g_iSeason, g_iNextSeason, iTime, iTime, sHostname, g_iSeason, g_iNextSeason, iTime);
	g_Database_Global.Query(TQuery_OnUpdateServerSettings, sQuery);

	if (g_iSeason == 0)
		ThrowError("Error while initializing season: Invalid season of 0");
}

void TryCreateSeasonalMapAndSessionTables()
{
	char sQuery[MAX_QUERY_SIZE];
	char sTable[MAX_TABLE_SIZE];
	Transaction trans = new Transaction();

	GetTableString_Season(sTable, sizeof(sTable));
	int cells = g_Database_Server.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`id` int(12) NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '', `accountid` int(12) NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `kills` int(12) NOT NULL DEFAULT 0, `deaths` int(12) NOT NULL DEFAULT 0, `assists` int(12) NOT NULL DEFAULT 0, `headshots` int(12) NOT NULL DEFAULT 0, `points` float NOT NULL DEFAULT 0, `longest_killstreak` int(12) NOT NULL DEFAULT 0, `hits` int(12) NOT NULL DEFAULT 0, `shots` int(12) NOT NULL DEFAULT 0, `kdr` float NOT NULL DEFAULT 0.0, `accuracy` float NOT NULL DEFAULT 0.0, `playtime` float NOT NULL DEFAULT 0.0, `weapons_statistics` varchar(4096) NOT NULL DEFAULT '', `first_created` int(32) NOT NULL DEFAULT 0, `last_updated` int(32) NOT NULL DEFAULT 0, PRIMARY KEY (`id`), UNIQUE KEY `id` (`id`), UNIQUE KEY `accountid` (`accountid`)", sTable);

	Call_StartForward(g_Forward_SeasonTable_OnCreateTable);
	Call_PushStringEx(sQuery[cells], sizeof(sQuery) - cells, SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(sizeof(sQuery) - cells);
	Call_PushCellRef(cells);
	Call_Finish();

	Format(sQuery[cells], sizeof(sQuery) - cells, ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;");

	trans.AddQuery(sQuery);

	GetTableString_Maps(sTable, sizeof(sTable));
	g_Database_Server.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`id` int(12) NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '', `accountid` int(12) NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `kills` int(12) NOT NULL DEFAULT 0, `deaths` int(12) NOT NULL DEFAULT 0, `assists` int(12) NOT NULL DEFAULT 0, `headshots` int(12) NOT NULL DEFAULT 0, `points` float NOT NULL DEFAULT 0, `longest_killstreak` int(12) NOT NULL DEFAULT 0, `hits` int(12) NOT NULL DEFAULT 0, `shots` int(12) NOT NULL DEFAULT 0, `kdr` float NOT NULL DEFAULT 0.0, `accuracy` float NOT NULL DEFAULT 0.0, `playtime` float NOT NULL DEFAULT 0.0, `playcount` int(12) NOT NULL DEFAULT 0, `map` varchar(64) NOT NULL DEFAULT '', `first_created` int(32) NOT NULL, `last_updated` int(32) NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `id` (`id`), UNIQUE KEY `map_ident` (`accountid`,`map`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", sTable);
	trans.AddQuery(sQuery);

	GetTableString_Sessions(sTable, sizeof(sTable));
	g_Database_Server.Format(sQuery, sizeof(sQuery), "CREATE TABLE IF NOT EXISTS `%s` (`id` int(12) NOT NULL AUTO_INCREMENT, `name` varchar(64) NOT NULL DEFAULT '', `accountid` int(12) NOT NULL DEFAULT 0, `steamid2` varchar(64) NOT NULL DEFAULT '', `steamid3` varchar(64) NOT NULL DEFAULT '', `steamid64` varchar(64) NOT NULL DEFAULT '', `ranks_gained` int(12) NOT NULL DEFAULT 0, `ranks_lost` int(12) NOT NULL DEFAULT 0, `points_gained` float NOT NULL DEFAULT 0, `points_lost` float NOT NULL DEFAULT 0, `map` varchar(32) NOT NULL DEFAULT '', `first_created` int(12) NOT NULL, PRIMARY KEY (`id`), UNIQUE KEY `id` (`id`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 DEFAULT COLLATE=utf8mb4_unicode_ci;", sTable);
	trans.AddQuery(sQuery);

	g_Database_Server.Execute(trans, Transaction_OnCreateTables_Success, Transaction_OnCreateTables_Failure);
}

public void Furious_Statistics_OnSeasonChange(int season, char[] ip, int port)
{
	if (season <= 1)
		return;

	DataPack pack = new DataPack();
	pack.WriteCell(season);
	pack.WriteString(ip);
	pack.WriteCell(port);

	char sTable[MAX_TABLE_SIZE];
	convar_Table_ServerSeasons.GetString(sTable, sizeof(sTable));
	Format(sTable, sizeof(sTable), "%s%i", sTable, season - 1);

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `name` FROM `%s` ORDER BY `points` DESC LIMIT 10;", sTable);
	g_Database_Server.Query(TQuery_CheckTopTen3, sQuery, pack);
}

public void TQuery_CheckTopTen3(Database database, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int season = pack.ReadCell();
	char ip[64];
	pack.ReadString(ip, sizeof(ip));
	int port = pack.ReadCell();
	delete pack;

	if (database == null)
		ThrowError("Database is null");

	char sAddress[128], sTitle[64], sBody[4096];
	Format(sAddress, sizeof(sAddress), "%s:%i", ip, port);
	Format(sTitle, sizeof(sTitle), "WELCOME TO SEASON %i", season);
	Format(sBody, sizeof(sBody), "Congratulations to the Season %i top players:\n", season - 1);

	JSON_Object hSocketData = new JSON_Object();
	hSocketData.SetString("socket_type", "season_change");
	hSocketData.SetString("socket_token", "C@%uKocGswh8@Ms#YDr6");
	hSocketData.SetInt("server_port", port);
	hSocketData.SetInt("season", season);

	JSON_Array hTopPlayers = new JSON_Array();
	
	int ix;
	while (results.FetchRow())
	{
		char sName[128];
		results.FetchString(0, sName, sizeof(sName));
		Format(sBody, sizeof(sBody), "%s\n%i %s", sBody, ++ix, sName);
		JSON_Object hTopPlayer = new JSON_Object();
		hTopPlayer.SetInt("rank", ix);
		hTopPlayer.SetString("name", sName);

		hTopPlayers.PushObject(hTopPlayer);
	}

	Format(sBody, sizeof(sBody), "%s\n\nSee all stats at: furious-clan.com/#/players", sBody);

	hSocketData.SetObject("data", hTopPlayers);
	char sSocketData[4096];
	json_encode(hSocketData, sSocketData, sizeof(sSocketData));
	hSocketData.Cleanup();
	delete hSocketData;
	SocketOutput(g_hSocketListeners, sizeof(g_hSocketListeners), sSocketData);
}

void PrecacheSoundF(char[] buffer, int maxlength, ConVar convar)
{
	convar.GetString(buffer, maxlength);
	if (strlen(buffer) > 0)
	{
		PrecacheSound(buffer);

		Format(buffer, maxlength, "sound/%s", buffer);
		AddFileToDownloadsTable(buffer);
	}
}

void PerformJoinMessage(int client)
{
	char sTable[MAX_TABLE_SIZE];
	GetTableString_Season(sTable, sizeof(sTable));

	char sQuery[MAX_QUERY_SIZE];
	g_Database_Server.Format(sQuery, sizeof(sQuery), "SELECT `steamid64` FROM `%s` ORDER BY `points` DESC LIMIT 10;", sTable);
	g_Database_Server.Query(TQuery_CheckTopTen2, sQuery, GetClientSerial(client));
}

public void OnSocketError(Handle socket, const int errorType, const int errorNum, any ary)
{
	LogError("socket error %d (errno %d)", errorType, errorNum);
	delete socket;
}

public void OnSocketIncoming(Handle socket, Handle newSocket, char[] remoteIP, int remotePort, any arg)
{
	LogMessage("[SOCKET] %s:%d connected", remoteIP, remotePort);

	SocketSetReceiveCallback(newSocket, OnChildSocketReceive);
	SocketSetDisconnectCallback(newSocket, OnChildSocketDisconnected);
	SocketSetErrorCallback(newSocket, OnChildSocketError);

	for (int i = 0; i < sizeof(g_hSocketListeners); ++i)
	{
		if (g_hSocketListeners[i] != null && SocketIsConnected(g_hSocketListeners[i]))
			continue;

		g_hSocketListeners[i] = CloneHandle(newSocket);
		break;
	}

	SocketSend(newSocket, "working!\n");
}

public void OnChildSocketReceive(Handle socket, char[] receiveData, const int dataSize, any hFile)
{
	SocketSend(socket, receiveData);

	if (StrEqual(receiveData, "quit"))
		delete socket;
}

public void OnChildSocketDisconnected(Handle socket, any hFile)
{
	delete socket;
}

public void OnChildSocketError(Handle socket, const int errorType, const int errorNum, any ary)
{
	LogError("child socket error %d (errno %d)", errorType, errorNum);
	delete socket;
}

public Action Command_TestSocket(int client, int args)
{
	Furious_Statistics_OnSeasonChange(5, "149.202.65.29", 27018);
	return Plugin_Handled;
}

void SocketOutput(Handle[] listeners, int length, char[] output)
{
	for (int i = 0; i < length; ++i)
	{
		if (listeners[i] == null || !SocketIsConnected(listeners[i]))
			continue;

		SocketSend(listeners[i], output);
	}
}

public Action Command_CountryRank(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	char sSearch[MAX_TARGET_LENGTH];
	GetCmdArgString(sSearch, sizeof(sSearch));

	if (strlen(sSearch) == 0)
		GetClientAuthId(client, AuthId_Steam2, sSearch, sizeof(sSearch));

	bool bIsSteamID = StrContains(sSearch, "STEAM_") != -1;

	int size = 2 * strlen(sSearch) + 1;
	char[] sSearchE = new char[size];
	g_Database_Global.Escape(sSearch, sSearchE, size);

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sSearchSteamID[64];
	Format(sSearchSteamID, sizeof(sSearchSteamID), "s.steamid2 = '%s'", sSearchE);

	char sSearchName[64];
	Format(sSearchName, sizeof(sSearchName), "s.name LIKE '%%%s%%'", sSearchE);

	char sQuery[512];
	Format(sQuery, sizeof(sQuery), "SELECT s.name, s.country, (SELECT COUNT(*) as rank_country FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills) AND country = s.country) + 1 as rank_country, (SELECT COUNT(*) as total_country FROM `%s` WHERE country = s.country) as total_country FROM `%s` as s WHERE %s;", sTable, sTable, sTable, bIsSteamID ? sSearchSteamID : sSearchName);
	g_Database_Global.Query(OnParseCountryRank, sQuery);

	return Plugin_Handled;
}

public void OnParseCountryRank(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing top country rank: %s", error);

	if (results.FetchRow())
	{
		char sName[MAX_NAME_LENGTH];
		results.FetchString(0, sName, sizeof(sName));

		char sCountry[64];
		results.FetchString(1, sCountry, sizeof(sCountry));

		int rank = results.FetchInt(2);
		int total = results.FetchInt(3);

		CPrintToChatAll("%t", "country top rank", sName, rank, total, sCountry, g_iSeason);
	}
}

public Action Command_TopCountries(int client, int args)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}

	OpenTopCountries(client);
	return Plugin_Handled;
}

void OpenTopCountries(int client)
{
	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sQuery[512];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT s.country, SUM(s.points), (SELECT COUNT(*) as rank FROM `%s` as r WHERE r.points > s.points OR (r.points = s.points AND r.kills > s.kills)) + 1 as rank FROM `%s` as s GROUP BY s.country, s.points DESC ORDER BY `rank` ASC;", sTable, sTable);
	g_Database_Global.Query(OnParseTopCountries, sQuery, GetClientSerial(client));
}

public void OnParseTopCountries(Database db, DBResultSet results, const char[] error, any data)
{
	if (results == null)
		ThrowError("Error while parsing top countries: %s", error);

	int client;
	if ((client = GetClientFromSerial(data)) == 0)
		return;

	Menu menu = new Menu(MenuHandler_Countries);
	menu.SetTitle("Top Countries");

	int count; char sCountry[64]; char sDisplay[256];
	while (results.FetchRow())
	{
		results.FetchString(0, sCountry, sizeof(sCountry));
		count++;
		FormatEx(sDisplay, sizeof(sDisplay), "Rank %i | %s - %i Points", count, sCountry, RoundFloat(results.FetchFloat(1)));
		menu.AddItem(sCountry, sDisplay);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Countries(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sCountry[64];
			menu.GetItem(param2, sCountry, sizeof(sCountry));

			OpenTopCountry(param1, sCountry);
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

void OpenTopCountry(int client, const char[] country)
{
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientSerial(client));
	pack.WriteString(country);

	char sTable[MAX_TABLE_SIZE];
	convar_Table_GlobalStatistics.GetString(sTable, sizeof(sTable));

	char sQuery[256];
	g_Database_Global.Format(sQuery, sizeof(sQuery), "SELECT steamid2, name, points FROM `%s` WHERE country = '%s' ORDER BY points DESC LIMIT 200;", sTable, country);
	g_Database_Global.Query(OnParseTopCountry, sQuery, pack);
}

public void OnParseTopCountry(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	pack.Reset();

	int serial = pack.ReadCell();

	char sCountry[64];
	pack.ReadString(sCountry, sizeof(sCountry));

	delete pack;

	if (results == null)
		ThrowError("Error while parsing top country: %s", error);

	int client;
	if ((client = GetClientFromSerial(serial)) == 0)
		return;

	Menu menu = new Menu(MenuHandler_Country);
	menu.SetTitle("Top Countries\n \n%s ( Top 200 )", sCountry);

	int count; char sSteamID2[64]; char sName[MAX_NAME_LENGTH]; char sDisplay[256];
	while (results.FetchRow())
	{
		results.FetchString(0, sSteamID2, sizeof(sSteamID2));
		results.FetchString(1, sName, sizeof(sName));

		count++;
		FormatEx(sDisplay, sizeof(sDisplay), "Rank %i | %s - %i Points", count, sName, RoundFloat(results.FetchFloat(2)));
		menu.AddItem(sSteamID2, sDisplay);
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Country(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sSteamID[64];
			menu.GetItem(param2, sSteamID, sizeof(sSteamID));

			ShowStatisticsMenu(param1, sSteamID);
		}

		case MenuAction_Cancel:
			if (param2 == MenuCancel_ExitBack)
				OpenTopCountries(param1);

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

public void OnWinPanel(Event event, const char[] name, bool dontBroadcast) {
	char sText[5192];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}

		if (!GenerateWinPanel(i, sText, sizeof(sText))) {
			continue;
		}

		ShowWinPanel(i, sText);

		g_WinPanel[i].Clear();
	}
}

public Action Command_TestWinPanel(int client, int args) {
	char sText[5192];
	if (!GenerateWinPanel(client, sText, sizeof(sText))) {
		PrintToChat(client, "error while showing win panel");
		return Plugin_Handled;
	}

	ShowWinPanel(client, sText);

	return Plugin_Handled;
}

bool GenerateWinPanel(int client, char[] text, int size) {
	if (client < 1 || !g_WinPanel[client].loaded) {
		return false;
	}

	char sUp[128];
	strcopy(sUp, sizeof(sUp), "<img src='https://furious-clan.com/csgo/points-up.png'>");

	char sDown[128];
	strcopy(sDown, sizeof(sDown), "<img src='https://furious-clan.com/csgo/points-down.png'>");

	//Based on the math, we need to flip positives and negatives.
	int kills = -(g_WinPanel[client].kills - g_iStatistics_Seasonal_Kills[client]);
	int assists = -(g_WinPanel[client].assists - g_iStatistics_Seasonal_Assists[client]);
	int position = -(g_WinPanel[client].position - g_iCacheData_Rank[client]);
	float points = -(g_WinPanel[client].points - g_fStatistics_Seasonal_Points[client]);

	char sKills[256];
	if (kills > 0) {
		FormatEx(sKills, sizeof(sKills), "<span color='#3AE489'>+%i</span> %s", kills, sUp);
	} else if (kills < 0) {
		FormatEx(sKills, sizeof(sKills), "<span color='#E43A3A'>%i</span> %s", kills, sDown);
	} else {
		FormatEx(sKills, sizeof(sKills), "<span color='#808080'>%i</span>", kills);
	}
	char sAssists[256];
	if (assists > 0) {
		FormatEx(sAssists, sizeof(sAssists), "Assists: <span color='#3AE489'>+%i</span> %s", assists, sUp);
	} else if (assists < 0) {
		FormatEx(sAssists, sizeof(sAssists), "Assists: <span color='#E43A3A'>%i</span> %s", assists, sDown);
	}
	char sPosition[256];
	if (position > 0) {
		FormatEx(sPosition, sizeof(sPosition), "<span color='#3AE489'>+%i</span>", position);
	} else if (position < 0) {
		FormatEx(sPosition, sizeof(sPosition), "<span color='#E43A3A'>%i</span>", position);
	} else {
		FormatEx(sPosition, sizeof(sPosition), "<span color='#808080'>%i</span>", position);
	}
	char sPoints[256];
	if (points > 0.0) {
		FormatEx(sPoints, sizeof(sPoints), "<span color='#3AE489'> +%.0f </span>", points);
	} else if (points < 0.0) {
		FormatEx(sPoints, sizeof(sPoints), "<span color='#E43A3A'> %.0f </span>", points);
	} else {
		FormatEx(sPoints, sizeof(sPoints), "<span color='#808080'> %.0f </span>", points);
	}

	FormatEx(text, size, "%T", "win panel", client, sKills, sAssists, sPosition, sPoints);

	return true;
}

void ShowWinPanel(int client, const char[] text) {
	Event newevent_message = CreateEvent("cs_win_panel_round");
	newevent_message.SetString("funfact_token", text);

	newevent_message.FireToClient(client);
	newevent_message.Cancel();
}