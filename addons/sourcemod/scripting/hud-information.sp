/*****************************************************************

    HUD Player Information
	Copyright (C) 2011 BCServ (plugins@bcserv.eu)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
*****************************************************************/

/*****************************************************************


C O M P I L E   O P T I O N S


*****************************************************************/
// enforce semicolons after each code statement
#pragma semicolon 1

/*****************************************************************


P L U G I N   I N C L U D E S


*****************************************************************/
#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <smlib/pluginmanager>

#undef REQUIRE_PLUGIN
#include <basekeyhintbox>

/*****************************************************************


P L U G I N   I N F O


*****************************************************************/
public Plugin:myinfo = {
	name 						= "HUD Information",
	author 						= "BCServ",
	description 				= "Display information about a player or players on the HUD",
	version 					= "1.0",
	url 						= "http://bcserv.eu/"
}

/*****************************************************************


		P L U G I N   D E F I N E S


*****************************************************************/
#define THINK_INTERVAL 1.0

/*****************************************************************


		G L O B A L   V A R S


*****************************************************************/
// Console Variables
new Handle:g_cvarEnable 					= INVALID_HANDLE;


// Console Variables: Runtime Optimizers
new g_iPlugin_Enable 					= 1;


// Plugin Internal Variables


// Library Load Checks
new bool:g_bLib_BaseKeyHintBox = false;

// Game Variables


// Timers
new Handle:g_hTimer_Think = INVALID_HANDLE;

// Server Variables


// Map Variables


// Client Variables


// M i s c


/*****************************************************************


		F O R W A R D   P U B L I C S


*****************************************************************/
public OnPluginStart()
{
	
	// Initialization for SMLib
	PluginManager_Initialize("hudinformation","[SM] ");
	
	// Translations
	// LoadTranslations("common.phrases");
	
	
	// Command Hooks (AddCommandListener) (If the command already exists, like the command kill, then hook it!)
	
	
	// Register New Commands (PluginManager_RegConsoleCmd) (If the command doesn't exist, hook it here)
	
	
	// Register Admin Commands (PluginManager_RegAdminCmd)
	
	
	// Cvars: Create a global handle variable.
	g_cvarEnable = PluginManager_CreateConVar("enable","1","Enables or disables this plugin");
	
	
	// Hook ConVar Change
	HookConVarChange(g_cvarEnable,ConVarChange_Enable);
	
	
	// Event Hooks
	
	
	// Library
	g_bLib_BaseKeyHintBox = LibraryExists("basekeyhintbox");
	
	/* Features
	if(CanTestFeatures()){
		
	}
	*/
	
	// Create ADT Arrays
	
	
	// Timers
	g_hTimer_Think = CreateTimer((g_bLib_BaseKeyHintBox ? BaseKeyHintBox_GetPrintInterval() : THINK_INTERVAL),Timer_Think,INVALID_HANDLE,TIMER_REPEAT);
	
}

public OnLibraryAdded(const String:name[])
{
	if(StrEqual(name,"basekeyhintbox",false)){
		
		g_bLib_BaseKeyHintBox = true;
		
		if(g_hTimer_Think != INVALID_HANDLE){
			CloseHandle(g_hTimer_Think);
			g_hTimer_Think = INVALID_HANDLE;
		}
		g_hTimer_Think = CreateTimer(BaseKeyHintBox_GetPrintInterval(),Timer_Think,INVALID_HANDLE,TIMER_REPEAT);
	}
}
public OnLibraryRemoved(const String:name[])
{
	if(StrEqual(name,"basekeyhintbox",false)){
		
		g_bLib_BaseKeyHintBox = false;
	}
}

public OnMapStart()
{
	// hax against valvefail (thx psychonic for fix)
	if (GuessSDKVersion() == SOURCE_SDK_EPISODE2VALVE) {
		SetConVarString(Plugin_VersionCvar, Plugin_Version);
	}
}

public OnConfigsExecuted()
{
	// Set your ConVar runtime optimizers here
	g_iPlugin_Enable = GetConVarInt(g_cvarEnable);
	
	//Mind: this is only here for late load, since on map change or server start, there isn't any client.
	//Remove it if you don't need it.
	Client_InitializeAll();
}

