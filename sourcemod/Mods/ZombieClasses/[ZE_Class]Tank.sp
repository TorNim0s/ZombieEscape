#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombieclasses>

#pragma newdecls required

#define CLASS_BASE_HEALTH 6000
#define CLASS_HEALTH_PER_PLAYER 500
#define CLASS_SPEED 1.02
#define CLASS_GRAVITY 1.05


char g_szClass[][] =  { "tank", "Tank", "+HP -KnockBack -Speed -Gravity", "models/player/kuristaja/zombies/fatty/fatty.mdl", "6000", "500", "3" };

int g_nClassID = 0;

int g_nTerroristCount = 0;
int g_nCTCount = 0;

enum struct ZombieClass {
	int health;
	int healthbonus;
	float speed;
	float gravity;
	
	void setDefault() {
		this.health = CLASS_BASE_HEALTH;
		this.healthbonus = CLASS_HEALTH_PER_PLAYER;
		this.speed = CLASS_SPEED;
		this.gravity = CLASS_GRAVITY;
	}
}

ZombieClass Tank;

public Plugin myinfo = 
{
	name = "[ZE_Class] - Tank", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnPluginStart() {
	HookEvent("player_spawn", OnPlayerSpawn);
	
	Tank.setDefault();
}

public void OnMapStart() {
	PrecacheModel(g_szClass[zClass_Model], true);
	
	LoadDirOfModels("materials/models/player/kuristaja/zombies/fatty");
	LoadDirOfModels("models/player/kuristaja/zombies/fatty");
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

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int nPlayerIndex = GetClientOfUserId(GetEventInt(event, "userid"));
	if (ZE_IsPlayerClassEnabled(nPlayerIndex, g_nClassID)) {
		if (GetClientTeam(nPlayerIndex) == CS_TEAM_T) {
			giveZombieAbilities(nPlayerIndex);
		}
	}
}

public void OnLibraryAdded(const char[] name) {
	if (!strcmp(name, "[CSGO] ZombieEscape - Classes")) {
		g_nClassID = ZE_CreateClass(g_szClass[zClass_Unique], g_szClass[zClass_Name], g_szClass[zClass_Description], g_szClass[zClass_Model], g_szClass[zClass_Health], g_szClass[zClass_HPbonus], g_szClass[zClass_KnockBack]);
	}
}
/*
public void ZE_OnClassSelected(int client, int class) {
	
}
*/

public void ZE_OnNewZombieSpawn(int nPlayerIndex) {
	if (ZE_IsPlayerClassEnabled(nPlayerIndex, g_nClassID)) {
		giveZombieAbilities(nPlayerIndex);
	}
}

void giveZombieAbilities(int nPlayerIndex) {
	checkPlayersInGame();
	
	int nHealth;
	float fSpeed;
	
	nHealth = Tank.health;
	fSpeed = Tank.speed;
	
	for (int nCurrentPlayer = 0; nCurrentPlayer < g_nTerroristCount + g_nCTCount; nCurrentPlayer++) {
		nHealth += Tank.healthbonus;
	}
	
	SetEntityHealth(nPlayerIndex, nHealth);
	SetEntityGravity(nPlayerIndex, Tank.gravity);
	SetEntPropFloat(nPlayerIndex, Prop_Data, "m_flLaggedMovementValue", fSpeed);
}

void checkPlayersInGame() {
	g_nCTCount = 0;
	g_nTerroristCount = 0;
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			if (GetClientTeam(nCurrentPlayer) == CS_TEAM_CT) {
				g_nCTCount++;
			}
			else if (GetClientTeam(nCurrentPlayer) == CS_TEAM_T) {
				g_nTerroristCount++;
			}
		}
	}
}
