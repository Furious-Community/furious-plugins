#include <sourcemod>
#include <sdktools>
#include <colors_csgo>
#include <redie>
#include <autoexecconfig>
#include <sdkhooks>
#undef REQUIRE_PLUGIN
#include <furious/furious-store>
#define REQUIRE_PLUGIN

#pragma newdecls required
#define PLUGIN_VERSION "1.00.1"

#define IsClientEntity(%0) ( %0 >= 1 && %0 <= MaxClients )

/*
* Plugin Information - Please do not change this
*/
public Plugin myinfo =
{
	name = "Easy Spawn Protection",
	author = "Invex | Byte, based on work of cREANy0 and Fredd",
	description = "Easy to use spawn protection plugin.",
	version = PLUGIN_VERSION,
	url = "http://www.invexgaming.com.au"
}

bool bForward;
bool isEnabled;
bool inRoundStartProtectionTime = false;
bool isProtected[MAXPLAYERS + 1];
float roundStartTime = 0.0;
float freezeTime = 0.0;
char PREFIX[] = "";
int g_iModelColor[4] =  { 0, 255, 0, 255 };
#define MODE_PLAYERSPAWN 0
#define MODE_ROUNDSTART 1
#define COLOUR_OFF 0
#define COLOUR_ALL 1
#define COLOUR_TEAMS 2

#define PROTECTION_COLOR view_as<int>({13, 117, 244, 50})

//Mod information
#define teamOne 2 //CS:S T, CS:GO T, TF2 RED, L4D survivor
#define teamTwo 3 //CS:S CT, CS:GO CT, TF2 BLU, L4D infected
int teamSpectator;
int teamTeamless;
bool hasTeams = true;


//Handles
Handle g_easysp_enabled = null;
Handle g_easysp_time = null;
Handle g_easysp_mode = null;
Handle g_easysp_endOnAttackMode = null;
Handle g_easysp_notify_start = null;
Handle g_easysp_notify_end = null;
Handle g_easysp_rgbcolour_mode = null;
Handle g_easysp_rgbcolour_all = null;
Handle g_easysp_rgbcolour_teamOne = null;
Handle g_easysp_rgbcolour_teamTwo = null;
Handle g_easysp_sponbotcontrol = null;
Handle gH_Frwd_Protection_Started = null;
Handle gH_Frwd_Protection_StartedClient = null;
Handle gH_Frwd_Protection_EndClient = null;
Handle g_hTimer[MAXPLAYERS + 1] = null;

bool g_bTimer[MAXPLAYERS + 1];
bool g_bFrsStore;

//Props
int g_renderOffs = -1;
int g_bIsControllingBot = -1;

enum FX
{
	FxNone = 0,
	FxPulseFast,
	FxPulseSlowWide,
	FxPulseFastWide,
	FxFadeSlow,
	FxFadeFast,
	FxSolidSlow,
	FxSolidFast,
	FxStrobeSlow,
	FxStrobeFast,
	FxStrobeFaster,
	FxFlickerSlow,
	FxFlickerFast,
	FxNoDissipation,
	FxDistort,  // Distort/scale/translate flicker
	FxHologram,  // kRenderFxDistort + distance fade
	FxExplode,  // Scale up really big!
	FxGlowShell,  // Glowing Shell
	FxClampMinScale,  // Keep this sprite from getting very small (SPRITES only!)
	FxEnvRain,  // for environmental rendermode, make rain
	FxEnvSnow,  //  "        "            "    , make snow
	FxSpotlight,
	FxRagdoll,
	FxPulseFastWider,
};

enum Render
{
	Normal = 0,  // src
	TransColor,  // c*a+dest*(1-a)
	TransTexture,  // src*a+dest*(1-a)
	Glow,  // src*a+dest -- No Z buffer checks -- Fixed size in screen space
	TransAlpha,  // src*srca+dest*(1-srca)
	TransAdd,  // src*a+dest
	Environmental,  // not drawn, used for environmental effects
	TransAddFrameBlend,  // use a fractional frame value to blend between animation frames
	TransAlphaAdd,  // src + dest*(1-a)
	WorldGlow,  // Same as kRenderGlow but not fixed size in screen space
	None,  // Don't render.
};

