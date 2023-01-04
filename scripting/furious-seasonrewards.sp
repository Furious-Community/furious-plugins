#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "1.0.0"
#define DIR_PERMS 511
#define MAX_REWARDS 64
#define MAX_OFFLINE_REWARDS 64

#include <sourcemod>
#include <sdktools>
#include <colorlib>
#include <furious/furious-statistics>
#include <furious/furious-store>

ConVar convar_Enabled;
ConVar convar_Overlay_Reminder;
ConVar convar_Overlay_Claimed;
ConVar convar_Sound_Reminder;
ConVar convar_Sound_Claimed;

Database g_Database;

char g_BasePath[PLATFORM_MAX_PATH];

enum struct Reward {
	char reward_type[64]; //credits - items
	char type[16]; //tier - rank
	char reward[64];
	int accountid;

	void Add(const char[] reward_type, const char[] type, const char[] reward, int accountid = -1) {
		strcopy(this.reward_type, sizeof(Reward::reward_type), reward_type);
		strcopy(this.type, sizeof(Reward::type), type);
		strcopy(this.reward, sizeof(Reward::reward), reward);
		this.accountid = accountid;
	}

	void Clear() {
		this.reward_type[0] = '\0';
		this.type[0] = '\0';
		this.reward[0] = '\0';
		this.accountid = -1;
	}
}

Reward g_Reward[MAXPLAYERS + 1][MAX_REWARDS];
int g_TotalRewards[MAXPLAYERS + 1];

int g_RewardSeason[MAXPLAYERS + 1];

Reward g_OfflineReward[MAX_OFFLINE_REWARDS + 1][MAX_REWARDS];
int g_OfflineTotalRewards[MAX_OFFLINE_REWARDS + 1];
int g_Offline;

int g_Reminder[MAXPLAYERS + 1];

public Plugin myinfo = {
	name = "[Furious] Season Rewards",
	author = "Drixevel",
	description = "Manages season rewards and claims.",
	version = PLUGIN_VERSION,
	url = "http://furious-clan.com/"
};

public void OnPluginStart() {
	LoadTranslations("common.phrases");
	LoadTranslations("furious.seasonrewards.phrases");

	CreateConVar("sm_furious_seasonrewards_version", PLUGIN_VERSION, "Version control for this plugin.", FCVAR_DONTRECORD);
	convar_Enabled = CreateConVar("sm_furious_seasonrewards_enabled", "1", "Should this plugin be enabled or disabled?", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	convar_Overlay_Reminder = CreateConVar("sm_furious_seasonrewards_overlay_reminder", "", "What overlay should show once reminded of unclaimed rewards?", FCVAR_NOTIFY);
	convar_Sound_Reminder = CreateConVar("sm_furious_seasonrewards_sound_reminder", "", "What sound should play once reminded of unclaimed rewards?", FCVAR_NOTIFY);
	convar_Overlay_Claimed = CreateConVar("sm_furious_seasonrewards_overlay_claimed", "", "What overlay should show once claimed manually?", FCVAR_NOTIFY);
	convar_Sound_Claimed = CreateConVar("sm_furious_seasonrewards_sound_claimed", "", "What sound should play once claimed manually?", FCVAR_NOTIFY);
	AutoExecConfig();

	Database.Connect(OnSQLConnect, "furious_seasonrewards");

	RegConsoleCmd("sm_claim", Command_Claim, "Claim any end of season rewards you might have.");

	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_disconnect", Event_OnPlayerDisconnect);

	BuildPath(Path_SM, g_BasePath, sizeof(g_BasePath), "configs/furious/seasonrewards");

	if (!DirExists(g_BasePath)) {
		CreateDirectory(g_BasePath, DIR_PERMS);
	}
}

public void OnMapStart() {
	char sSound[PLATFORM_MAX_PATH]; char sDownload[PLATFORM_MAX_PATH];

	convar_Sound_Reminder.GetString(sSound, sizeof(sSound));
	FormatEx(sDownload, sizeof(sDownload), "sound/%s", sSound);

	if (strlen(sSound) > 0 && FileExists(sDownload)) {
		PrecacheSound(sSound);
		AddFileToDownloadsTable(sDownload);
	}

	convar_Sound_Claimed.GetString(sSound, sizeof(sSound));
	FormatEx(sDownload, sizeof(sDownload), "sound/%s", sSound);

	if (strlen(sSound) > 0 && FileExists(sDownload)) {
		PrecacheSound(sSound);
		AddFileToDownloadsTable(sDownload);
	}
}

public void OnSQLConnect(Database db, const char[] error, any data) {
	if (db == null) {
		ThrowError("Error while connecting to database: %s", error);
	}
	
	g_Database = db;
	LogMessage("Connected to database successfully.");

	g_Database.Query(OnCreateTable, "CREATE TABLE IF NOT EXISTS `cache_data` ( `id` INT NOT NULL AUTO_INCREMENT , `accountid` INT(32) NOT NULL , `server` VARCHAR(64) NOT NULL , `last_season` INT NOT NULL , `last_tier` VARCHAR(64) NOT NULL , `last_rank` INT NOT NULL , `claimed` INT NOT NULL , PRIMARY KEY (`id`), UNIQUE (`accountid`, `server`)) ENGINE = InnoDB;", DBPrio_Low);
}

public void OnCreateTable(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while creating table: %s", error);
	}

	// char auth[64];
	// for (int i = 1; i <= MaxClients; i++) {
	// 	if (IsClientAuthorized(i) && GetClientAuthId(i, AuthId_Steam2, auth, sizeof(auth))) {
	// 		OnClientAuthorized(i, auth);
	// 	}
	// }
}