public OnClientPutInServer(client)
{
	Client_Initialize(client);
}

public OnClientPostAdminCheck(client)
{
	Client_Initialize(client);
}


/**************************************************************************************


	C A L L B A C K   F U N C T I O N S


**************************************************************************************/
public Action:Timer_Think(Handle:timer){
	
	if(!g_bLib_BaseKeyHintBox){
		return Plugin_Continue;
	}
	
	if(g_iPlugin_Enable == 0){
		return Plugin_Continue;
	}
	
	new userId = -1;
	decl String:steamAuth[MAX_STEAMAUTH_LENGTH];
	new health = -1;
	new armor = -1;
	new weapon = -1;
	new weaponClip1Ammo = 0;
	new weaponPlayer1Ammo = 0;
	new money = -1;
	new choke = -1;
	new loss = -1;
	new countSpectatorsAdmin = -1;
	new countSpectatorsNotAdmin = -1;
	new spectators[MAXPLAYERS+1];
	new String:messageClient[MAX_KEYHINTBOX_LENGTH];
	new String:messageObserver[MAX_KEYHINTBOX_LENGTH];
	new String:szButtons[32];
	new bool:isClientAdmin = false;
	new bool:isObserverAdmin = false;
	new Obs_Mode:obsMode = OBS_MODE_NONE;
	
	LOOP_CLIENTS(client,CLIENTFILTER_ALIVE){
		
		//get data
		userId = GetClientUserId(client);
		GetClientAuthString(client,steamAuth,sizeof(steamAuth));
		health = GetClientHealth(client);
		armor = GetClientArmor(client);
		weapon = Client_GetActiveWeapon(client);
		if(weapon != -1 && Weapon_IsValid(weapon)){
			weaponClip1Ammo = Weapon_GetPrimaryClip(weapon);
			Client_GetWeaponPlayerAmmoEx(client,weapon,weaponPlayer1Ammo);
		}
		money = Client_GetMoney(client);
		if(IsFakeClient(client)){
			choke = 0;
			loss = 0;
		}
		else {
			choke = RoundToNearest(GetClientAvgChoke(client,NetFlow_Outgoing)*1000);
			loss = RoundToNearest(GetClientAvgLoss(client,NetFlow_Outgoing)*1000);
		}
		isClientAdmin = Client_IsAdmin(client);
		countSpectatorsAdmin = Client_GetObservers(client,spectators);
		countSpectatorsNotAdmin = Client_GetObservers(client,spectators, CLIENTFILTER_NOADMINS);
		ButtonsToString(Client_GetButtons(client),szButtons,sizeof(szButtons));
		
		// print 
		messageClient[0] = '\0';
		
		//test case
		//Format(messageClient,sizeof(messageClient),"SteamId : %s",steamAuth);
		//PrintToChat(client,"countSpectatorsAdmin: %d; countSpectatorsNotAdmin: %d",countSpectatorsAdmin,countSpectatorsNotAdmin);
		
		if((isClientAdmin && countSpectatorsAdmin > 0) || (!isClientAdmin && countSpectatorsNotAdmin > 0)){
			
			StrCat(messageClient,sizeof(messageClient),"Spectators:\n");
		}
		
		LOOP_OBSERVERS(client, observer, CLIENTFILTER_ALL){
			
			if(client == observer){
				continue;
			}
			
			obsMode = Client_GetObserverMode(observer);
			if (obsMode != OBS_MODE_IN_EYE && obsMode != OBS_MODE_CHASE) {
				continue;
			}
			
			isObserverAdmin = Client_IsAdmin(observer);
			if(isClientAdmin || (!isClientAdmin && !isObserverAdmin)){
				Format(messageClient,sizeof(messageClient),"%s%N\n",messageClient,observer);
			}
			
			messageObserver[0] = '\0';
			
			if(isObserverAdmin) {
				Format(messageObserver,sizeof(messageObserver),"%sUserId : #%d\n",messageObserver,userId);
			}
			Format(messageObserver,sizeof(messageObserver),"%sSteamId : %s\n",messageObserver,steamAuth);
			Format(messageObserver,sizeof(messageObserver),"%sHP/Armor : %d/%d\n",messageObserver,health,armor);
			Format(messageObserver,sizeof(messageObserver),"%sClip/Load : %d/%d\n",messageObserver,weaponClip1Ammo,weaponPlayer1Ammo);
			Format(messageObserver,sizeof(messageObserver),"%sMoney : $ %d\n",messageObserver,money);
			Format(messageObserver,sizeof(messageObserver),"%sButtons : %s\n",messageObserver,szButtons);
			if(isObserverAdmin) {
				Format(messageObserver,sizeof(messageObserver),"%sChoke/Loss : %d/%d\n",messageObserver,choke,loss);
				Format(messageObserver,sizeof(messageObserver),"%sSpectators : %d\n",messageObserver,countSpectatorsAdmin);
			}
			else {
				Format(messageObserver,sizeof(messageObserver),"%sSpectators : %d\n",messageObserver,countSpectatorsNotAdmin);
			}
			
			BaseKeyHintBox_PrintToClient(observer,THINK_INTERVAL,messageObserver);
		}
		
		BaseKeyHintBox_PrintToClient(client,THINK_INTERVAL,messageClient);
	}
	return Plugin_Continue;
}


