#if defined _furious_stocks_included
 #endinput
#endif
#define _furious_stocks_included

stock int GetConVarRandom(ConVar convar, const char[] splitter = "-") {
	char sBuffer[128];
	convar.GetString(sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) == 0) {
		return -1;
	}

	char sPart[2][12];
	int iReturned = ExplodeString(sBuffer, splitter, sPart, 2, 12);
	
	int clamps[2];
	for (int i = 0; i < iReturned; i++) {
		clamps[i] = StringToInt(sPart[i]);
	}
		
	if (clamps[0] > clamps[1]) {
		clamps[0] = clamps[1];
	}

	return GetRandomInt(clamps[0], clamps[1]);
}

stock bool StopTimer(Handle& timer) {
	if (timer != null) {
		KillTimer(timer);
		timer = null;
		return true;
	}
	
	return false;
}

stock bool PushMenuString(Menu menu, const char[] id, const char[] value) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	return menu.AddItem(id, value, ITEMDRAW_IGNORE);
}

stock bool GetMenuString(Menu menu, const char[] id, char[] buffer, int size) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	char info[128]; char data[8192];
	for (int i = 0; i < menu.ItemCount; i++) {
		if (menu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, id)) {
			strcopy(buffer, size, data);
			return true;
		}
	}
	
	return false;
}

stock bool PushMenuInt(Menu menu, const char[] id, int value) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	char sBuffer[128];
	IntToString(value, sBuffer, sizeof(sBuffer));
	return menu.AddItem(id, sBuffer, ITEMDRAW_IGNORE);
}

stock int GetMenuInt(Menu menu, const char[] id, int defaultvalue = 0) {
	if (menu == null || strlen(id) == 0) {
		return defaultvalue;
	}
	
	char info[128]; char data[128];
	for (int i = 0; i < menu.ItemCount; i++) {
		if (menu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, id)) {
			return StringToInt(data);
		}
	}
	
	return defaultvalue;
}

stock int GetClientByAccountID(int accountid) {
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || GetSteamAccountID(i) != accountid) {
			continue;
		}

		return i;
	}

	return -1;
}

stock void FormatSeconds(float seconds, char[] buffer, int maxlength, const char[] format, bool precision = false) {
	int t = RoundToFloor(seconds);

	int day; char sDay[32];
	if (t >= 86400) {
		day = RoundToFloor(t / 86400.0);
		t %= 86400;

		Format(sDay, sizeof(sDay), "%02d", day);
	}

	int hour; char sHour[32];
	if (t >= 3600) {
		hour = RoundToFloor(t / 3600.0);
		t %= 3600;

		Format(sHour, sizeof(sHour), "%02d", hour);
	}

	int mins; char sMinute[32];
	if (t >= 60) {
		mins = RoundToFloor(t / 60.0);
		t %= 60;

		Format(sMinute, sizeof(sMinute), "%02d", mins);
	}

	char sSeconds[32];
	switch (precision) {
		case true: {
			Format(sSeconds, sizeof(sSeconds), "%05.2f", float(t) + seconds - RoundToFloor(seconds));
		}
		case false: {
			Format(sSeconds, sizeof(sSeconds), "%02d", t);
		}
	}

	strcopy(buffer, maxlength, format);

	ReplaceString(buffer, maxlength, "%D", strlen(sDay) > 0 ? sDay : "00");
	ReplaceString(buffer, maxlength, "%H", strlen(sHour) > 0 ? sHour : "00");
	ReplaceString(buffer, maxlength, "%M", strlen(sMinute) > 0 ? sMinute : "00");
	ReplaceString(buffer, maxlength, "%S", strlen(sSeconds) > 0 ? sSeconds : "00");
}

stock int GetCmdArgTarget(int client, int argnum, bool nobots = false, bool immunity = true) {
	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(argnum, sTarget, sizeof(sTarget));
	return FindTarget(client, sTarget, nobots, immunity);
}