public void OnClientAuthorized(int client, const char[] auth) {
	if (!convar_Enabled.BoolValue) {
		return;
	}
	
	if (IsFakeClient(client)) {
		return;
	}

	if (g_Database == null) {
		return;
	}

	int accountid = GetSteamAccountID(client);

	if (accountid < 1) {
		return;
	}

	//Check if they have any pending rewards to claim from their last connect.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT last_season, last_tier, last_rank, claimed FROM `cache_data` WHERE accountid = '%i' AND server = '%s';", accountid, GetServerIP(true));
	g_Database.Query(OnParseCache, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void OnParseCache(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while parsing player cache: %s", error);
	}

	int client;
	if ((client = GetClientOfUserId(data)) == 0) {
		return;
	}

	if (results.FetchRow()) {
		int last_season = results.FetchInt(0);

		char sUnique[64];
		results.FetchString(1, sUnique, sizeof(sUnique));

		int last_rank = results.FetchInt(2);

		//Rewards are currently claimed already, gotta wait.
		if (results.FetchInt(3) > 0) {
			return;
		}

		//Only allow past seasons to be claimed.
		if (last_season >= Furious_Statistics_GetSeason()) {
			return;
		}

		g_RewardSeason[client] = last_season;
		
		//They were here for a previous season and have a valid tier.
		g_TotalRewards[client] = 0;
		ProcessClaims(client, last_season, sUnique, last_rank);
	} else {
		LogMessage("%N is being processed for past rewards...", client);
		int season = Furious_Statistics_GetSeason() - 1;

		Transaction txn = new Transaction();

		int accountid = GetSteamAccountID(client);

		if (accountid < 1) {
			return;
		}

		char sQuery[256];
		for (int i = season; i > 0; i--) {
			g_Database.Format(sQuery, sizeof(sQuery), "SELECT * FROM `furious_server_season_%i` WHERE accountid = '%i';", i, accountid);
			txn.AddQuery(sQuery, i);
		}

		Database dbs = Furious_Statistics_GetServerDatabase();

		if (dbs == null) {
			delete txn;
			ThrowError("Error while processing player: Invalid Server Database");
		}

		dbs.Execute(txn, onSuccess, onFailure, GetClientUserId(client), DBPrio_Low);
	}
}

public void onSuccess(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData) {

	int client;
	if ((client = GetClientOfUserId(data)) == 0) {
		delete db;
		return;
	}

	bool found;
	for (int i = 0; i < numQueries; i++) {
		if (results[i] == null) {
			continue;
		}

		if (results[i].FetchRow()) {
			OnCalculateRank(db, client, queryData[i]);
			found = true;
			break;
		}
	}

	//Check if they've connected to any past seasons and if they haven't then we just set them up on the current season.
	if (!found) {
		int points = Furious_Statistics_GetPoints(client);
		int season = Furious_Statistics_GetSeason();

		char sUnique[64];
		Furious_Statistics_GetTierUnique(points, sUnique, sizeof(sUnique));

		int rank = Furious_Statistics_GetRank(client);

		int accountid = GetSteamAccountID(client);

		if (accountid < 1) {
			return;
		}
		
		//Save the current season and tier unique key so if they connect next season we can check for it and if not then we can force the rewards if the last season is two seasons behind.
		char sQuery[256];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `cache_data` (`accountid`, `server`, `last_season`, `last_tier`, `last_rank`, `claimed`) VALUES ('%i', '%s', '%i', '%s', '%i', '0');", accountid, GetServerIP(true), season, sUnique, rank);
		g_Database.Query(OnInsertNewData, sQuery, _, DBPrio_Low);
	}
}

public void OnInsertNewData(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while inserting new player data: %s", error);
	}
}

