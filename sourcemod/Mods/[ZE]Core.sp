#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#define PREFIX " \x04[Play-IL Zombie Escape]\x01"
#define MENU_PREFIX "[Play-IL Zombie Escape]"

#define DMG_FALL   (1 << 5)

#define MIN_PLAYERS 2

#define ZombieDiv 4

#define INFECTED_PRE_SOUND_PATH "zr/fz_scream1.mp3"
#define INFECTED_SOUND_PATH "sound/zr/fz_scream1.mp3"

#define START_SOUND_DIR "sound/zr/countdown"
#define START_SOUND_NUM 10

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <zombiecore>
#include <collisionhook>

#pragma newdecls required

ConVar g_cZeEnabled;
ConVar g_cZeStartTimer;

Handle g_hIgnoreWin;
Handle g_hTeamNoBlock;
Handle g_hBuyTime;
Handle g_hMoneyHud;
Handle g_hTeamMoneyHud;

bool g_hZeEnabled;
float g_hZeStartTimer;

int g_nStartTimer;
bool g_bRoundStarted = false;
bool g_bWaitingPlayers = false;

GlobalForward g_fwdNewZombie;
GlobalForward g_fwdZERoundStart;
GlobalForward g_fwdZERoundEnd;
GlobalForward g_fwdZEHumanKilledZombie;

Handle g_tStartHUD;
Handle g_tCountHUD;
Handle g_tStartTimer;

int g_nTerroristCount = 0;
int g_nCTCount = 0;

enum struct Player {
	char auth[32];
	char name[MAX_NAME_LENGTH];
	float deathtime;
	bool firstzombie;
	bool truedied;
	
	void reset() {
		this.auth[0] = 0;
		this.name[0] = 0;
		this.deathtime = 0.0;
		this.firstzombie = false;
		this.truedied = true;
	}
}

Player g_aPlayers[MAXPLAYERS];

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - Core", 
	author = PLUGIN_AUTHOR, 
	description = "Zombie Escape for CS:GO", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

bool g_bLate = false;

public void OnPluginStart()
{
	g_cZeEnabled = CreateConVar("ze_enabled", "1", "Enables or Disable the plugin");
	g_cZeStartTimer = CreateConVar("ze_startimer", "20.0", "Set The selected timer for zombie in the start of the round");
	
	g_hTeamNoBlock = FindConVar("mp_solid_teammates");
	g_hIgnoreWin = FindConVar("mp_ignore_round_win_conditions");
	g_hBuyTime = FindConVar("mp_buytime");
	g_hMoneyHud = FindConVar("mp_playercashawards");
	g_hTeamMoneyHud = FindConVar("mp_teamcashawards");
	
	RegConsoleCmd("kill", cmd_kill);
	
	AddCommandListener(BlockJoinTeam, "jointeam");
	
	HookConVarChange(g_cZeEnabled, OnCvarChange);
	HookConVarChange(g_cZeStartTimer, OnCvarChange);
	
	HookEvent("round_start", Round_Start);
	HookEvent("player_death", OnPlayer_Death);
	HookEvent("weapon_fire", WeaponFire);
	HookEvent("player_connect_full", Event_PlayerConnectFull, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerTeam, EventHookMode_Pre);
	
	UpdateAllConvars();
	
	if (g_bLate) {
		for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
			if (IsClientInGame(nCurrentPlayer)) {
				OnClientPostAdminCheck(nCurrentPlayer);
			}
		}
	}
}

public Action cmd_kill(int client, int args) {
	return Plugin_Handled;
}

