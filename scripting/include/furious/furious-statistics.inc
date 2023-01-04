#if defined _furious_statistics_included
 #endinput
#endif
#define _furious_statistics_included

#include <dbi>

native int Furious_Statistics_GetTier(int client);
native int Furious_Statistics_GetRank(int client);
native int Furious_Statistics_GetTierUnique(int points, char[] buffer, int size);
native int Furious_Statistics_GetPoints(int client);
native bool Furious_Statistics_GetTierTag(int client, const char[] sTag, int size);
native float Furious_Statistics_GetPlaytime(int client);
native bool Furious_Statistics_SetSpecHud(int client, bool enabled);
native void Furious_Statistics_AddCredits(int client, int credits, bool verbose = false);
native void Furious_Statistics_AddCreditsToAccount(int accountid, int credits);
native int Furious_Statistics_GetCredits(int client);
native void Furious_Statistics_SetCredits(int client, int credits, bool verbose = false);
native int Furious_Statistics_GetCreditsEarned(int client);
native void Furious_Statistics_SetCreditsEarned(int client, int credits);
native float Furious_Statistics_GetCreditsTimer(int client);
native void Furious_Statistics_SetCreditsTimer(int client, float timer);
native void Furious_Statistics_AddSeasonalPoints(int client, float points);
native float Furious_Statistics_GetRankPointsGain(int client);
native bool Furious_Statistics_IsRankedEnabled();
native Database Furious_Statistics_GetGlobalDatabase();
native Database Furious_Statistics_GetServerDatabase();
native int Furious_Statistics_GetSeason();
native bool Furious_Statistics_IsSeasonActive();

forward void Furious_Statistics_OnGlobalValidated(int client, bool created);
forward void Furious_Statistics_OnSeasonChange(int season, char[] ip, int port);
forward void Furious_Statistics_StatsMe_OnSeasonStats(int client, char[] text, int maxlength, int& cells);
forward void Furious_Statistics_OnConnectGlobal();
forward void Furious_Statistics_OnConnectServer();
forward void Furious_Statistics_OnSeasonRetrieved(int season);
forward void Furious_Statistics_SeasonTable_OnCreateTable(char[] queryEnd, int maxlength, int& cells);
forward void Furious_Statistics_SeasonTable_OnResetData(int client, char[] queryEnd, int maxlength, int& cells);
forward void Furious_Statistics_OnSeasonalStatsReset(int client);

#if !defined REQUIRE_PLUGIN
public void __pl_player_statistics_SetNTVOptional()
{
	MarkNativeAsOptional("Furious_Statistics_GetTier");
	MarkNativeAsOptional("Furious_Statistics_GetRank");
	MarkNativeAsOptional("Furious_Statistics_GetTierUnique");
	MarkNativeAsOptional("Furious_Statistics_GetPoints");
	MarkNativeAsOptional("Furious_Statistics_GetTierTag");
	MarkNativeAsOptional("Furious_Statistics_GetPlaytime");
	MarkNativeAsOptional("Furious_Statistics_SetSpecHud");
	MarkNativeAsOptional("Furious_Statistics_AddCredits");
	MarkNativeAsOptional("Furious_Statistics_AddCreditsToAccount");
	MarkNativeAsOptional("Furious_Statistics_GetCredits");
	MarkNativeAsOptional("Furious_Statistics_SetCredits");
	MarkNativeAsOptional("Furious_Statistics_GetCreditsEarned");
	MarkNativeAsOptional("Furious_Statistics_SetCreditsEarned");
	MarkNativeAsOptional("Furious_Statistics_GetCreditsTimer");
	MarkNativeAsOptional("Furious_Statistics_SetCreditsTimer");
	MarkNativeAsOptional("Furious_Statistics_AddSeasonalPoints");
	MarkNativeAsOptional("Furious_Statistics_GetRankPointsGain");
	MarkNativeAsOptional("Furious_Statistics_IsRankedEnabled");
	MarkNativeAsOptional("Furious_Statistics_GetGlobalDatabase");
	MarkNativeAsOptional("Furious_Statistics_GetServerDatabase");
	MarkNativeAsOptional("Furious_Statistics_GetSeason");
	MarkNativeAsOptional("Furious_Statistics_IsSeasonActive");
}
#endif

public SharedPlugin __pl_player_statistics =
{
	name = "furious_statistics",
	file = "furious-statistics.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