void OnCalculateRank(Database db, int client, int season) {
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(season);

	int accountid = GetSteamAccountID(client);

	if (accountid < 1) {
		return;
	}

	char sQuery[512];
	db.Format(sQuery, sizeof(sQuery), "SELECT points, FIND_IN_SET( points, ( SELECT GROUP_CONCAT( points ORDER BY points DESC ) FROM furious_server_season_%i ) ) AS rank FROM furious_server_season_%i WHERE accountid = '%i' ORDER BY `rank` ASC LIMIT 1", season, season, accountid);
	db.Query(OnParseRank, sQuery, pack, DBPrio_Low);
}

public void OnParseRank(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();

	int userid = pack.ReadCell();
	int season = pack.ReadCell();

	delete pack;

	int client;
	if ((client = GetClientOfUserId(userid)) == 0) {
		delete db;
		return;
	}

	if (results.FetchRow()) {
		int points = results.FetchInt(0);
		int rank = results.FetchInt(1);

		OnSaveCache(client, season, rank, points);
	}

	delete db;
}

void OnSaveCache(int client, int last_season, int last_rank, int points) {

	char sUnique[64];
	Furious_Statistics_GetTierUnique(points, sUnique, sizeof(sUnique));

	int accountid = GetSteamAccountID(client);

	if (accountid < 1) {
		return;
	}

	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteCell(last_season);
	pack.WriteString(sUnique);
	pack.WriteCell(last_rank);

	//Save the current season and tier unique key so if they connect next season we can check for it and if not then we can force the rewards if the last season is two seasons behind.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `cache_data` (`accountid`, `server`, `last_season`, `last_tier`, `last_rank`, `claimed`) VALUES ('%i', '%s', '%i', '%s', '%i', '0');", accountid, GetServerIP(true), last_season, sUnique, last_rank);
	g_Database.Query(OnSaveProcessedData, sQuery, pack, DBPrio_Low);
}

public void OnSaveProcessedData(Database db, DBResultSet results, const char[] error, DataPack pack) {
	pack.Reset();
	
	int userid = pack.ReadCell();
	int last_season = pack.ReadCell();

	char sUnique[64];
	pack.ReadString(sUnique, sizeof(sUnique));

	int last_rank = pack.ReadCell();

	delete pack;

	if (results == null) {
		ThrowError("Error while saving processed player data: %s", error);
	}

	int client;
	if ((client = GetClientOfUserId(userid)) > 0) {
		LogMessage("%N has been processed successfully.", client);

		g_RewardSeason[client] = last_season;
	
		//They were here for a previous season and have a valid tier.
		g_TotalRewards[client] = 0;
		ProcessClaims(client, last_season, sUnique, last_rank);
	}
}

public void onFailure(Database db, any data, int numQueries, const char[] error, int failIndex, any[] queryData) {
	// int client;
	// if ((client = GetClientOfUserId(data)) == 0) {
	// 	return;
	// }

	LogError("Error while processing previous season rewards:\n - Index: %i\n - Total: %i\n - Season: %i\n - Error: %s", failIndex, numQueries, queryData[failIndex], error);
}