public void OnMapStart() {
	PrecacheSound(INFECTED_PRE_SOUND_PATH, true);
	AddFileToDownloadsTable(INFECTED_SOUND_PATH);
	
	LoadDirOfModels("sound/zr/countdown");
	
	char sInfo[32];
	for (int nCurrentSound = 1; nCurrentSound <= START_SOUND_NUM; nCurrentSound++) {
		Format(sInfo, sizeof(sInfo), "zr/countdown/%d.mp3", nCurrentSound);
		PrecacheSound(sInfo, true);
	}
	
	AddFileToDownloadsTable("materials/panorama/images/icons/equipment/zombie.svg");
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

public Action CH_PassFilter(int ent1, int ent2, bool result)
{
	// No client-client collisions 
	if (1 <= ent1 <= MaxClients && 1 <= ent2 <= MaxClients && IsClientInGame(ent2) && IsPlayerAlive(ent2) && GetClientTeam(ent1) == GetClientTeam(ent2))
	{
		result = true;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void OnCvarChange(ConVar convar, char[] oldValue, char[] newValue) {
	if (convar == g_cZeEnabled)
		g_hZeEnabled = GetConVarBool(g_cZeEnabled);
	else if (convar == g_cZeStartTimer)
		g_hZeStartTimer = GetConVarFloat(g_cZeStartTimer);
}

void UpdateAllConvars() {
	g_hZeEnabled = GetConVarBool(g_cZeEnabled);
	g_hZeStartTimer = GetConVarFloat(g_cZeStartTimer);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLate = late;
	
	CreateNative("ZE_IsZeEnabled", Native_IsZeEnabled); // return true if plugin enabled
	CreateNative("ZE_IsRoundStarted", Native_IsRoundStarted); // return true if round started
	
	g_fwdNewZombie = CreateGlobalForward("ZE_OnNewZombieSpawn", ET_Event, Param_Cell); // (int nPlayerIndex) -- Send new zombie index
	g_fwdZERoundStart = CreateGlobalForward("ZE_OnRoundStart", ET_Event); // call when zombie round start
	g_fwdZERoundEnd = CreateGlobalForward("ZE_OnRoundEnd", ET_Event, Param_Cell); // (int team) -- Send winning team when round ends
	g_fwdZEHumanKilledZombie = CreateGlobalForward("ZE_HumanKilledZombie", ET_Event, Param_Cell, Param_Cell);
	
	RegPluginLibrary("[CSGO] ZombieEscape - Core");
	return APLRes_Success;
}

public void OnClientPostAdminCheck(int client) {
	g_aPlayers[client].reset();
	if (!GetClientAuthId(client, AuthId_Steam2, g_aPlayers[client].auth, sizeof(g_aPlayers[].auth))) {
		KickClient(client, "Verification problem, please reconnect");
		return;
	}
	
	GetClientName(client, g_aPlayers[client].name, sizeof(g_aPlayers[].name));
	
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action Event_PlayerConnectFull(Event event, const char[] name, bool dontBroadcast) {
	if (g_hZeEnabled) {
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (g_bRoundStarted) {
			ChangeClientTeam(client, CS_TEAM_T);
			ResapwnZombie(client);
		}
		else {
			ChangeClientTeam(client, CS_TEAM_CT);
			CS_RespawnPlayer(client);
		}
		
		if (g_bWaitingPlayers) {
			checkWaitingPlayers();
		}
	}
}

void checkWaitingPlayers() {
	int nPlayerCounter = GetClientCount();
	if (nPlayerCounter >= MIN_PLAYERS) {
		g_bWaitingPlayers = false;
		CS_TerminateRound(2.0, CSRoundEnd_GameStart);
		PrintToChatAll("%s Min players have been reached, Starting game", PREFIX);
	}
	else {
		PrintToChatAll("%s waiting for players \x04[%d/%d]\x01", PREFIX, nPlayerCounter, MIN_PLAYERS);
	}
}



public void OnClientDisconnect(int nPlayerIndex) {
	CreateTimer(0.1, Timer_CheckPlayers);
}

public Action Round_Start(Event event, const char[] name, bool dontBroadcast) {
	killTimers();
	
	if (GetClientCount() >= MIN_PLAYERS && g_hZeEnabled) {
		SetConVarInt(g_hIgnoreWin, 1);
		SetConVarInt(g_hTeamNoBlock, 0);
		SetConVarInt(g_hBuyTime, 0);
		SetConVarInt(g_hMoneyHud, 0);
		SetConVarInt(g_hTeamMoneyHud, 0);
		
		g_bRoundStarted = false;
		
		g_nTerroristCount = 0;
		g_nCTCount = 0;
		
		SwitchAllPlayers();
		
		g_nStartTimer = RoundToFloor(g_hZeStartTimer);
		setStartTimers();
	}
	else {
		SetConVarInt(g_hIgnoreWin, 0);
		SetConVarInt(g_hTeamNoBlock, 1);
		g_bWaitingPlayers = true;
	}
}

void killTimers() {
	if (g_tStartHUD != INVALID_HANDLE) {
		CloseHandle(g_tStartHUD);
		g_tStartHUD = INVALID_HANDLE;
	}
	
	if (g_tCountHUD != INVALID_HANDLE) {
		CloseHandle(g_tCountHUD);
		g_tCountHUD = INVALID_HANDLE;
	}
	
	if (g_tStartTimer != INVALID_HANDLE) {
		CloseHandle(g_tStartTimer);
		g_tStartTimer = INVALID_HANDLE;
	}
}

public Action OnPlayer_Death(Event event, const char[] name, bool dontBroadcast) {
	if (g_hZeEnabled) {
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));
		if (g_aPlayers[victim].truedied) {
			CreateTimer(0.2, Timer_CheckPlayers);
			
			int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
			
			if (g_bRoundStarted) {
				ResapwnZombie(victim);
				
				if (victim != attacker && victim > 0 && attacker > 0) {
					if (GetClientTeam(attacker) == CS_TEAM_CT) {
						Call_StartForward(g_fwdZEHumanKilledZombie);
						Call_PushCell(attacker);
						Call_PushCell(victim);
						Call_Finish();
					}
				}
			}
			
			char weapon[32];
			GetEventString(event, "weapon", weapon, sizeof(weapon));
			
			if (victim && !attacker && StrEqual(weapon, "trigger_hurt"))
			{
				float fGameTime = GetGameTime();
				
				if (fGameTime - g_aPlayers[victim].deathtime - 2.0 < 5.0)
				{
					char sInfo[128];
					
					CS_TerminateRound(5.0, CSRoundEnd_CTWin);
					
					Format(sInfo, sizeof(sInfo), "<font face=''><font color='#6600cc'>%s</font> \n \nThe Humans have <font color='#ff0000'>won!</font>", MENU_PREFIX);
					
					PrintHintTextToAll(sInfo);
					
					g_bRoundStarted = false;
					
					Call_StartForward(g_fwdZERoundEnd);
					Call_PushCell(CS_TEAM_CT);
					Call_Finish();
				}
				g_aPlayers[victim].deathtime = fGameTime;
				
				ResapwnZombie(victim);
			}
		}
		event.BroadcastDisabled = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	if (!event.GetBool("silent"))
	{
		event.BroadcastDisabled = true;
	}
}

public void AFK_OnPlayerMoveToSpec() {
	CreateTimer(0.1, Timer_CheckPlayers);
}

void ResapwnZombie(int nPlayerIndex) {
	CreateTimer(2.0, Timer_RespawnZombie, nPlayerIndex);
}

public Action Timer_RespawnZombie(Handle timer, int nPlayerIndex) {
	if (IsClientInGame(nPlayerIndex)) {
		if (GetClientTeam(nPlayerIndex) == CS_TEAM_T) {
			CS_RespawnPlayer(nPlayerIndex);
			disarmTarget(nPlayerIndex);
			GivePlayerItem(nPlayerIndex, "weapon_knife");
		}
		else if (GetClientTeam(nPlayerIndex) == CS_TEAM_CT) {
			ChangeClientTeam(nPlayerIndex, CS_TEAM_T);
			CS_RespawnPlayer(nPlayerIndex);
			disarmTarget(nPlayerIndex);
			GivePlayerItem(nPlayerIndex, "weapon_knife");
			
			Call_StartForward(g_fwdNewZombie);
			Call_PushCell(nPlayerIndex);
			Call_Finish();
			
		}
		
		checkPlayersAlive();
	}
}

public Action Timer_CheckPlayers(Handle timer) {
	checkPlayersAlive();
}

void checkPlayersAlive() {
	if (g_hZeEnabled && g_bRoundStarted) {
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
		char sInfo[256];
		if (g_nCTCount == 0) {
			CS_TerminateRound(5.0, CSRoundEnd_TerroristWin);
			
			g_bRoundStarted = false;
			
			Format(sInfo, sizeof(sInfo), "<font face=''><font color='#6600cc'>%s</font> \n \nThe Zombies have <font color='#ff0000'>won!</font>", MENU_PREFIX);
			
			PrintHintTextToAll(sInfo);
			
			Call_StartForward(g_fwdZERoundEnd);
			Call_PushCell(CS_TEAM_T);
			Call_Finish();
		}
		else if (g_nTerroristCount == 0) {
			PrintToChatAll("%s Zombies has left the server, Choosing new zombies", PREFIX);
			ChooseFirstZombies();
		}
	}
}

/*
-------------Natives----------------------
*/

public int Native_IsZeEnabled(Handle plugin, int numParams) {
	return g_hZeEnabled;
}

public int Native_IsRoundStarted(Handle plugin, int numParams) {
	return g_bRoundStarted;
}

/*
-------------------------------------------
*/

void setStartTimers() {
	g_tStartTimer = CreateTimer(g_hZeStartTimer, Timer_StartRound);
	g_tStartHUD = CreateTimer(1.0, Timer_StartHUD, _, TIMER_REPEAT);
}

public Action Timer_StartRound(Handle timer) {
	if (g_tStartHUD != INVALID_HANDLE) {
		CloseHandle(g_tStartHUD);
		g_tStartHUD = INVALID_HANDLE;
	}
	g_tStartTimer = INVALID_HANDLE;
	
	if (GetClientCount() >= MIN_PLAYERS) {
		SwitchAllPlayers();
		g_bRoundStarted = true;
		ChooseFirstZombies();
		
		PrintToChatAll("%s The zombies has been selected!!", PREFIX);
		
		Call_StartForward(g_fwdZERoundStart);
		Call_Finish();
	}
	else {
		PrintToChatAll("%s It look like there is not enough players", PREFIX);
		g_bWaitingPlayers = true;
	}
}

public Action Timer_StartHUD(Handle timer) {
	g_nStartTimer--;
	
	SwitchAllPlayers();
	
	char sInfo[256];
	Format(sInfo, sizeof(sInfo), "<font face=''><font color='#6600cc'>%s</font> \n \nNew Round Start in <font color='#ff1111'>%d</font Seconds", MENU_PREFIX, g_nStartTimer);
	
	PrintHintTextToAll(sInfo);
	
	if (g_nStartTimer > 0 && g_nStartTimer <= 10) {
		Format(sInfo, sizeof(sInfo), "zr/countdown/%d.mp3", g_nStartTimer);
		EmitSoundToAll(sInfo);
	}
}

void ChooseFirstZombies() {
	int nPlayersOnline[MAXPLAYERS];
	int nPlayersCount = 0;
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer) && IsPlayerAlive(nCurrentPlayer)) {
			nPlayersOnline[nPlayersCount] = nCurrentPlayer;
			nPlayersCount++;
		}
	}
	
	if (nPlayersCount < MIN_PLAYERS) {
		PrintToChatAll("%s It look like there is not enough players, \x02stopping\x01 current game", PREFIX);
		g_bWaitingPlayers = true;
		g_bRoundStarted = false;
		CS_TerminateRound(2.0, CSRoundEnd_GameStart);
		
		Call_StartForward(g_fwdZERoundEnd);
		Call_PushCell(CS_TEAM_CT);
		Call_Finish();
		
		return;
	}
	
	int nNumberOfZombies = RoundToCeil(float(nPlayersCount) / ZombieDiv);
	
	int aSelecetedZombies[MAXPLAYERS];
	
	char sInfo[256];
	Format(sInfo, sizeof(sInfo), "<font face=''><font color='#6600cc'>%s</font> \n \nZombies Have been \x04Selected\x01\n \n Zombies:", MENU_PREFIX);
	
	for (int nCurrentPlayer = 0; nCurrentPlayer < nNumberOfZombies; nCurrentPlayer++) {
		
		int nSelectedZombie = GetRandomInt(0, nPlayersCount - 1);
		
		if (GetClientTeam(nPlayersOnline[nSelectedZombie]) == CS_TEAM_T || g_aPlayers[nPlayersOnline[nSelectedZombie]].firstzombie) {
			nCurrentPlayer--;
			continue;
		}
		
		EmitSoundToAll(INFECTED_PRE_SOUND_PATH, nPlayersOnline[nSelectedZombie]);
		
		PrintToChat(nPlayersOnline[nSelectedZombie], "%s You have been selected to be zombie", PREFIX);
		ChangeClientTeam(nPlayersOnline[nSelectedZombie], CS_TEAM_T);
		
		PrintToChatAll("Zombie: \x06%N\x01 has been selected", nPlayersOnline[nSelectedZombie]);
		
		aSelecetedZombies[nCurrentPlayer] = nPlayersOnline[nSelectedZombie];
	}
	
	SetFirstZombie(aSelecetedZombies, nNumberOfZombies);
	//PrintHintTextToAll(sInfo);
	g_tCountHUD = CreateTimer(2.0, Timer_HUD, _, TIMER_REPEAT);
}

