#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#define PREFIX " \x04[Play-IL]\x01"
#define MENU_PREFIX "[Play-IL]"

#define SEC_GIVEHP 3
#define HP_GIVE 100

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiecore>
#include <zombieclasses>

#pragma newdecls required

int g_nPlayerIdle[MAXPLAYERS];

Handle g_tCheckIdle;

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - HealZombie", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart() {
	HookEvent("player_death", OnPlayer_Death);
}

public void OnClientPostAdminCheck(int nPlayerIndex) {
	SDKHook(nPlayerIndex, SDKHook_OnTakeDamage, OnTakeDamage);
	
	g_nPlayerIdle[nPlayerIndex] = 0;
}

public void ZE_OnRoundStart() {
	resetAll();
	startHPTimer();
}

public void ZE_OnRoundEnd(int nTeamIndex) {
	stopHPTimer();
}

public Action OnPlayer_Death(Event event, const char[] name, bool dontBroadcast) {
	if (ZE_IsZeEnabled() && ZE_IsRoundStarted()) {
		int nPlayerIndex = GetClientOfUserId(GetEventInt(event, "userid"));
		g_nPlayerIdle[nPlayerIndex] = 0;
	}
}

void resetAll() {
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			g_nPlayerIdle[nCurrentPlayer] = 0;
		}
	}
}

void startHPTimer() {
	if (g_tCheckIdle != INVALID_HANDLE) {
		KillTimer(g_tCheckIdle);
		g_tCheckIdle = INVALID_HANDLE;
	}
	
	g_tCheckIdle = CreateTimer(1.0, Timer_Idle, _, TIMER_REPEAT);
}

void stopHPTimer() {
	if (g_tCheckIdle != INVALID_HANDLE) {
		KillTimer(g_tCheckIdle);
		g_tCheckIdle = INVALID_HANDLE;
	}
}

public void OnPluginEnd()
{
	stopHPTimer();
}

public void OnMapEnd()
{
	stopHPTimer();
}

public Action Timer_Idle(Handle timer) {
	checkZombiesIdle();
}

void checkZombiesIdle() {
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			if (GetClientTeam(nCurrentPlayer) == CS_TEAM_T && IsPlayerAlive(nCurrentPlayer)) {
				if (g_nPlayerIdle[nCurrentPlayer] != 0 && !(g_nPlayerIdle[nCurrentPlayer] % SEC_GIVEHP)) {
					
					int nCurrentHP = GetEntProp(nCurrentPlayer, Prop_Send, "m_iHealth");
					int nMaxHealth = ZE_GetZombieMaxHealth(nCurrentPlayer);
					
					if ((nCurrentHP + HP_GIVE) < nMaxHealth) {
						SetEntityHealth(nCurrentPlayer, nCurrentHP += HP_GIVE);
					}
					else if (nCurrentHP < nMaxHealth && (nCurrentHP + HP_GIVE) >= nMaxHealth) {
						SetEntityHealth(nCurrentPlayer, nMaxHealth);
					}
				}
				g_nPlayerIdle[nCurrentPlayer]++;
			}
		}
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (ZE_IsZeEnabled() && ZE_IsRoundStarted()) {
		if (attacker > 0 && attacker < MaxClients) {
			if (GetClientTeam(attacker) != GetClientTeam(victim) && GetClientTeam(attacker) == CS_TEAM_CT)
			{
				g_nPlayerIdle[victim] = 0;
			}
		}
	}
} 