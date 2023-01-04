#include <sourcemod>

#define REQUIRE_EXTENSIONS
#include <dhooks>

DynamicHook g_hDHook_CBasePlayer_CreateRagdollEntity = null;
int g_iVtbl_CBasePlayer_CreateRagdollEntity = -1;

public MRESReturn DHook_CCSPlayer_CreateRagdollEntity_Pre( int iClient )
{
	return MRES_Supercede;
}

public void OnClientPutInServer( int iClient )
{
	// NOTE: We don't have to manually unhook it, extension already does that and manually unhooking where extension does is prone to server crashes
	DHookEntity( g_hDHook_CBasePlayer_CreateRagdollEntity, false, iClient );
}

public void OnPluginStart()
{
	#define GAMEDATA_FILE	"no_ragdolls"
	GameData hGameData = new GameData( GAMEDATA_FILE );

	if ( !hGameData )
	{
		SetFailState( "Unable to load gamedata file \"" ... GAMEDATA_FILE ... ".txt\"" );
	}

	g_iVtbl_CBasePlayer_CreateRagdollEntity = hGameData.GetOffset( "CBasePlayer::CreateRagdollEntity" );

	if ( g_iVtbl_CBasePlayer_CreateRagdollEntity == -1 )
	{
		delete hGameData;

		SetFailState( "Unable to find gamedata offset entry for \"CBasePlayer::CreateRagdollEntity\"" );
	}

	delete hGameData;

	// void CCSPlayer::CreateRagdollEntity()
	g_hDHook_CBasePlayer_CreateRagdollEntity = DHookCreate( g_iVtbl_CBasePlayer_CreateRagdollEntity,
		HookType_Entity,
		ReturnType_Void,
		ThisPointer_CBaseEntity,
		DHook_CCSPlayer_CreateRagdollEntity_Pre );

	for ( int iClient = 1; iClient <= MaxClients; iClient++ )
	{
		if ( IsClientInGame( iClient ) )
		{
			OnClientPutInServer( iClient );
		}
	}
}

public Plugin myinfo =
{
	name = "[Furious] No Ragdolls",
	author = "Sir Jay",
	description = "No longer creates a ragdoll upon player death",
	version = "1.0.0",
	url = "https://furious-clan.com/"
};