public void OnPluginStart()
{
	//Event hooks
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("round_prestart", Event_RoundPreStart);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_death", Event_PlayerDeath);

	//Load translation
	LoadTranslations("EasySpawnProtection.phrases");

	AutoExecConfig_SetFile("EasySpawnProtection")

	//ConVar List
	AutoExecConfig_CreateConVar("sm_easysp_version", PLUGIN_VERSION, "Version of 'Easy Spawn Protection' plugin", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY | FCVAR_CHEAT | FCVAR_DONTRECORD);
	g_easysp_enabled = AutoExecConfig_CreateConVar("sm_easysp_enabled", "1", "Enable Easy Spawn Protection Plugin (0 off, 1 on, def. 1)");
	g_easysp_mode = AutoExecConfig_CreateConVar("sm_easysp_mode", "0", "The mode of operation. (0 spawn protection when player is spawned, 1 spawn protection for set time from round start, def. 0");
	g_easysp_time = AutoExecConfig_CreateConVar("sm_easysp_time", "5.0", "Duration of spawn protection. (min. 0.0, def. 5.0)");
	g_easysp_notify_start = AutoExecConfig_CreateConVar("sm_easysp_notify_start", "1", "Let users know that they have gained spawn protection. (0 off, 1 on, def. 1)");
	g_easysp_notify_end = AutoExecConfig_CreateConVar("sm_easysp_notify_end", "1", "Let users know that they have lost spawn protection. (0 off, 1 on, def. 1)");
	g_easysp_rgbcolour_mode = AutoExecConfig_CreateConVar("sm_easysp_colour_mode", "1", "Colour highlighting mode to use. (0 off, 1 highlight all player same colour, 2 use different colours for teamOne/teamTwo, def. 1)");
	g_easysp_rgbcolour_all = AutoExecConfig_CreateConVar("sm_easysp_colour", "0 255 0 120", "Set spawn protection model highlighting colour. <RED> <GREEN> <BLUE> <OPACITY>. (def. \"0 255 0 120\")");
	g_easysp_rgbcolour_teamOne = AutoExecConfig_CreateConVar("sm_easysp_colour_teamOne", "0 255 0 120", "Set spawn protection model highlighting colour for team One (CS:S T, CS:GO T, TF2 RED, L4D Survivor). <RED> <GREEN> <BLUE> <OPACITY>. (def. \"0 255 0 120\")");
	g_easysp_rgbcolour_teamTwo = AutoExecConfig_CreateConVar("sm_easysp_colour_teamTwo", "0 255 0 120", "Set spawn protection model highlighting colour for team Two (CS:S CT, CS:GO CT, TF2 BLU, L4D Infected). <RED> <GREEN> <BLUE> <OPACITY>. (def. \"0 255 0 120\")");
	g_easysp_endOnAttackMode = AutoExecConfig_CreateConVar("sm_easysp_endonattack_mode", "0", "Specifies if spawn protection should end if player attacks. (0 off, 1 turn off SP as soon as player shots or fire any weapon, def. 0)");
	g_easysp_sponbotcontrol = AutoExecConfig_CreateConVar("sm_easysp_sponbotcontrol", "1", "Should bots receive spawn protection if another player takes control of them. (0 off, 1 on, def. 1)");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	char sPath[PLATFORM_MAX_PATH], sMap[32];
	ArrayList exclude = new ArrayList(32);
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/furious/furious_modeltints.cfg");
	KeyValues kv = new KeyValues("ModelTints");
	if (!kv.ImportFromFile(sPath))
		SetFailState("Couldn't import: \"%s\"", sPath);
	kv.JumpToKey("default color");
	kv.GetColor4("rgb", g_iModelColor);
	kv.GoBack();
	kv.JumpToKey("map_excluded");
	if (!kv.GotoFirstSubKey())
	{
		delete kv;
		delete exclude;
		LogMessage("No entries in modeltints config file");
	}
	else
	{
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
					kv.GetColor4("rgb", g_iModelColor);
					exclude.PushArray(g_iModelColor, sizeof(g_iModelColor));
				}
				while (kv.GotoNextKey());
				kv.GoBack();
				kv.GoBack();
				kv.GetColor4("default", g_iModelColor);
			}
		}
		while (kv.GotoNextKey());
	}

	//Enable status hook
	HookConVarChange(g_easysp_enabled, ConVarChange_enabled);

	//Find some props
	g_renderOffs = FindSendPropInfo("CBasePlayer", "m_clrRender");
	g_bIsControllingBot = FindSendPropInfo("CCSPlayer", "m_bIsControllingBot");

	//Detect mod
	char modName[21];
	GetGameFolderName(modName, sizeof(modName));

	if (StrEqual(modName, "cstrike", false) || StrEqual(modName, "dod", false) || StrEqual(modName, "csgo", false) || StrEqual(modName, "tf", false)) {
		teamSpectator = 1;
		teamTeamless = 0;
		hasTeams = true;
	}
	else if (StrEqual(modName, "Insurgency", false)) {
		teamSpectator = 3;
		teamTeamless = 0;
		hasTeams = true;
	}
	else if (StrEqual(modName, "hl2mp", false)) {
		hasTeams = false;
	}
	else {
		SetFailState("%s is an unsupported mod", modName);
	}

	//Set Variable Values
	isEnabled = true;

	gH_Frwd_Protection_Started = CreateGlobalForward("ESP_OnSpawnProtectionStart", ET_Ignore);
	gH_Frwd_Protection_StartedClient = CreateGlobalForward("ESP_OnSpawnProtectionStartClient", ET_Ignore, Param_Cell, Param_Array, Param_Cell);
	gH_Frwd_Protection_EndClient = CreateGlobalForward("ESP_OnSpawnProtectionEndClient", ET_Ignore, Param_Cell);
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "furious_store"))
		g_bFrsStore = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "furious_store"))
		g_bFrsStore = false;
}

