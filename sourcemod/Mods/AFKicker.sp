#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#define PREFIX "[Play-IL]"

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

int g_nPlayerIdle[MAXPLAYERS];

ConVar g_cKickEnabled;
ConVar g_cKickTime;
ConVar g_cKickAdmin;

int g_nKickEnabled;
float g_nKickTimer;
bool g_bKickAdmin;

Handle g_tCheckIdle;

GlobalForward g_fwdOnPlayerMoveToSpec;

public Plugin myinfo = 
{
	name = "AFK Kicker", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart()
{
	g_cKickEnabled = CreateConVar("afk_enabled", "1", "Enables or Disable the plugin");
	g_cKickTime = CreateConVar("afk_timer", "25", "The time for the afk menu to show");
	g_cKickAdmin = CreateConVar("afk_adminkick", "1", "Enables or Disable kick admins");
	
	HookConVarChange(g_cKickEnabled, OnCvarChange);
	HookConVarChange(g_cKickTime, OnCvarChange);
	HookConVarChange(g_cKickAdmin, OnCvarChange);
	
	UpdateAllConvars();
	
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_fwdOnPlayerMoveToSpec = CreateGlobalForward("AFK_OnPlayerMoveToSpec", ET_Event, Param_Cell); // (int nPlayerIndex) -- Send new zombie index

	return APLRes_Success;
}

void startAfkTimer() {
	if (g_tCheckIdle != INVALID_HANDLE) {
		KillTimer(g_tCheckIdle);
		g_tCheckIdle = INVALID_HANDLE;
	}
	
	g_tCheckIdle = CreateTimer(1.0, Timer_Idle, _, TIMER_REPEAT);
}

void stopAfkTimer() {
	if (g_tCheckIdle != INVALID_HANDLE) {
		KillTimer(g_tCheckIdle);
		g_tCheckIdle = INVALID_HANDLE;
	}
}

public void OnPluginEnd()
{
	if (g_tCheckIdle != INVALID_HANDLE) {
		KillTimer(g_tCheckIdle);
		g_tCheckIdle = INVALID_HANDLE;
	}
}

public void OnMapEnd()
{
	if (g_tCheckIdle != INVALID_HANDLE) {
		KillTimer(g_tCheckIdle);
		g_tCheckIdle = INVALID_HANDLE;
	}
}

void UpdateAllConvars() {
	g_nKickEnabled = GetConVarBool(g_cKickEnabled);
	g_nKickTimer = GetConVarFloat(g_cKickTime);
	g_bKickAdmin = GetConVarBool(g_cKickAdmin);
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	if (convar == g_cKickEnabled) {
		g_nKickEnabled = GetConVarBool(g_cKickEnabled);
	}
	if (convar == g_cKickTime) {
		g_nKickTimer = GetConVarFloat(g_cKickTime);
	}
	if (convar == g_cKickAdmin) {
		g_bKickAdmin = GetConVarBool(g_cKickAdmin);
	}
	
	if (!g_nKickEnabled) {
		stopAfkTimer();
	}
	if (g_nKickEnabled) {
		if (checkPlayerCount() >= 1) {
			if (g_tCheckIdle == INVALID_HANDLE) {
				startAfkTimer();
			}
		}
	}
}

public void OnClientPostAdminCheck(int nPlayerIndex) {
	g_nPlayerIdle[nPlayerIndex] = 0;
	
	if (checkPlayerCount() == 1) {
		startAfkTimer();
	}
}

public void OnClientDisconnect(int nPlayerIndex) {
	if (checkPlayerCount() <= 1) {
		stopAfkTimer();
	}
}

float getCorrectTime(float fTimer) {
	return fTimer * 60.0;
}

public Action Timer_Idle(Handle timer) {
	checkAllPlayersIdle();
}

void checkAllPlayersIdle() {
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			g_nPlayerIdle[nCurrentPlayer]++;
			if (g_nPlayerIdle[nCurrentPlayer] >= getCorrectTime(g_nKickTimer)) {
				if (!g_bKickAdmin) {
					if (!IsPlayerGenericAdmin(nCurrentPlayer)) {
						startKickMenu(nCurrentPlayer);
					}
				}
				else {
					startKickMenu(nCurrentPlayer);
				}
			}
			
			if (g_nPlayerIdle[nCurrentPlayer] >= 30) {
				if (GetClientTeam(nCurrentPlayer) != CS_TEAM_SPECTATOR) {
					ChangeClientTeam(nCurrentPlayer, CS_TEAM_SPECTATOR);
					PrintToChatAll("%s Player \x02%N\x01 moved to spec for being AFK", PREFIX, nCurrentPlayer);
					
					Call_StartForward(g_fwdOnPlayerMoveToSpec);
					Call_PushCell(nCurrentPlayer);
					Call_Finish();
				}
			}
		}
	}
}

bool IsPlayerGenericAdmin(int client)
{
	if (CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false))
	{
		return true;
	}
	
	return false;
}

public Action OnPlayerRunCmd(int nCurrentPlayer, int & buttons) {
	if (buttons != IN_LEFT && buttons != IN_RIGHT && buttons != 0) {
		g_nPlayerIdle[nCurrentPlayer] = 0;
		if (GetClientTeam(nCurrentPlayer) == CS_TEAM_SPECTATOR) {
			ChangeClientTeam(nCurrentPlayer, CS_TEAM_T);
			CS_RespawnPlayer(nCurrentPlayer);
		}
	}
}

int checkPlayerCount() {
	int nPlayerCount = 0;
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			nPlayerCount++;
		}
	}
	return nPlayerCount;
}

void startKickMenu(int nPlayerIndex) {
	Menu kickMenu = new Menu(MenuHandle_Kick);
	
	kickMenu.SetTitle("%s - Are you AFK?\n \n", PREFIX);
	
	kickMenu.AddItem("NO", "No I'M HERE!!");
	
	g_nPlayerIdle[nPlayerIndex] = 0;
	
	kickMenu.ExitButton = false;
	kickMenu.Display(nPlayerIndex, 15);
	
}

public int MenuHandle_Kick(Menu menu, MenuAction action, int nPlayerIndex, int position) {
	if (action == MenuAction_Select)
	{
		g_nPlayerIdle[nPlayerIndex] = 0;
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
	else if (action == MenuAction_Cancel) {
		if (IsClientInGame(nPlayerIndex)) {
			KickClient(nPlayerIndex, "%s You have been AFK for too long", PREFIX);
			PrintToChatAll(" \x04%s\x01 Player \x02%N\x01 Has been kicked for being AFK for too long", PREFIX, nPlayerIndex);
			OnClientDisconnect(nPlayerIndex);
		}
	}
}