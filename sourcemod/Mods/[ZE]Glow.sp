#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <CustomPlayerSkins>
#include <zombiecore>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void ZE_OnNewZombieSpawn(int nPlayerIndex) {
	if (!ZE_IsRoundStarted()) {
		return;
	}
	
	int nClient = countHumans();
	if (nClient != -1) {
		SetGlow(nClient, 255, 0, 0, 255, 0);
	}
}

int countHumans() {
	int nHumansCounter = 0;
	int nLastHumanIndex = -1;
	for (int nCurrentPlayer = 1; nCurrentPlayer < MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer) && GetClientTeam(nCurrentPlayer) == CS_TEAM_CT) {
			nHumansCounter++;
			nLastHumanIndex = nCurrentPlayer;
		}
	}
	if (nHumansCounter != 1) {
		return -1;
	}
	return nLastHumanIndex;
}


void SetGlow(int client, int r, int g, int b, int a, int style)
{
	char szModel[PLATFORM_MAX_PATH];
	GetClientModel(client, szModel, sizeof(szModel));
	
	int skin = CPS_SetSkin(client, szModel, CPS_RENDER);
	
	if (SDKHookEx(skin, SDKHook_SetTransmit, OnSetTransmit_GlowSkin))
	{
		int offset;
		
		if ((offset = GetEntSendPropOffs(skin, "m_clrGlow")) != -1)
		{
			SetEntProp(skin, Prop_Send, "m_bShouldGlow", true, true);
			SetEntProp(skin, Prop_Send, "m_nGlowStyle", style);
			SetEntPropFloat(skin, Prop_Send, "m_flGlowMaxDist", 10000000.0);
			
			SetEntData(skin, offset, r, _, true);
			SetEntData(skin, offset + 1, g, _, true);
			SetEntData(skin, offset + 2, b, _, true);
			SetEntData(skin, offset + 3, a, _, true);
			
			SetEntityRenderMode(skin, RENDER_GLOW);
			SetEntityRenderColor(skin, 255, 255, 255, a);
			
			SetEntityRenderMode(client, RENDER_GLOW);
			SetEntityRenderColor(client, 255, 255, 255, a);
		}
	}
}

public Action OnSetTransmit_GlowSkin(int skin, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!CPS_HasSkin(i))
			{
				continue;
			}
			
			if (EntRefToEntIndex(CPS_GetSkin(i)) != skin)
			{
				continue;
			}
			
			return Plugin_Continue;
		}
	}
	
	return Plugin_Handled;
} 