public void OnClientPutInServer(int client)
{
	isProtected[client] = false;
	g_bTimer[client] = false;
	SDKHook(client, SDKHook_OnTakeDamageAlive, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	g_bTimer[client] = false;
}

public void OnMapStart()
{
	UnhookEvent("round_end", Event_RoundEnd);
	HookEvent("round_end", Event_RoundEnd);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("ESP_IsSpawnProtected", Native_IsSpawnProtected);
	CreateNative("ESP_GiveSpawnProtection", Native_GiveSpawnProtection);
	CreateNative("ESP_RemoveSpawnProtection", Native_RemoveSpawnProtection)
	RegPluginLibrary("EasySpawnProtection");
	return APLRes_Success;
}

/*
* If enable convar is changed, use this to turn the plugin off or on
*/
public void ConVarChange_enabled(Handle convar, const char[] oldValue, const char[] newValue)
{
	isEnabled = view_as<bool>(StringToInt(newValue));
}

/*
* Round Pre Start
* We need this to set round start time before player spawns
*/
public Action Event_RoundPreStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (!isEnabled)
		return Plugin_Continue;

	//Record round start time
	roundStartTime = GetGameTime();

	//Get MP freeze time
	Handle mp_freezetime = FindConVar("mp_freezetime");
	if (mp_freezetime != null) {
		freezeTime = GetConVarFloat(mp_freezetime);
	}

	return Plugin_Continue;
}