//Process rewards for a player.
void ProcessClaims(int client, int season, const char[] unique, int rank) {
	//Quick way of processing global rewards.
	if (season != -1) {
		ProcessClaims(client, -1, unique, rank);
	}

	char sPath[PLATFORM_MAX_PATH];
	if (season == -1) {
		FormatEx(sPath, sizeof(sPath), "%s/season_all.cfg", g_BasePath);
	} else {
		FormatEx(sPath, sizeof(sPath), "%s/season_%i.cfg", g_BasePath, season);
	}

	if (!FileExists(sPath)) {
		ThrowError("Error while processing player: Missing season file: %s", sPath);
	}

	KeyValues kv = new KeyValues("seasonrewards");

	if (kv.ImportFromFile(sPath)) {
		
		if (strlen(unique) > 0 && kv.JumpToKey(unique) && kv.GotoFirstSubKey(false)) {
			char sRewardType[64]; char sType[16]; char sReward[64];
			do {
				kv.GetSectionName(sRewardType, sizeof(sRewardType));
				kv.GetString("type", sType, sizeof(sType), "tier");

				if (!StrEqual(sType, "tier", false)) {
					continue;
				}

				kv.GetString(NULL_STRING, sReward, sizeof(sReward));
				g_Reward[client][g_TotalRewards[client]++].Add(sRewardType, sType, sReward);
			} while (kv.GotoNextKey(false));

			kv.Rewind();
		}

		char sRank[16];
		IntToString(rank, sRank, sizeof(sRank));

		if (rank > 0 && kv.JumpToKey(sRank) && kv.GotoFirstSubKey(false)) {
			char sRewardType[64]; char sType[16]; char sReward[64];
			do {
				kv.GetSectionName(sRewardType, sizeof(sRewardType));
				kv.GetString("type", sType, sizeof(sType), "tier");

				if (!StrEqual(sType, "rank", false)) {
					continue;
				}

				kv.GetString(NULL_STRING, sReward, sizeof(sReward));
				g_Reward[client][g_TotalRewards[client]++].Add(sRewardType, sType, sReward);
			} while (kv.GotoNextKey(false));
		}
	} else {
		ThrowError("Error while processing player: Malformed season file: %s", sPath);
	}

	delete kv;

	if (IsClientInGame(client) && g_TotalRewards[client] > 0) {
		RemindOfRewards(client);
	}
}

//Processes rewards into an index that isn't a client and is offline.
void ProcessOfflineClaims(int index, int season, const char[] unique, int rank, int accountid = -1) {
	//Quick way of processing global rewards.
	if (season != -1) {
		ProcessOfflineClaims(index, -1, unique, rank, accountid);
	}

	char sPath[PLATFORM_MAX_PATH];
	if (season == -1) {
		FormatEx(sPath, sizeof(sPath), "%s/season_all.cfg", g_BasePath);
	} else {
		FormatEx(sPath, sizeof(sPath), "%s/season_%i.cfg", g_BasePath, season);
	}

	KeyValues kv = new KeyValues("seasonrewards");

	if (kv.ImportFromFile(sPath)) {

		if (strlen(unique) > 0 && kv.JumpToKey(unique) && kv.GotoFirstSubKey(false)) {
			char sRewardType[64]; char sType[16]; char sReward[64];
			do {
				kv.GetSectionName(sRewardType, sizeof(sRewardType));
				kv.GetString("type", sType, sizeof(sType));

				if (!StrEqual(sType, "tier", false)) {
					continue;
				}

				kv.GetString(NULL_STRING, sReward, sizeof(sReward));
				g_OfflineReward[index][g_OfflineTotalRewards[index]++].Add(sRewardType, sType, sReward, accountid);
			} while (kv.GotoNextKey(false));

			kv.Rewind();
		}

		char sRank[16];
		IntToString(rank, sRank, sizeof(sRank));

		if (rank > 0 && kv.JumpToKey(sRank) && kv.GotoFirstSubKey(false)) {
			char sRewardType[64]; char sType[16]; char sReward[64];
			do {
				kv.GetSectionName(sRewardType, sizeof(sRewardType));
				kv.GetString("type", sType, sizeof(sType));

				if (!StrEqual(sType, "rank", false)) {
					continue;
				}

				kv.GetString(NULL_STRING, sReward, sizeof(sReward));
				g_OfflineReward[index][g_OfflineTotalRewards[index]++].Add(sRewardType, sType, sReward, accountid);
			} while (kv.GotoNextKey(false));
		}
	}

	delete kv;
}

