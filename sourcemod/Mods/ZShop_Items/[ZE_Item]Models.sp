#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiezshop>
#include <zombievip>

#pragma newdecls required

#define MaxItems 3

char g_szItems[][][] =  {
	{ "batman", "Batman", "Batman Skin", "models/player/custom_player/kuristaja/ak/batman/batmanv2.mdl", "60", "1" }, 
	{ "venom", "Venom", "Venom Skin", "models/player/custom_player/kirby/venom/venom_small.mdl", "60", "1" }, 
	{ "goku", "Goku", "Goku Skin", "models/player/custom_player/kodua/goku/goku.mdl", "60", "1" }
};

bool g_bPlayers[MaxItems][MAXPLAYERS];

enum {
	Items_Unique = 0, 
	Items_Name, 
	Items_Description, 
	Items_ItemTag, 
	Items_Price, 
	Items_VIP
}

int g_nItems[MaxItems] =  { 0 };

public Plugin myinfo = 
{
	name = "[ZE_Item] - Models", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart() {
	HookEvent("player_spawn", OnPlayerSpawn);
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int nPlayerIndex = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (IsClientInGame(nPlayerIndex)) {
		if (GetClientTeam(nPlayerIndex) == CS_TEAM_CT) {
			for (int nCurrentItem = 0; nCurrentItem < MaxItems; nCurrentItem++) {
				if (g_bPlayers[nCurrentItem][nPlayerIndex]) {
					if (VIP_CheckClientVip(nPlayerIndex)) {
						SetEntityModel(nPlayerIndex, g_szItems[nCurrentItem][Items_ItemTag]);
					}
				}
			}
			
		}
	}
}

public void OnClientDisconnect(int nPlayerIndex) {
	for (int nCurrentItem = 0; nCurrentItem < MaxItems; nCurrentItem++) {
		g_bPlayers[nCurrentItem][nPlayerIndex] = false;
	}
}

public void OnMapStart() {
	for (int nCurrentItem = 0; nCurrentItem < MaxItems; nCurrentItem++) {
		PrecacheModel(g_szItems[nCurrentItem][Items_ItemTag], true);
	}
	
	LoadDirOfModels("materials/models/player/kuristaja/ak/batman");
	LoadDirOfModels("models/player/custom_player/kuristaja/ak/batman");
	
	LoadDirOfModels("models/player/custom_player/kirby/venom");
	LoadDirOfModels("materials/models/player/kirby/venom");
	
	LoadDirOfModels("models/player/custom_player/kodua/goku");
	LoadDirOfModels("materials/models/player/custom_player/kodua/goku/");
}

void LoadDirOfModels(char[] dirofmodels) {
	char path[PLATFORM_MAX_PATH];
	FileType type;
	char FileAfter[PLATFORM_MAX_PATH];
	Handle dir = OpenDirectory(dirofmodels);
	if (dir == INVALID_HANDLE) {
		delete dir;
		return;
	}
	while (ReadDirEntry(dir, path, sizeof(path), type)) {
		if (type == FileType_File)
		{
			FormatEx(FileAfter, sizeof(FileAfter), "%s/%s", dirofmodels, path);
			AddFileToDownloadsTable(FileAfter);
		}
	}
	delete dir;
	
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
			g_bPlayers[nCurrentItem][client] = true;
			SetEntityModel(client, g_szItems[nCurrentItem][Items_ItemTag]);
			for (int nCItem = 0; nCItem < MaxItems; nCItem++) {
				if (nCItem != nCurrentItem) {
					g_bPlayers[nCItem][client] = false;
				}
			}
			break;
		}
	}
} 