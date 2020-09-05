#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "TorNim0s"
#define PLUGIN_VERSION "1.00"
#define PLUGIN_URL "play-il.co.il"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiecore>
#include <zombieclasses>

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[CSGO] ZombieEscape - KnockBack", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL
};

public void OnClientPostAdminCheck(int client) {
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (ZE_IsZeEnabled()) {
		if (attacker > 0 && attacker < MaxClients) {
			if (GetClientTeam(attacker) != GetClientTeam(victim) && GetClientTeam(attacker) == CS_TEAM_CT)
			{
				char sWeapon[32];
				GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));
				if (StrEqual("weapon_negev", sWeapon)) {
					damage = (damage/2);
				}
				DamageOnClientKnockBack(victim, attacker, damage);
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

void DamageOnClientKnockBack(int victimIndex, int attackerIndex, float damageAmount)
{
	// Initialize vectors
	float flClientLoc[3];
	float flEyeAngle[3];
	float flAttackerLoc[3];
	float flVector[3];
	
	// Get victim's position
	GetClientAbsOrigin(victimIndex, flClientLoc);
	
	// Get attacker's position
	GetClientEyeAngles(attackerIndex, flEyeAngle);
	GetClientEyePosition(attackerIndex, flAttackerLoc);
	
	// Calculate knockback end-vector
	TR_TraceRayFilter(flAttackerLoc, flEyeAngle, MASK_ALL, RayType_Infinite, FilterPlayers);
	TR_GetEndPosition(flClientLoc);
	
	// Get vector from the given starting and ending points
	MakeVectorFromPoints(flAttackerLoc, flClientLoc, flVector);
	
	// Normalize the vector (equal magnitude at varying distances)
	NormalizeVector(flVector, flVector);
	
	// Apply the magnitude by scaling the vector
	ScaleVector(flVector, ZE_GetZombieKnockBack(victimIndex) * damageAmount);
	
	// Push the player
	TeleportEntity(victimIndex, NULL_VECTOR, NULL_VECTOR, flVector);
	
}

public bool FilterPlayers(int nEntity, int contentsMask)
{
	return !(1 <= nEntity <= MaxClients);
} 