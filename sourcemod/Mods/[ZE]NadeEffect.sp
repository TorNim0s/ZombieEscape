#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s, (Credits: Hirsw0w)"
#define PLUGIN_VERSION "1.0"
#define PLUGIN_URL "Play-IL.co.il"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <cstrike>

#pragma newdecls required

#define FROST_EXPLODE 1
#define FROST_HIT 2
#define FROST_UNFREEZE 3

#define FragColor 	{255,75,75,255}

#define HE_GRANADE_DURATAION 6.0

int g_BeamSprite = -1;
int g_HaloSprite = -1;

char frostbomb[64] = "zombie/frostbomb%d.wav";

GlobalForward h_fwdOnClientIgnite;
GlobalForward h_fwdOnClientIgnited;

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - Nades Effect", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	HookEvent("player_blind", player_blind);
	HookEvent("player_hurt", OnPlayerHurt);
	HookEvent("hegrenade_detonate", OnHeDetonate);
}

public void OnMapStart() {
	char buff[128];
	
	g_BeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sprites/glow.vmt");
	
	for (int i = 1; i <= 3; i++) {
		Format(buff, 128, frostbomb, i);
		PrecacheSound(buff, true);
		Format(buff, 128, "sound/%s", buff);
		AddFileToDownloadsTable(buff);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	h_fwdOnClientIgnite = CreateGlobalForward("ZR_OnClientIgnite", ET_Hook, Param_Cell, Param_Cell, Param_FloatByRef);
	h_fwdOnClientIgnited = CreateGlobalForward("ZR_OnClientIgnited", ET_Ignore, Param_Cell, Param_Cell, Param_Float);
	
	return APLRes_Success;
}

public Action OnSmokeTouch(int iEntity, int itEntity)
{
	char buff[128];
	
	float Pos[3], xyz[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", Pos);
	AcceptEntityInput(iEntity, "kill");
	
	TE_SetupBeamRingPoint(Pos, 10.0, 150.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.5, 30.0, 0.0, { 0, 100, 200, 255 }, 10, 0);
	TE_SendToAll();
	
	TE_SetupBeamRingPoint(Pos, 10.0, 300.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.25, 30.0, 0.0, { 0, 100, 200, 255 }, 10, 0);
	TE_SendToAll();
	
	TE_SetupBeamRingPoint(Pos, 10.0, 450.0, g_BeamSprite, g_HaloSprite, 0, 15, 1.0, 30.0, 0.0, { 0, 100, 200, 255 }, 10, 0);
	TE_SendToAll();
	
	Format(buff, 128, frostbomb, FROST_EXPLODE);
	EmitAmbientSound(buff, Pos);
	
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		if (GetClientTeam(i) == CS_TEAM_CT) {
			continue;
		}
		
		GetEntPropVector(i, Prop_Send, "m_vecOrigin", xyz);
		float Distance = GetVectorDistance(Pos, xyz, false);
		if (Distance <= 200.0) {
			Client_ScreenFade(i, 1000, FFADE_IN, 750, 0, 100, 200, 150);
			SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.0);
			SetEntityRenderColor(i, 0, 100, 200, 255);
			Format(buff, 128, frostbomb, FROST_HIT);
			EmitSoundToAll(buff, i);
			CreateTimer(2.0, RemoveFreeze, i);
		}
	}
}

public void OnEntitySpawned(int entity)
{
	TE_SetupBeamFollow(entity, g_BeamSprite, 0, 0.7, 1.0, 1.0, 1, { 0, 100, 200, 255 } );
	TE_SendToAll();
}