/*
* Round Start
*/
public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (!isEnabled)
		return Plugin_Continue;
	//Check if mode is correct, otherwise return
	if (GetConVarInt(g_easysp_mode) != MODE_ROUNDSTART)
		return Plugin_Continue;

	CreateTimer(0.2, Timer_RoundStart);
	return Plugin_Continue;
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	bForward = false;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || Redie_IsClientGhost(i))
			continue;
		set_rendering(i, _, g_iModelColor[0], g_iModelColor[1], g_iModelColor[2]);
	}
}

public Action Timer_RoundStart(Handle timer)
{
	//Mode is fixed time mode, give sp to all players
	float sptime = GetConVarFloat(g_easysp_time);

	for (int i = 1; i <= MaxClients; ++i)
	{
		//Ignore players not here, dead players or ghost players
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || Redie_IsClientGhost(i))
			continue;

		//If client is on spectator or is teamless, ignore them
		int iTeam = GetClientTeam(i);
		if (hasTeams && (iTeam == teamSpectator || iTeam == teamTeamless))
			continue;

		//Set spawn protection
		GiveSpawnProtection(i, GetConVarFloat(g_easysp_time), PROTECTION_COLOR);

		//Check if we should notify player of spawn protection
		if (GetConVarBool(g_easysp_notify_start))
			CPrintToChat(i, "%t", "Spawn Protection Start", RoundToNearest(sptime));
	}
	if (!bForward)
	{
		Call_StartForward(gH_Frwd_Protection_Started);
		Call_Finish();
		bForward = true;
	}

	//Now we must set up a timer to globally disable spawn protection for all
	CreateTimer(sptime + freezeTime, RemoveAllProtection);
	inRoundStartProtectionTime = true;
}

/*
* OnPlayerSpawn
*/
public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!isEnabled || g_bFrsStore && Furious_Store_Phoenix_Kit_Used(GetClientOfUserId(event.GetInt("userid"))))
		return Plugin_Continue;

	CreateTimer(0.2, Timer_PlayerSpawn, GetEventInt(event, "userid"));
	return Plugin_Continue;
}

public Action Timer_PlayerSpawn(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);

	if (client < 1 || client > MaxClients)
	{
		return Plugin_Continue;
	}

	if (!IsClientInGame(client))
	{
		return Plugin_Continue;
	}

	int clientTeam = GetClientTeam(client);

	//Ignore dead players and ghosts
	if (!IsPlayerAlive(client) || Redie_IsClientGhost(client))
		return Plugin_Continue;

	//If player controlling a bot and we do not want sp on bot control, then return
	if (!GetConVarBool(g_easysp_sponbotcontrol) && IsPlayerControllingBot(client))
		return Plugin_Continue;

	//If client is on spectator or is teamless, ignore them
	if (hasTeams && (clientTeam == teamSpectator || clientTeam == teamTeamless))
		return Plugin_Continue;

	//Check if mode is correct, otherwise return
	//However, if still in spawn protection time, allow spawn protecting this client
	if (!inRoundStartProtectionTime && GetConVarInt(g_easysp_mode) != MODE_PLAYERSPAWN)
		return Plugin_Continue;

	if (IsClientSpawnProtected(client))
		RemoveProtection(client, false, "");

	//Set spawn protection
	GiveSpawnProtection(client, GetConVarFloat(g_easysp_time), PROTECTION_COLOR);

	//Check if we should notify player of spawn protection
	if (GetConVarBool(g_easysp_notify_start)) {
		float sptime = GetConVarFloat(g_easysp_time);
		if (!bForward)
		{
			Call_StartForward(gH_Frwd_Protection_Started);
			Call_Finish();
			bForward = true
		}
		if (inRoundStartProtectionTime && GetConVarInt(g_easysp_mode) != MODE_PLAYERSPAWN)
			CPrintToChat(client, "%t", "Spawn Protection Start", RoundToNearest(sptime - (GetGameTime() - roundStartTime) + freezeTime));
		else
			CPrintToChat(client, "%t", "Spawn Protection Start", RoundToNearest(sptime));
	}

	return Plugin_Continue;
}

