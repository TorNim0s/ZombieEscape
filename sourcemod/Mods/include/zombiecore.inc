/*
**
*/
#if defined _ZombieEscape_included
 #endinput
#endif
#define _ZombieEscape_included

native bool ZE_IsRoundStarted();
native bool ZE_IsZeEnabled();

forward void ZE_OnNewZombieSpawn(int client);
forward void ZE_OnRoundStart(int client);
forward void ZE_OnRoundEnd(int client);
forward void ZE_HumanKilledZombie(int attacker, int victim);

#if !defined REQUIRE_PLUGIN
public __pl_ZombieEscape_SetNTVOptional()
{
	MarkNativeAsOptional("ZE_IsRoundStarted");
	MarkNativeAsOptional("ZE_IsZeEnabled");
}
#endif

public SharedPlugin __pl_ZombieEscape =
{
	name = "[CSGO] ZombieEscape - Core",
	file = "ZombieEscape.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};