/**************************************************************************************

	C O N  V A R  C H A N G E

**************************************************************************************/
/* Example Callback Con Var Change*/
public ConVarChange_Enable(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_iPlugin_Enable = StringToInt(newVal);
}



/**************************************************************************************

	C O M M A N D S

**************************************************************************************/
/* Example Command Callback
public Action:Command_(client, args)
{
	
	return Plugin_Handled;
}
*/


/**************************************************************************************

	E V E N T S

**************************************************************************************/
/* Example Callback Event
public Action:Event_Example(Handle:event, const String:name[], bool:dontBroadcast)
{

}
*/


/***************************************************************************************


	P L U G I N   F U N C T I O N S


***************************************************************************************/



/***************************************************************************************

	S T O C K

***************************************************************************************/
stock ButtonsToString(buttons,String:output[],size){
	
	output[0] = '\0';
	
	if(buttons == 0){strcopy(output,size,"");return;}
	
	if(buttons & IN_SPEED){Format(output,size,"slow;%s",output);}
	if(buttons & IN_SCORE){Format(output,size,"score;%s",output);}
	if(buttons & IN_USE){Format(output,size,"use;%s",output);}
	if(buttons & IN_ZOOM){Format(output,size,"zoom;%s",output);}
	
	if(buttons & IN_DUCK){Format(output,size,"duck;%s",output);}
	if(buttons & IN_JUMP){Format(output,size,"jump;%s",output);}
	
	if(buttons & IN_RELOAD){Format(output,size,"reload;%s",output);}
	if(buttons & IN_ATTACK2){Format(output,size,"attack2;%s",output);}
	if(buttons & IN_ATTACK){Format(output,size,"attack;%s",output);}
	
	
	if(buttons & IN_MOVERIGHT){Format(output,size,"→ %s",output);}
	else {Format(output,size,"  %s",output);}
	
	if(buttons & IN_FORWARD && buttons & IN_BACK){Format(output,size,"↕ %s",output);}
	else if(buttons & IN_FORWARD){Format(output,size,"↑ %s",output);}
	else if(buttons & IN_BACK){Format(output,size,"↓ %s",output);}
	else {Format(output,size,"  %s",output);}
	
	if(buttons & IN_MOVELEFT){Format(output,size,"← %s",output);}
	else {Format(output,size,"  %s",output);}
}

stock Client_InitializeAll()
{
	LOOP_CLIENTS(client,CLIENTFILTER_ALL){
		
		Client_Initialize(client);
	}
}

stock Client_Initialize(client)
{
	// Variables
	Client_InitializeVariables(client);
	
	
	// Functions
	
	
	/* Functions where the player needs to be in game 
	if(!IsClientInGame(client)){
		return;
	}
	*/
}

stock Client_InitializeVariables(client)
{
	// Client Variables
	
}