stock bool StringToColor(const char[] explode, int buffer[4], int defaultvalues[4] = {255, 255, 255, 255}) {
	if (strlen(explode) == 0) {
		buffer[0] = defaultvalues[0]; buffer[1] = defaultvalues[1]; buffer[2] = defaultvalues[2]; buffer[3] = defaultvalues[3];
		return false;
	}

	char sPart[4][32];
	int iReturned = ExplodeString(explode, StrContains(explode, ",") != -1 ? ", " : " ", sPart, 4, 32);

	if (iReturned != 4) {
		buffer[0] = defaultvalues[0]; buffer[1] = defaultvalues[1]; buffer[2] = defaultvalues[2]; buffer[3] = defaultvalues[3];
		return false;
	}

	buffer[0] = StringToInt(sPart[0]); buffer[1] = StringToInt(sPart[1]); buffer[2] = StringToInt(sPart[2]); buffer[3] = StringToInt(sPart[3]);
	return true;
}

stock bool ArrayEqual(int[] array, int[] array2, int size) {
	for (int i = 0; i < size; i++) {
		if (array[i] != array2[i]) {
			return false;
		}
	}

	return true;
}

stock void GetServerIP(char[] buffer, int size, bool showport = false) {
	int ip = FindConVar("hostip").IntValue;

	int ips[4];
	ips[0] = (ip >> 24) & 0x000000FF;
	ips[1] = (ip >> 16) & 0x000000FF;
	ips[2] = (ip >> 8) & 0x000000FF;
	ips[3] = ip & 0x000000FF;

	Format(buffer, size, "%d.%d.%d.%d", ips[0], ips[1], ips[2], ips[3]);

	if (showport) {
		Format(buffer, size, "%s:%d", buffer, FindConVar("hostport").IntValue);
	}
}

stock float CalculateAccuracy(int hits, int shots) {
	float rate = 0.0;
	
	if (shots > 0) {
		rate = float(hits) / float(shots) * 100.0;
	}
	
	return rate;
}

stock float CalculateKDR(int kills, int deaths) {
	float rate = float(kills) / float(deaths);

	if (deaths == 0 && kills != 0) {
		rate = float(kills);
	}

	if (kills < 0) {
		rate = float(0);
	}

	return rate;
}

stock int FindTargetEx(int client, const char[] target, bool nobots = false, bool immunity = true) {
	int flags = COMMAND_FILTER_NO_MULTI;
	
	if (nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	
	if (!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[1];
	bool tn_is_ml;
	
	if (ProcessTargetString(target, client, target_list, 1, flags, target_name, sizeof(target_name), tn_is_ml) > 0) {
		return target_list[0];
	}
	
	return -1;
}

stock int GetClientBySteamID(const char[] steamid, AuthIdType authtype = AuthId_Engine)
{
	if (strlen(steamid) == 0) {
		return -1;
	}
	
	char sSteamID[64];
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || IsFakeClient(i) || !GetClientAuthId(i, authtype, sSteamID, sizeof(sSteamID)) || !StrEqual(steamid, sSteamID)) {
			continue;
		}

		return i;
	}

	return -1;
}

stock float GetMenuFloat(Menu menu, const char[] id, float defaultvalue = 0.0) {
	if (menu == null || strlen(id) == 0) {
		return defaultvalue;
	}
		
	char info[128]; char data[128];
	for (int i = 0; i < menu.ItemCount; i++) {
		if (menu.GetItem(i, info, sizeof(info), _, data, sizeof(data)) && StrEqual(info, id)) {
			return StringToFloat(data);
		}
	}
	
	return defaultvalue;
}

stock bool PushMenuFloat(Menu menu, const char[] id, float value) {
	if (menu == null || strlen(id) == 0) {
		return false;
	}
	
	char sBuffer[128];
	FloatToString(value, sBuffer, sizeof(sBuffer));
	return menu.AddItem(id, sBuffer, ITEMDRAW_IGNORE);
}

stock bool IsStringNumeric(const char[] str) {
	int x = 0;
	int dotsFound = 0;
	int numbersFound = 0;

	if (str[x] == '+' || str[x] == '-') {
		x++;
	}

	while (str[x] != '\0') {
		if (IsCharNumeric(str[x])) {
			numbersFound++;
		} else if (str[x] == '.') {
			dotsFound++;

			if (dotsFound > 1) {
				return false;
			}
		} else {
			return false;
		}

		x++;
	}

	return numbersFound > 0;
}