public void Event_OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast) {
	if (!convar_Enabled.BoolValue) {
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client < 1 || IsFakeClient(client) || event.GetBool("bot")) {
		return;
	}

	if (g_Database == null) {
		return;
	}

	int points = Furious_Statistics_GetPoints(client);
	int season = Furious_Statistics_GetSeason();

	char sUnique[64];
	Furious_Statistics_GetTierUnique(points, sUnique, sizeof(sUnique));

	int rank = Furious_Statistics_GetRank(client);

	int accountid = GetSteamAccountID(client);

	if (accountid < 1) {
		return;
	}

	//Save the current season and tier unique key so if they connect next season we can check for it and if not then we can force the rewards if the last season is two seasons behind.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE IGNORE `cache_data` SET last_season = '%i', last_tier = '%s', last_rank = '%i' WHERE accountid = '%i' AND server = '%s';", season, sUnique, rank, accountid, GetServerIP(true));
	g_Database.Query(OnCacheData, sQuery, _, DBPrio_Low);
}

public void OnCacheData(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while caching data: %s", error);
	}
}

char[] GetServerIP(bool showport = false)
{
	int ip = FindConVar("hostip").IntValue;

	int ips[4];
	ips[0] = (ip >> 24) & 0x000000FF;
	ips[1] = (ip >> 16) & 0x000000FF;
	ips[2] = (ip >> 8) & 0x000000FF;
	ips[3] = ip & 0x000000FF;

	char sIP[64];
	Format(sIP, sizeof(sIP), "%d.%d.%d.%d", ips[0], ips[1], ips[2], ips[3]);

	if (showport)
		Format(sIP, sizeof(sIP), "%s:%d", sIP, FindConVar("hostport").IntValue);
	
	return sIP;
}

public Action Command_Claim(int client, int args) {
	if (!convar_Enabled.BoolValue) {
		return Plugin_Handled;
	}

	if (client == 0) {
		CReplyToCommand(client, "%T%T", "chat tag", client, "Command is in-game only", client);
		return Plugin_Handled;
	}

	if (g_Database == null) {
		CPrintToChat(client, "%T%T", "chat tag", client, "error", client);
		return Plugin_Handled;
	}

	//No rewards available to them, they have nothing to claim.
	if (g_TotalRewards[client] == 0) {
		CPrintToChat(client, "%T%T", "chat tag", client, "no rewards", client);
		return Plugin_Handled;
	}

	int accountid = GetSteamAccountID(client);

	if (accountid < 1) {
		PrintToChat(client, "You are currently not connected to Steam to use this command.");
		return Plugin_Handled;
	}

	//Check if they already claimed rewards for last season yet or not.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `cache_data` SET claimed = '1' WHERE accountid = '%i' AND server = '%s';", accountid, GetServerIP(true));
	g_Database.Query(OnClaimRewards, sQuery, GetClientUserId(client), DBPrio_Low);

	return Plugin_Handled;
}

