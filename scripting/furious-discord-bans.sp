#include <sourcemod>
#include <sourcebanspp>
#include <autoexecconfig>
#include <unixtime_sourcemod>
#include <ripext>
#include <discord>

public Plugin myinfo = 
{
	name = "[Furious] Discord bans notification", 
	author = "FrAgOrDiE", 
	description = "", 
	version = "1.0", 
	url = "https://furious-clan.com"
};

ConVar convar_Webhook;
ConVar convar_SteamWebAPIKey;
HTTPClient g_hHTTPClient;

public void OnPluginStart()
{
	AutoExecConfig_SetFile("frs.discordbansnotification");
	convar_Webhook = AutoExecConfig_CreateConVar("sm_discordbansnotification_webhook", "");
	convar_SteamWebAPIKey = AutoExecConfig_CreateConVar("sm_discordbansnotification_steam_webkey", "");
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	g_hHTTPClient = new HTTPClient("https://api.steampowered.com");
	RegAdminCmd("sm_firebanplayer", Command_FireBanPlayer, ADMFLAG_ROOT);
}

public Action Command_FireBanPlayer(int client, int target)
{
	char sAdminIndex[3], sTargetIndex[3], sTime[64], sReason[256];
	GetCmdArg(1, sAdminIndex, sizeof(sAdminIndex));
	GetCmdArg(2, sTargetIndex, sizeof(sTargetIndex));
	GetCmdArg(3, sTime, sizeof(sTime));
	GetCmdArg(4, sReason, sizeof(sReason));
	SendDiscordMessage(StringToInt(sAdminIndex), StringToInt(sTargetIndex), StringToInt(sTime), sReason);
	return Plugin_Handled;
}

public void SBPP_OnBanPlayer(int admin, int target, int time, const char[] reason)
{
	SendDiscordMessage(admin, target, time, reason);
}

void SendDiscordMessage(int admin, int target, int time, const char[] reason)
{
	char sEndPoint[128], sAPIKey[64], sTargetSteam64[32], sAdminName[64], sTargetName[64];
	convar_SteamWebAPIKey.GetString(sAPIKey, sizeof(sAPIKey));
	GetClientAuthId(target, AuthId_SteamID64, sTargetSteam64, sizeof(sTargetSteam64));
	GetClientName(admin, sAdminName, sizeof(sAdminName));
	GetClientName(target, sTargetName, sizeof(sTargetName));
	Format(sEndPoint, sizeof(sEndPoint), "ISteamUser/GetPlayerSummaries/v0002/?key=%s&steamids=%s", sAPIKey, sTargetSteam64);
	DataPack pack = new DataPack();
	pack.WriteString(sAdminName);
	pack.WriteString(sTargetName);
	pack.WriteString(sTargetSteam64);
	pack.WriteCell(time);
	pack.WriteString(reason);
	g_hHTTPClient.Get(sEndPoint, HTTPRequestCallback_GetPlayerSummary, pack);
}

public void HTTPRequestCallback_GetPlayerSummary(HTTPResponse response, DataPack pack, const char[] error)
{
	char sAdminName[64], sTargetName[64], sReason[256], sFooter[128], sTargetSteam64[32];
	pack.Reset();
	pack.ReadString(sAdminName, sizeof(sAdminName));
	pack.ReadString(sTargetName, sizeof(sTargetName));
	pack.ReadString(sTargetSteam64, sizeof(sTargetSteam64));
	int time = pack.ReadCell();
	pack.ReadString(sReason, sizeof(sReason));
	delete pack;
	
	if (response.Status != HTTPStatus_OK)
	{
		LogError("Error on request. (%i) Error: %s", response.Status, error);
		return;
	}
	
	int iTime = GetTime();
	int year, month, day, hour, minute, second;
	UnixToTime(iTime, year, month, day, hour, minute, second, UT_TIMEZONE_SERVER);
	char sHostname[128], sTitle[256], sTitleLink[128], sBanLength[64], sImage[128];
	FindConVar("hostname").GetString(sHostname, sizeof(sHostname));
	Format(sFooter, sizeof(sFooter), "%i/%s%i - %i (%s)", day, month < 10 ? "0" : "", month, year, sHostname);
	Format(sTitle, sizeof(sTitle), "%s ( Steam Link )", sTargetName);
	Format(sTitleLink, sizeof(sTitleLink), "http://steamcommunity.com/profiles/%s", sTargetSteam64);
	Format(sAdminName, sizeof(sAdminName), StrEqual(sAdminName, sHostname) ? "Anticheat" : sAdminName);
	if (time == 0)
	{
		Format(sBanLength, sizeof(sBanLength), "Permanent");
	}
	else
	{
		FormatSecondsEx(time, day, hour, minute, second);
		if (day > 0)
		{
			Format(sBanLength, sizeof(sBanLength), day != 1 ? "%i days " : "%s1 day ", day);
		}
		if (hour > 0)
		{
			Format(sBanLength, sizeof(sBanLength), hour != 1 ? "%s%i hours " : "%s1 hour ", sBanLength, hour);
		}
		if (minute > 0)
		{
			Format(sBanLength, sizeof(sBanLength), minute != 1 ? "%s%i minutes " : "%s1 minute ", sBanLength, minute);
		}
		if (second > 0)
		{
			Format(sBanLength, sizeof(sBanLength), second != 1 ? "%s%i seconds " : "%s1 second ", sBanLength, second);
		}
	}
	JSONObject fullResponse = view_as<JSONObject>(response.Data);
	JSONObject jResponse = view_as<JSONObject>(fullResponse.Get("response"));
	JSONArray players = view_as<JSONArray>(jResponse.Get("players"));
	JSONObject player = view_as<JSONObject>(players.Get(0));
	player.GetString("avatarfull", sImage, sizeof(sImage));
	delete fullResponse;
	delete jResponse;
	delete players;
	delete player;
	MessageEmbed embed = new MessageEmbed();
	embed.SetColor("#ea5353");
	embed.SetAuthor("PLAYER BANNED");
	embed.SetThumb(sImage)
	embed.SetTitle(sTitle);
	embed.SetTitleLink(sTitleLink);
	embed.AddField("Reason", sReason, false);
	embed.AddField("Length", sBanLength, false);
	embed.AddField("Banned by", sAdminName, false);
	embed.SetFooter(sFooter);
	char sWebHook[128];
	convar_Webhook.GetString(sWebHook, sizeof(sWebHook));
	DiscordWebHook hook = new DiscordWebHook(sWebHook);
	hook.SlackMode = true;
	hook.Embed(embed);
	hook.Send();
	delete hook;
}

void FormatSecondsEx(int starting, int & days, int & hours, int & minutes, int & seconds)
{
	days = starting / (24 * 3600);
	starting = starting % (24 * 3600);
	hours = starting / 3600;
	starting %= 3600;
	minutes = starting / 60;
	starting %= 60;
	seconds = starting;
} 