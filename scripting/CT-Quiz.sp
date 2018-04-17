/* CT-Quiz
*
* Copyright (C) 2017-2018 Oscar Wos // github.com/OSCAR-WOS | theoscar@protonmail.com
*
* This program is free software: you can redistribute it and/or modify it
* under the terms of the GNU General Public License as published by the Free
* Software Foundation, either version 3 of the License, or (at your option)
* any later version.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License along with
* this program. If not, see http://www.gnu.org/licenses/.
*/

// Compiler Info: Pawn 1.8 - build 6041

#define PLUGIN_VERSION "1.00.2"
#define PLUGIN_PREFIX "\x01[\x06CT-Quiz\x01]"

#define TEAM_CT 3

#include <sourcemod>

enum CONFIG {
	CONFIG_TYPE,
	CONFIG_TYPE_AMOUNT,
	CONFIG_MAX_LOOK,
	CONFIG_MOVE_BEFORE,
	CONFIG_SHOW_ADMINS,
	CONFIG_FORCE_COMMAND
}

enum QUIZ {
	QUIZ_QUESTION = 0,
	QUIZ_CORRECT = 64,
	QUIZ_INCORRECT = 128
}

ArrayList g_aQuiz;
ArrayList g_aConfig;
bool g_bReady;
bool g_bEnabled;

public Plugin myinfo = {
	name = "CT-Quiz",
	author = "Oscar Wos (OSWO)",
	description = "Customisable prompted quiz when a user tries to join the CT team. Useful for Jailbreak servers.",
	version = PLUGIN_VERSION,
	url = "https://github.com/OSCAR-WOS / https://steamcommunity.com/id/OSWO",
}

public void OnPluginStart() {
	HookEvent("player_team", Event_Team, EventHookMode_Pre);
	RegAdminCmd("sm_ctqreloadquestions", Command_ReloadQuestions, ADMFLAG_ROOT, "Reloads the Questions for CT-Quiz");
	RegAdminCmd("sm_ctqreloadconfig", Command_ReloadConfig, ADMFLAG_ROOT, "Reloads the Config for CT-Quiz");
}

public void OnMapStart() {
	LoadConfig();
	LoadQuestions();
}

public Action Command_ReloadQuestions(int iClient, int iArgs) {
	LoadQuestions();
	ReplyToCommand(iClient, "%s %T", PLUGIN_PREFIX, "Command_ReloadQuestions")

	return Plugin_Handled;
}

public Action Command_ReloadConfig(int iClient, int iArgs) {
	LoadConfig();
	ReplyToCommand(iClient, "%s %T", PLUGIN_PREFIX, "Command_ReloadConfig")

	return Plugin_Handled;
}

public Action Command_EnableQuiz(int iClient, int iArgs) {
	g_bEnabled = true;
	ReplyToCommand(iClient, "%s %T", PLUGIN_PREFIX, "Command_Enabled")

	return Plugin_Handled;
}

public Action Event_Team(Event eEvent, const char[] cName, bool bDontBroadcast) {
	if (!g_bReady) return Plugin_Continue;

	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	if (IsFakeClient(iClient)) return Plugin_Continue;

	int iNewTeam = eEvent.GetInt("team");
	int iOldTeam = eEvent.GetInt("oldteam");

	if (iNewTeam == TEAM_CT && iOldTeam != TEAM_CT && g_bEnabled) {
		ShowQuiz(iClient)
	}

	return Plugin_Continue;
}