public void OnClaimRewards(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while claiming rewards: %s", error);
	}

	int client;
	if ((client = GetClientOfUserId(data)) == 0) {
		return;
	}

	//Give them the pending rewards we processed earlier.
	for (int i = 0; i < g_TotalRewards[client]; i++) {
		if (StrEqual(g_Reward[client][i].reward_type, "credits", false)) {
			Furious_Statistics_AddCredits(client, StringToInt(g_Reward[client][i].reward), true);
		} else if (StrEqual(g_Reward[client][i].reward_type, "item", false)) {
			Furious_Store_SendItemByName(client, g_Reward[client][i].reward);
		}
	}

	//Clear the pending rewards data and tell them they got it.
	ClearRewards(client);
	CPrintToChat(client, "%T%T", "chat tag", client, "claimed", client, g_RewardSeason[client]);

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Claimed.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0) {
		EmitSoundToClient(client, sSound);
	}

	char sOverlay[PLATFORM_MAX_PATH];
	convar_Overlay_Claimed.GetString(sOverlay, sizeof(sOverlay));

	if (strlen(sOverlay) > 0) {
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		ClientCommand(client, "r_screenoverlay \"%s\"", sOverlay);
		SetCommandFlags("r_screenoverlay", iFlags);

		CreateTimer(3.0, Timer_ResetOverlayForClient, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

void ClearRewards(int client) {
	for (int i = 0; i < g_TotalRewards[client]; i++) {
		g_Reward[i][client].Clear();
	}

	g_TotalRewards[client] = 0;
}

public void Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	if (!convar_Enabled.BoolValue) {
		return;
	}

	int client = GetClientOfUserId(event.GetInt("userid"));

	//Rewards available, let them know on spawn.
	if (g_TotalRewards[client] > 0) {
		RemindOfRewards(client);
	}
}

public void Furious_Statistics_OnSeasonChange(int season, char[] ip, int port) {
	if (!convar_Enabled.BoolValue) {
		return;
	}

	if (g_Database == null) {
		return;
	}

	//Once a season changes, we want to make sure players from last season can claim their rewards for last season or any seasons prior.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `cache_data` SET claimed = '0' WHERE last_season = '%i' AND server = '%s';", (season - 1), GetServerIP(true));
	g_Database.Query(OnResetClaims, sQuery, season, DBPrio_Low);
}

public void OnResetClaims(Database db, DBResultSet results, const char[] error, any season) {
	if (results == null) {
		ThrowError("Error while resetting available claims for last season: %s", error);
	}
	
	//Lets check if any players have claimed their rewards for seasons prior to the last season and if they haven't, just give them the rewards instead manually.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id, last_season, last_tier, last_rank FROM `cache_data` WHERE claimed = '0' AND last_season < '%i' AND server = '%s';", (season - 1), GetServerIP(true));
	g_Database.Query(OnForceClaims, sQuery, _, DBPrio_Low);
}

public void OnForceClaims(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while forcing available claims from seasons prior to last season: %s", error);
	}

	g_Offline = 0;

	//Process the claims from the database for the offline player to give to them.
	int id; int accountid; int last_season; char unique[64]; int last_rank; char sQuery[256];
	while (results.FetchRow()) {
		id = results.FetchInt(0);
		accountid = results.FetchInt(1);
		last_season = results.FetchInt(2);
		results.FetchString(3, unique, sizeof(unique));
		last_rank = results.FetchInt(4);
		
		//Process the claims into indexes and make sure they increment.
		int index = g_Offline;
		g_OfflineTotalRewards[index] = 0;
		ProcessOfflineClaims(index, last_season, unique, last_rank, accountid);
		g_Offline++;

		//Make sure to update their status since they've claimed their previous items.
		g_Database.Format(sQuery, sizeof(sQuery), "UPDATE `cache_data` SET claimed = '1' WHERE id = '%i';", id);
		g_Database.Query(OnUpdateID, sQuery, _, DBPrio_Low);
	}

	//Give the rewards to the player while they're offline with their accountid.
	for (int index = 0; index < g_Offline; index++) {
		
		//Each reward is tied to the offline index which comes with the accountid by default.
		for (int reward = 0; reward < g_TotalRewards[index]; reward++) {
			if (StrEqual(g_Reward[index][reward].reward_type, "credits", false)) {
				Furious_Statistics_AddCreditsToAccount(g_Reward[index][reward].accountid, StringToInt(g_Reward[index][reward].reward));
			} else if (StrEqual(g_Reward[index][reward].reward_type, "item", false)) {
				Furious_Store_SendItemByNameToAccount(g_Reward[index][reward].accountid, g_Reward[index][reward].reward);
			}

			g_Reward[index][reward].Clear();
		}

		g_TotalRewards[index] = 0;
	}

	g_Offline = 0;
}

public void OnUpdateID(Database db, DBResultSet results, const char[] error, any data) {
	if (results == null) {
		ThrowError("Error while resetting claim status for last season players: %s", error);
	}
}

//Gentle reminder that they should probably claim their rewards.
void RemindOfRewards(int client) {
	int time = GetTime();

	if (g_Reminder[client] > time) {
		return;
	}

	g_Reminder[client] = time + 2;

	CPrintToChat(client, "%T%T", "chat tag", client, "claim", client);

	char sSound[PLATFORM_MAX_PATH];
	convar_Sound_Reminder.GetString(sSound, sizeof(sSound));

	if (strlen(sSound) > 0) {
		EmitSoundToClient(client, sSound);
	}

	char sOverlay[PLATFORM_MAX_PATH];
	convar_Overlay_Reminder.GetString(sOverlay, sizeof(sOverlay));

	if (strlen(sOverlay) > 0) {
		int iFlags = GetCommandFlags("r_screenoverlay");
		SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
		ClientCommand(client, "r_screenoverlay \"%s\"", sOverlay);
		SetCommandFlags("r_screenoverlay", iFlags);

		CreateTimer(3.0, Timer_ResetOverlayForClient, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
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

public void OnClientDisconnect_Post(int client) {
	g_Reminder[client] = 0;
}