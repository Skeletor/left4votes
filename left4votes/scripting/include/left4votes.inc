#if defined _left4votes
    #endinput
#endif
#define _left4votes


#include <sourcemod>


enum VoteHandledResult {
	VoteResult_Passed = 0,
	VoteResult_Failed
};

enum AllowedTeamToVote {
	AllowedTeam_Spectators 	= 1,
	AllowedTeam_Survivors	= 2,
	AllowedTeam_Infected	= 3,
	AllowedTeam_Any			= -1
};

typedef VoteHandledCallback = function void(VoteHandledResult result);

/**
 * @brief 	Adds the translation file to use the translated phrases. Specify the file without ".txt" extension.
 *		  	This function should be called in "OnAllPluginsLoaded".
 *
 * @param file		File to load translation phrases from.
 */
native void L4V_AddTranslationFile(const char[] file);

/**
 * @brief 	Creates the vote, but doesn't trigger it.
 *
 * @param cb		Callback function to be invoked after voting ends.
 *
 * @return			true if vote has been registered, false if there's ongoing vote currently.
 */
native bool L4V_CreateVote(VoteHandledCallback cb);

/**
 * @brief 	Specify the team that should be allowed to vote.
 *
 * @param team		See "AllowedTeamToVote" enum.
 */
native void L4V_SetAllowedTeam(AllowedTeamToVote team);

/**
 * @brief 	Sets the description for the vote.
 * @remarks This will use the static description you provided. If you want to use translated
 * 			phrases use "L4V_SetTranslatedDescription" instead.
 *
 * @param desc		The description to appear in the vote box.
 */
native void L4V_SetDescription(const char[] desc);

/**
 * @brief 	Sets the translated description for the vote.
 * @remarks Use translation phrase. This function will auto-translate it for all clients.
 *			If translation phrase won't be found during "L4V_Start" call, static description
 *			is used as a fallback, which is set with "L4V_SetDescription".
 *
 * @param phrase	The translation phrase from the file you specified in "L4V_AddTranslationFile".
 */
native void L4V_SetTranslatedDescription(const char[] phrase);

/**
 * @brief 	Sets the description for the successful vote.
 * @remarks This will use the static description you provided. If you want to use translated
 * 			phrases use "L4V_SetTranslatedSuccessDescription" instead.
 *
 * @param desc		The description to appear in the successful vote box.
 */
native void L4V_SetSuccessDescription(const char[] desc);

/**
 * @brief 	Sets the translated description for the successful vote.
 * @remarks Use translation phrase. This function will auto-translate it for all clients.
 *			If translation phrase won't be found during "L4V_Start" call, static description
 *			is used as a fallback, which is set with "L4V_SetSuccessDescription".
 *
 * @param phrase	The translation phrase from the file you specified in "L4V_AddTranslationFile".
 */
native void L4V_SetTranslatedSuccessDescription(const char[] phrase);

/**
 * @brief 	Sets the minimum ratio of "Yes" votes.
 * @remarks A vote is successful if the resulting vote poll of "Yes" votes is greater or equal
 * 			than the given ratio. For example, if you want to have that 80% of recieved votes must be yes,
 *			you must set ratio as 0.8. If you provide the value that is negative or
 *			higher than 1.0 (or dont provide it at all by not calling this native),
 *			it will be corrected to default value, which is 0.6.
 *
 * @param ratio		Ratio to set.
 */
native void L4V_SetSuccessVotesRatio(float ratio);

/**
 * @brief 	Starts the vote and sends it to all respective clients.
 * @remarks	IMPORTANT: note that regardless of return value, once you call this native everything you specified
 *			before will be erased (e.g. the descriptions and the allowed team you provided, etc),
 *			meaning that you will have to start building the vote again from "L4V_CreateVote" if this function returns false.
 *
 * @param client	Client who triggered the vote.
 * @param timeout	Optional parameter to finish the vote poll after this many seconds
 *					if not all clients voted. If anything less than 1 second is provided,
 *					it will be clamped to that value.
 *
 * @return			false if either client is invalid, vote is ongoing, "L4V_CreateVote" wasn't called
 *					or there are 0 actual players in the team specified by "L4V_SetAllowedTeam".
 */
native bool L4V_Start(int client, float timeout = 10.0);

/**
 * @brief 	Returns if the vote is in progress currently.
 *
 * @return			true if is in progress, false otherwise.
 */
native bool L4V_IsVoteInProgress();
