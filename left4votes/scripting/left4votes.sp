#include <left4votes>


#define TARGET_ID_PLAYER	"#L4D_TargetID_Player"
#define YES_VOTE			"Yes"

#define DEFAULT_RATIO	0.6


Function 	g_callback;
Handle		g_callingPlugin = null;

Handle		g_timer = null;
StringMap	g_votersSteamId;
bool		g_voteInProgress = false;
char		g_description[256];
char		g_translatedDescription[64];
char		g_successDescription[256];
char		g_translatedSuccessDescription[64];
int			g_allowedTeam = view_as<int>(AllowedTeam_Any);
int			g_yesVotes;
int			g_noVotes;
float		g_ratio = DEFAULT_RATIO;
int			g_maxVoters;


/* v2.0 - added an opportunity to work with translations */

public Plugin myinfo =
{
	name = "Left4Votes",
	author = "Skeletor",
	description = "Lib for simplifying interactions with votes in l4d1",
	version = "2.0"
}

public OnPluginStart()
{
	g_votersSteamId = CreateTrie();
}

public OnMapEnd()
{
	ResetAll();
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int iErr_max) 
{
	CreateNative("L4V_AddTranslationFile", Native_AddTranslationFile);
	CreateNative("L4V_CreateVote", Native_CreateVote);
	CreateNative("L4V_SetAllowedTeam", Native_SetAllowedTeam);
	CreateNative("L4V_SetDescription", Native_SetDescription);
	CreateNative("L4V_SetTranslatedDescription", Native_SetTranslatedDescription);
	CreateNative("L4V_SetSuccessDescription", Native_SetSuccessDescription);
	CreateNative("L4V_SetTranslatedSuccessDescription", Native_SetTranslatedSuccessDescription);
	CreateNative("L4V_SetSuccessVotesRatio", Native_SetSuccessVotesRatio);
	CreateNative("L4V_IsVoteInProgress", Native_IsVoteInProgress);
	CreateNative("L4V_Start", Native_Start);
	
	RegPluginLibrary("Left4Votes");
}


/* Natives */

public Native_AddTranslationFile(Handle plugin, int numParams)
{
	char file[64];
	GetNativeString(1, file, sizeof(file));
	
	LoadTranslations(file);
	ServerCommand("sm_reload_translations");
}

public Native_CreateVote(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return false;
	
	g_callback = GetNativeFunction(1);
	g_callingPlugin = plugin;
	
	return true;
}

public Native_SetAllowedTeam(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return;
	
	g_allowedTeam = view_as<int>(GetNativeCell(1));
}

public Native_SetDescription(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return;
	
	GetNativeString(1, g_description, sizeof(g_description));
}

public Native_SetTranslatedDescription(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return;
	
	GetNativeString(1, g_translatedDescription, sizeof(g_translatedDescription));
}

public Native_SetSuccessDescription(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return;
	
	GetNativeString(1, g_successDescription, sizeof(g_successDescription));
}

public Native_SetTranslatedSuccessDescription(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return;
	
	GetNativeString(1, g_translatedSuccessDescription, sizeof(g_translatedSuccessDescription));
}

public Native_SetSuccessVotesRatio(Handle plugin, int numParams)
{
	if (g_voteInProgress)
		return;
	
	float ratio = GetNativeCell(1);
	if (ratio <= 0.0 || ratio > 1.0)
		ratio = DEFAULT_RATIO;
	
	g_ratio = ratio;
}

public Native_IsVoteInProgress(Handle plugin, int numParams)
{
	return g_voteInProgress;
}

public Native_Start(Handle plugin, int numParams)
{
	g_maxVoters = GetMaxPotentialVoters();
	int client = GetNativeCell(1);
	
	if (!CanStart(client))
	{
		ResetAll();
		return false;
	}
	
	float timeout = GetNativeCell(2);
	if (timeout < 1.0)
		timeout = 1.0;
	
	AddCommandListener(CallvoteBlocker, "callvote");
	AddCommandListener(VoteHandler, "vote");
	StartVote(client, timeout);
	
	return true;
}


/* Main */

Action CallvoteBlocker(int client, const char[] command, int argc)
{
	return Plugin_Stop;
}

Action VoteHandler(int client, const char[] command, int argc)
{
	if (!CanClientVote(client))
		return Plugin_Stop;
	
	char arg[4];
	GetCmdArg(1, arg, sizeof(arg));
	
	HandleRecievedVote(client, arg);
	
	return Plugin_Stop;
}

void StartVote(int client, float timeout)
{
	g_voteInProgress = true;
	g_timer = CreateTimer(timeout, Timer_CheckVotes);
	
	CreateAndFireVoteStartedEvent(client);
	HandleRecievedVote(client, YES_VOTE);
}

Action Timer_CheckVotes(Handle t)
{
	CheckVotes();
	return Plugin_Handled;
}

void HandleRecievedVote(int client, const char[] vote)
{
	CastVote(client, vote);
	AddVotedClient(client);
	UpdateVotes();
}