/*
* Give spawn protection to given player and colours them
*/
void GiveSpawnProtection(int client, float sptime, int color[4])
{
	//Check if freeze time will affect this respawn
	float extraTime = 0.0;

	//If this spawn is occuring during spawn time
	if (freezeTime > 0.0 && (GetGameTime() - roundStartTime <= freezeTime)) {
		extraTime = freezeTime - (GetGameTime() - roundStartTime);
	}

	Call_StartForward(gH_Frwd_Protection_StartedClient);
	Call_PushCell(client);
	Call_PushArray(color, sizeof(color));
	int iSptime = RoundToNearest(sptime);
	int iExtraTime = RoundToNearest(extraTime);
	Call_PushCell(iSptime + iExtraTime);
	Call_Finish();

	//Get Colour Highlight information
	int colourMode = GetConVarInt(g_easysp_rgbcolour_mode);
	int clientTeam = GetClientTeam(client);

	if (colourMode != COLOUR_OFF) {
		//We need to apply colour
		char SzColor[32];
		char Colours[4][4];

		if (colourMode == COLOUR_ALL) {
			//Use one colour for all
			GetConVarString(g_easysp_rgbcolour_all, SzColor, sizeof(SzColor));
		}
		else if (colourMode == COLOUR_TEAMS) {
			//Different colour for team one and team two
			if (clientTeam == teamOne) {
				GetConVarString(g_easysp_rgbcolour_teamOne, SzColor, sizeof(SzColor));
			}
			else if (clientTeam == teamTwo) {
				GetConVarString(g_easysp_rgbcolour_teamTwo, SzColor, sizeof(SzColor));
			}
		}

		//Set Colour
		ExplodeString(SzColor, " ", Colours, 4, 4);

		set_rendering(client, view_as<FX>(FxDistort), color[0], color[1], color[2], view_as<Render>(RENDER_TRANSADD), StringToInt(Colours[3]));
	}

	//Set god mode to player
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	isProtected[client] = true;

	//Set a timer to reset spawn protection only if this is player spawn mode
	if (GetConVarInt(g_easysp_mode) == MODE_PLAYERSPAWN) {
		if (g_bTimer[client])
		{
			KillTimer(g_hTimer[client]);
			g_hTimer[client] = CreateTimer(sptime + extraTime + 1, Timer_RemoveProtection, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
		}
		else
		{
			g_hTimer[client] = CreateTimer(sptime + extraTime + 1, Timer_RemoveProtection, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
			g_bTimer[client] = true;
		}
	}
}

/*
* Timer used to remove protection
*/
public Action Timer_RemoveProtection(Handle timer, any serial)//here
{
	int client = GetClientFromSerial(serial);
	if (client == 0)
	{
		g_bTimer[client] = false;
		return Plugin_Stop;
	}

	if (g_bTimer[client] == false)
		return Plugin_Stop;

	g_bTimer[client] = false;

	Call_StartForward(gH_Frwd_Protection_EndClient);
	Call_PushCell(client);
	Call_Finish();

	RemoveProtection(client, true, "%s%t", PREFIX, "Spawn Protection End Normal");
	return Plugin_Stop;
}

void RemoveProtection(int client, bool printMessage = false, char[] message, any...)
{
	if (g_bTimer[client])
		KillTimer(g_hTimer[client]);

	//Check if this player currently has god mode (aka spawn protection)
	if (IsClientInGame(client) && IsClientSpawnProtected(client)) {
		SetEntProp(client, Prop_Data, "m_takedamage", 2, 1);
		set_rendering(client, _, g_iModelColor[0], g_iModelColor[1], g_iModelColor[2]); //reset rendering

		if (GetConVarBool(g_easysp_notify_end) && IsPlayerAlive(client) && printMessage)
		{
			char sMessage[256];
			VFormat(sMessage, sizeof(sMessage), message, 4);
			CPrintToChat(client, sMessage);
		}
	}

	isProtected[client] = false;
	g_bTimer[client] = false;
}

/*
* Timer used to remove protection from all players
*/
public Action RemoveAllProtection(Handle timer)
{
	inRoundStartProtectionTime = false;

	for (int i = 1; i <= MaxClients; ++i)
	{
		//Check if this player currently has god mode (aka spawn protection)
		if (IsClientInGame(i) && IsClientSpawnProtected(i)) {
			SetEntProp(i, Prop_Data, "m_takedamage", 2, 1);
			isProtected[i] = false;
			set_rendering(i, _, g_iModelColor[0], g_iModelColor[1], g_iModelColor[2]); //reset rendering

			if (GetConVarBool(g_easysp_notify_end) && IsPlayerAlive(i))
				CPrintToChat(i, "%s%t", PREFIX, "Spawn Protection End Normal");
		}
	}
}

/*
* Weapon Fire
*/
public Action Event_WeaponFire(Handle event, const char[] name, bool dontBroadcast)
{
	if (!isEnabled)
		return Plugin_Continue;

	//Return if option is disabled
	if (!GetConVarBool(g_easysp_endOnAttackMode))
		return Plugin_Continue;

	//Get client who fired
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	RemoveProtection(client, true, "%s%t", PREFIX, "Spawn Protection End Attack");

	return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	/*int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsClientSpawnProtected(client))
		RemoveProtection(client, _, "");*/
}

/*
* Function to set player rendering (colour highlighting)
*/
stock void set_rendering(int index, FX fx = FxNone, int r = 255, int g = 255, int b = 255, Render render = Normal, int amount = 255)
{
	SetEntProp(index, Prop_Send, "m_nRenderFX", fx, 1);
	SetEntProp(index, Prop_Send, "m_nRenderMode", render, 1);
	SetEntData(index, g_renderOffs, r, 1, true);
	SetEntData(index, g_renderOffs + 1, g, 1, true);
	SetEntData(index, g_renderOffs + 2, b, 1, true);
	SetEntData(index, g_renderOffs + 3, amount, 1, true);
}

/*
* Check if a player is controlling a bot
* Credit: TnTSCS
* Url: https://forums.alliedmods.net/showthread.php?t=188807&page=13
*/
bool IsPlayerControllingBot(int client)
{
	return view_as<bool>(GetEntData(client, g_bIsControllingBot, 1));
}

/*
* Public function to check if player has spawn protection
*/
public bool IsClientSpawnProtected(int client)
{
	return isProtected[client];
}

public int Native_IsSpawnProtected(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	if (!IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Error. %i is not a valid client.", client);
	return view_as<bool>(IsClientSpawnProtected(client));
}

public int Native_GiveSpawnProtection(Handle plugin, int params)
{
	int client = GetNativeCell(1);
	int time = GetNativeCell(2);
	int color[4];
	GetNativeArray(3, color, sizeof(color));

	if (!IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Error. %i is not a valid client.", client);

	if (IsClientSpawnProtected(client))
		RemoveProtection(client, false, "");

	GiveSpawnProtection(client, float(time), color);

	return 1;
}

public int Native_RemoveSpawnProtection(Handle plugin, int params)
{
	int client = GetNativeCell(1);

	if (!IsClientInGame(client))
		return ThrowNativeError(SP_ERROR_NATIVE, "Error. %i is not a valid client.", client);

	RemoveProtection(client, false, "");

	isProtected[client] = false;

	return 1;
}

public Action OnTakeDamage(int victim, int & attacker, int & inflictor, float & damage, int & damagetype, int & weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsClientEntity(attacker))
	{
		return Plugin_Continue;
	}

	if (IsClientInGame(victim) && !IsFakeClient(victim) && IsClientInGame(attacker) && !IsFakeClient(attacker) && IsClientSpawnProtected(attacker))
	{
		return Plugin_Stop;
	}

	return Plugin_Continue;
}