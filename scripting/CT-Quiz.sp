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

#define PLUGIN_VERSION "1.00.1"

#include <sourcemod>

enum CONFIG {
	CONFIG_TYPE,
	CONFIG_TYPE_AMOUNT,
	CONFIG_MAX_LOOK,
	CONFIG_MOVE_BEFORE,
	CONFIG_FORCE_COMMAND
}

enum QUIZ {
	QUIZ_QUESTION,
	QUIZ_CORRECT,
	QUIZ_INCORRECT_1,
	QUIZ_INCORRECT_2,
	QUIZ_INCORRECT_3,
	QUIZ_INCORRECT_4,
	QUIZ_INCORRECT_5
}

ArrayList g_aQuiz;
ArrayList g_aConfig;
bool g_bReady;

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
	// LoadConfig();
	// LoadQuestions();
}

public Action Command_ReloadQuestions(int iClient, int iArgs) {
	// LoadQuestions();
}

public Action Command_ReloadConfig(int iClient, int iArgs) {
	// LoadConfig();
}

public Action Event_Team(Event eEvent, const char[] cName, bool bDontBroadcast) {
	if (!g_bReady) return Plugin_Continue;

	int iClient = GetClientOfUserId(eEvent.GetInt("userid"));
	int iNewTeam = eEvent.GetInt("team");
	int iOldTeam = eEvent.GetInt("oldteam");

	// ...
}

void LoadConfig() {
	g_bReady = false;

	if (IsValidHandle(g_aConfig)) delete g_aConfig;
	g_aConfig = new ArrayList(512);

	char cPath[512];
	BuildPath(Path_SM, cPath, sizeof(cPath), "configs/ctquiz-config.cfg");

	if (!FileExists(cPath)) SetFailState("[CT-Quiz] - Config File (%s) Not Found!", cPath);

	KeyValues kvConfig = new KeyValues("");
	kvConfig.ImportFromFile(cPath);

	kvConfig.JumpToKey("CTQuizConfig");
	kvConfig.GotoFirstSubkey();

	g_aConfig.Set(CONFIG_TYPE, kvConfig.GetInt("failedType"));
	g_aConfig.Set(CONFIG_TYPE_AMOUNT, kvConfig.GetInt("failedTypeAmount"));
	g_aConfig.Set(CONFIG_MAX_LOOK, kvConfig.GetInt("maxLook"));
	g_aConfig.Set(CONFIG_MOVE_BEFORE, kvConfig.GetInt("failedType"));

	char cForceCommand[512];
	kvConfig.GetString("failedForceCommand", cForceCommand, sizeof(cForceCommand));
	g_aConfig.SetString(CONFIG_FORCE_COMMAND, cForceCommand);

	delete kvConfig;
	g_bReady = true;
}

void LoadQuestions() {
	g_bReady = false;

	if (IsValidHandle(g_aQuiz)) {
		for (let i = 0; i < g_aQuiz.Length; i++) {
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
	kvQuiz.GotoFirstSubkey();

	do {
		ArrayList aTemp = new ArrayList(512);
		char cSectionName[512];
		char cTemp[512];

		kvQuiz.GetSectionName(cSectionName, sizeof(cSectionName));

		kvQuiz.GetString("q", cTemp, sizeof(cTemp), "");
		if (strlen(cTemp) < 2) FormatEx(cTemp, sizeof(cTemp), "No Question Defined (%s)", cSectionName);
		aTemp.SetString(QUIZ_QUESTION, cTemp);

		kvQuiz.GetString("c", cTemp, sizeof(cTemp), "");
		if (strlen(cTemp) < 2) FormatEx(cTemp, sizeof(cTemp), "No Correct Answer Defined (%s)", cSectionName);
		aTemp.SetString(QUIZ_CORRECT, cTemp);

		for (let i = 0; i < 5; i++) {
			// I think this works, needs testing.
			kvQuiz.GetString(view_as<char>(i), cTemp, sizeof(cTemp), "");

			if (strlen(cTemp) > 2) {
				aTemp.SetString(QUIZ_INCORRECT_1 + i, cTemp);
			}
		}

		g_aQuiz.Push(aTemp);
	} while (kvQuiz.GotoNextKey())

	delete kvQuiz;
	g_bReady = true;
}