void CreateAndFireVoteStartedEvent(int client)
{
	char translatedPhrase[128];
	
	bool translationExists = TranslationPhraseExists(g_translatedDescription);
	if (translationExists)
		Format(translatedPhrase, sizeof(translatedPhrase), "%T", g_translatedDescription, LANG_SERVER);
	else
		Format(translatedPhrase, sizeof(translatedPhrase), "%s", g_description);
	
	Event event = CreateEvent("vote_started");
	event.SetString("issue", TARGET_ID_PLAYER);
	event.SetString("param1", translatedPhrase);
	event.SetInt("team", g_allowedTeam);
	event.SetInt("initiator", client);
	event.Fire();
	
	if (translationExists)
	{
		event = CreateEvent("vote_started");
		event.SetString("issue", TARGET_ID_PLAYER);
		event.SetInt("team", g_allowedTeam);
		event.SetInt("initiator", client);
		
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (!IsValidClient(i) || IsFakeClient(i))
				continue;
			
			Format(translatedPhrase, sizeof(translatedPhrase), "%T", g_translatedDescription, i);
			event.SetString("param1", translatedPhrase);
			event.FireToClient(i);
		}
		
		event.Cancel();
	}
}

void CreateAndFireVotePassedEvent()
{
	char translatedPhrase[128];
	
	bool translationExists = TranslationPhraseExists(g_translatedSuccessDescription);
	if (translationExists)
		Format(translatedPhrase, sizeof(translatedPhrase), "%T", g_translatedSuccessDescription, LANG_SERVER);
	else
		Format(translatedPhrase, sizeof(translatedPhrase), "%s", g_successDescription);
	
	Event event = CreateEvent("vote_passed");
	event.SetString("details", TARGET_ID_PLAYER);
	event.SetString("param1", translatedPhrase);
	event.SetInt("team", g_allowedTeam);
	event.Fire();
	
	if (translationExists)
	{
		event = CreateEvent("vote_passed");
		event.SetString("details", TARGET_ID_PLAYER);
		event.SetInt("team", g_allowedTeam);
		
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (!IsValidClient(i) || IsFakeClient(i))
				continue;
			
			Format(translatedPhrase, sizeof(translatedPhrase), "%T", g_translatedSuccessDescription, i);
			event.SetString("param1", translatedPhrase);
			event.FireToClient(i);
		}
		
		event.Cancel();
	}
}

void CastVote(int client, const char[] vote)
{
	char type[16];
	
	if (StrEqual(vote, YES_VOTE, false))
	{
		++g_yesVotes;
		type = "vote_cast_yes";
	}
	else
	{
		++g_noVotes;
		type = "vote_cast_no";
	}
	
	Event voteCast = CreateEvent(type);
	voteCast.SetInt("entityid", client);
	voteCast.SetInt("team", g_allowedTeam);
	voteCast.Fire();
}

void UpdateVotes()
{
	Event event = CreateEvent("vote_changed");
	event.SetInt("yesVotes", g_yesVotes);
	event.SetInt("noVotes", g_noVotes);
	event.SetInt("potentialVotes", g_maxVoters);
	event.Fire();
	
	if (g_yesVotes + g_noVotes >= g_maxVoters)
	{
		CheckVotes();
		DeleteTimer();
	}
}

void CheckVotes()
{
	VoteHandledResult result = VoteResult_Passed;
	
	if (IsVoteSuccessful())
		CreateAndFireVotePassedEvent();
	else
	{
		Event event = CreateEvent("vote_failed");
		event.SetInt("team", g_allowedTeam);
		event.Fire();
		
		result = VoteResult_Failed;
	}
	
	Call_StartFunction(g_callingPlugin, g_callback);
	Call_PushCell(result);
	Call_Finish();
	
	RemoveCommandListener(CallvoteBlocker, "callvote");
	RemoveCommandListener(VoteHandler, "vote");
	ResetAll();
}


/* Helpers */

void ResetAll()
{
	g_callingPlugin = null;
	
	g_voteInProgress = false;
	g_description[0] = 0;
	g_translatedDescription[0] = 0;
	g_successDescription[0] = 0;
	g_translatedSuccessDescription[0] = 0;
	g_allowedTeam = view_as<int>(AllowedTeam_Any);
	g_yesVotes = 0;
	g_noVotes = 0;
	g_ratio = DEFAULT_RATIO;
	g_maxVoters = 0;
	g_votersSteamId.Clear();
}

void DeleteTimer()
{
	delete g_timer;
	g_timer = null;
}

bool CanStart(int client)
{
	return IsValidClient(client) && !g_voteInProgress && g_callingPlugin && g_maxVoters;
}

bool CanClientVote(int client)
{	
	return BelongsToTeam(client, g_allowedTeam) && !HasClientVoted(client);
}

void AddVotedClient(int client)
{
	char auth[32];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	g_votersSteamId.SetValue(auth, 1);
}

bool HasClientVoted(int client)
{
	char auth[32];
	GetClientAuthId(client, AuthId_SteamID64, auth, sizeof(auth));
	
	int dummy;
	return g_votersSteamId.GetValue(auth, dummy);
}

int GetMaxPotentialVoters()
{
	int count = 0;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsValidClient(i) || IsFakeClient(i))
			continue;
		
		if (BelongsToTeam(i, g_allowedTeam))
			++count;
	}
	
	return count;
}

bool IsVoteSuccessful()
{
	return float(g_yesVotes) / float(g_yesVotes + g_noVotes) >= g_ratio;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool BelongsToTeam(int client, int team)
{
	return IsValidClient(client) && (team == view_as<int>(AllowedTeam_Any) || GetClientTeam(client) == team);
}