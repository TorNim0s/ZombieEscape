#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiecore>
#include <zombiezshop>
#include <zombiecash>

#pragma newdecls required

#define PREFIX " \x04[Play-IL]\x01"

#define MaxItems 3

#define MAX_BUY_IN_ROUND 2

char g_szItems[][][] =  {
	{ "granade", "HE Granade", "Boom Granade", "weapon_hegrenade", "20", "0" }, 
	{ "flash", "Flashbang", "Flash the area", "weapon_flashbang", "15", "0" }, 
	{ "smoke", "Frozen Nade", "Freeze zombies around", "weapon_smokegrenade", "25", "0" }
};

enum {
	Items_Unique = 0, 
	Items_Name, 
	Items_Description, 
	Items_ItemTag, 
	Items_Price, 
	Items_VIP
}

int g_nBoughRounds[MaxItems][MAXPLAYERS];

int g_nItems[MaxItems] =  { 0 };

public Plugin myinfo = 
{
	name = "[ZE_Items] - Granades", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart() {
	HookEvent("round_start", Round_Start);
}

public void OnClientPostAdminCheck(int client) {
	for (int nCurrentItem = 0; nCurrentItem < MaxItems; nCurrentItem++) {
		g_nBoughRounds[nCurrentItem][client] = 0;
	}
	
}

public Action Round_Start(Event event, const char[] name, bool dontBroadcast) {
	if (ZE_IsZeEnabled()) {
		for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
			for (int nCurrentItem = 0; nCurrentItem < MaxItems; nCurrentItem++) {
				g_nBoughRounds[nCurrentItem][nCurrentPlayer] = 0;
			}
		}
	}
}

public void OnLibraryAdded(const char[] name) {
	if (!strcmp(name, "[CSGO] ZombieEscape - ZShop")) {
		for (int i = 0; i < MaxItems; i++) {
			g_nItems[i] = ZShop_CreateItem(g_szItems[i][Items_Unique], g_szItems[i][Items_Name], g_szItems[i][Items_Description], g_szItems[i][Items_ItemTag], g_szItems[i][Items_Price], g_szItems[i][Items_VIP]);
		}
	}
}

public void ZShop_OnItemSelected(int client, int item) {
	for (int nCurrentItem = 0; nCurrentItem < MaxItems; nCurrentItem++) {
		if (item == g_nItems[nCurrentItem]) {
			if (g_nBoughRounds[item][client] >= MAX_BUY_IN_ROUND) {
				PrintToChat(client, "%s You can't buy more than %d per round!", PREFIX, MAX_BUY_IN_ROUND);
				SetCash(client, (GetCash(client) + StringToInt(g_szItems[nCurrentItem][Items_Price])));
				return;
			}
			GivePlayerItem(client, g_szItems[nCurrentItem][Items_ItemTag]);
			g_nBoughRounds[item][client]++;
			break;
		}
	}
} 