/*
**
*/
#if defined _ZombieEscapeClasses_included
#endinput
#endif
#define _ZombieEscapeClasses_included

enum {
	zClass_Unique = 0, 
	zClass_Name, 
	zClass_Description, 
	zClass_Model, 
	zClass_Health, 
	zClass_HPbonus, 
	zClass_KnockBack,
	zClass_MaxLevel,
	zClass_PriceLevel1,
	zClass_PriceLevel2,
	zClass_PriceLevel3
}

native int ZE_CreateClass(char[] unique, char[] name, char[] description, char[] model, char[] health, char[] HPbonus ,char[] knockback);
native bool ZE_IsPlayerClassEnabled(int client, int class);
native float ZE_GetZombieKnockBack(int client);
native int ZE_GetZombieMaxHealth(int client);

forward void ZE_OnClassSelected(int client, int class);

#if !defined REQUIRE_PLUGIN
public __pl_ZombieEscapeClasses_SetNTVOptional()
{
	MarkNativeAsOptional("ZE_CreateClass");
	MarkNativeAsOptional("ZE_IsPlayerClassEnabled");
	MarkNativeAsOptional("ZE_GetZombieKnockBack");
	MarkNativeAsOptional("ZE_GetZombieMaxHealth");
}
#endif

public SharedPlugin __pl_ZombieEscapeClasses = 
{
	name = "[CSGO] ZombieEscape - Classes", 
	file = "ZombieClasses.smx", 
	#if defined REQUIRE_PLUGIN
	required = 1, 
	#else
	required = 0, 
	#endif
};