void LoadConfig() {
	g_bReady = false;

	if (g_aConfig != INVALID_HANDLE) delete g_aConfig;
	g_aConfig = new ArrayList(512);

	char cPath[512];
	BuildPath(Path_SM, cPath, sizeof(cPath), "configs/ctquiz-config.cfg");

	if (!FileExists(cPath)) SetFailState("[CT-Quiz] - Config File (%s) Not Found!", cPath);

	KeyValues kvConfig = new KeyValues("");
	kvConfig.ImportFromFile(cPath);

	kvConfig.JumpToKey("CTQuizConfig");
	kvConfig.GotoFirstSubKey();

	g_aConfig.Set(view_as<int>(CONFIG_TYPE), kvConfig.GetNum("failedType"));
	g_aConfig.Set(view_as<int>(CONFIG_TYPE_AMOUNT), kvConfig.GetNum("failedTypeAmount"));
	g_aConfig.Set(view_as<int>(CONFIG_MAX_LOOK), kvConfig.GetNum("maxLook"));
	g_aConfig.Set(view_as<int>(CONFIG_MOVE_BEFORE), kvConfig.GetNum("moveBeforeQuiz"));
	g_aConfig.Set(view_as<int>(CONFIG_SHOW_ADMINS), kvConfig.GetNum("showFailed"));

	char cForceCommand[512];
	kvConfig.GetString("failedForceCommand", cForceCommand, sizeof(cForceCommand));
	g_aConfig.SetString(view_as<int>(CONFIG_FORCE_COMMAND), cForceCommand);

	delete kvConfig;
	g_bReady = true;
}

void LoadQuestions() {
	g_bReady = false;

	if (g_aQuiz != INVALID_HANDLE) {
		for (int i = 0; i < g_aQuiz.Length; i++) {
			ArrayList aTemp = g_aQuiz.Get(i);
			delete aTemp;
		}
	}

	g_aQuiz = new ArrayList(512);

	char cPath[512];
	BuildPath(Path_SM, cPath, sizeof(cPath), "configs/ctquiz-questions.cfg");

	if (!FileExists(cPath)) SetFailState("[CT-Quiz] - Config File (%s) Not Found!", cPath);

	KeyValues kvQuiz = new KeyValues("");
	kvQuiz.ImportFromFile(cPath);

	kvQuiz.JumpToKey("CTQuizQuestions");
	kvQuiz.GotoFirstSubKey();

	do {
		ArrayList aTemp = new ArrayList(512);
		char cSectionName[512];
		char cTemp[512];

		kvQuiz.GetSectionName(cSectionName, sizeof(cSectionName));

		kvQuiz.GetString("q", cTemp, sizeof(cTemp), "");
		if (strlen(cTemp) < 2) FormatEx(cTemp, sizeof(cTemp), "No Question Defined (%s)", cSectionName);
		aTemp.SetString(view_as<int>(QUIZ_QUESTION), cTemp);

		kvQuiz.GetString("c", cTemp, sizeof(cTemp), "");
		if (strlen(cTemp) < 2) FormatEx(cTemp, sizeof(cTemp), "No Correct Answer Defined (%s)", cSectionName);
		aTemp.SetString(view_as<int>(QUIZ_CORRECT), cTemp);

		for (int i = 0; i < 5; i++) {
			// So view_as<char>(i) doesn't work...
			char sI[4];
			FormatEx(sI, sizeof(sI), "%i", i);
			kvQuiz.GetString(sI, cTemp, sizeof(cTemp), "");

			if (strlen(cTemp) < 2) break;
			aTemp.SetString((view_as<int>(QUIZ_INCORRECT) + (i * 64)), cTemp);
		}

		g_aQuiz.Push(aTemp);
	} while (kvQuiz.GotoNextKey())

	delete kvQuiz;
	g_bReady = true;
}

void ShowQuiz(int iClient) {
	Menu mQuiz = new Menu(Menu_Quiz);
	mQuiz.ExitButton = false;

	// Shuffling and Randoming of Questions / Answers per Execution

	if (!mQuiz.Display(iClient, 0)) {

	}
}

public int Menu_Quiz(Menu mMenu, MenuAction maAction, int iParam1, int iParam2) {
	switch (MenuAction) {
		case MenuAction_Select: {

		}

		case MenuAction_Cancel: {

		}

		case MenuAction_End: {

		}
	}
}