void SetFirstZombie(int nFirstZombies[MAXPLAYERS], int nNumberOfZombies) {
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++) {
		if (IsClientInGame(nCurrentPlayer)) {
			g_aPlayers[nCurrentPlayer].firstzombie = false;
		}
	}
	
	for (int nCurrentZombie = 0; nCurrentZombie < nNumberOfZombies; nCurrentZombie++) {
		g_aPlayers[nFirstZombies[nCurrentZombie]].firstzombie = true;
	}
}

void SwitchAllPlayers()
{
	for (int nCurrentPlayer = 1; nCurrentPlayer <= MaxClients; nCurrentPlayer++)
	{
		if (IsClientInGame(nCurrentPlayer))
		{
			if (GetClientTeam(nCurrentPlayer) == CS_TEAM_T) {
				
				ChangeClientTeam(nCurrentPlayer, CS_TEAM_CT);
				CS_RespawnPlayer(nCurrentPlayer);
			}
		}
	}
}

void disarmTarget(int target)
{
	for (int currentWeapon = 0; currentWeapon <= 5; currentWeapon++)
	{
		int targetWeapon = GetPlayerWeaponSlot(target, currentWeapon);
		if (IsValidEntity(targetWeapon))
			RemovePlayerItem(target, targetWeapon);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (g_hZeEnabled) {
		if (attacker > 0 && attacker < MaxClients) {
			if (GetClientTeam(attacker) != GetClientTeam(victim) && GetClientTeam(attacker) == CS_TEAM_T)
			{
				PrintToChat(victim, "%s You have been infected by %N", PREFIX, attacker);
				ChangeClientTeam_Safe(victim, CS_TEAM_T, attacker);
				
				int weaponIndex;
				for (int x = 0; x <= 6; x++)
				{
					if ((weaponIndex = GetPlayerWeaponSlot(victim, x)) != -1)
					{
						CS_DropWeapon(victim, weaponIndex, true, true);
					}
				}
				
				//disarmTarget(victim);
				GivePlayerItem(victim, "weapon_knife");
				
				EmitSoundToAll(INFECTED_PRE_SOUND_PATH, victim);
				
				SendDeathMessage(attacker, victim, "zombie");
			}
		}
		
		if (damagetype & DMG_FALL && GetClientTeam(victim) == CS_TEAM_T) {
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void SendDeathMessage(int attacker, int victim, const char[] weapon)
{
	g_aPlayers[victim].truedied = false;
	
	Event event = CreateEvent("player_death");
	if (event == null)
	{
		return;
	}
	
	event.SetInt("userid", GetClientUserId(victim));
	event.SetInt("attacker", GetClientUserId(attacker));
	event.SetString("weapon", weapon);
	event.Fire();
	
	g_aPlayers[victim].truedied = true;
}

public Action OnWeaponCanUse(int client, int weapon) {
	if (g_hZeEnabled)
	{
		char sWeapon[32];
		GetEntityClassname(weapon, sWeapon, 32);
		
		if (GetClientTeam(client) == CS_TEAM_T && !StrEqual(sWeapon, "weapon_knife")) {
			return Plugin_Handled;
		}
		
	}
	return Plugin_Continue;
}

public Action WeaponFire(Event event, const char[] name, bool dontBroadcast) {
	if (g_hZeEnabled)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		
		SetEntProp(weapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 1000);
	}
}

void ChangeClientTeam_Safe(int client, int team, int attacker)
{
	char sModel[63];
	
	GetClientModel(attacker, sModel, sizeof(sModel));
	
	CS_SwitchTeam(client, team);
	
	//disarmTarget(client);
	
	SetEntityModel(client, sModel);
	
	Call_StartForward(g_fwdNewZombie);
	Call_PushCell(client);
	Call_Finish();
	
	checkPlayersAlive();
}

public Action BlockJoinTeam(int client, const char[] command, int args)
{
	if (g_hZeEnabled) {
		if (client != 0)
		{
			if (IsClientInGame(client) && !IsFakeClient(client))
			{
				if (GetClientTeam(client) != CS_TEAM_SPECTATOR)
				{
					return Plugin_Stop;
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Timer_HUD(Handle timer) {
	if (!g_bRoundStarted || g_nCTCount <= 0) {
		KillTimer(timer);
		g_tCountHUD = INVALID_HANDLE;
		
		return Plugin_Handled;
	}
	
	char sInfo[256];
	Format(sInfo, sizeof(sInfo), "<font face=''><font color='#6600cc'>%s</font> \n \nZombies Count: <font color='#6544ff'>%d</font>\nCT Count: <font color='#6544ff'>%d</font>", MENU_PREFIX, g_nTerroristCount, g_nCTCount);
	
	PrintHintTextToAll(sInfo);
	
	return Plugin_Continue;
} 