public Action player_blind(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(client) == CS_TEAM_CT) {
		SetEntPropFloat(client, Prop_Send, "m_flFlashDuration", 0.0);
		return Plugin_Handled;
	}
	
	float duration = GetEntPropFloat(client, Prop_Send, "m_flFlashDuration");
	
	int color[4];
	color[0] = GetRandomInt(0, 255);
	color[1] = GetRandomInt(0, 255);
	color[2] = GetRandomInt(0, 255);
	color[3] = 255;
	
	if (duration <= 3.0)
	{
		color[3] = RoundToNearest((255.0 / 3.0) * duration);
	}
	
	duration -= 3.0;
	duration *= 1000.0;
	duration /= 2.0;
	duration = duration < 0.0 ? 0.0:duration;
	
	int holdtime = RoundToNearest(duration);
	int flashDuration = 1500; // 3sec 
	
	SetEntPropFloat(client, Prop_Send, "m_flFlashDuration", 0.0);
	
	Handle message = StartMessageOne("Fade", client);
	
	if (GetUserMessageType() == UM_Protobuf)
	{
		PbSetInt(message, "duration", flashDuration);
		PbSetInt(message, "hold_time", holdtime);
		PbSetInt(message, "flags", FFADE_IN | FFADE_PURGE);
		PbSetColor(message, "clr", color);
	}
	else
	{
		BfWriteShort(message, flashDuration);
		BfWriteShort(message, holdtime);
		BfWriteShort(message, FFADE_IN | FFADE_PURGE);
		BfWriteByte(message, color[0]);
		BfWriteByte(message, color[1]);
		BfWriteByte(message, color[2]);
		BfWriteByte(message, color[3]);
	}
	
	EndMessage();
	
	return Plugin_Handled;
}

public void OnEntityCreated(int iEntity, const char[] sClassName)
{
	if (!strcmp(sClassName, "hegrenade_projectile"))
	{
		IgniteEntity(iEntity, 2.0);
	}
	
	if (StrEqual(sClassName, "smokegrenade_projectile", false))
	{
		SDKHook(iEntity, SDKHook_StartTouch, OnSmokeTouch);
		SDKHook(iEntity, SDKHook_SpawnPost, OnEntitySpawned);
	}
	if (!strcmp(sClassName, "flashbang_projectile", false)) {
		SDKHook(iEntity, SDKHook_SpawnPost, OnEntitySpawned);
	}
}

public Action RemoveFreeze(Handle timer, any data) {
	if (!IsClientInGame(data) || !IsPlayerAlive(data))
		return;
	
	char buff[128];
	
	SetEntityRenderColor(data);
	SetEntPropFloat(data, Prop_Data, "m_flLaggedMovementValue", 1.0);
	Format(buff, 128, frostbomb, FROST_UNFREEZE);
	EmitSoundToAll(buff, data);
	
	SetEntityRenderColor(data);
}

public Action OnPlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	char g_szWeapon[32];
	GetEventString(event, "weapon", g_szWeapon, sizeof(g_szWeapon));
	
	if (!StrEqual(g_szWeapon, "hegrenade", false))
	{
		return;
	}
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (GetClientTeam(client) == CS_TEAM_CT)
	{
		return;
	}
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	Action result;
	float fNadeDuration = HE_GRANADE_DURATAION;
	result = Forward_OnClientIgnite(client, attacker, fNadeDuration);
	
	if (result == Plugin_Handled || result == Plugin_Stop) {
		return;
	}
	
	ExtinguishEntity(client);
	IgniteEntity(client, fNadeDuration);
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 0.8);
	CreateTimer(HE_GRANADE_DURATAION, Timer_StopSlow, client);
	
	Forward_OnClientIgnited(client, attacker, fNadeDuration);
}

public Action Timer_StopSlow(Handle timer, int client) {
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);
}

public Action OnHeDetonate(Handle event, const char[] name, bool dontBroadcast)
{
	float origin[3];
	origin[0] = GetEventFloat(event, "x"); origin[1] = GetEventFloat(event, "y"); origin[2] = GetEventFloat(event, "z");
	
	TE_SetupBeamRingPoint(origin, 10.0, 400.0, g_BeamSprite, g_HaloSprite, 1, 1, 0.2, 100.0, 1.0, FragColor, 0, 0);
	TE_SendToAll();
}

public Action Forward_OnClientIgnite(int client, int attacker, float time)
{
	Action result = Plugin_Continue;
	
	Call_StartForward(h_fwdOnClientIgnite);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloatRef(time);
	Call_Finish(result);
	
	return result;
}

void Forward_OnClientIgnited(int client, int attacker, float time)
{
	Call_StartForward(h_fwdOnClientIgnited);
	Call_PushCell(client);
	Call_PushCell(attacker);
	Call_PushFloat(time);
	Call_Finish();
} 