stock bool ClearTrieSafe(StringMap map) {
	if (map == null) {
		return false;
	}

	StringMapSnapshot snapshot = map.Snapshot();
	int size;

	for (int i = 0; i < snapshot.Length; i++) {
		size = snapshot.KeyBufferSize(i);

		char[] sBuffer = new char[size];
		snapshot.GetKey(i, sBuffer, size);

		Handle hLocal;
		map.GetValue(sBuffer, hLocal);

		delete hLocal;

		map.Remove(sBuffer);
	}

	delete snapshot;
	return true;
}

enum ConfirmationResponses {
	Confirm_Yes,			//Client said yes.
	Confirm_No,				//Client said no.
	Confirm_Disconnected,	//Client disconnected with the question active.
	Confirm_Interrupted,	//Client either couldn't receive the question was active or was interrupted with another menu.
	Confirm_Timeout,		//Client didn't answer the question in time.
}

typeset Callback_Confirmation {
	function void (int client, ConfirmationResponses response, Handle data);
	function void (int client, ConfirmationResponses response, any data);
	function void (int client, ConfirmationResponses response);
}

static Callback_Confirmation g_ConfirmationCall[MAXPLAYERS + 1];
static ReplySource g_ConfirmReplySource[MAXPLAYERS + 1];

stock bool SendConfirmationMenu(int client, Callback_Confirmation callback, char[] title = "", int time = MENU_TIME_FOREVER, any data = 0) {
	if (client == 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client)) {
		return false;
	}
	
	g_ConfirmationCall[client] = callback;
	g_ConfirmReplySource[client] = GetCmdReplySource();
	
	Menu menu = new Menu(___MenuHandler_SendConfirmation, MenuAction_Select|MenuAction_Cancel|MenuAction_End);
	menu.SetTitle(strlen(title) > 0 ? title : "Are you sure you want to do this?");
	
	//menu.AddItem("", "---", ITEMDRAW_DISABLED);
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	
	char sBuffer[256];
	IntToString(data, sBuffer, sizeof(sBuffer));
	menu.AddItem("data", sBuffer, ITEMDRAW_IGNORE);
	
	menu.Display(client, time);
	return true;
}

public int ___MenuHandler_SendConfirmation(Menu menu, MenuAction action, int param1, int param2) {
	any data; char info[128]; char datastring[128];
	for (int i = 0; i < menu.ItemCount; i++) {
		if (menu.GetItem(i, info, sizeof(info), _, datastring, sizeof(datastring)) && StrEqual(info, "data")) {
			data = StringToInt(datastring);
			break;
		}
	}
	
	switch (action) {
		case MenuAction_Select: {
			ReplySource reply = SetCmdReplySource(g_ConfirmReplySource[param1]);
			
			Call_StartFunction(null, g_ConfirmationCall[param1]);
			Call_PushCell(param1);
			
			char sInfo[12];
			menu.GetItem(param2, sInfo, sizeof(sInfo));
			Call_PushCell(StrEqual(sInfo, "yes") ? Confirm_Yes : Confirm_No);
			
			Call_PushCell(data);
			Call_Finish();
			
			SetCmdReplySource(reply);
		}
		case MenuAction_Cancel: {
			switch (param2) {
				case MenuCancel_Disconnected: {
					ReplySource reply = SetCmdReplySource(g_ConfirmReplySource[param1]);
					
					Call_StartFunction(null, g_ConfirmationCall[param1]);
					Call_PushCell(param1);
					Call_PushCell(Confirm_Disconnected);
					Call_PushCell(data);
					Call_Finish();
					
					SetCmdReplySource(reply);
				}
				case MenuCancel_Interrupted, MenuCancel_NoDisplay: {
					ReplySource reply = SetCmdReplySource(g_ConfirmReplySource[param1]);
					
					Call_StartFunction(null, g_ConfirmationCall[param1]);
					Call_PushCell(param1);
					Call_PushCell(Confirm_Interrupted);
					Call_PushCell(data);
					Call_Finish();
					
					SetCmdReplySource(reply);
				}
				case MenuCancel_Exit: {
					ReplySource reply = SetCmdReplySource(g_ConfirmReplySource[param1]);
					
					Call_StartFunction(null, g_ConfirmationCall[param1]);
					Call_PushCell(param1);
					Call_PushCell(Confirm_No);
					Call_PushCell(data);
					Call_Finish();
					
					SetCmdReplySource(reply);
				}
				case MenuCancel_Timeout: {
					ReplySource reply = SetCmdReplySource(g_ConfirmReplySource[param1]);
					
					Call_StartFunction(null, g_ConfirmationCall[param1]);
					Call_PushCell(param1);
					Call_PushCell(Confirm_Timeout);
					Call_PushCell(data);
					Call_Finish();
					
					SetCmdReplySource(reply);
				}
			}
		}
		case MenuAction_End: {
			delete menu;
		}
	}

	return 0;
}

stock void ShowOverlay(int client, const char[] overlay, float duration = 0.0) {
	if (client == 0 || client > MaxClients) {
		return;
	}

	int iFlags = GetCommandFlags("r_screenoverlay");
	SetCommandFlags("r_screenoverlay", iFlags & ~FCVAR_CHEAT);
	ClientCommand(client, "r_screenoverlay \"%s\"", overlay);
	SetCommandFlags("r_screenoverlay", iFlags);

	if (duration > 0.0) {
		CreateTimer(duration, __Timer_ResetOverlay, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action __Timer_ResetOverlay(Handle timer, any data) {
	ShowOverlay(GetClientOfUserId(data), "0", 0.0);

	return Plugin_Stop;
}

stock float GetConVarRandomFloat(ConVar convar, const char[] splitter = "-") {
	char sBuffer[128];
	convar.GetString(sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) == 0) {
		return -1.0;
	}

	char sPart[2][12];
	int iReturned = ExplodeString(sBuffer, splitter, sPart, 2, 12);
	
	float clamps[2];
	for (int i = 0; i < iReturned; i++) {
		clamps[i] = StringToFloat(sPart[i]);
	}
		
	if (clamps[0] > clamps[1]) {
		clamps[0] = clamps[1];
	}

	return GetRandomFloat(clamps[0], clamps[1]);
}

stock bool GetEntGroundCoordinates(int entity, float buffer[3], float distance = 0.0, float offset[3] = {0.0, 0.0, 0.0}) {
	float vecOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vecOrigin);

	float vecLook[3] = {90.0, 0.0, 0.0};
	Handle trace = TR_TraceRayFilterEx(vecOrigin, vecLook, MASK_SOLID_BRUSHONLY, RayType_Infinite, ___TraceEntityFilter_NoPlayers, entity);

	if (TR_DidHit(trace)) {
		TR_GetEndPosition(buffer, trace);
		delete trace;
		
		buffer[0] += offset[0]; buffer[1] += offset[1]; buffer[2] += offset[2];
		return (distance > 0.0 && vecOrigin[2] - buffer[2] > distance);
	}

	delete trace;
	return false;
}

public bool ___TraceEntityFilter_NoPlayers(int entity, int contentsMask, any data) {
	return entity != data && entity > MaxClients;
}

stock int[] GetConVarColor(ConVar convar) {
	int colors[4] = {255, 255, 255, 255};

	char sBuffer[128];
	convar.GetString(sBuffer, sizeof(sBuffer));

	if (strlen(sBuffer) == 0) {
		return colors;
	}

	char sPart[4][6];
	int iReturned = ExplodeString(sBuffer, StrContains(sBuffer, ", ") != -1 ? ", " : " ", sPart, 4, 6);

	for (int i = 0; i < iReturned; i++) {
		colors[i] = StringToInt(sPart[i]);
	}

	return colors;
}

stock void CSGO_AddClientArmor(int client, int amount) {
	int current = GetEntProp(client, Prop_Send, "m_ArmorValue");
	SetEntProp(client, Prop_Send, "m_ArmorValue", current + amount);
}

stock bool IsValidClient(int client) {
	return client > 0 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsClientSourceTV(client);
}

stock void strtolower(const char[] input, char[] output, int size) {
	size--;

	int x = 0;
	while (input[x] != '\0' && x < size) {
		output[x] = CharToLower(input[x]);
		x++;
	}

	output[x] = '\0';
}

stock int FindEntityByName(const char[] name, const char[] classname = "*") {
	int entity = -1; char temp[256];
	while ((entity = FindEntityByClassname(entity, classname)) != -1) {
		GetEntPropString(entity, Prop_Data, "m_iName", temp, sizeof(temp));
		
		if (StrEqual(temp, name, false)) {
			return entity;
		}
	}
	
	return entity;
}